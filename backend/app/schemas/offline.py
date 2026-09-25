from datetime import datetime
from typing import List, Literal, Optional

from pydantic import BaseModel, Field

from app.schemas.testing import AnswerValue
from app.schemas.user import ProfileOut

MAX_SYNC_ATTEMPTS = 50
MAX_ATTEMPT_QUESTIONS = 200


class SubtestOut(BaseModel):
    subject_id: int
    position: int
    max_score: int
    language_track: Optional[str]


class ClusterStructureOut(BaseModel):
    id: int
    code: str
    title_ru: str
    title_tj: str
    duration_minutes: int
    subtests: List[SubtestOut]


class PackOut(BaseModel):
    subject_id: int
    code: Optional[str]
    title_ru: str
    title_tj: str
    grade: Optional[int]
    version: str
    size_bytes: int
    questions: int
    lessons: int
    images: int


class ManifestOut(BaseModel):
    format: int
    clusters: List[ClusterStructureOut]
    packs: List[PackOut]


class SyncAnswer(BaseModel):
    question_id: int
    answer: AnswerValue
    answered_at: datetime


class SyncAttempt(BaseModel):
    """A test taken offline. The server re-grades every answer with its own keys."""

    client_id: str = Field(min_length=8, max_length=64, pattern=r"^[A-Za-z0-9_-]+$")
    test_type: Literal["topic_test", "section_test", "practice", "mock_exam", "lesson_check", "mistakes"]
    reference_id: Optional[int] = None
    question_ids: List[int] = Field(min_length=1, max_length=MAX_ATTEMPT_QUESTIONS)
    started_at: datetime
    finished_at: datetime
    answers: List[SyncAnswer] = Field(default_factory=list, max_length=MAX_ATTEMPT_QUESTIONS)


class SyncLesson(BaseModel):
    lesson_id: int
    completed_at: datetime


class SyncIn(BaseModel):
    attempts: List[SyncAttempt] = Field(default_factory=list, max_length=MAX_SYNC_ATTEMPTS)
    lessons: List[SyncLesson] = Field(default_factory=list, max_length=500)
    marked: List[int] = Field(default_factory=list, max_length=500)
    unmarked: List[int] = Field(default_factory=list, max_length=500)


class SyncAttemptResult(BaseModel):
    client_id: str
    status: Literal["created", "duplicate", "rejected"]
    detail: Optional[str] = None
    attempt_id: Optional[int] = None
    score: Optional[int] = None
    points: Optional[int] = None
    max_points: Optional[int] = None
    correct_count: Optional[int] = None
    total_count: Optional[int] = None
    mmt_score: Optional[int] = None


class SyncOut(BaseModel):
    attempts: List[SyncAttemptResult]
    lessons_saved: int
    server_time: datetime
    profile: ProfileOut
