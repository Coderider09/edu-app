import re
from datetime import date, datetime
from typing import List, Literal, Optional

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator, model_validator

PHONE_RE = re.compile(r"^\+?\d{9,15}$")

# Ready-made avatar icons (no photo upload in MVP — simpler moderation)
AVATARS = ["owl", "fox", "cat", "panda", "lion", "rabbit", "bear", "penguin", "tiger", "koala", "eagle", "dolphin"]


def normalize_phone(value: str) -> str:
    return re.sub(r"[\s\-()]", "", value)


class RegisterRequest(BaseModel):
    email: Optional[EmailStr] = None
    phone: Optional[str] = None
    password: str = Field(min_length=8, max_length=128)
    name: str = Field(min_length=1, max_length=100)
    language: Literal["tj", "ru"] = "tj"

    @field_validator("phone")
    @classmethod
    def check_phone(cls, v: Optional[str]) -> Optional[str]:
        if v is None or v == "":
            return None
        v = normalize_phone(v)
        if not PHONE_RE.match(v):
            raise ValueError("Invalid phone number")
        return v

    @field_validator("name")
    @classmethod
    def strip_name(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("Name is required")
        return v

    @model_validator(mode="after")
    def email_or_phone(self):
        if not self.email and not self.phone:
            raise ValueError("Email or phone is required")
        return self


class RefreshRequest(BaseModel):
    refresh_token: str


class GoogleAuthRequest(BaseModel):
    id_token: str
    language: Literal["tj", "ru"] = "tj"


class Token(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    needs_onboarding: bool = False


class AbiturientSurvey(BaseModel):
    cluster_id: int
    backup_cluster_id: Optional[int] = None
    target_year: int = Field(ge=2000, le=2100)
    region: Optional[str] = Field(default=None, max_length=64)


class SchoolSurvey(BaseModel):
    grade: int = Field(ge=1, le=11)
    school_name: Optional[str] = Field(default=None, max_length=200)
    language_of_study: Literal["tj", "ru"] = "tj"


class RoleRequest(BaseModel):
    """Choose a role with its questionnaire. Also used to add a second role later."""

    role: Literal["abiturient", "schoolboy"]
    abiturient: Optional[AbiturientSurvey] = None
    school: Optional[SchoolSurvey] = None

    @model_validator(mode="after")
    def survey_matches_role(self):
        if self.role == "abiturient" and self.abiturient is None:
            raise ValueError("abiturient survey is required")
        if self.role == "schoolboy" and self.school is None:
            raise ValueError("school survey is required")
        return self


class AbiturientProfileOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    cluster_id: int
    cluster_title: Optional[str] = None
    backup_cluster_id: Optional[int] = None
    target_year: int
    region: Optional[str] = None


class SchoolProfileOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    grade: int
    school_name: Optional[str] = None
    language_of_study: str


class LevelOut(BaseModel):
    number: int
    code: str
    min_points: int
    next_level_points: Optional[int]
    progress: float


class ProfileOut(BaseModel):
    id: int
    email: Optional[str]
    phone: Optional[str]
    name: str
    avatar_id: str
    language: str
    theme: str
    notifications_enabled: bool
    roles: List[str]
    active_role: Optional[str]
    is_admin: bool
    abiturient: Optional[AbiturientProfileOut]
    school: Optional[SchoolProfileOut]
    total_points: int
    role_points: int
    level: LevelOut
    current_streak: int
    longest_streak: int
    last_activity_date: Optional[date]
    created_at: datetime


class ProfileUpdate(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=100)
    avatar_id: Optional[str] = None
    language: Optional[Literal["tj", "ru"]] = None
    theme: Optional[Literal["system", "light", "dark"]] = None
    notifications_enabled: Optional[bool] = None
    active_role: Optional[Literal["abiturient", "schoolboy"]] = None
    abiturient: Optional[AbiturientSurvey] = None
    school: Optional[SchoolSurvey] = None

    @field_validator("avatar_id")
    @classmethod
    def known_avatar(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and v not in AVATARS:
            raise ValueError("Unknown avatar")
        return v


class DeviceTokenIn(BaseModel):
    token: str = Field(min_length=10, max_length=512)
    platform: Literal["android", "ios", "web"] = "android"
