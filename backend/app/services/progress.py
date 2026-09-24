"""Progress by subject/topic, separately for each role."""
from typing import Dict, List

from sqlalchemy import case, func, select
from sqlalchemy.orm import Session

from app.models import (
    AttemptStatus,
    ClusterSubject,
    Language,
    Lesson,
    LessonProgress,
    Question,
    Subject,
    TestAttempt,
    TestType,
    Topic,
    User,
    UserAnswer,
    UserRole,
)
from app.models.content import topic_pool
from app.services.gamification import passed_topic_ids


def subjects_for_role(db: Session, user: User, role: UserRole) -> List[Subject]:
    if role == UserRole.ABITURIENT and user.abiturient_profile:
        return list(
            db.scalars(
                select(Subject)
                .join(ClusterSubject, ClusterSubject.subject_id == Subject.id)
                .where(ClusterSubject.cluster_id == user.abiturient_profile.cluster_id)
                .order_by(ClusterSubject.position, Subject.order, Subject.id)
            ).all()
        )
    if role == UserRole.SCHOOLBOY and user.school_profile:
        stmt = select(Subject).where(Subject.grade == user.school_profile.grade)
        return list(db.scalars(stmt.order_by(Subject.order, Subject.id)).all())
    return []


def lessons_by_topic(db: Session, topic_ids: List[int], lang: str) -> Dict[int, List[Lesson]]:
    """Lessons per topic in the content language, falling back to the other language per topic."""
    result: Dict[int, List[Lesson]] = {tid: [] for tid in topic_ids}
    if not topic_ids:
        return result
    all_lessons = db.scalars(
        select(Lesson).where(Lesson.topic_id.in_(topic_ids)).order_by(Lesson.order, Lesson.id)
    ).all()
    for tid in topic_ids:
        own = [lesson for lesson in all_lessons if lesson.topic_id == tid]
        preferred = [lesson for lesson in own if lesson.language == Language(lang)]
        result[tid] = preferred or own
    return result


def topics_with_questions(db: Session, topic_ids: List[int]) -> Dict[int, int]:
    if not topic_ids:
        return {}
    rows = db.execute(
        select(Question.topic_id, func.count(Question.id))
        .where(Question.topic_id.in_(topic_ids), topic_pool())
        .group_by(Question.topic_id)
    ).all()
    return {tid: count for tid, count in rows}


def completed_lesson_ids(db: Session, user_id: int, role: UserRole) -> set[int]:
    return set(
        db.scalars(
            select(LessonProgress.lesson_id).where(LessonProgress.user_id == user_id, LessonProgress.role == role)
        ).all()
    )


def best_topic_accuracy(db: Session, user_id: int, role: UserRole, topic_ids: List[int]) -> Dict[int, float]:
    if not topic_ids:
        return {}
    rows = db.execute(
        select(TestAttempt.reference_id, TestAttempt.correct_count, TestAttempt.total_count).where(
            TestAttempt.user_id == user_id,
            TestAttempt.role == role,
            TestAttempt.test_type == TestType.TOPIC_TEST,
            TestAttempt.status == AttemptStatus.FINISHED,
            TestAttempt.reference_id.in_(topic_ids),
        )
    ).all()
    best: Dict[int, float] = {}
    for ref, correct, total in rows:
        if total:
            best[ref] = max(best.get(ref, 0.0), correct / total)
    return best


def subject_progress(db: Session, user: User, role: UserRole, subject: Subject, lang: str) -> dict:
    topic_ids = list(db.scalars(select(Topic.id).where(Topic.subject_id == subject.id)).all())
    lessons = lessons_by_topic(db, topic_ids, lang)
    with_questions = topics_with_questions(db, topic_ids)
    done_lessons = completed_lesson_ids(db, user.id, role)
    passed = passed_topic_ids(db, user.id, role)

    total_items = sum(len(v) for v in lessons.values()) + len(with_questions)
    done_items = sum(1 for v in lessons.values() for lesson in v if lesson.id in done_lessons)
    done_items += sum(1 for tid in with_questions if tid in passed)

    correct, answered = db.execute(
        select(
            func.coalesce(func.sum(case((UserAnswer.is_correct.is_(True), 1), else_=0)), 0),
            func.count(UserAnswer.id),
        )
        .join(TestAttempt, TestAttempt.id == UserAnswer.attempt_id)
        .join(Question, Question.id == UserAnswer.question_id)
        .where(
            TestAttempt.user_id == user.id,
            TestAttempt.role == role,
            (Question.topic_id.in_(topic_ids)) | (Question.subject_id == subject.id),
        )
    ).one()

    return {
        "subject_id": subject.id,
        "title": subject.title_for(lang),
        "icon": subject.icon,
        "color": subject.color,
        "completed_items": done_items,
        "total_items": total_items,
        "percent": round(100 * done_items / total_items) if total_items else 0,
        "answered": int(answered or 0),
        "accuracy": round(100 * int(correct or 0) / answered) if answered else 0,
    }


def topic_progress(db: Session, user: User, role: UserRole, topics: List[Topic], lang: str) -> Dict[int, dict]:
    topic_ids = [t.id for t in topics]
    lessons = lessons_by_topic(db, topic_ids, lang)
    with_questions = topics_with_questions(db, topic_ids)
    done_lessons = completed_lesson_ids(db, user.id, role)
    best = best_topic_accuracy(db, user.id, role, topic_ids)
    result = {}
    for tid in topic_ids:
        topic_lessons = lessons.get(tid, [])
        lessons_done = sum(1 for lesson in topic_lessons if lesson.id in done_lessons)
        has_test = tid in with_questions
        accuracy = best.get(tid)
        passed = accuracy is not None and accuracy >= 0.7
        total = len(topic_lessons) + (1 if has_test else 0)
        done = lessons_done + (1 if passed else 0)
        result[tid] = {
            "lessons_total": len(topic_lessons),
            "lessons_completed": lessons_done,
            "questions_count": with_questions.get(tid, 0),
            "best_accuracy": round(accuracy * 100) if accuracy is not None else None,
            "passed": passed,
            "percent": round(100 * done / total) if total else 0,
        }
    return result
