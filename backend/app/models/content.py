import enum
from datetime import datetime
from typing import List, Optional

from sqlalchemy import JSON, Boolean, DateTime, ForeignKey, Integer, String, Text, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.database import Base
from app.models.base import str_enum
from app.models.user import Language


class Difficulty(str, enum.Enum):
    EASY = "easy"
    MEDIUM = "medium"
    HARD = "hard"


class Localized:
    """Mixin for entities titled in both languages (tj/ru), falling back to the other one."""

    def title_for(self, lang: str) -> str:
        if lang == "tj" and self.title_tj:
            return self.title_tj
        return self.title_ru or self.title_tj or ""

    def description_for(self, lang: str) -> Optional[str]:
        if lang == "tj" and getattr(self, "description_tj", None):
            return self.description_tj
        return getattr(self, "description_ru", None) or getattr(self, "description_tj", None)


class Cluster(Base, Localized):
    """MMT cluster (направление). Edited via admin, never hardcoded."""

    __tablename__ = "clusters"

    id: Mapped[int] = mapped_column(primary_key=True)
    code: Mapped[str] = mapped_column(String(32), unique=True)
    title_ru: Mapped[str] = mapped_column(String(200))
    title_tj: Mapped[str] = mapped_column(String(200), default="")
    description_ru: Mapped[Optional[str]] = mapped_column(Text)
    description_tj: Mapped[Optional[str]] = mapped_column(Text)
    icon: Mapped[Optional[str]] = mapped_column(String(64))
    order: Mapped[int] = mapped_column(Integer, default=0)
    # Official exam duration of component A for this cluster (190–220 min)
    duration_minutes: Mapped[int] = mapped_column(Integer, default=200)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    subject_links: Mapped[List["ClusterSubject"]] = relationship(
        back_populates="cluster", cascade="all, delete-orphan", order_by="ClusterSubject.position"
    )
    exam_tests: Mapped[List["ExamTest"]] = relationship(back_populates="cluster")

    @property
    def subjects(self) -> List["Subject"]:
        return [link.subject for link in self.subject_links]

    def __str__(self) -> str:
        return self.title_ru


class Subject(Base, Localized):
    """An abiturient subject (linked to clusters through ClusterSubject) or a school subject (grade set)."""

    __tablename__ = "subjects"

    id: Mapped[int] = mapped_column(primary_key=True)
    code: Mapped[Optional[str]] = mapped_column(String(32), unique=True)
    title_ru: Mapped[str] = mapped_column(String(200))
    title_tj: Mapped[str] = mapped_column(String(200), default="")
    icon: Mapped[Optional[str]] = mapped_column(String(64))
    color: Mapped[Optional[str]] = mapped_column(String(16))
    grade: Mapped[Optional[int]] = mapped_column(Integer, index=True)
    order: Mapped[int] = mapped_column(Integer, default=0)
    # Official subtest structure: {"single": 20, "matching": 4, "numeric": 2}
    exam_structure: Mapped[Optional[dict]] = mapped_column(JSON)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    cluster_links: Mapped[List["ClusterSubject"]] = relationship(back_populates="subject")
    topics: Mapped[List["Topic"]] = relationship(back_populates="subject", cascade="all, delete-orphan")

    def __str__(self) -> str:
        suffix = f" ({self.grade} кл.)" if self.grade else ""
        return f"{self.title_ru}{suffix}"


class ClusterSubject(Base):
    """A subtest of a cluster: A1..A4. Tajik language is A1 in every cluster.

    `language_track` marks alternatives of the same position (cluster 3, A3: Tajik literature for
    the Tajik exam language, Russian language & literature for the Russian one).
    `max_score` is the subtest's share of the 500-point scale (A1 is always 75).
    """

    __tablename__ = "cluster_subjects"
    __table_args__ = (UniqueConstraint("cluster_id", "subject_id", name="uq_cluster_subject"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    cluster_id: Mapped[int] = mapped_column(ForeignKey("clusters.id", ondelete="CASCADE"), index=True)
    subject_id: Mapped[int] = mapped_column(ForeignKey("subjects.id", ondelete="CASCADE"), index=True)
    position: Mapped[int] = mapped_column(Integer)
    max_score: Mapped[int] = mapped_column(Integer, default=125)
    language_track: Mapped[Optional[str]] = mapped_column(String(4))

    cluster: Mapped[Cluster] = relationship(back_populates="subject_links")
    subject: Mapped[Subject] = relationship(back_populates="cluster_links", lazy="joined")

    def __str__(self) -> str:
        return f"A{self.position}: {self.subject_id}"


class Topic(Base, Localized):
    """Topic tree: a root topic is a section/quarter (раздел/четверть), its children are topics."""

    __tablename__ = "topics"

    id: Mapped[int] = mapped_column(primary_key=True)
    subject_id: Mapped[int] = mapped_column(ForeignKey("subjects.id", ondelete="CASCADE"), index=True)
    parent_topic_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("topics.id", ondelete="CASCADE"), index=True
    )
    title_ru: Mapped[str] = mapped_column(String(300))
    title_tj: Mapped[str] = mapped_column(String(300), default="")
    order: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    subject: Mapped[Subject] = relationship(back_populates="topics")
    parent_topic: Mapped[Optional["Topic"]] = relationship(remote_side=[id], back_populates="child_topics")
    child_topics: Mapped[List["Topic"]] = relationship(back_populates="parent_topic", order_by="Topic.order")
    lessons: Mapped[List["Lesson"]] = relationship(back_populates="topic", cascade="all, delete-orphan")
    questions: Mapped[List["Question"]] = relationship(back_populates="topic")

    def __str__(self) -> str:
        return self.title_ru


class Lesson(Base):
    """Lesson content is authored per language (Markdown)."""

    __tablename__ = "lessons"

    id: Mapped[int] = mapped_column(primary_key=True)
    topic_id: Mapped[int] = mapped_column(ForeignKey("topics.id", ondelete="CASCADE"), index=True)
    language: Mapped[Language] = mapped_column(str_enum(Language), default=Language.RUSSIAN, index=True)
    title: Mapped[str] = mapped_column(String(300))
    content: Mapped[str] = mapped_column(Text)
    media_urls: Mapped[Optional[list]] = mapped_column(JSON, default=list)
    video_url: Mapped[Optional[str]] = mapped_column(String(500))
    order: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    topic: Mapped[Topic] = relationship(back_populates="lessons")
    check_questions: Mapped[List["Question"]] = relationship(back_populates="lesson")

    def __str__(self) -> str:
        return self.title


class QuestionType(str, enum.Enum):
    """Official ЦВЭ task types and their maximum points (points per task, «очки»)."""

    SINGLE = "single"       # one correct answer out of A–D: 1 point
    MATCHING = "matching"   # match A–D with 1–5 (one extra): 1 point per pair, max 4
    NUMERIC = "numeric"     # open answer, a natural number: 2 points

    @property
    def max_points(self) -> int:
        return {"single": 1, "matching": 4, "numeric": 2}[self.value]


class ExamTest(Base):
    """Fixed full test of a cluster (created in the admin panel)."""

    __tablename__ = "exam_tests"

    id: Mapped[int] = mapped_column(primary_key=True)
    cluster_id: Mapped[int] = mapped_column(ForeignKey("clusters.id"), index=True)
    year: Mapped[int] = mapped_column(Integer, index=True)
    language: Mapped[Language] = mapped_column(str_enum(Language), default=Language.RUSSIAN)
    title: Mapped[str] = mapped_column(String(200))
    duration_minutes: Mapped[int] = mapped_column(Integer)
    is_published: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    cluster: Mapped[Cluster] = relationship(back_populates="exam_tests")
    questions: Mapped[List["Question"]] = relationship(back_populates="exam_test", order_by="Question.order")

    def __str__(self) -> str:
        return self.title


class Question(Base):
    """Question of a topic, a lesson mini-check, or a fixed exam test.

    single:   options = 4 answers, correct_answer = [index, ...] (normally one)
    matching: matching_left = 4 items (A–D), options = 5 items (1–5), correct_answer = [option index for A..D]
    numeric:  options = [], correct_answer = "125" (a natural number)
    """

    __tablename__ = "questions"

    id: Mapped[int] = mapped_column(primary_key=True)
    topic_id: Mapped[Optional[int]] = mapped_column(ForeignKey("topics.id", ondelete="SET NULL"), index=True)
    lesson_id: Mapped[Optional[int]] = mapped_column(ForeignKey("lessons.id", ondelete="SET NULL"), index=True)
    exam_test_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("exam_tests.id", ondelete="CASCADE"), index=True
    )
    # Subject of an exam question, for the per-subject breakdown of a full MMT test
    subject_id: Mapped[Optional[int]] = mapped_column(ForeignKey("subjects.id", ondelete="SET NULL"), index=True)
    language: Mapped[Language] = mapped_column(str_enum(Language), default=Language.RUSSIAN, index=True)
    question_type: Mapped[QuestionType] = mapped_column(str_enum(QuestionType), default=QuestionType.SINGLE)
    passage: Mapped[Optional[str]] = mapped_column(Text)  # shared text (reading comprehension)
    text: Mapped[str] = mapped_column(Text)
    image_url: Mapped[Optional[str]] = mapped_column(String(500))
    options: Mapped[list] = mapped_column(JSON)
    matching_left: Mapped[Optional[list]] = mapped_column(JSON)
    correct_option_index: Mapped[Optional[int]] = mapped_column(Integer)
    correct_answer: Mapped[Optional[object]] = mapped_column(JSON)
    explanation: Mapped[Optional[str]] = mapped_column(Text)
    source: Mapped[Optional[str]] = mapped_column(String(200))  # e.g. "НЦТ, типовые задания ЦВЭ-2026, №257"
    difficulty: Mapped[Difficulty] = mapped_column(str_enum(Difficulty), default=Difficulty.MEDIUM)
    order: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    topic: Mapped[Optional[Topic]] = relationship(back_populates="questions")
    lesson: Mapped[Optional[Lesson]] = relationship(back_populates="check_questions")
    exam_test: Mapped[Optional[ExamTest]] = relationship(back_populates="questions")
    subject: Mapped[Optional[Subject]] = relationship()

    @property
    def max_points(self) -> int:
        return self.question_type.max_points

    @property
    def answer_key(self):
        """Normalized correct answer: list[int] for single/matching, str for numeric."""
        if self.correct_answer is not None:
            return self.correct_answer
        if self.question_type == QuestionType.SINGLE and self.correct_option_index is not None:
            return [self.correct_option_index]
        return None

    def __str__(self) -> str:
        return (self.text or self.source or "")[:60]


def topic_pool():
    """Questions of topic/section/practice tests: not lesson mini-checks and not past MMT papers."""
    return Question.exam_test_id.is_(None) & Question.lesson_id.is_(None)
