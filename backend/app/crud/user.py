from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.security import get_password_hash, verify_password
from app.models import AbiturientProfile, Cluster, Language, SchoolProfile, User, UserRole, UserRoleLink
from app.schemas.user import AbiturientSurvey, RegisterRequest, SchoolSurvey, normalize_phone


def get_user_by_email(db: Session, email: str) -> Optional[User]:
    return db.scalar(select(User).where(func.lower(User.email) == email.lower()))


def get_user_by_phone(db: Session, phone: str) -> Optional[User]:
    return db.scalar(select(User).where(User.phone == normalize_phone(phone)))


def get_user_by_login(db: Session, login: str) -> Optional[User]:
    login = login.strip()
    return get_user_by_email(db, login) if "@" in login else get_user_by_phone(db, login)


def create_user(db: Session, data: RegisterRequest) -> User:
    user = User(
        email=data.email.lower() if data.email else None,
        phone=data.phone,
        password_hash=get_password_hash(data.password),
        name=data.name,
        language=Language(data.language),
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def authenticate_user(db: Session, login: str, password: str) -> Optional[User]:
    user = get_user_by_login(db, login)
    if user is None or not verify_password(password, user.password_hash):
        return None
    return user


def touch_login(db: Session, user: User) -> None:
    user.last_login_at = datetime.now(timezone.utc)
    db.commit()


def _check_cluster(db: Session, cluster_id: Optional[int]) -> None:
    if cluster_id is not None and db.get(Cluster, cluster_id) is None:
        raise ValueError(f"Cluster {cluster_id} does not exist")


def upsert_abiturient_profile(db: Session, user: User, survey: AbiturientSurvey) -> AbiturientProfile:
    _check_cluster(db, survey.cluster_id)
    _check_cluster(db, survey.backup_cluster_id)
    if survey.backup_cluster_id == survey.cluster_id:
        survey.backup_cluster_id = None
    profile = user.abiturient_profile or AbiturientProfile(user_id=user.id)
    profile.cluster_id = survey.cluster_id
    profile.backup_cluster_id = survey.backup_cluster_id
    profile.target_year = survey.target_year
    profile.region = survey.region.strip() if survey.region else None
    user.abiturient_profile = profile
    return profile


def upsert_school_profile(db: Session, user: User, survey: SchoolSurvey) -> SchoolProfile:
    profile = user.school_profile or SchoolProfile(user_id=user.id)
    profile.grade = survey.grade
    profile.school_name = survey.school_name.strip() if survey.school_name else None
    profile.language_of_study = Language(survey.language_of_study)
    user.school_profile = profile
    return profile


def add_role(db: Session, user: User, role: UserRole) -> None:
    if not user.has_role(role):
        user.roles.append(UserRoleLink(role=role))
    user.active_role = role
