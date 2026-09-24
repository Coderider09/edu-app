from typing import List, Literal, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.v1.serializers import profile_out, role_or_active, subject_out
from app.core.deps import get_content_language, get_current_user, get_onboarded_user
from app.crud.user import upsert_abiturient_profile, upsert_school_profile
from app.db.database import get_db
from app.models import (
    Achievement,
    AttemptStatus,
    DeviceToken,
    ExamTest,
    Language,
    Lesson,
    Subject,
    TestAttempt,
    TestType,
    ThemeMode,
    Topic,
    User,
    UserAchievement,
    UserRole,
)
from app.schemas.testing import AttemptHistoryItem
from app.schemas.user import DeviceTokenIn, ProfileOut, ProfileUpdate
from app.services import leaderboard as lb
from app.services.progress import subject_progress, subjects_for_role

router = APIRouter()


@router.get("/profile/me", response_model=ProfileOut)
def get_profile(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return profile_out(db, user)


@router.patch("/profile/me", response_model=ProfileOut)
def update_profile(data: ProfileUpdate, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Settings: name, avatar, language, theme, notifications, active role switch, questionnaires."""
    if data.name is not None:
        user.name = data.name.strip()
    if data.avatar_id is not None:
        user.avatar_id = data.avatar_id
    if data.language is not None:
        user.language = Language(data.language)
    if data.theme is not None:
        user.theme = ThemeMode(data.theme)
    if data.notifications_enabled is not None:
        user.notifications_enabled = data.notifications_enabled
    if data.active_role is not None:
        role = UserRole(data.active_role)
        if not user.has_role(role):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST, detail="Add the role first via POST /profile/role"
            )
        user.active_role = role
    try:
        if data.abiturient is not None:
            if not user.has_role(UserRole.ABITURIENT):
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="User is not an abiturient")
            upsert_abiturient_profile(db, user, data.abiturient)
        if data.school is not None:
            if not user.has_role(UserRole.SCHOOLBOY):
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="User is not a schoolboy")
            upsert_school_profile(db, user, data.school)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail=str(exc)) from exc
    db.commit()
    db.refresh(user)
    return profile_out(db, user)


@router.get("/profile/me/progress")
def get_progress(
    role: Optional[Literal["abiturient", "schoolboy"]] = None,
    user: User = Depends(get_onboarded_user),
    lang: str = Depends(get_content_language),
    db: Session = Depends(get_db),
) -> dict:
    """Progress by subject (for the radar chart / bars): % of material and answer accuracy."""
    r = role_or_active(user, role)
    if r is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="User does not have this role")
    subjects = [subject_progress(db, user, r, s, lang) for s in subjects_for_role(db, user, r)]
    overall = round(sum(s["percent"] for s in subjects) / len(subjects)) if subjects else 0
    return {"role": r.value, "overall_percent": overall, "subjects": subjects}


@router.get("/profile/me/achievements")
def get_achievements(user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> List[dict]:
    """All achievements with the unlocked ones marked."""
    lang = user.language.value
    unlocked = {
        ua.achievement_id: ua.unlocked_at
        for ua in db.scalars(select(UserAchievement).where(UserAchievement.user_id == user.id)).all()
    }
    return [
        {
            "code": a.code,
            "title": a.title_for(lang),
            "description": a.description_for(lang),
            "icon": a.icon,
            "points_reward": a.points_reward,
            "unlocked": a.id in unlocked,
            "unlocked_at": unlocked.get(a.id),
        }
        for a in db.scalars(select(Achievement).order_by(Achievement.id)).all()
    ]


def _attempt_title(db: Session, attempt: TestAttempt, lang: str) -> str:
    t = attempt.test_type
    ref = attempt.reference_id
    if t in (TestType.TOPIC_TEST, TestType.SECTION_TEST) and ref:
        topic = db.get(Topic, ref)
        return topic.title_for(lang) if topic else "—"
    if t == TestType.PRACTICE and ref:
        subject = db.get(Subject, ref)
        return subject.title_for(lang) if subject else "—"
    if t == TestType.EXAM_TEST and ref:
        exam = db.get(ExamTest, ref)
        return exam.title if exam else "—"
    if t == TestType.LESSON_CHECK and ref:
        lesson = db.get(Lesson, ref)
        return lesson.title if lesson else "—"
    return "Повторить ошибки" if lang == "ru" else "Такрори хатоҳо"


@router.get("/profile/me/history", response_model=List[AttemptHistoryItem])
def get_history(
    limit: int = Query(default=20, ge=1, le=100),
    role: Optional[Literal["abiturient", "schoolboy"]] = None,
    user: User = Depends(get_onboarded_user),
    db: Session = Depends(get_db),
):
    """Recently taken tests with results."""
    r = role_or_active(user, role)
    lang = user.language.value
    attempts = db.scalars(
        select(TestAttempt)
        .where(TestAttempt.user_id == user.id, TestAttempt.role == r, TestAttempt.status == AttemptStatus.FINISHED)
        .order_by(TestAttempt.finished_at.desc(), TestAttempt.id.desc())
        .limit(limit)
    ).all()
    return [
        AttemptHistoryItem(
            id=a.id,
            test_type=a.test_type.value,
            reference_id=a.reference_id,
            title=_attempt_title(db, a, lang),
            status=a.status.value,
            started_at=a.started_at,
            finished_at=a.finished_at,
            correct_count=a.correct_count,
            total_count=a.total_count,
            accuracy=round(100 * a.correct_count / a.total_count) if a.total_count else 0,
            score=a.score,
            mmt_score=a.mmt_score,
        )
        for a in attempts
    ]


@router.get("/dashboard")
def get_dashboard(
    user: User = Depends(get_onboarded_user),
    lang: str = Depends(get_content_language),
    db: Session = Depends(get_db),
) -> dict:
    """Home screen of the active branch: subjects with progress, unfinished/last test, rank."""
    role = user.active_role
    subjects = []
    for s in subjects_for_role(db, user, role):
        p = subject_progress(db, user, role, s, lang)
        subjects.append(subject_out(s, lang, p["percent"]).model_dump())

    unfinished = db.scalar(
        select(TestAttempt)
        .where(
            TestAttempt.user_id == user.id,
            TestAttempt.role == role,
            TestAttempt.status == AttemptStatus.IN_PROGRESS,
        )
        .order_by(TestAttempt.id.desc())
    )
    last = db.scalar(
        select(TestAttempt)
        .where(TestAttempt.user_id == user.id, TestAttempt.role == role, TestAttempt.status == AttemptStatus.FINISHED)
        .order_by(TestAttempt.finished_at.desc(), TestAttempt.id.desc())
    )

    def brief(a: Optional[TestAttempt]) -> Optional[dict]:
        if a is None:
            return None
        return {
            "id": a.id, "test_type": a.test_type.value, "reference_id": a.reference_id,
            "title": _attempt_title(db, a, lang), "correct_count": a.correct_count,
            "total_count": a.total_count, "answered_count": len(a.user_answers), "mmt_score": a.mmt_score,
        }

    data = {
        "role": role.value,
        "profile": profile_out(db, user).model_dump(mode="json"),
        "subjects": subjects,
        "unfinished_attempt": brief(unfinished),
        "last_attempt": brief(last),
        "rank": None,
    }
    scope = "cluster" if role == UserRole.ABITURIENT else "grade"
    try:
        board = lb.get_leaderboard(db, user, scope, "all")
        data["rank"] = board["me"]["rank"] if board["me"] else None
    except HTTPException:
        pass
    if role == UserRole.ABITURIENT and user.abiturient_profile:
        cluster = user.abiturient_profile.cluster
        data["cluster"] = {"id": cluster.id, "title": cluster.title_for(lang), "icon": cluster.icon}
    if role == UserRole.SCHOOLBOY and user.school_profile:
        data["grade"] = user.school_profile.grade
    return data


@router.get("/leaderboard")
def get_leaderboard(
    scope: Optional[Literal["cluster", "region", "grade"]] = None,
    period: Literal["week", "all"] = "all",
    cluster_id: Optional[int] = None,
    grade: Optional[int] = Query(default=None, ge=1, le=11),
    user: User = Depends(get_onboarded_user),
    db: Session = Depends(get_db),
) -> dict:
    if scope is None:
        scope = "cluster" if user.active_role == UserRole.ABITURIENT else "grade"
    return lb.get_leaderboard(db, user, scope, period, cluster_id, grade)


@router.post("/profile/me/devices", status_code=status.HTTP_204_NO_CONTENT)
def register_device(data: DeviceTokenIn, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Register an FCM token for push notifications (streak reminders, new tests)."""
    device = db.scalar(select(DeviceToken).where(DeviceToken.token == data.token))
    if device is None:
        db.add(DeviceToken(user_id=user.id, token=data.token, platform=data.platform))
    else:
        device.user_id = user.id
        device.platform = data.platform
    db.commit()
