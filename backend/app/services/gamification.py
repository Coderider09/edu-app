"""Points, levels, daily streaks and achievements (ТЗ, раздел 5)."""
from datetime import date, datetime, timedelta, timezone
from typing import List, Optional
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models import (
    Achievement,
    AttemptStatus,
    ClusterSubject,
    PointsLedger,
    PointsReason,
    TestAttempt,
    TestType,
    Topic,
    User,
    UserAchievement,
    UserRole,
)
from app.models.content import topic_pool

BASE_POINTS = 10
STREAK_THRESHOLD = 5          # after 5 correct answers in a row...
STREAK_MULTIPLIER = 1.5       # ...each next correct answer is worth x1.5
COMPLETION_BONUS = {
    TestType.TOPIC_TEST: 20,
    TestType.SECTION_TEST: 50,
    TestType.PRACTICE: 10,
    TestType.EXAM_TEST: 100,
    TestType.MOCK_EXAM: 100,
    TestType.LESSON_CHECK: 10,
    TestType.MISTAKES: 10,
}
TOPIC_PASS_ACCURACY = 0.7     # a topic counts as completed at >=70% in its topic test
MMT_MAX = 500                 # component A: 4 subtests, 500 points in total (A1 — 75)

# (min total points, code) — titles are localized on the client
LEVELS = [
    (0, "novice"),        # Новичок
    (500, "learner"),     # Ученик
    (2000, "advanced"),   # Продвинутый
    (5000, "expert"),     # Эксперт
    (10000, "master"),    # Мастер
]

try:
    LOCAL_TZ = ZoneInfo(settings.TIMEZONE)
except ZoneInfoNotFoundError:  # Windows without tzdata; Tajikistan is UTC+5 with no DST
    LOCAL_TZ = timezone(timedelta(hours=5))


def local_today(now: Optional[datetime] = None) -> date:
    return (now or datetime.now(timezone.utc)).astimezone(LOCAL_TZ).date()


def points_for_answer(is_correct: bool, streak_before: int, official_points: int = 1) -> tuple[int, int]:
    """Return (base, streak_bonus) in app points for one answer.

    Base = official points («очки»: 1 for a choice, up to 4 for matching, 2 for an open answer) × 10,
    so partially correct matching still earns points. Wrong answers give 0 and cost nothing.
    The x1.5 streak bonus applies to fully correct answers after 5 in a row.
    """
    base = official_points * BASE_POINTS
    if not is_correct or streak_before < STREAK_THRESHOLD:
        return base, 0
    return base, int(base * STREAK_MULTIPLIER) - base


def scale_subtest(points: int, max_points: int, max_score: int) -> float:
    """Official points of a subtest → score («баллы»).

    The Center scales each subtest per cluster with its own table (e.g. Tajik language 40 points →
    75). The tables are published after the exam, so a linear approximation is used here.
    """
    if max_points <= 0:
        return 0.0
    return max_score * points / max_points


def estimate_mmt_score(subtests: list[dict]) -> int:
    """Total estimated ЦВЭ score on the 500-point scale of component A."""
    return round(sum(s["score"] for s in subtests))


def level_for_points(points: int) -> dict:
    index = 0
    for i, (threshold, _) in enumerate(LEVELS):
        if points >= threshold:
            index = i
    threshold, code = LEVELS[index]
    next_threshold = LEVELS[index + 1][0] if index + 1 < len(LEVELS) else None
    progress = 1.0
    if next_threshold is not None:
        progress = (points - threshold) / (next_threshold - threshold)
    return {
        "number": index + 1,
        "code": code,
        "min_points": threshold,
        "next_level_points": next_threshold,
        "progress": round(progress, 3),
    }


def add_points(
    db: Session, user: User, role: UserRole, points: int, reason: PointsReason,
    attempt_id: Optional[int] = None,
) -> None:
    if points:
        db.add(PointsLedger(user_id=user.id, role=role, points=points, reason=reason, attempt_id=attempt_id))


def total_points(db: Session, user_id: int, role: Optional[UserRole] = None) -> int:
    stmt = select(func.coalesce(func.sum(PointsLedger.points), 0)).where(PointsLedger.user_id == user_id)
    if role is not None:
        stmt = stmt.where(PointsLedger.role == role)
    return int(db.scalar(stmt) or 0)


def register_activity(user: User, now: Optional[datetime] = None) -> None:
    """Update the daily streak: consecutive local days with at least one answer."""
    today = local_today(now)
    last = user.last_activity_date
    if last == today:
        return
    if last == today - timedelta(days=1):
        user.current_streak = (user.current_streak or 0) + 1
    else:
        user.current_streak = 1
    user.longest_streak = max(user.longest_streak or 0, user.current_streak)
    user.last_activity_date = today


def effective_streak(user: User) -> int:
    """The stored streak is stale if the user skipped yesterday."""
    if user.last_activity_date is None:
        return 0
    if user.last_activity_date >= local_today() - timedelta(days=1):
        return user.current_streak or 0
    return 0


def _unlock(db: Session, user: User, role: UserRole, code: str, attempt_id: Optional[int]) -> Optional[Achievement]:
    achievement = db.scalar(select(Achievement).where(Achievement.code == code))
    if achievement is None:
        return None
    exists = db.scalar(
        select(UserAchievement.id).where(
            UserAchievement.user_id == user.id, UserAchievement.achievement_id == achievement.id
        )
    )
    if exists:
        return None
    db.add(UserAchievement(user_id=user.id, achievement_id=achievement.id))
    add_points(db, user, role, achievement.points_reward, PointsReason.ACHIEVEMENT, attempt_id)
    return achievement


def passed_topic_ids(db: Session, user_id: int, role: UserRole) -> set[int]:
    rows = db.execute(
        select(TestAttempt.reference_id, TestAttempt.correct_count, TestAttempt.total_count).where(
            TestAttempt.user_id == user_id,
            TestAttempt.role == role,
            TestAttempt.test_type == TestType.TOPIC_TEST,
            TestAttempt.status == AttemptStatus.FINISHED,
        )
    ).all()
    return {
        ref for ref, correct, total in rows
        if total and correct / total >= TOPIC_PASS_ACCURACY
    }


def _cluster_completed(db: Session, user: User, role: UserRole) -> bool:
    profile = user.abiturient_profile
    if role != UserRole.ABITURIENT or profile is None:
        return False
    topic_ids = set(
        db.scalars(
            select(Topic.id)
            .join(ClusterSubject, ClusterSubject.subject_id == Topic.subject_id)
            .where(ClusterSubject.cluster_id == profile.cluster_id, Topic.questions.any(topic_pool()))
        ).all()
    )
    return bool(topic_ids) and topic_ids <= passed_topic_ids(db, user.id, role)


def check_achievements(db: Session, user: User, attempt: TestAttempt) -> List[Achievement]:
    """Evaluate achievements after a finished attempt. Caller commits."""
    role = attempt.role
    unlocked: List[Achievement] = []

    def unlock(code: str) -> None:
        a = _unlock(db, user, role, code, attempt.id)
        if a:
            unlocked.append(a)

    db.flush()
    finished = db.scalar(
        select(func.count(TestAttempt.id)).where(
            TestAttempt.user_id == user.id, TestAttempt.status == AttemptStatus.FINISHED
        )
    )
    if finished >= 1:
        unlock("first_test")
    if attempt.total_count >= 5 and attempt.correct_count == attempt.total_count:
        unlock("perfect_score")
    if attempt.test_type in (TestType.EXAM_TEST, TestType.MOCK_EXAM):
        unlock("first_exam")
    if (user.current_streak or 0) >= 7:
        unlock("streak_7")
    if (user.current_streak or 0) >= 30:
        unlock("streak_30")
    if attempt.test_type == TestType.TOPIC_TEST and _cluster_completed(db, user, role):
        unlock("cluster_complete")
    db.flush()
    if total_points(db, user.id) >= 1000:
        unlock("points_1000")
    return unlocked


ACHIEVEMENTS_SEED = [
    {
        "code": "first_test", "icon": "flag", "points_reward": 20,
        "title_ru": "Первый тест пройден", "title_tj": "Санҷиши аввал супорида шуд",
        "description_ru": "Завершите любой тест", "description_tj": "Ягон санҷишро анҷом диҳед",
    },
    {
        "code": "streak_7", "icon": "fire", "points_reward": 70,
        "title_ru": "7 дней подряд", "title_tj": "7 рӯз пай дар пай",
        "description_ru": "Занимайтесь 7 дней без перерыва",
        "description_tj": "7 рӯз бе танаффус машғул шавед",
    },
    {
        "code": "streak_30", "icon": "crown", "points_reward": 300,
        "title_ru": "30 дней подряд", "title_tj": "30 рӯз пай дар пай",
        "description_ru": "Занимайтесь 30 дней без перерыва",
        "description_tj": "30 рӯз бе танаффус машғул шавед",
    },
    {
        "code": "perfect_score", "icon": "star", "points_reward": 50,
        "title_ru": "100% в тесте", "title_tj": "100% дар санҷиш",
        "description_ru": "Ответьте правильно на все вопросы теста (от 5 вопросов)",
        "description_tj": "Ба ҳамаи саволҳои санҷиш дуруст ҷавоб диҳед (аз 5 савол)",
    },
    {
        "code": "first_exam", "icon": "graduation", "points_reward": 50,
        "title_ru": "Пробный ЦВЭ", "title_tj": "ИМД-и озмоишӣ",
        "description_ru": "Пройдите полный пробный экзамен своего кластера",
        "description_tj": "Имтиҳони пурраи озмоишии кластери худро супоред",
    },
    {
        "code": "cluster_complete", "icon": "trophy", "points_reward": 500,
        "title_ru": "Все темы кластера пройдены", "title_tj": "Ҳамаи мавзӯъҳои кластер гузашта шуд",
        "description_ru": "Сдайте тесты по всем темам своего кластера на 70%+",
        "description_tj": "Санҷишҳои ҳамаи мавзӯъҳои кластерро бо 70%+ супоред",
    },
    {
        "code": "points_1000", "icon": "gem", "points_reward": 0,
        "title_ru": "1000 баллов", "title_tj": "1000 хол",
        "description_ru": "Наберите 1000 баллов", "description_tj": "1000 хол ҷамъ кунед",
    },
]
