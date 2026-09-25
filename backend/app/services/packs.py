"""Offline content packs: one ZIP per subject with topics, lessons, questions (with answer keys),
explanations and task images. The app downloads the packs of its cluster once and then works
without internet; results are uploaded later through /sync and re-graded on the server.
"""
import hashlib
import io
import json
import os
import threading
import time
import zipfile
from pathlib import Path
from typing import Optional

from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.models import Cluster, Lesson, Question, Subject, Topic
from app.services.testing import DEFAULT_STRUCTURE

PACK_FORMAT = 1
APP_DIR = Path(__file__).resolve().parent.parent
# Built ZIPs; a writable directory (data/ is mounted read-only in Docker)
PACKS_DIR = Path(os.environ.get("PACKS_DIR") or APP_DIR.parent / "data" / "packs")
STATIC_DIR = APP_DIR / "static"
CACHE_SECONDS = 3600  # admin changes invalidate it at once; this covers `python -m app.seed`

_lock = threading.Lock()
# subject_id -> (built_at, content, version, images)
_cache: dict[int, tuple[float, dict, str, list[tuple[str, Path]]]] = {}


def invalidate() -> None:
    """Called after content changes in the admin panel."""
    with _lock:
        _cache.clear()


def _image_name(url: Optional[str]) -> Optional[str]:
    if not url or not url.startswith("/static/"):
        return None
    return "images/" + url.rsplit("/", 1)[-1]


def _question_dict(q: Question) -> dict:
    return {
        "id": q.id,
        "topic_id": q.topic_id,
        "lesson_id": q.lesson_id,
        "subject_id": q.subject_id,
        "language": q.language.value,
        "type": q.question_type.value,
        "passage": q.passage,
        "text": q.text,
        "image": _image_name(q.image_url),
        "image_url": q.image_url,
        "options": list(q.options or []),
        "matching_left": list(q.matching_left) if q.matching_left else None,
        "answer": q.answer_key,
        "explanation": q.explanation,
        "difficulty": q.difficulty.value,
        "source": q.source,
        "max_points": q.max_points,
    }


def build_content(db: Session, subject: Subject) -> dict:
    topics = list(db.scalars(select(Topic).where(Topic.subject_id == subject.id).order_by(Topic.order, Topic.id)))
    topic_ids = [t.id for t in topics]
    lessons = list(
        db.scalars(select(Lesson).where(Lesson.topic_id.in_(topic_ids)).order_by(Lesson.order, Lesson.id))
    ) if topic_ids else []
    lesson_ids = [lesson.id for lesson in lessons]
    owners = [Question.topic_id.in_(topic_ids)] if topic_ids else []
    if lesson_ids:
        owners.append(Question.lesson_id.in_(lesson_ids))
    questions = list(
        db.scalars(
            select(Question)
            .where(or_(*owners), Question.exam_test_id.is_(None))
            .order_by(Question.order, Question.id)
        )
    ) if owners else []
    return {
        "format": PACK_FORMAT,
        "subject": {
            "id": subject.id,
            "code": subject.code,
            "title_ru": subject.title_ru,
            "title_tj": subject.title_tj,
            "icon": subject.icon,
            "color": subject.color,
            "grade": subject.grade,
            "exam_structure": subject.exam_structure or DEFAULT_STRUCTURE,
        },
        "topics": [
            {"id": t.id, "parent_id": t.parent_topic_id, "title_ru": t.title_ru, "title_tj": t.title_tj,
             "order": t.order}
            for t in topics
        ],
        "lessons": [
            {"id": lesson.id, "topic_id": lesson.topic_id, "language": lesson.language.value, "title": lesson.title,
             "content": lesson.content, "media_urls": list(lesson.media_urls or []), "video_url": lesson.video_url,
             "order": lesson.order}
            for lesson in lessons
        ],
        "questions": [_question_dict(q) for q in questions],
    }


def _snapshot(db: Session, subject: Subject) -> tuple[dict, str, list[tuple[str, Path]]]:
    """Content, its version and image files of a subject (cached: checking files is slow on mounts)."""
    with _lock:
        cached = _cache.get(subject.id)
        if cached and time.time() - cached[0] < CACHE_SECONDS:
            return cached[1], cached[2], cached[3]
    content = build_content(db, subject)
    raw = json.dumps(content, ensure_ascii=False, sort_keys=True).encode("utf-8")
    version = hashlib.sha1(raw).hexdigest()[:16]
    images = _images(content)
    with _lock:
        _cache[subject.id] = (time.time(), content, version, images)
    return content, version, images


def content_and_version(db: Session, subject: Subject) -> tuple[dict, str]:
    content, version, _ = _snapshot(db, subject)
    return content, version


def _images(content: dict) -> list[tuple[str, Path]]:
    files = {}
    for q in content["questions"]:
        if q["image"] and q["image_url"]:
            path = STATIC_DIR / q["image_url"][len("/static/"):]
            if path.is_file():
                files[q["image"]] = path
    return sorted(files.items())


def estimated_size(content: dict, images: list[tuple[str, Path]]) -> int:
    raw = len(json.dumps(content, ensure_ascii=False).encode("utf-8")) // 4  # JSON compresses ~4x
    return raw + sum(path.stat().st_size for _, path in images)


def pack_path(subject_id: int, version: str) -> Path:
    return PACKS_DIR / f"subject-{subject_id}-{version}.zip"


def build_zip(db: Session, subject: Subject) -> Path:
    """Build (or reuse) the ZIP of the current version of a subject."""
    content, version, images = _snapshot(db, subject)
    path = pack_path(subject.id, version)
    if path.is_file():
        return path
    PACKS_DIR.mkdir(parents=True, exist_ok=True)
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w", zipfile.ZIP_DEFLATED) as zf:
        # The server-side image path is not needed in the app (content itself is cached, don't mutate it)
        questions = [{k: v for k, v in q.items() if k != "image_url"} for q in content["questions"]]
        pack = {**content, "questions": questions, "version": version}
        zf.writestr("content.json", json.dumps(pack, ensure_ascii=False))
        for name, image in images:
            zf.write(image, name, compress_type=zipfile.ZIP_STORED)  # WebP is already compressed
    tmp = path.with_suffix(".tmp")
    tmp.write_bytes(buffer.getvalue())
    tmp.replace(path)
    for old in PACKS_DIR.glob(f"subject-{subject.id}-*.zip"):
        if old != path:
            old.unlink(missing_ok=True)
    return path


def pack_info(db: Session, subject: Subject) -> dict:
    content, version, images = _snapshot(db, subject)
    built = pack_path(subject.id, version)
    return {
        "subject_id": subject.id,
        "code": subject.code,
        "title_ru": subject.title_ru,
        "title_tj": subject.title_tj,
        "grade": subject.grade,
        "version": version,
        "size_bytes": built.stat().st_size if built.is_file() else estimated_size(content, images),
        "questions": len(content["questions"]),
        "lessons": len(content["lessons"]),
        "images": len(images),
    }


def manifest(db: Session, cluster_id: Optional[int] = None, grade: Optional[int] = None) -> dict:
    """Structure of the clusters (subtests A1–A4, task counts, durations) + available packs."""
    clusters = list(db.scalars(select(Cluster).order_by(Cluster.order, Cluster.id)))
    cluster_data = [
        {
            "id": c.id,
            "code": c.code,
            "title_ru": c.title_ru,
            "title_tj": c.title_tj,
            "duration_minutes": c.duration_minutes,
            "subtests": [
                {"subject_id": link.subject_id, "position": link.position, "max_score": link.max_score,
                 "language_track": link.language_track}
                for link in c.subject_links
            ],
        }
        for c in clusters
    ]
    if cluster_id is not None:
        subject_ids = {s["subject_id"] for c in cluster_data if c["id"] == cluster_id for s in c["subtests"]}
        subjects = [db.get(Subject, sid) for sid in sorted(subject_ids)]
    elif grade is not None:
        subjects = list(db.scalars(select(Subject).where(Subject.grade == grade).order_by(Subject.order)))
    else:
        subjects = list(db.scalars(select(Subject).order_by(Subject.order, Subject.id)))
    return {
        "format": PACK_FORMAT,
        "clusters": cluster_data,
        "packs": [pack_info(db, s) for s in subjects if s is not None],
    }
