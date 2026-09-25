"""A small deterministic task bank for tests: sections by task type and a fixed exam test per cluster."""
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Cluster, Difficulty, ExamTest, Language, Question, QuestionType, Subject, Topic
from app.seed_exam import CLUSTERS, SUBJECTS

SINGLE_PER_SUBJECT = 30
MATCHING_PER_SUBJECT = 5
NUMERIC_PER_SUBJECT = 8
SAMPLE_PER_SUBJECT = 3

SOURCE = "Тестовые данные"
EXAM_TITLE = "Пробный вариант ЦВЭ"
SECTION_TITLES = {
    "single": ("Задания с выбором ответа", "Саволҳо бо интихоби ҷавоб"),
    "matching": ("Задания на соответствие", "Саволҳо барои муайян кардани мувофиқат"),
    "numeric": ("Задания открытого типа", "Саволҳои шакли кушода"),
}


def _record(code: str, qtype: str, number: int, topic: str, sample: bool = False) -> dict:
    lang = "tj" if code in ("tj_lang", "tj_lit") else "ru"
    base = {"subject": code, "type": qtype, "topic": topic, "number": number, "sample": sample,
            "language": lang, "text": f"{code} {qtype} {number}"}
    if qtype == "single":
        return base | {"options": ["A1", "B1", "C1", "D1"], "correct": [number % 4]}
    if qtype == "matching":
        return base | {"left": ["l1", "l2", "l3", "l4"], "options": ["r1", "r2", "r3", "r4", "r5"],
                       "correct": [1, 0, 3, 2]}
    return base | {"options": [], "correct": str(10 + number)}


def small_bank() -> list[dict]:
    records = []
    for code in SUBJECTS:
        records += [_record(code, "single", n, "Тема A" if n <= 15 else "Тема B")
                    for n in range(1, SINGLE_PER_SUBJECT + 1)]
        records += [_record(code, "matching", n, "Соответствие") for n in range(1, MATCHING_PER_SUBJECT + 1)]
        records += [_record(code, "numeric", n, "Вычисления") for n in range(1, NUMERIC_PER_SUBJECT + 1)]
        records += [_record(code, "single", n, "Образец субтеста", sample=True)
                    for n in range(1, SAMPLE_PER_SUBJECT + 1)]
    return records


def _question(record: dict, subject: Subject, **links) -> Question:
    qtype = QuestionType(record["type"])
    correct = record["correct"]
    return Question(
        question_type=qtype, language=Language(record["language"]), text=record["text"],
        options=record["options"], matching_left=record.get("left"), correct_answer=correct,
        correct_option_index=correct[0] if qtype == QuestionType.SINGLE else None,
        difficulty=Difficulty.MEDIUM, source=SOURCE, subject=subject, order=record["number"], **links,
    )


def seed_small_bank(db: Session) -> None:
    """Sections «Задания …» with topics for every exam subject + a fixed exam test per cluster/language track."""
    subjects = {s.code: s for s in db.scalars(select(Subject).where(Subject.code.in_(SUBJECTS)))}
    records = small_bank()
    samples: dict[str, list[dict]] = {}
    for code, subject in subjects.items():
        own = [r for r in records if r["subject"] == code]
        samples[code] = [r for r in own if r["sample"]]
        topics: dict[tuple[str, str], Topic] = {}
        for order, qtype in enumerate(("single", "matching", "numeric"), start=1):
            title_ru, title_tj = SECTION_TITLES[qtype]
            section = Topic(subject=subject, title_ru=title_ru, title_tj=title_tj, order=100 + order)
            db.add(section)
            for r in (r for r in own if r["type"] == qtype and not r["sample"]):
                topic = topics.get((qtype, r["topic"]))
                if topic is None:
                    topic = Topic(subject=subject, parent_topic=section, title_ru=r["topic"], title_tj=r["topic"],
                                  order=len([k for k in topics if k[0] == qtype]) + 1)
                    db.add(topic)
                    topics[(qtype, r["topic"])] = topic
                db.add(_question(r, subject, topic=topic))
    db.flush()

    for data in CLUSTERS:
        cluster = db.scalar(select(Cluster).where(Cluster.code == data["code"]))
        tracks = sorted({t for *_, t in data["subtests"] if t}) or [None]
        for track in tracks:
            chosen = sorted(((code, pos) for code, pos, _, t in data["subtests"] if t in (None, track)),
                            key=lambda c: c[1])
            exam = ExamTest(cluster=cluster, year=2026, language=Language(track or "ru"),
                            duration_minutes=cluster.duration_minutes, title=EXAM_TITLE)
            db.add(exam)
            order = 0
            for code, _pos in chosen:
                for r in samples[code]:
                    order += 1
                    q = _question(r, subjects[code], exam_test=exam)
                    q.order = order
                    db.add(q)
    db.flush()
