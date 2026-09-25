"""Upload of work done offline: tests taken from downloaded packs, read lessons, marks.

The client's own grading is never trusted: every answer is re-graded with the server keys,
points and streaks are computed exactly as for online answers, in the order the answers were given.
Uploads are idempotent by the attempt's `client_id`, so the app can safely retry after a network error.
"""
from datetime import datetime, timedelta
from typing import Optional

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.models import (
    Cluster,
    Lesson,
    LessonProgress,
    MarkedQuestion,
    Question,
    Subject,
    TestAttempt,
    TestType,
    Topic,
    User,
)
from app.schemas.offline import SyncAttempt, SyncAttemptResult, SyncIn
from app.services import gamification as g
from app.services import testing as t

MAX_AGE_DAYS = 60  # older offline work is still saved, but dated no earlier than this
REFERENCE_MODELS = {
    TestType.TOPIC_TEST: Topic,
    TestType.SECTION_TEST: Topic,
    TestType.PRACTICE: Subject,
    TestType.MOCK_EXAM: Cluster,
    TestType.LESSON_CHECK: Lesson,
}


def _clamp(value: datetime, now: datetime, earliest: Optional[datetime] = None) -> datetime:
    value = t._aware(value)
    lower = earliest or now - timedelta(days=MAX_AGE_DAYS)
    return min(max(value, lower), now)


def _result(attempt: TestAttempt, status: str) -> SyncAttemptResult:
    return SyncAttemptResult(
        client_id=attempt.client_id,
        status=status,
        attempt_id=attempt.id,
        score=attempt.score,
        points=attempt.points,
        max_points=attempt.max_points,
        correct_count=attempt.correct_count,
        total_count=attempt.total_count,
        mmt_score=attempt.mmt_score,
    )


def _find(db: Session, user: User, client_id: str) -> Optional[TestAttempt]:
    return db.scalar(select(TestAttempt).where(TestAttempt.user_id == user.id, TestAttempt.client_id == client_id))


def sync_attempt(db: Session, user: User, item: SyncAttempt, now: datetime) -> SyncAttemptResult:
    existing = _find(db, user, item.client_id)
    if existing is not None:
        return _result(existing, "duplicate")

    test_type = TestType(item.test_type)
    model = REFERENCE_MODELS.get(test_type)
    if model is not None and (item.reference_id is None or db.get(model, item.reference_id) is None):
        return SyncAttemptResult(client_id=item.client_id, status="rejected", detail="Unknown reference")

    # Only questions that are shipped in packs (fixed official samples stay online-only)
    ids = list(dict.fromkeys(item.question_ids))
    questions = {
        q.id: q
        for q in db.scalars(select(Question).where(Question.id.in_(ids), Question.exam_test_id.is_(None))).all()
    }
    ids = [qid for qid in ids if qid in questions]
    if not ids:
        return SyncAttemptResult(client_id=item.client_id, status="rejected", detail="No known questions")

    started_at = _clamp(item.started_at, now)
    attempt = TestAttempt(
        user_id=user.id,
        client_id=item.client_id,
        role=user.active_role,
        test_type=test_type,
        reference_id=item.reference_id,
        question_ids=ids,
        total_count=len(ids),
        max_points=sum(questions[qid].max_points for qid in ids),
        started_at=started_at,
    )
    if test_type == TestType.MOCK_EXAM:
        attempt.is_timed = True
        attempt.expires_at = started_at + timedelta(minutes=db.get(Cluster, item.reference_id).duration_minutes)
    db.add(attempt)
    try:
        db.flush()
    except IntegrityError:  # the same upload is being processed concurrently
        db.rollback()
        existing = _find(db, user, item.client_id)
        if existing is None:
            raise
        return _result(existing, "duplicate")

    seen: set[int] = set()
    for answer in sorted(item.answers, key=lambda a: t._aware(a.answered_at)):
        question = questions.get(answer.question_id)
        if question is None or question.id in seen:
            continue
        answered_at = _clamp(answer.answered_at, now, earliest=started_at)
        if t.is_expired(attempt, answered_at):
            continue
        try:
            value = t.validate_answer(question, None, answer.answer)
        except HTTPException:
            continue
        seen.add(question.id)
        t.record_answer(db, user, attempt, question, value, answered_at)

    finished_at = _clamp(item.finished_at, now, earliest=started_at)
    t.finish_attempt(db, user, attempt, finished_at)  # commits
    return _result(attempt, "created")


def sync_lessons(db: Session, user: User, data: SyncIn, now: datetime) -> int:
    done = set(
        db.scalars(
            select(LessonProgress.lesson_id).where(
                LessonProgress.user_id == user.id, LessonProgress.role == user.active_role
            )
        ).all()
    )
    saved = 0
    for item in sorted(data.lessons, key=lambda x: t._aware(x.completed_at)):
        if item.lesson_id in done or db.get(Lesson, item.lesson_id) is None:
            continue
        completed_at = _clamp(item.completed_at, now)
        db.add(LessonProgress(user_id=user.id, lesson_id=item.lesson_id, role=user.active_role,
                              completed_at=completed_at))
        g.register_activity(user, completed_at)
        done.add(item.lesson_id)
        saved += 1
    return saved


def sync_marks(db: Session, user: User, data: SyncIn) -> None:
    ids = set(data.marked) | set(data.unmarked)
    if not ids:
        return
    current = {
        m.question_id: m
        for m in db.scalars(
            select(MarkedQuestion).where(MarkedQuestion.user_id == user.id, MarkedQuestion.question_id.in_(ids))
        ).all()
    }
    known = set(db.scalars(select(Question.id).where(Question.id.in_(ids))).all())
    for qid in set(data.marked) - set(data.unmarked):
        if qid in known and qid not in current:
            db.add(MarkedQuestion(user_id=user.id, question_id=qid))
    for qid in set(data.unmarked) - set(data.marked):
        if qid in current:
            db.delete(current[qid])


def sync(db: Session, user: User, data: SyncIn) -> dict:
    now = t.utcnow()
    # Lessons first: reading usually precedes the tests of the same session
    lessons_saved = sync_lessons(db, user, data, now)
    sync_marks(db, user, data)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
    results = [
        sync_attempt(db, user, item, now)
        for item in sorted(data.attempts, key=lambda a: t._aware(a.finished_at))
    ]
    return {"attempts": results, "lessons_saved": lessons_saved, "server_time": now}

