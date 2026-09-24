import enum
from datetime import datetime
from typing import List, Optional

from sqlalchemy import JSON, Boolean, DateTime, ForeignKey, Index, Integer, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.database import Base
from app.models.base import str_enum
from app.models.user import UserRole


class TestType(str, enum.Enum):
    TOPIC_TEST = "topic_test"        # 10–20 questions on one topic
    SECTION_TEST = "section_test"    # final test of a section/quarter (all child topics)
    PRACTICE = "practice"            # subject training: untimed, explanation after each answer
    EXAM_TEST = "exam_test"          # fixed full test (official sample): timed, no feedback until finish
    MOCK_EXAM = "mock_exam"          # full ЦВЭ simulation generated from the bank by the official structure
    LESSON_CHECK = "lesson_check"    # 3–5 questions at the end of a lesson
    MISTAKES = "mistakes"            # "Повторить ошибки": marked + recently wrong questions


class AttemptStatus(str, enum.Enum):
    IN_PROGRESS = "in_progress"
    FINISHED = "finished"


class PointsReason(str, enum.Enum):
    CORRECT_ANSWER = "correct_answer"
    STREAK_BONUS = "streak_bonus"
    ACHIEVEMENT = "achievement"
    TEST_COMPLETION = "test_completion"


class TestAttempt(Base):
    __tablename__ = "test_attempts"
    __table_args__ = (Index("ix_attempt_user_type_ref", "user_id", "test_type", "reference_id"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    role: Mapped[UserRole] = mapped_column(str_enum(UserRole))
    test_type: Mapped[TestType] = mapped_column(str_enum(TestType))
    reference_id: Mapped[Optional[int]] = mapped_column(Integer)  # topic/section/subject/exam/lesson id
    question_ids: Mapped[list] = mapped_column(JSON)  # fixed question order of this attempt
    status: Mapped[AttemptStatus] = mapped_column(str_enum(AttemptStatus), default=AttemptStatus.IN_PROGRESS)
    is_timed: Mapped[bool] = mapped_column(Boolean, default=False)
    expires_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    finished_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    answer_streak: Mapped[int] = mapped_column(Integer, default=0)  # consecutive correct answers
    score: Mapped[int] = mapped_column(Integer, default=0)  # points earned in this attempt
    correct_count: Mapped[int] = mapped_column(Integer, default=0)
    total_count: Mapped[int] = mapped_column(Integer, default=0)
    mmt_score: Mapped[Optional[int]] = mapped_column(Integer)  # estimated ЦВЭ score (0–500)
    points: Mapped[int] = mapped_column(Integer, default=0)  # official points («очки»)
    max_points: Mapped[int] = mapped_column(Integer, default=0)
    details: Mapped[Optional[dict]] = mapped_column(JSON)  # per-subtest results of an exam

    user = relationship("User")
    user_answers: Mapped[List["UserAnswer"]] = relationship(
        back_populates="attempt", cascade="all, delete-orphan", order_by="UserAnswer.id"
    )


class UserAnswer(Base):
    __tablename__ = "user_answers"
    __table_args__ = (UniqueConstraint("attempt_id", "question_id", name="uq_answer_attempt_question"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    attempt_id: Mapped[int] = mapped_column(ForeignKey("test_attempts.id", ondelete="CASCADE"), index=True)
    question_id: Mapped[int] = mapped_column(ForeignKey("questions.id", ondelete="CASCADE"), index=True)
    selected_option_index: Mapped[Optional[int]] = mapped_column(Integer)
    answer: Mapped[Optional[object]] = mapped_column(JSON)  # matching: [i, i, i, i]; numeric: "125"
    is_correct: Mapped[bool] = mapped_column(Boolean, default=False)
    points: Mapped[int] = mapped_column(Integer, default=0)  # official points for this answer
    points_awarded: Mapped[int] = mapped_column(Integer, default=0)
    answered_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    attempt: Mapped[TestAttempt] = relationship(back_populates="user_answers")
    question = relationship("Question")


class MarkedQuestion(Base):
    """Question marked as "сложный / на повтор"; it goes into "Повторить ошибки"."""

    __tablename__ = "marked_questions"
    __table_args__ = (UniqueConstraint("user_id", "question_id", name="uq_marked_user_question"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    question_id: Mapped[int] = mapped_column(ForeignKey("questions.id", ondelete="CASCADE"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class LessonProgress(Base):
    __tablename__ = "lesson_progress"
    __table_args__ = (UniqueConstraint("user_id", "lesson_id", "role", name="uq_lesson_progress"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    lesson_id: Mapped[int] = mapped_column(ForeignKey("lessons.id", ondelete="CASCADE"))
    role: Mapped[UserRole] = mapped_column(str_enum(UserRole))
    completed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class PointsLedger(Base):
    __tablename__ = "points_ledger"
    __table_args__ = (Index("ix_points_role_created", "role", "created_at"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    role: Mapped[UserRole] = mapped_column(str_enum(UserRole))
    points: Mapped[int] = mapped_column(Integer)
    reason: Mapped[PointsReason] = mapped_column(str_enum(PointsReason))
    attempt_id: Mapped[Optional[int]] = mapped_column(ForeignKey("test_attempts.id", ondelete="SET NULL"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Achievement(Base):
    __tablename__ = "achievements"

    id: Mapped[int] = mapped_column(primary_key=True)
    code: Mapped[str] = mapped_column(String(64), unique=True)
    title_ru: Mapped[str] = mapped_column(String(200))
    title_tj: Mapped[str] = mapped_column(String(200), default="")
    description_ru: Mapped[Optional[str]] = mapped_column(String(500))
    description_tj: Mapped[Optional[str]] = mapped_column(String(500))
    icon: Mapped[Optional[str]] = mapped_column(String(64))
    points_reward: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    def title_for(self, lang: str) -> str:
        return self.title_tj if lang == "tj" and self.title_tj else self.title_ru

    def description_for(self, lang: str) -> Optional[str]:
        return self.description_tj if lang == "tj" and self.description_tj else self.description_ru

    def __str__(self) -> str:
        return self.title_ru


class UserAchievement(Base):
    __tablename__ = "user_achievements"
    __table_args__ = (UniqueConstraint("user_id", "achievement_id", name="uq_user_achievement"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    achievement_id: Mapped[int] = mapped_column(ForeignKey("achievements.id", ondelete="CASCADE"))
    unlocked_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    achievement: Mapped[Achievement] = relationship()
