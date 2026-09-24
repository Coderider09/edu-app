from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import create_access_token, create_refresh_token, decode_token
from app.crud.user import (
    authenticate_user,
    create_user,
    get_user_by_email,
    get_user_by_phone,
    touch_login,
)
from app.db.database import get_db
from app.models import Language, User
from app.schemas.user import GoogleAuthRequest, RefreshRequest, RegisterRequest, Token
from app.services import google_auth
from app.services.cache import cache

router = APIRouter()


def issue_tokens(user: User) -> Token:
    return Token(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
        needs_onboarding=not user.roles,
    )


@router.post("/register", response_model=Token, status_code=status.HTTP_201_CREATED)
def register(data: RegisterRequest, db: Session = Depends(get_db)):
    """Register with email and/or phone + password. The role is chosen next via POST /profile/role."""
    if data.email and get_user_by_email(db, data.email):
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email already registered")
    if data.phone and get_user_by_phone(db, data.phone):
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Phone already registered")
    user = create_user(db, data)
    touch_login(db, user)
    return issue_tokens(user)


@router.post("/login", response_model=Token)
def login(request: Request, form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    """Login with email or phone (`username` field) and password. Rate limited against brute force."""
    client_ip = request.client.host if request.client else "unknown"
    key = f"ratelimit:login:{client_ip}:{form_data.username.lower().strip()}"
    if cache.hit(key, settings.LOGIN_RATE_WINDOW_SECONDS) > settings.LOGIN_RATE_LIMIT:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many login attempts, try again later",
            headers={"Retry-After": str(settings.LOGIN_RATE_WINDOW_SECONDS)},
        )
    user = authenticate_user(db, form_data.username, form_data.password)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect login or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    if not user.is_active:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account is blocked")
    touch_login(db, user)
    return issue_tokens(user)


@router.post("/refresh", response_model=Token)
def refresh(data: RefreshRequest, db: Session = Depends(get_db)):
    user_id = decode_token(data.refresh_token, "refresh")
    user = db.get(User, user_id) if user_id else None
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token")
    if not user.is_active:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account is blocked")
    return issue_tokens(user)


@router.post("/oauth/google", response_model=Token)
def google_oauth(data: GoogleAuthRequest, db: Session = Depends(get_db)):
    """Sign in with a Google ID token obtained by the mobile app (google_sign_in)."""
    info = google_auth.verify(data.id_token)
    if info is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid Google token")

    user = db.query(User).filter(User.google_sub == info["sub"]).first()
    if user is None and info.get("email") and info.get("email_verified"):
        user = get_user_by_email(db, info["email"])
        if user is not None:
            user.google_sub = info["sub"]
    if user is None:
        user = User(
            email=info.get("email", "").lower() or None,
            google_sub=info["sub"],
            name=(info.get("name") or info.get("email", "User").split("@")[0])[:100],
            language=Language(data.language),
        )
        db.add(user)
    db.commit()
    db.refresh(user)
    if not user.is_active:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account is blocked")
    touch_login(db, user)
    return issue_tokens(user)
