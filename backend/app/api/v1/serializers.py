"""ORM -> response schema conversion (localization lives here, not in the models)."""
from typing import List, Optional

from sqlalchemy.orm import Session

from app.models import (
    Achievement,
    Cluster,
    Question,
    QuestionType,
    Subject,
    TestAttempt,
    User,
    UserRole,
)
from app.schemas.content import ClusterOut, SubjectOut
from app.schemas.testing import (
    AchievementBrief,
    AnsweredOut,
    AttemptOut,
    AttemptResult,
    QuestionOut,
    ReviewItem,
    SubjectBreakdown,
)
from app.schemas.user import AbiturientProfileOut, LevelOut, ProfileOut, SchoolProfileOut
from app.services import gamification as g
from app.services.testing import EXAM_TYPES, exam_breakdown, marked_ids, ordered_questions, utcnow


def subject_out(
    subject: Subject, lang: str, progress_percent: Optional[int] = None, cluster_id: Optional[int] = None,
    position: Optional[int] = None,
) -> SubjectOut:
    return SubjectOut(
        id=subject.id,
        code=subject.code,
        title=subject.title_for(lang),
        icon=subject.icon,
        color=subject.color,
        cluster_id=cluster_id,
        position=position,
        grade=subject.grade,
        progress_percent=progress_percent,
    )


def cluster_out(cluster: Cluster, lang: str, with_subjects: bool = False) -> ClusterOut:
    return ClusterOut(
        id=cluster.id,
        code=cluster.code,
        title=cluster.title_for(lang),
        description=cluster.description_for(lang),
        icon=cluster.icon,
        order=cluster.order,
        duration_minutes=cluster.duration_minutes,
        subjects=[
            subject_out(link.subject, lang, cluster_id=cluster.id, position=link.position)
            for link in cluster.subject_links
        ] if with_subjects else [],
    )


def profile_out(db: Session, user: User) -> ProfileOut:
    lang = user.language.value if user.language else "tj"
    total = g.total_points(db, user.id)
    role_points = g.total_points(db, user.id, user.active_role) if user.active_role else 0
    abiturient = None
    if user.abiturient_profile:
        p = user.abiturient_profile
        abiturient = AbiturientProfileOut(
            cluster_id=p.cluster_id,
            cluster_title=p.cluster.title_for(lang) if p.cluster else None,
            backup_cluster_id=p.backup_cluster_id,
            target_year=p.target_year,
            region=p.region,
        )
    school = None
    if user.school_profile:
        p = user.school_profile
        school = SchoolProfileOut(
            grade=p.grade, school_name=p.school_name, language_of_study=p.language_of_study.value
        )
    return ProfileOut(
        id=user.id,
        email=user.email,
        phone=user.phone,
        name=user.name,
        avatar_id=user.avatar_id,
        language=lang,
        theme=user.theme.value if user.theme else "system",
        notifications_enabled=user.notifications_enabled,
        roles=[r.value for r in user.role_list],
        active_role=user.active_role.value if user.active_role else None,
        is_admin=user.admin_role is not None,
        abiturient=abiturient,
        school=school,
        total_points=total,
        role_points=role_points,
        level=LevelOut(**g.level_for_points(total)),
        current_streak=g.effective_streak(user),
        longest_streak=user.longest_streak or 0,
        last_activity_date=user.last_activity_date,
        created_at=user.created_at,
    )


def shows_feedback(attempt: TestAttempt) -> bool:
    """Exams reproduce the real ЦВЭ: no correctness/explanations until the end."""
    return attempt.test_type not in EXAM_TYPES


def correct_single_index(q: Question) -> Optional[int]:
    key = q.answer_key
    if q.question_type == QuestionType.SINGLE and isinstance(key, list) and key:
        return key[0]
    return None


def question_out(q: Question, marked: set[int]) -> QuestionOut:
    return QuestionOut(
        id=q.id,
        question_type=q.question_type.value,
        passage=q.passage,
        text=q.text,
        image_url=q.image_url,
        options=list(q.options or []),
        matching_left=list(q.matching_left) if q.matching_left else None,
        max_points=q.max_points,
        difficulty=q.difficulty.value,
        subject_id=q.subject_id,
        source=q.source,
        is_marked=q.id in marked,
    )


def attempt_out(db: Session, user: User, attempt: TestAttempt) -> AttemptOut:
    questions = ordered_questions(db, attempt.question_ids)
    marked = marked_ids(db, user.id, attempt.question_ids)
    by_id = {q.id: q for q in questions}
    feedback = shows_feedback(attempt)
    answers: List[AnsweredOut] = []
    for a in attempt.user_answers:
        q = by_id.get(a.question_id)
        answers.append(
            AnsweredOut(
                question_id=a.question_id,
                selected_option_index=a.selected_option_index,
                answer=a.answer,
                is_correct=a.is_correct if feedback else None,
                points=a.points if feedback else None,
                correct_option_index=correct_single_index(q) if feedback and q else None,
                correct_answer=q.answer_key if feedback and q else None,
                explanation=q.explanation if feedback and q else None,
            )
        )
    return AttemptOut(
        id=attempt.id,
        test_type=attempt.test_type.value,
        reference_id=attempt.reference_id,
        status=attempt.status.value,
        is_timed=attempt.is_timed,
        started_at=attempt.started_at,
        expires_at=attempt.expires_at,
        server_time=utcnow(),
        shows_feedback=feedback,
        questions=[question_out(q, marked) for q in questions],
        answers=answers,
        score=attempt.score if feedback else 0,
        answer_streak=attempt.answer_streak if feedback else 0,
    )


def achievement_brief(a: Achievement, lang: str) -> AchievementBrief:
    return AchievementBrief(code=a.code, title=a.title_for(lang), icon=a.icon, points_reward=a.points_reward)


def result_out(
    db: Session, user: User, attempt: TestAttempt, lang: str,
    completion_bonus: int = 0, new_achievements: Optional[List[Achievement]] = None,
) -> AttemptResult:
    questions = ordered_questions(db, attempt.question_ids)
    marked = marked_ids(db, user.id, attempt.question_ids)
    answers = {a.question_id: a for a in attempt.user_answers}

    review: List[ReviewItem] = []
    for q in questions:
        a = answers.get(q.id)
        review.append(
            ReviewItem(
                question_id=q.id,
                question_type=q.question_type.value,
                passage=q.passage,
                text=q.text,
                image_url=q.image_url,
                options=list(q.options or []),
                matching_left=list(q.matching_left) if q.matching_left else None,
                selected_option_index=a.selected_option_index if a else None,
                answer=a.answer if a else None,
                correct_option_index=correct_single_index(q),
                correct_answer=q.answer_key,
                is_correct=bool(a and a.is_correct),
                points=a.points if a else 0,
                max_points=q.max_points,
                explanation=q.explanation,
                source=q.source,
                is_marked=q.id in marked,
                subject_id=q.subject_id,
            )
        )

    subjects: List[SubjectBreakdown] = []
    if attempt.test_type in EXAM_TYPES:
        details = attempt.details or exam_breakdown(db, attempt)
        for e in details["subtests"]:
            subject = db.get(Subject, e["subject_id"]) if e.get("subject_id") else None
            subjects.append(SubjectBreakdown(title=subject.title_for(lang) if subject else "—", **e))

    duration = None
    if attempt.finished_at and attempt.started_at:
        duration = int((attempt.finished_at - attempt.started_at).total_seconds())
    total = g.total_points(db, user.id)
    max_points = attempt.max_points or sum(q.max_points for q in questions)
    return AttemptResult(
        attempt_id=attempt.id,
        test_type=attempt.test_type.value,
        reference_id=attempt.reference_id,
        correct_count=attempt.correct_count,
        total_count=attempt.total_count,
        answered_count=len(answers),
        accuracy=round(100 * attempt.points / max_points) if max_points else 0,
        points=attempt.points,
        max_points=max_points,
        score=attempt.score,
        completion_bonus=completion_bonus,
        mmt_score=attempt.mmt_score,
        mmt_max=g.MMT_MAX,
        duration_seconds=max(duration, 0) if duration is not None else None,
        subjects=subjects,
        new_achievements=[achievement_brief(a, lang) for a in (new_achievements or [])],
        total_points=total,
        level=g.level_for_points(total),
        review=review,
    )


def role_or_active(user: User, role: Optional[str]) -> Optional[UserRole]:
    if role is None:
        return user.active_role
    r = UserRole(role)
    return r if user.has_role(r) else None

