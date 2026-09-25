from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.api.v1.serializers import attempt_out, correct_single_index, question_out, result_out, shows_feedback
from app.core.deps import get_content_language, get_onboarded_user
from app.db.database import get_db
from app.models import AttemptStatus, MarkedQuestion, Question, TestType, User
from app.schemas.testing import AnswerIn, AnswerResult, AttemptCreate, AttemptOut, AttemptResult, QuestionOut
from app.services import testing as svc
from app.services.gamification import BASE_POINTS

router = APIRouter()


@router.post("/attempts", response_model=AttemptOut, status_code=status.HTTP_201_CREATED)
def start_attempt(
    data: AttemptCreate,
    user: User = Depends(get_onboarded_user),
    lang: str = Depends(get_content_language),
    db: Session = Depends(get_db),
):
    """Start (or resume an unfinished) attempt. Questions come without correct answers.

    - `topic_test` — reference_id = topic id, optional `timed`
    - `section_test` — reference_id = section (root topic) id, final test of a section/quarter
    - `practice` — reference_id = subject id, untimed training with explanations
    - `exam_test` — reference_id = fixed exam test (created in the admin panel); timed, feedback only after finishing
    - `mock_exam` — reference_id = cluster id; a full ЦВЭ generated from the app's own task bank
      (4 subtests with the official number of tasks of each type, official duration)
    - `lesson_check` — reference_id = lesson id
    - `mistakes` — "Повторить ошибки", no reference_id
    """
    attempt = svc.start_attempt(
        db, user, TestType(data.test_type), data.reference_id, lang, data.timed, data.question_count
    )
    return attempt_out(db, user, attempt)


@router.get("/attempts/{attempt_id}", response_model=AttemptOut)
def get_attempt(attempt_id: int, user: User = Depends(get_onboarded_user), db: Session = Depends(get_db)):
    """Current state of an attempt, used to resume it."""
    return attempt_out(db, user, svc.get_user_attempt(db, user, attempt_id))


@router.post("/attempts/{attempt_id}/answer", response_model=AnswerResult)
def submit_answer(
    attempt_id: int,
    data: AnswerIn,
    user: User = Depends(get_onboarded_user),
    db: Session = Depends(get_db),
):
    attempt = svc.get_user_attempt(db, user, attempt_id)
    try:
        answer, question = svc.submit_answer(
            db, user, attempt, data.question_id, data.selected_option_index, data.answer
        )
    except IntegrityError:  # the same answer sent twice concurrently
        db.rollback()
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Question already answered") from None
    result = AnswerResult(
        question_id=question.id,
        answered_count=len(attempt.user_answers),
        total_count=len(attempt.question_ids),
    )
    if shows_feedback(attempt):
        result.is_correct = answer.is_correct
        result.points = answer.points
        result.max_points = question.max_points
        result.correct_option_index = correct_single_index(question)
        result.correct_answer = question.answer_key
        result.explanation = question.explanation
        result.points_awarded = answer.points_awarded
        result.streak_bonus = answer.points_awarded > answer.points * BASE_POINTS
        result.answer_streak = attempt.answer_streak
        result.attempt_score = attempt.score
    return result


@router.post("/attempts/{attempt_id}/finish", response_model=AttemptResult)
def finish_attempt(
    attempt_id: int,
    user: User = Depends(get_onboarded_user),
    lang: str = Depends(get_content_language),
    db: Session = Depends(get_db),
):
    """Finish the attempt: result, earned points, MMT score estimate, new achievements, full review."""
    attempt = svc.get_user_attempt(db, user, attempt_id)
    earned = svc.finish_attempt(db, user, attempt)
    return result_out(db, user, attempt, lang, earned["completion_bonus"], earned["achievements"])


@router.get("/attempts/{attempt_id}/result", response_model=AttemptResult)
def get_result(
    attempt_id: int,
    user: User = Depends(get_onboarded_user),
    lang: str = Depends(get_content_language),
    db: Session = Depends(get_db),
):
    attempt = svc.get_user_attempt(db, user, attempt_id)
    if attempt.status != AttemptStatus.FINISHED:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Attempt is not finished")
    return result_out(db, user, attempt, lang)


@router.post("/questions/{question_id}/mark", status_code=status.HTTP_204_NO_CONTENT)
def mark_question(question_id: int, user: User = Depends(get_onboarded_user), db: Session = Depends(get_db)):
    """Mark a question as "сложный / на повтор"."""
    if db.get(Question, question_id) is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Question not found")
    exists = db.scalar(
        select(MarkedQuestion.id).where(MarkedQuestion.user_id == user.id, MarkedQuestion.question_id == question_id)
    )
    if not exists:
        db.add(MarkedQuestion(user_id=user.id, question_id=question_id))
        try:
            db.commit()
        except IntegrityError:
            db.rollback()


@router.delete("/questions/{question_id}/mark", status_code=status.HTTP_204_NO_CONTENT)
def unmark_question(question_id: int, user: User = Depends(get_onboarded_user), db: Session = Depends(get_db)):
    marked = db.scalar(
        select(MarkedQuestion).where(MarkedQuestion.user_id == user.id, MarkedQuestion.question_id == question_id)
    )
    if marked:
        db.delete(marked)
        db.commit()


@router.get("/review/questions", response_model=List[QuestionOut])
def review_questions(
    limit: int = Query(default=50, ge=1, le=200),
    user: User = Depends(get_onboarded_user),
    db: Session = Depends(get_db),
):
    """The "Повторить ошибки" pool: marked questions and recent mistakes."""
    ids = svc.mistake_question_ids(db, user.id)[:limit]
    marked = svc.marked_ids(db, user.id, ids)
    return [question_out(q, marked) for q in svc.ordered_questions(db, ids)]
