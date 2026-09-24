from datetime import datetime
from typing import List, Literal, Optional, Union

from pydantic import BaseModel, Field

# single: option index; matching: [option index for A, B, C, D]; numeric: "125"
AnswerValue = Union[int, List[int], str]


class AttemptCreate(BaseModel):
    test_type: Literal[
        "topic_test", "section_test", "practice", "exam_test", "mock_exam", "lesson_check", "mistakes"
    ]
    reference_id: Optional[int] = None
    timed: bool = False
    question_count: Optional[int] = Field(default=None, ge=1, le=50)


class QuestionOut(BaseModel):
    """A question without its answer: correctness is revealed only after answering."""

    id: int
    question_type: str
    passage: Optional[str]
    text: str
    image_url: Optional[str]
    options: List[str]
    matching_left: Optional[List[str]]
    max_points: int
    difficulty: str
    subject_id: Optional[int]
    source: Optional[str]
    is_marked: bool


class AnsweredOut(BaseModel):
    question_id: int
    selected_option_index: Optional[int] = None
    answer: Optional[AnswerValue] = None
    # Hidden (None) during an exam
    is_correct: Optional[bool] = None
    points: Optional[int] = None
    correct_option_index: Optional[int] = None
    correct_answer: Optional[AnswerValue] = None
    explanation: Optional[str] = None


class AttemptOut(BaseModel):
    id: int
    test_type: str
    reference_id: Optional[int]
    status: str
    is_timed: bool
    started_at: datetime
    expires_at: Optional[datetime]
    server_time: datetime
    shows_feedback: bool
    questions: List[QuestionOut]
    answers: List[AnsweredOut]
    score: int
    answer_streak: int


class AnswerIn(BaseModel):
    question_id: int
    selected_option_index: Optional[int] = Field(default=None, ge=0)
    answer: Optional[AnswerValue] = None


class AnswerResult(BaseModel):
    question_id: int
    accepted: bool = True
    answered_count: int
    total_count: int
    # Feedback fields are None during an exam
    is_correct: Optional[bool] = None
    points: Optional[int] = None
    max_points: Optional[int] = None
    correct_option_index: Optional[int] = None
    correct_answer: Optional[AnswerValue] = None
    explanation: Optional[str] = None
    points_awarded: Optional[int] = None
    streak_bonus: Optional[bool] = None
    answer_streak: Optional[int] = None
    attempt_score: Optional[int] = None


class ReviewItem(BaseModel):
    question_id: int
    question_type: str
    passage: Optional[str]
    text: str
    image_url: Optional[str]
    options: List[str]
    matching_left: Optional[List[str]]
    selected_option_index: Optional[int]
    answer: Optional[AnswerValue]
    correct_option_index: Optional[int]
    correct_answer: Optional[AnswerValue]
    is_correct: bool
    points: int
    max_points: int
    explanation: Optional[str]
    source: Optional[str]
    is_marked: bool
    subject_id: Optional[int]


class SubjectBreakdown(BaseModel):
    """A subtest of an exam (A1..A4): official points and the scaled score."""

    subject_id: Optional[int]
    title: str
    position: int = 0
    correct: int
    total: int
    points: int = 0
    max_points: int = 0
    score: float = 0
    max_score: int = 0


class AchievementBrief(BaseModel):
    code: str
    title: str
    icon: Optional[str]
    points_reward: int


class AttemptResult(BaseModel):
    attempt_id: int
    test_type: str
    reference_id: Optional[int]
    correct_count: int
    total_count: int
    answered_count: int
    accuracy: int
    points: int
    max_points: int
    score: int
    completion_bonus: int
    mmt_score: Optional[int]
    mmt_max: int = 500
    duration_seconds: Optional[int]
    subjects: List[SubjectBreakdown]
    new_achievements: List[AchievementBrief]
    total_points: int
    level: dict
    review: List[ReviewItem]


class AttemptHistoryItem(BaseModel):
    id: int
    test_type: str
    reference_id: Optional[int]
    title: str
    status: str
    started_at: datetime
    finished_at: Optional[datetime]
    correct_count: int
    total_count: int
    accuracy: int
    score: int
    mmt_score: Optional[int]
