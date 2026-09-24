import enum
from datetime import date, datetime
from typing import List, Optional

from sqlalchemy import Boolean, Date, DateTime, ForeignKey, Integer, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.database import Base
from app.models.base import str_enum


class UserRole(str, enum.Enum):
    ABITURIENT = "abiturient"
    SCHOOLBOY = "schoolboy"


class Language(str, enum.Enum):
    TAJIK = "tj"
    RUSSIAN = "ru"


class AdminRole(str, enum.Enum):
    CONTENT_MANAGER = "content_manager"
    SUPERADMIN = "superadmin"


class ThemeMode(str, enum.Enum):
    SYSTEM = "system"
    LIGHT = "light"
    DARK = "dark"


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    email: Mapped[Optional[str]] = mapped_column(String(255), unique=True, index=True)
    phone: Mapped[Optional[str]] = mapped_column(String(32), unique=True, index=True)
    password_hash: Mapped[Optional[str]] = mapped_column(String(255))
    google_sub: Mapped[Optional[str]] = mapped_column(String(255), unique=True, index=True)
    name: Mapped[str] = mapped_column(String(100))
    avatar_id: Mapped[str] = mapped_column(String(32), default="owl")
    language: Mapped[Language] = mapped_column(str_enum(Language), default=Language.TAJIK)
    theme: Mapped[ThemeMode] = mapped_column(str_enum(ThemeMode), default=ThemeMode.SYSTEM)
    notifications_enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    # Role whose dashboard and progress are currently shown; always one of the user's roles
    active_role: Mapped[Optional[UserRole]] = mapped_column(str_enum(UserRole))
    admin_role: Mapped[Optional[AdminRole]] = mapped_column(str_enum(AdminRole))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)

    # Daily activity streak (Duolingo-style)
    current_streak: Mapped[int] = mapped_column(Integer, default=0)
    longest_streak: Mapped[int] = mapped_column(Integer, default=0)
    last_activity_date: Mapped[Optional[date]] = mapped_column(Date)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    last_login_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))

    roles: Mapped[List["UserRoleLink"]] = relationship(
        back_populates="user", cascade="all, delete-orphan", lazy="selectin"
    )
    abiturient_profile: Mapped[Optional["AbiturientProfile"]] = relationship(
        back_populates="user", uselist=False, cascade="all, delete-orphan"
    )
    school_profile: Mapped[Optional["SchoolProfile"]] = relationship(
        back_populates="user", uselist=False, cascade="all, delete-orphan"
    )

    @property
    def role_list(self) -> List[UserRole]:
        return [link.role for link in self.roles]

    def has_role(self, role: UserRole) -> bool:
        return role in self.role_list

    def __str__(self) -> str:
        return f"{self.name} <{self.email or self.phone or self.id}>"


class UserRoleLink(Base):
    """A user may hold both roles; progress and points are kept separately per role."""

    __tablename__ = "user_roles"
    __table_args__ = (UniqueConstraint("user_id", "role", name="uq_user_role"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    role: Mapped[UserRole] = mapped_column(str_enum(UserRole))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user: Mapped[User] = relationship(back_populates="roles")


class AbiturientProfile(Base):
    __tablename__ = "abiturient_profiles"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), unique=True)
    cluster_id: Mapped[int] = mapped_column(ForeignKey("clusters.id"), index=True)
    backup_cluster_id: Mapped[Optional[int]] = mapped_column(ForeignKey("clusters.id"))
    target_year: Mapped[int] = mapped_column(Integer)
    region: Mapped[Optional[str]] = mapped_column(String(64), index=True)

    user: Mapped[User] = relationship(back_populates="abiturient_profile")
    cluster = relationship("Cluster", foreign_keys=[cluster_id])
    backup_cluster = relationship("Cluster", foreign_keys=[backup_cluster_id])


class SchoolProfile(Base):
    __tablename__ = "school_profiles"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), unique=True)
    grade: Mapped[int] = mapped_column(Integer, index=True)
    school_name: Mapped[Optional[str]] = mapped_column(String(200))
    language_of_study: Mapped[Language] = mapped_column(str_enum(Language), default=Language.TAJIK)

    user: Mapped[User] = relationship(back_populates="school_profile")


class DeviceToken(Base):
    """FCM push tokens (daily streak reminders, new tests)."""

    __tablename__ = "device_tokens"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    token: Mapped[str] = mapped_column(String(512), unique=True)
    platform: Mapped[str] = mapped_column(String(16), default="android")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
