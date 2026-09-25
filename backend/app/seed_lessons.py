"""Lessons written for EduApp (data/lessons/*.json, built by `python -m tools.lessons.build`).

Every subject gets a section «Уроки и упражнения»: a topic per lesson with the lesson itself (per language),
its 3-question mini-check and practice exercises for the topic test.
"""
import json
import logging
from pathlib import Path
from typing import Optional

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Difficulty, Language, Lesson, Question, QuestionType, Subject, Topic

logger = logging.getLogger(__name__)

LESSONS_DIR = Path(__file__).resolve().parents[1] / "data" / "lessons"
LESSONS_SECTION = ("Уроки и упражнения", "Дарсҳо ва машқҳо")
LESSONS_SOURCE = "EduApp · уроки"


def load_lesson_banks(directory: Optional[Path] = None) -> list[dict]:
    directory = directory or LESSONS_DIR
    return [json.loads(p.read_text(encoding="utf-8")) for p in sorted(directory.glob("*.json"))]


def _question(r: dict, subject: Subject, lang: str, order: int, **links) -> Question:
    qtype = QuestionType(r["type"])
    return Question(
        question_type=qtype,
        language=Language(lang),
        passage=r.get("passage"),
        text=r["text"],
        options=r.get("options") or [],
        matching_left=r.get("left"),
        correct_answer=r["correct"],
        correct_option_index=r["correct"][0] if qtype == QuestionType.SINGLE else None,
        difficulty=Difficulty(r.get("difficulty", "medium")),
        explanation=r.get("explanation"),
        source=f"{LESSONS_SOURCE} · {subject.title_for(lang)}",
        order=order,
        **links,
    )


def seed_lessons(db: Session, subjects: dict[str, Subject], banks: list[dict]) -> int:
    """Idempotent per subject and language; translations share the topics of the Russian lessons."""
    count = 0
    for bank in banks:
        subject, lang = subjects.get(bank["subject"]), bank["language"]
        if subject is None:
            logger.warning("Lessons for unknown subject %s skipped", bank["subject"])
            continue
        section = db.scalar(select(Topic).where(Topic.subject_id == subject.id, Topic.title_ru == LESSONS_SECTION[0]))
        if section is None:
            section = Topic(subject=subject, title_ru=LESSONS_SECTION[0], title_tj=LESSONS_SECTION[1], order=5)
            db.add(section)
            db.flush()
        elif db.scalar(select(Lesson.id).join(Topic).where(Topic.parent_topic_id == section.id,
                                                            Lesson.language == Language(lang))):
            continue
        topics = {t.title_ru: t for t in section.child_topics}
        for order, r in enumerate(bank["lessons"], start=1):
            topic = topics.get(r["topic"])
            if topic is None:
                topic = Topic(subject=subject, parent_topic=section, title_ru=r["topic"], title_tj=r["topic_tj"],
                              order=order)
                db.add(topic)
                topics[r["topic"]] = topic
            else:
                topic.title_tj = r["topic_tj"]
            lesson = Lesson(topic=topic, language=Language(lang), title=r["title"], content=r["content"], order=1)
            db.add(lesson)
            for i, item in enumerate(r["check"]):
                db.add(_question(item, subject, lang, i, topic=topic, lesson=lesson))
            for i, item in enumerate(r["practice"]):
                db.add(_question(item, subject, lang, i, topic=topic))
            count += 1
        db.flush()
    return count
