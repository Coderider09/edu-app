"""Leaderboards by cluster / grade / region, weekly or all-time. Top list is cached in Redis."""
from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import HTTPException
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models import AbiturientProfile, PointsLedger, SchoolProfile, User, UserRole
from app.services.cache import cache
from app.services.gamification import level_for_points

TOP_SIZE = 50


def _scope_filter(scope: str, user: User, cluster_id: Optional[int], grade: Optional[int]):
    """Return (role, profile join target, filter clause, resolved scope value)."""
    if scope == "cluster":
        cid = cluster_id or (user.abiturient_profile.cluster_id if user.abiturient_profile else None)
        if cid is None:
            raise HTTPException(status_code=400, detail="cluster_id is required")
        return UserRole.ABITURIENT, AbiturientProfile, AbiturientProfile.cluster_id == cid, cid
    if scope == "region":
        profile = user.abiturient_profile
        if profile is None or not profile.region:
            raise HTTPException(status_code=400, detail="Region is not set in the profile")
        clause = (AbiturientProfile.cluster_id == profile.cluster_id) & (AbiturientProfile.region == profile.region)
        return UserRole.ABITURIENT, AbiturientProfile, clause, f"{profile.cluster_id}:{profile.region}"
    if scope == "grade":
        g = grade or (user.school_profile.grade if user.school_profile else None)
        if g is None:
            raise HTTPException(status_code=400, detail="grade is required")
        return UserRole.SCHOOLBOY, SchoolProfile, SchoolProfile.grade == g, g
    raise HTTPException(status_code=400, detail="scope must be cluster, region or grade")


def _points_query(role, profile_model, clause, since):
    total = func.sum(PointsLedger.points).label("total")
    stmt = (
        select(User.id, User.name, User.avatar_id, total)
        .join(PointsLedger, PointsLedger.user_id == User.id)
        .join(profile_model, profile_model.user_id == User.id)
        .where(PointsLedger.role == role, clause, User.is_active.is_(True))
        .group_by(User.id, User.name, User.avatar_id)
    )
    if since is not None:
        stmt = stmt.where(PointsLedger.created_at >= since)
    return stmt, total


def get_leaderboard(
    db: Session, user: User, scope: str, period: str,
    cluster_id: Optional[int] = None, grade: Optional[int] = None,
) -> dict:
    if period not in ("week", "all"):
        raise HTTPException(status_code=400, detail="period must be week or all")
    role, profile_model, clause, scope_value = _scope_filter(scope, user, cluster_id, grade)
    since = datetime.now(timezone.utc) - timedelta(days=7) if period == "week" else None

    key = f"leaderboard:{scope}:{scope_value}:{period}"
    top = cache.get_json(key)
    if top is None:
        stmt, total = _points_query(role, profile_model, clause, since)
        rows = db.execute(stmt.order_by(total.desc(), User.id).limit(TOP_SIZE)).all()
        top = [
            {"rank": i + 1, "user_id": uid, "name": name, "avatar_id": avatar, "points": int(points or 0)}
            for i, (uid, name, avatar, points) in enumerate(rows)
        ]
        cache.set_json(key, top, settings.LEADERBOARD_CACHE_SECONDS)

    me = next((entry for entry in top if entry["user_id"] == user.id), None)
    if me is None and user.has_role(role):
        stmt, total = _points_query(role, profile_model, clause, since)
        mine = db.execute(stmt.where(User.id == user.id)).first()
        my_points = int(mine.total) if mine else 0
        sub = stmt.subquery()
        above = db.scalar(select(func.count()).select_from(sub).where(sub.c.total > my_points)) or 0
        me = {
            "rank": above + 1, "user_id": user.id, "name": user.name,
            "avatar_id": user.avatar_id, "points": my_points,
        }
    for entry in top + ([me] if me else []):
        entry["level"] = level_for_points(entry["points"])["number"]
    return {"scope": scope, "period": period, "entries": top, "me": me}
