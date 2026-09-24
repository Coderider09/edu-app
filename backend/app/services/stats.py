"""Platform statistics for the admin panel."""
from datetime import datetime, timedelta, timezone

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models import (
    AbiturientProfile,
    AttemptStatus,
    Cluster,
    Question,
    TestAttempt,
    TestType,
    User,
    UserAnswer,
    UserRole,
    UserRoleLink,
)


def collect_stats(db: Session) -> dict:
    now = datetime.now(timezone.utc)
    day_ago = now - timedelta(days=1)
    week_ago = now - timedelta(days=7)

    def active_since(since: datetime) -> int:
        return db.scalar(
            select(func.count(func.distinct(TestAttempt.user_id)))
            .join(UserAnswer, UserAnswer.attempt_id == TestAttempt.id)
            .where(UserAnswer.answered_at >= since)
        ) or 0

    finished = select(func.count(TestAttempt.id)).where(TestAttempt.status == AttemptStatus.FINISHED)

    by_cluster = []
    rows = db.execute(
        select(
            Cluster.id,
            Cluster.title_ru,
            func.count(TestAttempt.id),
            func.avg(100.0 * TestAttempt.correct_count / func.nullif(TestAttempt.total_count, 0)),
            func.avg(TestAttempt.mmt_score),
        )
        .select_from(Cluster)
        .outerjoin(AbiturientProfile, AbiturientProfile.cluster_id == Cluster.id)
        .outerjoin(
            TestAttempt,
            (TestAttempt.user_id == AbiturientProfile.user_id)
            & (TestAttempt.role == UserRole.ABITURIENT)
            & (TestAttempt.status == AttemptStatus.FINISHED),
        )
        .group_by(Cluster.id, Cluster.title_ru)
        .order_by(Cluster.id)
    ).all()
    for cid, title, attempts, avg_acc, avg_mmt in rows:
        by_cluster.append({
            "cluster_id": cid,
            "title": title,
            "tests_finished": attempts,
            "avg_accuracy": round(float(avg_acc), 1) if avg_acc is not None else None,
            "avg_mmt_score": round(float(avg_mmt), 1) if avg_mmt is not None else None,
        })

    role_counts = dict(
        db.execute(select(UserRoleLink.role, func.count(UserRoleLink.id)).group_by(UserRoleLink.role)).all()
    )
    return {
        "users_total": db.scalar(select(func.count(User.id))) or 0,
        "users_blocked": db.scalar(select(func.count(User.id)).where(User.is_active.is_(False))) or 0,
        "abiturients": role_counts.get(UserRole.ABITURIENT, 0),
        "schoolboys": role_counts.get(UserRole.SCHOOLBOY, 0),
        "new_users_week": db.scalar(select(func.count(User.id)).where(User.created_at >= week_ago)) or 0,
        "dau": active_since(day_ago),
        "wau": active_since(week_ago),
        "tests_finished_total": db.scalar(finished) or 0,
        "tests_finished_today": db.scalar(finished.where(TestAttempt.finished_at >= day_ago)) or 0,
        "exam_tests_finished": db.scalar(finished.where(TestAttempt.test_type == TestType.EXAM_TEST)) or 0,
        "questions_total": db.scalar(select(func.count(Question.id))) or 0,
        "by_cluster": by_cluster,
    }
