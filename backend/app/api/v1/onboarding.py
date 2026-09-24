from typing import List, Literal, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.api.v1.serializers import cluster_out, profile_out, subject_out
from app.core.deps import get_current_user
from app.crud.user import add_role, upsert_abiturient_profile, upsert_school_profile
from app.db.database import get_db
from app.models import Cluster, ClusterSubject, Subject, User, UserRole
from app.schemas.content import ClusterOut, SubjectOut
from app.schemas.user import AVATARS, ProfileOut, RoleRequest

router = APIRouter()

# Administrative regions of Tajikistan (for the optional regional leaderboard)
REGIONS = [
    {"code": "dushanbe", "ru": "Душанбе", "tj": "Душанбе"},
    {"code": "sughd", "ru": "Согдийская область", "tj": "Вилояти Суғд"},
    {"code": "khatlon", "ru": "Хатлонская область", "tj": "Вилояти Хатлон"},
    {"code": "gbao", "ru": "ГБАО", "tj": "ВМКБ"},
    {"code": "rrp", "ru": "Районы республиканского подчинения", "tj": "Ноҳияҳои тобеи ҷумҳурӣ"},
]


@router.post("/profile/role", response_model=ProfileOut)
def set_role(data: RoleRequest, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Choose a role with its questionnaire (mandatory after registration).

    Calling it again with the other role adds a second role to the same account (ТЗ 2.2);
    progress is kept separately for each role. The role itself cannot be removed.
    """
    role = UserRole(data.role)
    if user.has_role(role):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Role already added; update the questionnaire via PATCH /profile/me",
        )
    try:
        if role == UserRole.ABITURIENT:
            upsert_abiturient_profile(db, user, data.abiturient)
        else:
            upsert_school_profile(db, user, data.school)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail=str(exc)) from exc
    add_role(db, user, role)
    db.commit()
    db.refresh(user)
    return profile_out(db, user)


@router.get("/clusters", response_model=List[ClusterOut])
def get_clusters(lang: Literal["tj", "ru"] = "tj", db: Session = Depends(get_db)):
    """The 5 ЦВЭ clusters with their subtests A1–A4 (managed in the admin panel)."""
    clusters = db.scalars(
        select(Cluster).options(selectinload(Cluster.subject_links)).order_by(Cluster.order, Cluster.id)
    ).all()
    return [cluster_out(c, lang, with_subjects=True) for c in clusters]


@router.get("/subjects", response_model=List[SubjectOut])
def get_subjects(
    grade: Optional[int] = Query(default=None, ge=1, le=11),
    cluster_id: Optional[int] = None,
    lang: Literal["tj", "ru"] = "tj",
    db: Session = Depends(get_db),
):
    if cluster_id is not None:
        links = db.scalars(
            select(ClusterSubject).where(ClusterSubject.cluster_id == cluster_id).order_by(ClusterSubject.position)
        ).all()
        return [subject_out(link.subject, lang, cluster_id=cluster_id, position=link.position) for link in links]
    stmt = select(Subject)
    if grade is not None:
        stmt = stmt.where(Subject.grade == grade)
    return [subject_out(s, lang) for s in db.scalars(stmt.order_by(Subject.order, Subject.id)).all()]


@router.get("/regions")
def get_regions():
    return REGIONS


@router.get("/avatars")
def get_avatars():
    return AVATARS
