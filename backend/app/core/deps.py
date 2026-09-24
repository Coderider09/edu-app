from typing import Optional

from fastapi import Depends, Header, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

from app.core.security import decode_token
from app.db.database import get_db
from app.models.user import AdminRole, Language, User, UserRole

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")


def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    user_id = decode_token(token, "access")
    if user_id is None:
        raise credentials_exception
    user = db.get(User, user_id)
    if user is None:
        raise credentials_exception
    if not user.is_active:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account is blocked")
    return user


def get_onboarded_user(user: User = Depends(get_current_user)) -> User:
    """A user who has already chosen a role."""
    if not user.roles or user.active_role is None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Role is not selected yet")
    return user


def get_content_language(
    user: User = Depends(get_current_user),
    accept_language: Optional[str] = Header(default=None),
) -> str:
    """Content language: a schoolboy's language of study, else the interface language."""
    if user.active_role == UserRole.SCHOOLBOY and user.school_profile:
        return user.school_profile.language_of_study.value
    if user.language:
        return user.language.value
    if accept_language and accept_language.lower().startswith("ru"):
        return Language.RUSSIAN.value
    return Language.TAJIK.value


def require_content_manager(user: User = Depends(get_current_user)) -> User:
    if user.admin_role not in (AdminRole.CONTENT_MANAGER, AdminRole.SUPERADMIN):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required")
    return user


def require_superadmin(user: User = Depends(get_current_user)) -> User:
    if user.admin_role != AdminRole.SUPERADMIN:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Superadmin access required")
    return user
