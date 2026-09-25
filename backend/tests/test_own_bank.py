import json

from sqlalchemy import func, select

from app.models import Language, Question, Subject, Topic
from app.seed import seed_content
from app.seed_ntc import OWN_DIR, OWN_SECTION, OWN_SOURCE
from tests.conftest import subject_id
from tools.own_bank.build import SOURCES, build_source


def _own_count(db) -> int:
    return db.scalar(select(func.count(Question.id)).where(Question.source.like(f"{OWN_SOURCE}%")))


def test_built_json_is_up_to_date():
    """data/own/*.json must be rebuilt after editing the sources (python -m tools.own_bank.build)."""
    for name in SOURCES:
        path, records = build_source(name)
        assert json.loads(path.read_text(encoding="utf-8"))["questions"] == records


# One ЦВЭ subtest per subject: (single, matching, numeric) — as in the official sample exams
SUBTEST = {
    "math": (18, 2, 7), "physics": (18, 2, 7), "chemistry": (18, 2, 7), "biology": (20, 4, 1),
    "geography": (20, 4, 2), "history": (20, 4, 2), "law": (20, 5, 0), "english": (20, 5, 0),
    "ru_lang_lit": (20, 5, 0), "tj_lang": (20, 5, 0), "tj_lit": (20, 5, 0),
}


def test_every_subject_has_full_subtests():
    for path in sorted(OWN_DIR.glob("*.json")):
        records = json.loads(path.read_text(encoding="utf-8"))["questions"]
        subject = records[0]["subject"]
        types = [r["type"] for r in records]
        counts = (types.count("single"), types.count("matching"), types.count("numeric"))
        variants = counts[0] // SUBTEST[subject][0]
        assert variants >= 2 and counts == tuple(n * variants for n in SUBTEST[subject]), (path.name, counts)
        assert all(r["explanation"] for r in records)
    assert {p.stem.rsplit("_", 1)[0] for p in OWN_DIR.glob("*.json")} == set(SUBTEST)


def test_math_bank_follows_the_exam_format():
    records = json.loads((OWN_DIR / "math_ru.json").read_text(encoding="utf-8"))["questions"]
    types = [r["type"] for r in records]
    # four full math subtests: 18 single + 2 matching + 7 open tasks each
    assert (types.count("single"), types.count("matching"), types.count("numeric")) == (72, 8, 28)
    assert all(r["explanation"] for r in records)
    # the right answer is spread over A–D
    letters = {r["correct"][0] for r in records if r["type"] == "single"}
    assert letters == {0, 1, 2, 3}


def test_own_tasks_are_seeded_once_with_solutions(client, db, abiturient):
    math = db.get(Subject, subject_id(db, "math"))
    total = _own_count(db)
    assert total == sum(len(json.loads(p.read_text(encoding="utf-8"))["questions"]) for p in OWN_DIR.glob("*.json"))
    section = db.scalar(select(Topic).where(Topic.subject_id == math.id, Topic.title_ru == OWN_SECTION[0]))
    assert section is not None and len(section.child_topics) >= 10

    seed_content(db, bank={"questions": []})  # running the seed again adds nothing
    db.commit()
    assert _own_count(db) == total

    for code in SUBTEST:  # every subject got its own section
        subject = subject_id(db, code)
        assert db.scalar(select(Topic.id).where(Topic.subject_id == subject, Topic.title_ru == OWN_SECTION[0]))

    topic = next(t for t in section.child_topics if t.title_ru == "Тригонометрия")
    attempt = client.post("/api/v1/attempts", json={"test_type": "topic_test", "reference_id": topic.id},
                          headers=abiturient).json()
    q = db.get(Question, attempt["questions"][0]["id"])
    answer = {"selected_option_index": q.correct_option_index} if q.correct_option_index is not None \
        else {"answer": q.correct_answer}
    r = client.post(f"/api/v1/attempts/{attempt['id']}/answer", json={"question_id": q.id, **answer},
                    headers=abiturient).json()
    assert r["is_correct"] is True and r["explanation"]


def test_own_tasks_join_the_mock_exam(db):
    math = subject_id(db, "math")
    own = db.scalar(select(func.count(Question.id)).where(
        Question.subject_id == math, Question.source.like(f"{OWN_SOURCE}%"), Question.question_type == "numeric",
        Question.language == "ru"))
    assert own == 28  # open tasks of the mock exam can now come from our bank too


def test_tajik_versions_share_topics_with_russian(db):
    math = subject_id(db, "math")
    section = db.scalar(select(Topic).where(Topic.subject_id == math, Topic.title_ru == OWN_SECTION[0]))
    word_problems = next(t for t in section.child_topics if t.title_ru == "Текстовые задачи")
    assert word_problems.title_tj == "Масъалаҳои матнӣ"
    by_language = dict(db.execute(
        select(Question.language, func.count(Question.id)).where(Question.topic_id == word_problems.id)
        .group_by(Question.language)).all())
    assert by_language[Language("ru")] == by_language[Language("tj")] > 0  # one topic, both languages
