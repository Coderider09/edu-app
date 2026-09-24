from typing import List, Optional

from pydantic import BaseModel


class ClusterOut(BaseModel):
    id: int
    code: str
    title: str
    description: Optional[str]
    icon: Optional[str]
    order: int
    duration_minutes: int = 200
    subjects: List["SubjectOut"] = []


class SubjectOut(BaseModel):
    id: int
    code: Optional[str] = None
    title: str
    icon: Optional[str]
    color: Optional[str]
    cluster_id: Optional[int] = None
    position: Optional[int] = None  # subtest A1..A4 within the cluster
    grade: Optional[int]
    progress_percent: Optional[int] = None


class TopicProgressOut(BaseModel):
    lessons_total: int
    lessons_completed: int
    questions_count: int
    best_accuracy: Optional[int]
    passed: bool
    percent: int


class TopicOut(BaseModel):
    id: int
    title: str
    order: int
    parent_topic_id: Optional[int]
    progress: Optional[TopicProgressOut] = None


class SectionOut(BaseModel):
    """A section/quarter with its topics; has its own final test."""

    id: int
    title: str
    order: int
    has_final_test: bool
    topics: List[TopicOut]
    progress: Optional[TopicProgressOut] = None


class SubjectTopicsOut(BaseModel):
    subject: SubjectOut
    sections: List[SectionOut]


class LessonOut(BaseModel):
    id: int
    topic_id: int
    title: str
    content: str
    language: str
    media_urls: List[str]
    video_url: Optional[str]
    order: int
    check_questions_count: int
    completed: bool


class TopicTestOut(BaseModel):
    topic_id: int
    title: str
    questions_count: int
    default_question_count: int
    time_limit_seconds_per_question: int
    best_accuracy: Optional[int]
    attempts_count: int


class ExamTestOut(BaseModel):
    id: int
    cluster_id: int
    year: int
    title: str
    language: str
    duration_minutes: int
    total_questions: int
    best_mmt_score: Optional[int] = None


ClusterOut.model_rebuild()
