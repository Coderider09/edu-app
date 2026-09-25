"""Test attempts: question selection, answer checking (official ЦВЭ rules), scoring and results."""
import random
import re
from datetime import datetime, timedelta, timezone
from typing import Any, List, Optional, Sequence

from fastapi import HTTPException, status
from sqlalchemy import and_, exists, select
from sqlalchemy.orm import Session

from app.models import (
    AttemptStatus,
    Cluster,
    ClusterSubject,
    ExamTest,
    Language,
    Lesson,
    MarkedQuestion,
    PointsReason,
    Question,
    QuestionType,
    Subject,
    TestAttempt,
    TestType,
    Topic,
    User,
    UserAnswer,
)
from app.models.content import topic_pool
from app.services import gamification as g
from app.services.cache import cache

TOPIC_TEST_MAX = 20
SECTION_TEST_MAX = 30
PRACTICE_DEFAULT = 10
MISTAKES_MAX = 20
SECONDS_PER_QUESTION = 60      # time limit of a timed topic/section test
TIME_GRACE_SECONDS = 15        # network latency allowance after the deadline
MISTAKES_LOOKBACK_DAYS = 60
EXAM_TYPES = (TestType.EXAM_TEST, TestType.MOCK_EXAM)
# Official subtest structure when a subject has none configured (ЦВЭ-2026, table 11.2)
DEFAULT_STRUCTURE = {"single": 20, "matching": 4, "numeric": 2}


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _aware(dt: Optional[datetime]) -> Optional[datetime]:
    # SQLite drops tzinfo; values are always stored in UTC
    if dt is not None and dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt


def _not_found(what: str) -> HTTPException:
    return HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"{what} not found")


def _in_language(db: Session, base_filter, lang: str) -> List[int]:
    """Question ids matching the filter in the requested language, falling back to the other."""
    stmt = select(Question.id).where(base_filter).order_by(Question.order, Question.id)
    ids = list(db.scalars(stmt.where(Question.language == Language(lang))).all())
    return ids or list(db.scalars(stmt).all())


def _sample(ids: Sequence[int], limit: int) -> List[int]:
    ids = list(ids)
    random.shuffle(ids)
    return ids[:limit]


# ------------------------------------------------------------------ grading
def _normalize_number(value: Any) -> Optional[str]:
    text = re.sub(r"\s+", "", str(value or "")).replace(",", ".")
    if not re.fullmatch(r"\d+(\.\d+)?", text):
        return None
    text = text.lstrip("0") or "0"
    if "." in text:
        text = text.rstrip("0").rstrip(".")
    return text


def grade(question: Question, answer: Any) -> tuple[int, bool]:
    """Official points («очки») for an answer and whether it is fully correct.

    single: 1 point; matching: 1 point per correct pair (max 4); numeric: 2 points.
    """
    key = question.answer_key
    qtype = question.question_type
    if key is None:
        return 0, False
    if qtype == QuestionType.SINGLE:
        ok = isinstance(answer, int) and answer in key
        return (1, True) if ok else (0, False)
    if qtype == QuestionType.MATCHING:
        if not isinstance(answer, list):
            return 0, False
        points = sum(1 for a, k in zip(answer, key, strict=False) if a == k)
        return points, points == len(key)
    expected = _normalize_number(key)
    ok = expected is not None and _normalize_number(answer) == expected
    return (2, True) if ok else (0, False)


def validate_answer(question: Question, selected_option_index: Optional[int], answer: Any) -> Any:
    """Check the answer shape for the question type; returns the normalized answer."""
    qtype = question.question_type
    bad = HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail="Invalid answer")
    if qtype == QuestionType.SINGLE:
        value = selected_option_index if selected_option_index is not None else answer
        if not isinstance(value, int) or not 0 <= value < len(question.options):
            raise bad
        return value
    if qtype == QuestionType.MATCHING:
        left = question.matching_left or []
        if (
            not isinstance(answer, list)
            or len(answer) != len(left)
            or not all(isinstance(a, int) and 0 <= a < len(question.options) for a in answer)
        ):
            raise bad
        return answer
    text = re.sub(r"\s+", "", str(answer if answer is not None else ""))
    if not re.fullmatch(r"\d{1,9}([.,]\d{1,4})?", text):
        raise bad
    return text


# ------------------------------------------------------------------ question selection
def _mistake_question_ids(db: Session, user_id: int) -> List[int]:
    """Marked questions + questions answered wrong recently and not answered right afterwards."""
    marked = list(
        db.scalars(
            select(MarkedQuestion.question_id)
            .where(MarkedQuestion.user_id == user_id)
            .order_by(MarkedQuestion.created_at.desc())
        ).all()
    )
    since = utcnow() - timedelta(days=MISTAKES_LOOKBACK_DAYS)
    wrong = db.execute(
        select(UserAnswer.question_id, UserAnswer.answered_at)
        .join(TestAttempt, TestAttempt.id == UserAnswer.attempt_id)
        .where(TestAttempt.user_id == user_id, UserAnswer.is_correct.is_(False), UserAnswer.answered_at >= since)
        .order_by(UserAnswer.answered_at.desc())
    ).all()
    fixed_later = {
        qid: _aware(at)
        for qid, at in db.execute(
            select(UserAnswer.question_id, UserAnswer.answered_at)
            .join(TestAttempt, TestAttempt.id == UserAnswer.attempt_id)
            .where(TestAttempt.user_id == user_id, UserAnswer.is_correct.is_(True), UserAnswer.answered_at >= since)
        ).all()
    }
    result: List[int] = []
    for qid in marked:
        if qid not in result:
            result.append(qid)
    for qid, at in wrong:
        fixed_at = fixed_later.get(qid)
        if qid in result or (fixed_at is not None and fixed_at >= _aware(at)):
            continue
        result.append(qid)
    return result


def mistake_question_ids(db: Session, user_id: int) -> List[int]:
    return _mistake_question_ids(db, user_id)


def exam_subtests(db: Session, cluster: Cluster, lang: str) -> List[ClusterSubject]:
    """A1..A4 of a cluster; at a position with alternatives the one of the exam language is taken."""
    by_position: dict[int, List[ClusterSubject]] = {}
    for link in cluster.subject_links:
        by_position.setdefault(link.position, []).append(link)
    chosen = []
    for position in sorted(by_position):
        links = by_position[position]
        match = [link for link in links if link.language_track == lang] or [
            link for link in links if link.language_track is None
        ] or links
        chosen.append(match[0])
    return chosen


def _mock_exam_questions(db: Session, cluster: Cluster, lang: str) -> List[int]:
    """Full ЦВЭ simulation: for every subtest the official number of tasks of each type.

    Only exam tasks (with subject_id set) are used — not the app's own theory questions. Tasks are
    taken in the exam language when the subject has them, so a subtest never mixes translations.
    """
    ids: List[int] = []
    for link in exam_subtests(db, cluster, lang):
        structure = link.subject.exam_structure or DEFAULT_STRUCTURE
        in_subject = and_(Question.subject_id == link.subject_id, topic_pool())
        if db.scalar(select(Question.id).where(in_subject, Question.language == Language(lang)).limit(1)):
            in_subject = and_(in_subject, Question.language == Language(lang))
        missing = 0
        per_type: dict[str, List[int]] = {}
        for qtype in (QuestionType.SINGLE, QuestionType.MATCHING, QuestionType.NUMERIC):
            pool = list(db.scalars(select(Question.id).where(in_subject, Question.question_type == qtype)).all())
            need = structure.get(qtype.value, 0)
            picked = _sample(pool, need)
            missing += need - len(picked)
            per_type[qtype.value] = picked
        if missing:  # e.g. no open tasks in the bank for this subject: fill with single-choice ones
            pool = list(
                db.scalars(
                    select(Question.id).where(
                        in_subject,
                        Question.question_type == QuestionType.SINGLE,
                        Question.id.not_in(per_type["single"]),
                    )
                ).all()
            )
            per_type["single"] += _sample(pool, missing)
        ids += per_type["single"] + per_type["matching"] + per_type["numeric"]
    return ids


def select_questions(
    db: Session, user: User, test_type: TestType, reference_id: Optional[int], lang: str,
    question_count: Optional[int],
) -> tuple[List[int], Optional[int]]:
    """Return (question ids, time limit in seconds for exams)."""
    exam_duration = None
    if test_type == TestType.TOPIC_TEST:
        topic = db.get(Topic, reference_id) if reference_id else None
        if topic is None:
            raise _not_found("Topic")
        ids = _in_language(db, and_(Question.topic_id == topic.id, topic_pool()), lang)
        ids = _sample(ids, min(question_count or TOPIC_TEST_MAX, TOPIC_TEST_MAX))
    elif test_type == TestType.SECTION_TEST:
        section = db.get(Topic, reference_id) if reference_id else None
        if section is None:
            raise _not_found("Section")
        topic_ids = [section.id] + [t.id for t in section.child_topics]
        ids = _in_language(db, and_(Question.topic_id.in_(topic_ids), topic_pool()), lang)
        ids = _sample(ids, min(question_count or SECTION_TEST_MAX, SECTION_TEST_MAX))
    elif test_type == TestType.PRACTICE:
        subject = db.get(Subject, reference_id) if reference_id else None
        if subject is None:
            raise _not_found("Subject")
        topic_ids = select(Topic.id).where(Topic.subject_id == subject.id)
        ids = _in_language(db, and_(Question.topic_id.in_(topic_ids), topic_pool()), lang)
        ids = _sample(ids, min(question_count or PRACTICE_DEFAULT, 50))
    elif test_type == TestType.EXAM_TEST:
        exam = db.get(ExamTest, reference_id) if reference_id else None
        if exam is None or not exam.is_published:
            raise _not_found("Exam test")
        # Immutable: the whole test in its fixed order, exactly as on the real exam
        ids = [q.id for q in exam.questions]
        exam_duration = exam.duration_minutes * 60
    elif test_type == TestType.MOCK_EXAM:
        cluster = db.get(Cluster, reference_id) if reference_id else None
        if cluster is None:
            raise _not_found("Cluster")
        ids = _mock_exam_questions(db, cluster, lang)
        exam_duration = cluster.duration_minutes * 60
    elif test_type == TestType.LESSON_CHECK:
        lesson = db.get(Lesson, reference_id) if reference_id else None
        if lesson is None:
            raise _not_found("Lesson")
        ids = [q.id for q in sorted(lesson.check_questions, key=lambda q: (q.order, q.id))]
    elif test_type == TestType.MISTAKES:
        ids = _mistake_question_ids(db, user.id)[: question_count or MISTAKES_MAX]
    else:  # pragma: no cover
        raise HTTPException(status_code=400, detail="Unknown test type")

    if not ids:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No questions available")
    return ids, exam_duration


# ------------------------------------------------------------------ attempts
def start_attempt(
    db: Session, user: User, test_type: TestType, reference_id: Optional[int], lang: str,
    timed: bool = False, question_count: Optional[int] = None,
) -> TestAttempt:
    role = user.active_role
    if test_type != TestType.MISTAKES:
        existing = db.scalar(
            select(TestAttempt)
            .where(
                TestAttempt.user_id == user.id,
                TestAttempt.role == role,
                TestAttempt.test_type == test_type,
                TestAttempt.reference_id == reference_id,
                TestAttempt.status == AttemptStatus.IN_PROGRESS,
            )
            .order_by(TestAttempt.id.desc())
        )
        # Resume an unfinished attempt (e.g. after the app was closed or went offline)
        if existing is not None:
            if not is_expired(existing):
                return existing
            finish_attempt(db, user, existing)

    ids, exam_duration = select_questions(db, user, test_type, reference_id, lang, question_count)
    max_points = sum(q.max_points for q in ordered_questions(db, ids))
    now = utcnow()
    attempt = TestAttempt(
        user_id=user.id,
        role=role,
        test_type=test_type,
        reference_id=reference_id,
        question_ids=ids,
        total_count=len(ids),
        max_points=max_points,
        started_at=now,
    )
    if exam_duration is not None:
        attempt.is_timed = True
        attempt.expires_at = now + timedelta(seconds=exam_duration)
    elif timed and test_type in (TestType.TOPIC_TEST, TestType.SECTION_TEST):
        attempt.is_timed = True
        attempt.expires_at = now + timedelta(seconds=SECONDS_PER_QUESTION * len(ids))
    db.add(attempt)
    db.commit()
    db.refresh(attempt)
    return attempt


def is_expired(attempt: TestAttempt, now: Optional[datetime] = None) -> bool:
    if not attempt.is_timed or attempt.expires_at is None:
        return False
    return (now or utcnow()) > _aware(attempt.expires_at) + timedelta(seconds=TIME_GRACE_SECONDS)


def get_user_attempt(db: Session, user: User, attempt_id: int) -> TestAttempt:
    attempt = db.get(TestAttempt, attempt_id)
    if attempt is None or attempt.user_id != user.id:
        raise _not_found("Attempt")
    return attempt


def submit_answer(
    db: Session, user: User, attempt: TestAttempt, question_id: int,
    selected_option_index: Optional[int] = None, answer: Any = None,
) -> tuple[UserAnswer, Question]:
    if attempt.status != AttemptStatus.IN_PROGRESS:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Attempt is already finished")
    if is_expired(attempt):
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Time is up")
    if question_id not in attempt.question_ids:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Question is not part of this attempt")
    if any(a.question_id == question_id for a in attempt.user_answers):
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Question already answered")
    question = db.get(Question, question_id)
    if question is None:
        raise _not_found("Question")

    value = validate_answer(question, selected_option_index, answer)
    record = record_answer(db, user, attempt, question, value, utcnow())
    db.commit()
    db.refresh(record)
    return record, question


def record_answer(
    db: Session, user: User, attempt: TestAttempt, question: Question, value: Any, answered_at: datetime
) -> UserAnswer:
    """Grade a validated answer and credit points (shared by online answers and /sync)."""
    official, is_correct = grade(question, value)
    base, bonus = g.points_for_answer(is_correct, attempt.answer_streak, official)
    attempt.answer_streak = attempt.answer_streak + 1 if is_correct else 0
    record = UserAnswer(
        attempt_id=attempt.id,
        question_id=question.id,
        selected_option_index=value if question.question_type == QuestionType.SINGLE else None,
        answer=None if question.question_type == QuestionType.SINGLE else value,
        is_correct=is_correct,
        points=official,
        points_awarded=base + bonus,
        answered_at=answered_at,
    )
    attempt.user_answers.append(record)
    if is_correct:
        attempt.correct_count += 1
    attempt.points += official
    attempt.score += base + bonus
    # Exam points are credited at finish so the running score does not hint at correctness
    if attempt.test_type not in EXAM_TYPES:
        g.add_points(db, user, attempt.role, base, PointsReason.CORRECT_ANSWER, attempt.id)
        g.add_points(db, user, attempt.role, bonus, PointsReason.STREAK_BONUS, attempt.id)
    g.register_activity(user, answered_at)
    return record


def exam_breakdown(db: Session, attempt: TestAttempt) -> dict:
    """Per-subtest official points and the estimated score on the 500-point scale."""
    questions = ordered_questions(db, attempt.question_ids)
    answers = {a.question_id: a for a in attempt.user_answers}
    cluster_id = None
    if attempt.test_type == TestType.MOCK_EXAM:
        cluster_id = attempt.reference_id
    elif attempt.test_type == TestType.EXAM_TEST:
        exam = db.get(ExamTest, attempt.reference_id)
        cluster_id = exam.cluster_id if exam else None
    links = {
        link.subject_id: link
        for link in db.scalars(select(ClusterSubject).where(ClusterSubject.cluster_id == cluster_id)).all()
    }
    subtests: dict[Optional[int], dict] = {}
    for q in questions:
        subject_id = q.subject_id or (q.topic.subject_id if q.topic else None)
        link = links.get(subject_id)
        entry = subtests.setdefault(subject_id, {
            "subject_id": subject_id,
            "position": link.position if link else 9,
            "points": 0,
            "max_points": 0,
            "correct": 0,
            "total": 0,
            "max_score": link.max_score if link else 0,
        })
        a = answers.get(q.id)
        entry["points"] += a.points if a else 0
        entry["max_points"] += q.max_points
        entry["correct"] += 1 if a and a.is_correct else 0
        entry["total"] += 1
    result = sorted(subtests.values(), key=lambda e: e["position"])
    for e in result:
        e["score"] = round(g.scale_subtest(e["points"], e["max_points"], e["max_score"]), 1)
    return {"subtests": result, "total": g.estimate_mmt_score(result), "max_total": g.MMT_MAX}


def finish_attempt(
    db: Session, user: User, attempt: TestAttempt, finished_at: Optional[datetime] = None
) -> dict:
    """Close the attempt (idempotent) and return points/achievements earned by finishing."""
    if attempt.status == AttemptStatus.FINISHED:
        return {"completion_bonus": 0, "achievements": []}

    attempt.status = AttemptStatus.FINISHED
    attempt.finished_at = finished_at or utcnow()
    attempt.total_count = len(attempt.question_ids)

    if attempt.test_type in EXAM_TYPES:
        details = exam_breakdown(db, attempt)
        attempt.details = details
        attempt.mmt_score = details["total"]
        earned = sum(a.points_awarded for a in attempt.user_answers)
        base = sum(a.points * g.BASE_POINTS for a in attempt.user_answers)
        g.add_points(db, user, attempt.role, base, PointsReason.CORRECT_ANSWER, attempt.id)
        g.add_points(db, user, attempt.role, earned - base, PointsReason.STREAK_BONUS, attempt.id)

    # Completion bonus only for the first finished attempt of the same test (no farming)
    bonus = 0
    if attempt.user_answers:
        repeated = db.scalar(
            select(
                exists().where(
                    TestAttempt.user_id == user.id,
                    TestAttempt.role == attempt.role,
                    TestAttempt.test_type == attempt.test_type,
                    TestAttempt.reference_id == attempt.reference_id
                    if attempt.reference_id is not None else TestAttempt.reference_id.is_(None),
                    TestAttempt.status == AttemptStatus.FINISHED,
                    TestAttempt.id != attempt.id,
                )
            )
        )
        if not repeated:
            bonus = g.COMPLETION_BONUS.get(attempt.test_type, 0)
            g.add_points(db, user, attempt.role, bonus, PointsReason.TEST_COMPLETION, attempt.id)
            attempt.score += bonus

    achievements = g.check_achievements(db, user, attempt)
    attempt.score += sum(a.points_reward for a in achievements)
    db.commit()
    db.refresh(attempt)
    cache.invalidate_prefix("leaderboard:")
    return {"completion_bonus": bonus, "achievements": achievements}


def marked_ids(db: Session, user_id: int, question_ids: Sequence[int]) -> set[int]:
    if not question_ids:
        return set()
    return set(
        db.scalars(
            select(MarkedQuestion.question_id).where(
                MarkedQuestion.user_id == user_id, MarkedQuestion.question_id.in_(list(question_ids))
            )
        ).all()
    )


def ordered_questions(db: Session, ids: Sequence[int]) -> List[Question]:
    by_id = {q.id: q for q in db.scalars(select(Question).where(Question.id.in_(list(ids)))).all()}
    return [by_id[i] for i in ids if i in by_id]
