import json

from sqlalchemy import func, select

from app.models import Lesson, Question, Topic
from app.seed import seed_content
from app.seed_lessons import LESSONS_DIR, LESSONS_SECTION
from tests.conftest import subject_id
from tools.lessons.build import SOURCES, build_source


def _banks() -> list[dict]:
    return [json.loads(p.read_text(encoding="utf-8")) for p in sorted(LESSONS_DIR.glob("*.json"))]


def _section(db, code: str) -> Topic:
    return db.scalar(select(Topic).where(Topic.subject_id == subject_id(db, code),
                                         Topic.title_ru == LESSONS_SECTION[0]))


def test_built_json_is_up_to_date():
    """data/lessons/*.json must be rebuilt after editing the sources (python -m tools.lessons.build)."""
    for name in SOURCES:
        path, bank = build_source(name)
        assert json.loads(path.read_text(encoding="utf-8")) == bank


def test_every_lesson_has_a_summary_a_check_and_exercises():
    for bank in _banks():
        for lesson in bank["lessons"]:
            assert lesson["content"].startswith("# ") and "\n## " in lesson["content"]
            assert len(lesson["check"]) == 3 and len(lesson["practice"]) >= 5
            assert all(q["explanation"] for q in lesson["check"] + lesson["practice"])


def test_lessons_are_seeded_once(db):
    expected = sum(len(b["lessons"]) for b in _banks())
    sections = select(Topic.id).where(Topic.title_ru == LESSONS_SECTION[0])
    total = db.scalar(select(func.count(Lesson.id)).join(Topic).where(Topic.parent_topic_id.in_(sections)))
    assert total == expected
    section = _section(db, "math")
    assert section is not None and section.title_tj == LESSONS_SECTION[1]
    before = db.scalar(select(func.count(Lesson.id)))
    seed_content(db, bank={"questions": []})  # running the seed again adds nothing
    db.commit()
    assert db.scalar(select(func.count(Lesson.id))) == before


def test_lesson_check_and_topic_test_use_lesson_questions(client, db, abiturient):
    section = _section(db, "math")
    topic = next(t for t in section.child_topics if t.title_ru == "Тригонометрия")
    assert topic.title_tj == "Тригонометрия"
    lesson = topic.lessons[0]
    check = client.post("/api/v1/attempts", json={"test_type": "lesson_check", "reference_id": lesson.id},
                        headers=abiturient).json()
    assert len(check["questions"]) == 3
    practice = client.post("/api/v1/attempts", json={"test_type": "topic_test", "reference_id": topic.id},
                           headers=abiturient).json()
    ids = {q["id"] for q in practice["questions"]}
    # the topic test takes the exercises, not the lesson's mini-check
    assert ids and not ids & {q["id"] for q in check["questions"]}
    assert all(db.get(Question, i).lesson_id is None for i in ids)
