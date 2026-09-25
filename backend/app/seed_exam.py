"""ЦВЭ exam structure (clusters, subjects, subtests) and the app's own task bank.

Component A — exam after 11th grade: 4 subtests per cluster, Tajik language is always A1.
The structure follows the public exam rules ("Справочник абитуриента-2026", sections 9, 10, 11, 14).
Tasks: data/own/*.json, written by the EduApp team (built by `python -m tools.own_bank.build`).
"""
import json
import logging
from pathlib import Path
from typing import Optional

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import (
    Cluster,
    ClusterSubject,
    Difficulty,
    Language,
    Question,
    QuestionType,
    Subject,
    Topic,
)

logger = logging.getLogger(__name__)

DATA_DIR = Path(__file__).resolve().parent.parent / "data"

HUMANITIES = {"single": 20, "matching": 4, "numeric": 2}  # 26 tasks, 40 points (table 11.2)
SCIENCES = {"single": 18, "matching": 2, "numeric": 7}    # 27 tasks, 40 points

# code: (title_ru, title_tj, icon, color, structure)
SUBJECTS = {
    "tj_lang": ("Таджикский язык", "Забони тоҷикӣ", "translate", "#2563EB", HUMANITIES),
    "math": ("Математика", "Математика", "calculate", "#4F46E5", SCIENCES),
    "physics": ("Физика", "Физика", "bolt", "#7C3AED", SCIENCES),
    "chemistry": ("Химия", "Химия", "science", "#0D9488", SCIENCES),
    "biology": ("Биология", "Биология", "eco", "#059669", HUMANITIES),
    "geography": ("География", "Ҷуғрофия", "public", "#0891B2", HUMANITIES),
    "history": ("История", "Таърих", "account_balance", "#B45309", HUMANITIES),
    "law": ("Право", "Ҳуқуқ", "gavel", "#DB2777", HUMANITIES),
    "tj_lit": ("Таджикская литература", "Адабиёти тоҷик", "auto_stories", "#9333EA", HUMANITIES),
    "ru_lang_lit": ("Русский язык и литература", "Забон ва адабиёти рус", "menu_book", "#E11D48", HUMANITIES),
    "english": ("Английский язык", "Забони англисӣ", "language", "#0EA5E9", HUMANITIES),
}

# Subtest max scores follow examples of table 14.2 of the handbook; the real split depends on the
# chosen speciality (A1 Tajik language is always 75, the total is 500).
CLUSTERS = [
    {
        "code": "c1", "order": 1, "icon": "engineering", "duration_minutes": 220,
        "title_ru": "Естественный и технический", "title_tj": "Табиӣ ва техникӣ",
        "description_ru": "Инженерия, IT, энергетика, строительство, химические технологии",
        "description_tj": "Муҳандисӣ, IT, энергетика, сохтмон, технологияҳои химиявӣ",
        "subtests": [("tj_lang", 1, 75, None), ("math", 2, 175, None), ("chemistry", 3, 100, None),
                     ("physics", 4, 150, None)],
    },
    {
        "code": "c2", "order": 2, "icon": "bar_chart", "duration_minutes": 200,
        "title_ru": "Экономика и география", "title_tj": "Иқтисод ва ҷуғрофия",
        "description_ru": "Экономика, финансы, менеджмент, география, туризм",
        "description_tj": "Иқтисод, молия, менеҷмент, ҷуғрофия, сайёҳӣ",
        "subtests": [("tj_lang", 1, 75, None), ("math", 2, 175, None), ("geography", 3, 100, None),
                     ("english", 4, 150, None)],
    },
    {
        "code": "c3", "order": 3, "icon": "history_edu", "duration_minutes": 190,
        "title_ru": "Филология, педагогика и искусство", "title_tj": "Филология, педагогика ва санъат",
        "description_ru": "Языки и литература, журналистика, педагогика, искусство",
        "description_tj": "Забонҳо ва адабиёт, журналистика, педагогика, санъат",
        "subtests": [("tj_lang", 1, 75, None), ("history", 2, 100, None), ("tj_lit", 3, 175, "tj"),
                     ("ru_lang_lit", 3, 175, "ru"), ("english", 4, 150, None)],
    },
    {
        "code": "c4", "order": 4, "icon": "gavel", "duration_minutes": 190,
        "title_ru": "Обществоведение и право", "title_tj": "Ҷамъиятшиносӣ ва ҳуқуқ",
        "description_ru": "Юриспруденция, политология, международные отношения, история",
        "description_tj": "Ҳуқуқшиносӣ, сиёсатшиносӣ, муносибатҳои байналмилалӣ, таърих",
        "subtests": [("tj_lang", 1, 75, None), ("history", 2, 150, None), ("law", 3, 175, None),
                     ("english", 4, 100, None)],
    },
    {
        "code": "c5", "order": 5, "icon": "biotech", "duration_minutes": 220,
        "title_ru": "Медицина, биология и спорт", "title_tj": "Тиб, биология ва варзиш",
        "description_ru": "Медицина, фармация, биология, физическая культура",
        "description_tj": "Тиб, дорусозӣ, биология, тарбияи ҷисмонӣ",
        "subtests": [("tj_lang", 1, 75, None), ("biology", 2, 175, None), ("chemistry", 3, 150, None),
                     ("physics", 4, 100, None)],
    },
]

def seed_structure(db: Session) -> dict[str, Subject]:
    """Create the 5 clusters and 11 subjects with their subtests (idempotent by code)."""
    subjects: dict[str, Subject] = {}
    for order, (code, (title_ru, title_tj, icon, color, structure)) in enumerate(SUBJECTS.items(), start=1):
        subject = db.scalar(select(Subject).where(Subject.code == code))
        if subject is None:
            subject = Subject(code=code)
            db.add(subject)
        subject.title_ru, subject.title_tj, subject.icon, subject.color = title_ru, title_tj, icon, color
        subject.exam_structure, subject.order = structure, order
        subjects[code] = subject
    db.flush()

    for data in CLUSTERS:
        cluster = db.scalar(select(Cluster).where(Cluster.code == data["code"]))
        if cluster is None:
            cluster = Cluster(code=data["code"])
            db.add(cluster)
        for key in ("order", "icon", "duration_minutes", "title_ru", "title_tj", "description_ru", "description_tj"):
            setattr(cluster, key, data[key])
        db.flush()
        existing = {link.subject_id: link for link in cluster.subject_links}
        for code, position, max_score, track in data["subtests"]:
            subject = subjects[code]
            link = existing.get(subject.id) or ClusterSubject(cluster=cluster, subject=subject)
            link.position, link.max_score, link.language_track = position, max_score, track
            db.add(link)
    db.flush()
    return subjects


# ------------------------------------------------------------------ the app's own tasks
OWN_DIR = DATA_DIR / "own"
OWN_SOURCE = "EduApp · авторские задания"
OWN_SECTION = ("Задания повышенной сложности", "Супоришҳои мураккаб")


def load_own_banks(directory: Optional[Path] = None) -> list[dict]:
    """Our own tasks in the ЦВЭ format (data/own/*.json, built by `python -m tools.own_bank.build`)."""
    directory = directory or OWN_DIR
    return [json.loads(p.read_text(encoding="utf-8")) for p in sorted(directory.glob("*.json"))]


def seed_own_bank(db: Session, subjects: dict[str, Subject], banks: list[dict]) -> int:
    """A section «Задания повышенной сложности» per subject with topics; idempotent per subject and language."""
    count = 0
    for bank in banks:
        by_subject: dict[tuple[str, str], list[dict]] = {}
        for r in bank.get("questions", []):
            by_subject.setdefault((r["subject"], r["language"]), []).append(r)
        for (code, lang), records in by_subject.items():
            subject = subjects.get(code)
            if subject is None:
                logger.warning("Own tasks for unknown subject %s skipped", code)
                continue
            loaded = db.scalar(
                select(Question.id).where(
                    Question.subject_id == subject.id,
                    Question.language == Language(lang),
                    Question.source.like(f"{OWN_SOURCE}%"),
                )
            )
            if loaded:
                continue
            section = db.scalar(
                select(Topic).where(Topic.subject_id == subject.id, Topic.title_ru == OWN_SECTION[0])
            )
            if section is None:
                section = Topic(subject=subject, title_ru=OWN_SECTION[0], title_tj=OWN_SECTION[1], order=50)
                db.add(section)
            topics = {t.title_ru: t for t in section.child_topics}
            for order, r in enumerate(records, start=1):
                topic = topics.get(r["topic"])
                title_tj = r.get("topic_tj") or r["topic"]  # translated banks share topics with the Russian one
                if topic is None:
                    topic = Topic(subject=subject, parent_topic=section, title_ru=r["topic"], title_tj=title_tj,
                                  order=len(topics) + 1)
                    db.add(topic)
                    topics[r["topic"]] = topic
                elif r.get("topic_tj"):
                    topic.title_tj = title_tj
                qtype = QuestionType(r["type"])
                db.add(Question(
                    question_type=qtype,
                    language=Language(lang),
                    passage=r.get("passage"),
                    text=r["text"],
                    options=r.get("options") or [],
                    matching_left=r.get("left"),
                    correct_answer=r["correct"],
                    correct_option_index=r["correct"][0] if qtype == QuestionType.SINGLE else None,
                    difficulty=Difficulty(r.get("difficulty", "hard")),
                    explanation=r.get("explanation"),
                    source=f"{OWN_SOURCE} · {subject.title_for(lang)}",
                    subject=subject,
                    topic=topic,
                    order=order,
                ))
                count += 1
            db.flush()
    return count
