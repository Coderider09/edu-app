import io
import json
import zipfile
from datetime import datetime, timedelta, timezone

from sqlalchemy import func, select

from app.models import (
    ClusterSubject,
    Lesson,
    LessonProgress,
    MarkedQuestion,
    PointsLedger,
    Question,
    QuestionType,
    TestAttempt,
    Topic,
    User,
)
from app.services import packs
from tests.conftest import cluster_id, subject_id


def _now():
    return datetime.now(timezone.utc)


def _pack(client, headers, sid) -> dict:
    r = client.get(f"/api/v1/packs/{sid}/download", headers=headers)
    assert r.status_code == 200, r.text
    with zipfile.ZipFile(io.BytesIO(r.content)) as zf:
        content = json.loads(zf.read("content.json"))
    assert content["version"] == r.headers["x-pack-version"]
    return content


def _right(q: dict):
    """The correct answer in the shape the app sends it."""
    return q["answer"][0] if q["type"] == "single" else q["answer"]


def _wrong(q: dict):
    if q["type"] == "single":
        return (q["answer"][0] + 1) % len(q["options"])
    if q["type"] == "matching":
        return [(a + 1) % len(q["options"]) for a in q["answer"]]
    return "999999"


def _attempt(client_id, test_type, reference_id, questions, answers, start=None, **extra):
    start = start or _now() - timedelta(minutes=30)
    return {
        "client_id": client_id,
        "test_type": test_type,
        "reference_id": reference_id,
        "question_ids": [q["id"] for q in questions],
        "started_at": start.isoformat(),
        "finished_at": (start + timedelta(minutes=20)).isoformat(),
        "answers": [
            {"question_id": q["id"], "answer": a, "answered_at": (start + timedelta(minutes=i + 1)).isoformat()}
            for i, (q, a) in enumerate(answers)
        ],
        **extra,
    }


def test_manifest_lists_packs_of_the_users_cluster(client, db, abiturient):
    r = client.get("/api/v1/packs", headers=abiturient)
    assert r.status_code == 200, r.text
    data = r.json()
    assert len(data["clusters"]) == 5
    c1 = next(c for c in data["clusters"] if c["id"] == cluster_id(db))
    assert [s["position"] for s in c1["subtests"]] == [1, 2, 3, 4]
    assert c1["duration_minutes"] == 220
    expected = {link.subject_id for link in db.scalars(
        select(ClusterSubject).where(ClusterSubject.cluster_id == cluster_id(db)))}
    assert {p["subject_id"] for p in data["packs"]} == expected
    assert all(p["version"] and p["questions"] > 0 and p["size_bytes"] > 0 for p in data["packs"])
    assert client.get("/api/v1/packs").status_code == 401


def test_pack_has_answer_keys_but_not_fixed_exam_questions(client, db, abiturient):
    sid = subject_id(db, "math")
    content = _pack(client, abiturient, sid)
    assert content["subject"]["code"] == "math"
    assert content["subject"]["exam_structure"]
    types = {q["type"] for q in content["questions"]}
    assert types == {"single", "matching", "numeric"}
    assert all(q["answer"] is not None for q in content["questions"])
    exam_qids = set(db.scalars(select(Question.id).where(Question.exam_test_id.is_not(None))))
    assert exam_qids and not exam_qids & {q["id"] for q in content["questions"]}
    # theory lessons with their mini-checks are included too
    assert content["lessons"]
    assert any(q["lesson_id"] for q in content["questions"])
    assert client.get("/api/v1/packs/999999/download", headers=abiturient).status_code == 404


def test_pack_version_changes_with_content(client, db, abiturient):
    sid = subject_id(db, "math")
    before = _pack(client, abiturient, sid)["version"]
    assert _pack(client, abiturient, sid)["version"] == before  # stable while nothing changes
    q = db.scalar(select(Question).where(Question.subject_id == sid))
    q.text = "Изменённое условие"
    db.commit()
    packs.invalidate()  # done by the admin panel after every save
    after = _pack(client, abiturient, sid)["version"]
    assert after != before
    assert len(list(packs.PACKS_DIR.glob(f"subject-{sid}-*.zip"))) == 1  # old versions are removed


def test_sync_regrades_answers_and_is_idempotent(client, db, abiturient):
    content = _pack(client, abiturient, subject_id(db, "math"))
    topic_id = next(q["topic_id"] for q in content["questions"] if q["type"] == "single" and q["topic_id"])
    qs = [q for q in content["questions"] if q["topic_id"] == topic_id and not q["lesson_id"]][:5]
    answers = [(qs[0], _right(qs[0])), (qs[1], _right(qs[1])), (qs[2], _wrong(qs[2])), (qs[3], "bad")]
    body = {"attempts": [_attempt("offline-attempt-0001", "topic_test", topic_id, qs, answers)]}

    r = client.post("/api/v1/sync", json=body, headers=abiturient)
    assert r.status_code == 200, r.text
    res = r.json()["attempts"][0]
    assert res["status"] == "created"
    assert res["correct_count"] == 2 and res["total_count"] == 5 and res["points"] == 2
    attempt = db.get(TestAttempt, res["attempt_id"])
    assert attempt.status.value == "finished" and len(attempt.user_answers) == 3  # malformed answer skipped
    ledger = db.scalar(select(func.sum(PointsLedger.points)).where(PointsLedger.user_id == attempt.user_id))
    assert r.json()["profile"]["total_points"] == ledger

    again = client.post("/api/v1/sync", json=body, headers=abiturient).json()["attempts"][0]
    assert again["status"] == "duplicate" and again["attempt_id"] == res["attempt_id"]
    assert db.scalar(select(func.count(TestAttempt.id))) == 1
    assert db.scalar(select(func.sum(PointsLedger.points))) == ledger


def test_sync_mock_exam_gives_500_point_estimate(client, db, abiturient):
    cid = cluster_id(db)
    links = db.scalars(select(ClusterSubject).where(ClusterSubject.cluster_id == cid)
                       .order_by(ClusterSubject.position)).all()
    questions = []
    for link in links:
        content = _pack(client, abiturient, link.subject_id)
        questions += [q for q in content["questions"] if q["subject_id"] == link.subject_id][:10]
    answers = [(q, _right(q)) for q in questions]
    body = {"attempts": [_attempt("offline-mock-0001", "mock_exam", cid, questions, answers)]}
    res = client.post("/api/v1/sync", json=body, headers=abiturient).json()["attempts"][0]
    assert res["status"] == "created"
    assert res["mmt_score"] == 500  # everything answered correctly
    attempt = db.get(TestAttempt, res["attempt_id"])
    assert [s["position"] for s in attempt.details["subtests"]] == [1, 2, 3, 4]


def test_sync_answers_after_exam_time_are_ignored(client, db, abiturient):
    cid = cluster_id(db)
    link = db.scalars(select(ClusterSubject).where(ClusterSubject.cluster_id == cid)).first()
    qs = [q for q in _pack(client, abiturient, link.subject_id)["questions"]
          if q["type"] == "single" and q["subject_id"]][:2]
    start = _now() - timedelta(hours=10)
    item = _attempt("offline-late-0001", "mock_exam", cid, qs, [], start=start)
    item["answers"] = [
        {"question_id": qs[0]["id"], "answer": _right(qs[0]), "answered_at": (start + timedelta(hours=1)).isoformat()},
        {"question_id": qs[1]["id"], "answer": _right(qs[1]), "answered_at": (start + timedelta(hours=5)).isoformat()},
    ]
    res = client.post("/api/v1/sync", json={"attempts": [item]}, headers=abiturient).json()["attempts"][0]
    assert res["correct_count"] == 1


def test_sync_rejects_unknown_references_and_online_only_questions(client, db, abiturient):
    exam_q = db.scalar(select(Question).where(Question.exam_test_id.is_not(None)))
    fake = {"id": exam_q.id}
    topic = db.scalar(select(Topic))
    body = {"attempts": [
        _attempt("offline-bad-ref-01", "topic_test", 999999, [fake], []),
        _attempt("offline-exam-q-01", "topic_test", topic.id, [fake], []),
    ]}
    results = client.post("/api/v1/sync", json=body, headers=abiturient).json()["attempts"]
    assert [r["status"] for r in results] == ["rejected", "rejected"]
    bad_id = _attempt("x", "topic_test", topic.id, [fake], [])
    assert client.post("/api/v1/sync", json={"attempts": [bad_id]}, headers=abiturient).status_code == 422


def test_sync_restores_daily_streak_from_offline_days(client, db, abiturient):
    content = _pack(client, abiturient, subject_id(db, "math"))
    qs = [q for q in content["questions"] if q["type"] == "single" and not q["lesson_id"]]
    topic_id = qs[0]["topic_id"]
    qs = [q for q in qs if q["topic_id"] == topic_id]
    body = {"attempts": [
        _attempt(f"offline-day-{d:04d}", "topic_test", topic_id, [qs[d]], [(qs[d], _right(qs[d]))],
                 start=_now() - timedelta(days=d, minutes=40))
        for d in (2, 1, 0)
    ]}
    profile = client.post("/api/v1/sync", json=body, headers=abiturient).json()["profile"]
    assert profile["current_streak"] == 3
    # a late upload of an older day does not break the streak
    late = _attempt("offline-day-old1", "topic_test", topic_id, [qs[5]], [(qs[5], _right(qs[5]))],
                    start=_now() - timedelta(days=4))
    profile = client.post("/api/v1/sync", json={"attempts": [late]}, headers=abiturient).json()["profile"]
    assert profile["current_streak"] == 3


def test_sync_lessons_and_marks(client, db, abiturient):
    lesson = db.scalar(select(Lesson))
    qids = list(db.scalars(select(Question.id).where(Question.question_type == QuestionType.SINGLE).limit(2)))
    db.add(MarkedQuestion(user_id=db.scalar(select(User.id).where(User.email == "abi@example.com")),
                          question_id=qids[1]))
    db.commit()
    body = {
        "lessons": [{"lesson_id": lesson.id, "completed_at": _now().isoformat()},
                    {"lesson_id": 999999, "completed_at": _now().isoformat()}],
        "marked": [qids[0], 999999],
        "unmarked": [qids[1]],
    }
    r = client.post("/api/v1/sync", json=body, headers=abiturient)
    assert r.status_code == 200, r.text
    assert r.json()["lessons_saved"] == 1
    assert client.post("/api/v1/sync", json=body, headers=abiturient).json()["lessons_saved"] == 0
    assert db.scalar(select(func.count(LessonProgress.id))) == 1
    assert set(db.scalars(select(MarkedQuestion.question_id))) == {qids[0]}
