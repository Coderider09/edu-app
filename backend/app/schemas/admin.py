"""Payloads of the admin REST API (content CRUD)."""
import re
from typing import List, Literal, Optional, Union

from pydantic import BaseModel, Field, model_validator

Lang = Literal["tj", "ru"]


class ClusterIn(BaseModel):
    code: str = Field(min_length=1, max_length=32)
    title_ru: str
    title_tj: str = ""
    description_ru: Optional[str] = None
    description_tj: Optional[str] = None
    icon: Optional[str] = None
    order: int = 0
    duration_minutes: int = Field(default=200, ge=10, le=600)


class SubjectIn(BaseModel):
    """Abiturient subjects have no grade and are linked to clusters via /admin/cluster-subjects."""

    code: Optional[str] = Field(default=None, max_length=32)
    title_ru: str
    title_tj: str = ""
    icon: Optional[str] = None
    color: Optional[str] = None
    grade: Optional[int] = Field(default=None, ge=1, le=11)
    order: int = 0
    exam_structure: Optional[dict] = None  # {"single": 20, "matching": 4, "numeric": 2}


class ClusterSubjectIn(BaseModel):
    cluster_id: int
    subject_id: int
    position: int = Field(ge=1, le=6)
    max_score: int = Field(default=125, ge=0, le=500)
    language_track: Optional[Lang] = None


class TopicIn(BaseModel):
    subject_id: int
    parent_topic_id: Optional[int] = None
    title_ru: str
    title_tj: str = ""
    order: int = 0


class LessonIn(BaseModel):
    topic_id: int
    language: Lang = "ru"
    title: str
    content: str
    media_urls: List[str] = []
    video_url: Optional[str] = None
    order: int = 0


class QuestionIn(BaseModel):
    topic_id: Optional[int] = None
    lesson_id: Optional[int] = None
    exam_test_id: Optional[int] = None
    subject_id: Optional[int] = None
    language: Lang = "ru"
    question_type: Literal["single", "matching", "numeric"] = "single"
    passage: Optional[str] = None
    text: str = ""
    image_url: Optional[str] = None
    options: List[str] = Field(default_factory=list, max_length=6)
    matching_left: Optional[List[str]] = None
    correct_option_index: Optional[int] = Field(default=None, ge=0)
    correct_answer: Optional[Union[List[int], str]] = None
    explanation: Optional[str] = None
    source: Optional[str] = None
    difficulty: Literal["easy", "medium", "hard"] = "medium"
    order: int = 0

    @model_validator(mode="after")
    def check_answer_and_owner(self):
        if self.topic_id is None and self.lesson_id is None and self.exam_test_id is None:
            raise ValueError("Question must belong to a topic, a lesson or an exam test")
        if not self.text and not self.image_url:
            raise ValueError("Question needs a text or an image")
        if self.question_type == "single":
            if len(self.options) < 2:
                raise ValueError("A single-choice question needs at least 2 options")
            if self.correct_answer is None and self.correct_option_index is not None:
                self.correct_answer = [self.correct_option_index]
            key = self.correct_answer
            if not isinstance(key, list) or not key or any(not 0 <= k < len(self.options) for k in key):
                raise ValueError("correct_option_index is out of range")
            self.correct_option_index = key[0]
        elif self.question_type == "matching":
            left = self.matching_left or []
            key = self.correct_answer
            if len(left) < 2 or len(self.options) <= len(left) - 1:
                raise ValueError("Matching needs left items and at least as many options")
            if not isinstance(key, list) or len(key) != len(left) or any(
                not 0 <= k < len(self.options) for k in key
            ):
                raise ValueError("correct_answer must give an option index for every left item")
        else:
            if not isinstance(self.correct_answer, str) or not re.fullmatch(r"\d+([.,]\d+)?", self.correct_answer):
                raise ValueError("correct_answer of an open question must be a number")
            self.options = []
        return self


class ExamTestIn(BaseModel):
    cluster_id: int
    year: int = Field(ge=2000, le=2100)
    language: Lang = "ru"
    title: str
    duration_minutes: int = Field(ge=1, le=600)
    is_published: bool = True
