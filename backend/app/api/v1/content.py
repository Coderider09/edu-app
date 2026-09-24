from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.api.v1.serializers import cluster_out, subject_out
from app.core.deps import get_content_language, get_onboarded_user
from app.db.database import get_db
from app.models import (
    AttemptStatus,
    Cluster,
    ExamTest,
    Lesson,
    LessonProgress,
    Question,
    Subject,
    TestAttempt,
    TestType,
    Topic,
    User,
)
from app.models.content import topic_pool
from app.schemas.content import (
    ExamTestOut,
    LessonOut,
    SectionOut,
    SubjectOut,
    SubjectTopicsOut,
    TopicOut,
    TopicProgressOut,
    TopicTestOut,
)
from app.services import gamification as g
from app.services.progress import lessons_by_topic, subject_progress, topic_progress
from app.services.testing import DEFAULT_STRUCTURE, SECONDS_PER_QUESTION, TOPIC_TEST_MAX, exam_subtests

router = APIRouter()


def _get_or_404(db: Session, model, obj_id: int, name: str):
    obj = db.get(model, obj_id)
    if obj is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"{name} not found")
    return obj


@router.get("/clusters/{cluster_id}")
def get_cluster(
    cluster_id: int,
    user: User = Depends(get_onboarded_user),
    lang: str = Depends(get_content_language),
    db: Session = Depends(get_db),
) -> dict:
    """Cluster screen: subjects (subtests A1–A4) with progress, the mock ЦВЭ and fixed exam tests."""
    cluster = _get_or_404(db, Cluster, cluster_id, "Cluster")
    subjects = []
    for link in cluster.subject_links:
        p = subject_progress(db, user, user.active_role, link.subject, lang)
        subjects.append(subject_out(link.subject, lang, p["percent"], cluster.id, link.position))
    data = cluster_out(cluster, lang).model_dump()
    data["subjects"] = [s.model_dump() for s in subjects]
    data["mock_exam"] = mock_exam_info(db, cluster, lang)
    data["exam_tests"] = [e.model_dump() for e in _exam_tests(db, user, cluster_id, None)]
    return data


def mock_exam_info(db: Session, cluster: Cluster, lang: str) -> dict:
    """Structure of the full ЦВЭ simulation of a cluster (official subtests, task counts, duration)."""
    subtests = []
    for link in exam_subtests(db, cluster, lang):
        structure = link.subject.exam_structure or DEFAULT_STRUCTURE
        subtests.append({
            "position": link.position,
            "subject_id": link.subject_id,
            "title": link.subject.title_for(lang),
            "questions": sum(structure.values()),
            "max_score": link.max_score,
        })
    return {
        "cluster_id": cluster.id,
        "duration_minutes": cluster.duration_minutes,
        "questions": sum(s["questions"] for s in subtests),
        "max_score": sum(s["max_score"] for s in subtests),
        "subtests": subtests,
    }


@router.get("/subjects/{subject_id}/topics", response_model=SubjectTopicsOut)
def get_subject_topics(
    subject_id: int,
    user: User = Depends(get_onboarded_user),
    lang: str = Depends(get_content_language),
    db: Session = Depends(get_db),
):
    """Subject tree: sections (раздел/четверть) → topics, with the user's progress."""
    subject = _get_or_404(db, Subject, subject_id, "Subject")
    all_topics = list(
        db.scalars(select(Topic).where(Topic.subject_id == subject.id).order_by(Topic.order, Topic.id)).all()
    )
    progress = topic_progress(db, user, user.active_role, all_topics, lang)
    roots = [t for t in all_topics if t.parent_topic_id is None]

    def topic_out(t: Topic) -> TopicOut:
        return TopicOut(
            id=t.id, title=t.title_for(lang), order=t.order, parent_topic_id=t.parent_topic_id,
            progress=TopicProgressOut(**progress[t.id]),
        )

    sections: List[SectionOut] = []
    for root in roots:
        children = [t for t in all_topics if t.parent_topic_id == root.id]
        child_progress = [progress[c.id]["percent"] for c in children]
        section_progress = TopicProgressOut(**progress[root.id])
        if children:
            section_progress.percent = round(sum(child_progress) / len(child_progress))
        questions_in_section = progress[root.id]["questions_count"] + sum(
            progress[c.id]["questions_count"] for c in children
        )
        sections.append(
            SectionOut(
                id=root.id,
                title=root.title_for(lang),
                order=root.order,
                has_final_test=bool(children) and questions_in_section > 0,
                topics=[topic_out(c) for c in children] if children else [topic_out(root)],
                progress=section_progress,
            )
        )
    percent = subject_progress(db, user, user.active_role, subject, lang)["percent"]
    return SubjectTopicsOut(subject=subject_out(subject, lang, percent), sections=sections)


def _lesson_out(db: Session, lesson: Lesson, completed: set[int]) -> LessonOut:
    check_count = db.scalar(select(func.count(Question.id)).where(Question.lesson_id == lesson.id)) or 0
    return LessonOut(
        id=lesson.id,
        topic_id=lesson.topic_id,
        title=lesson.title,
        content=lesson.content,
        language=lesson.language.value,
        media_urls=list(lesson.media_urls or []),
        video_url=lesson.video_url,
        order=lesson.order,
        check_questions_count=check_count,
        completed=lesson.id in completed,
    )


def _completed_lessons(db: Session, user: User) -> set[int]:
    return set(
        db.scalars(
            select(LessonProgress.lesson_id).where(
                LessonProgress.user_id == user.id, LessonProgress.role == user.active_role
            )
        ).all()
    )


@router.get("/topics/{topic_id}/lessons", response_model=List[LessonOut])
def get_topic_lessons(
    topic_id: int,
    user: User = Depends(get_onboarded_user),
    lang: str = Depends(get_content_language),
    db: Session = Depends(get_db),
):
    _get_or_404(db, Topic, topic_id, "Topic")
    completed = _completed_lessons(db, user)
    return [_lesson_out(db, lesson, completed) for lesson in lessons_by_topic(db, [topic_id], lang)[topic_id]]


@router.get("/lessons/{lesson_id}", response_model=LessonOut)
def get_lesson(lesson_id: int, user: User = Depends(get_onboarded_user), db: Session = Depends(get_db)):
    lesson = _get_or_404(db, Lesson, lesson_id, "Lesson")
    return _lesson_out(db, lesson, _completed_lessons(db, user))


@router.post("/lessons/{lesson_id}/complete", response_model=LessonOut)
def complete_lesson(lesson_id: int, user: User = Depends(get_onboarded_user), db: Session = Depends(get_db)):
    """Mark a lesson as read (counts towards subject progress and the daily streak)."""
    lesson = _get_or_404(db, Lesson, lesson_id, "Lesson")
    if lesson.id not in _completed_lessons(db, user):
        db.add(LessonProgress(user_id=user.id, lesson_id=lesson.id, role=user.active_role))
        g.register_activity(user)
        try:
            db.commit()
        except IntegrityError:  # concurrent double tap
            db.rollback()
    return _lesson_out(db, lesson, _completed_lessons(db, user))


@router.get("/topics/{topic_id}/tests", response_model=List[TopicTestOut])
def get_topic_tests(
    topic_id: int,
    user: User = Depends(get_onboarded_user),
    lang: str = Depends(get_content_language),
    db: Session = Depends(get_db),
):
    topic = _get_or_404(db, Topic, topic_id, "Topic")
    count = db.scalar(
        select(func.count(Question.id)).where(Question.topic_id == topic.id, topic_pool())
    ) or 0
    if count == 0:
        return []
    attempts = db.execute(
        select(TestAttempt.correct_count, TestAttempt.total_count).where(
            TestAttempt.user_id == user.id,
            TestAttempt.role == user.active_role,
            TestAttempt.test_type == TestType.TOPIC_TEST,
            TestAttempt.reference_id == topic.id,
            TestAttempt.status == AttemptStatus.FINISHED,
        )
    ).all()
    best = max((round(100 * c / t) for c, t in attempts if t), default=None)
    return [
        TopicTestOut(
            topic_id=topic.id,
            title=topic.title_for(lang),
            questions_count=count,
            default_question_count=min(count, TOPIC_TEST_MAX),
            time_limit_seconds_per_question=SECONDS_PER_QUESTION,
            best_accuracy=best,
            attempts_count=len(attempts),
        )
    ]


def _exam_tests(db: Session, user: User, cluster_id: Optional[int], year: Optional[int]) -> List[ExamTestOut]:
    counts = (
        select(Question.exam_test_id, func.count(Question.id).label("n"))
        .where(Question.exam_test_id.is_not(None))
        .group_by(Question.exam_test_id)
        .subquery()
    )
    stmt = (
        select(ExamTest, func.coalesce(counts.c.n, 0))
        .outerjoin(counts, counts.c.exam_test_id == ExamTest.id)
        .where(ExamTest.is_published.is_(True))
    )
    if cluster_id is not None:
        stmt = stmt.where(ExamTest.cluster_id == cluster_id)
    if year is not None:
        stmt = stmt.where(ExamTest.year == year)
    rows = db.execute(stmt.order_by(ExamTest.year.desc(), ExamTest.id)).all()

    best_scores = dict(
        db.execute(
            select(TestAttempt.reference_id, func.max(TestAttempt.mmt_score))
            .where(
                TestAttempt.user_id == user.id,
                TestAttempt.test_type == TestType.EXAM_TEST,
                TestAttempt.status == AttemptStatus.FINISHED,
            )
            .group_by(TestAttempt.reference_id)
        ).all()
    )
    return [
        ExamTestOut(
            id=e.id, cluster_id=e.cluster_id, year=e.year, title=e.title, language=e.language.value,
            duration_minutes=e.duration_minutes, total_questions=n, best_mmt_score=best_scores.get(e.id),
        )
        for e, n in rows
        if n > 0
    ]


@router.get("/exam-tests", response_model=List[ExamTestOut])
def get_exam_tests(
    cluster_id: Optional[int] = None,
    year: Optional[int] = None,
    user: User = Depends(get_onboarded_user),
    db: Session = Depends(get_db),
):
    """Past-year MMT tests (архив по годам)."""
    if cluster_id is None and user.abiturient_profile:
        cluster_id = user.abiturient_profile.cluster_id
    return _exam_tests(db, user, cluster_id, year)


@router.get("/subjects/{subject_id}/summary", response_model=SubjectOut)
def get_subject(
    subject_id: int,
    user: User = Depends(get_onboarded_user),
    lang: str = Depends(get_content_language),
    db: Session = Depends(get_db),
):
    subject = _get_or_404(db, Subject, subject_id, "Subject")
    return subject_out(subject, lang, subject_progress(db, user, user.active_role, subject, lang)["percent"])
