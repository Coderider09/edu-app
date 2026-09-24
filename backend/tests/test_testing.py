from datetime import datetime, timedelta

from sqlalchemy import select

from app.models import ExamTest, PointsLedger, Question, QuestionType, Subject, TestAttempt, Topic
from tests.conftest import auth_headers, cluster_id, register, subject_id


def _topic(db, title="Линейные уравнения") -> Topic:
    return db.scalar(select(Topic).where(Topic.title_ru == title))


def _correct(db, qid: int) -> int:
    return db.get(Question, qid).correct_option_index


def _wrong(db, qid: int) -> int:
    q = db.get(Question, qid)
    return (q.correct_option_index + 1) % len(q.options)


def _start(client, headers, **body):
    r = client.post("/api/v1/attempts", json=body, headers=headers)
    assert r.status_code == 201, r.text
    return r.json()


def _answer(client, headers, attempt_id, qid, option):
    return client.post(
        f"/api/v1/attempts/{attempt_id}/answer",
        json={"question_id": qid, "selected_option_index": option},
        headers=headers,
    )


def test_topic_test_flow_with_feedback(client, db, abiturient):
    topic = _topic(db)
    attempt = _start(client, abiturient, test_type="topic_test", reference_id=topic.id)
    assert attempt["shows_feedback"] is True
    assert len(attempt["questions"]) == 7  # topic questions, not lesson-check ones
    assert "correct_option_index" not in attempt["questions"][0]

    q1, q2 = attempt["questions"][0]["id"], attempt["questions"][1]["id"]
    r = _answer(client, abiturient, attempt["id"], q1, _correct(db, q1)).json()
    assert r["is_correct"] is True and r["points_awarded"] == 10 and r["explanation"]
    r = _answer(client, abiturient, attempt["id"], q2, _wrong(db, q2)).json()
    assert r["is_correct"] is False and r["points_awarded"] == 0
    assert r["correct_option_index"] == _correct(db, q2)

    # the same question cannot be answered twice; foreign questions are rejected
    assert _answer(client, abiturient, attempt["id"], q1, 0).status_code == 409
    assert _answer(client, abiturient, attempt["id"], 999999, 0).status_code == 400
    assert _answer(client, abiturient, attempt["id"], attempt["questions"][2]["id"], 9).status_code == 422

    result = client.post(f"/api/v1/attempts/{attempt['id']}/finish", headers=abiturient).json()
    assert result["correct_count"] == 1 and result["total_count"] == 7 and result["answered_count"] == 2
    assert result["completion_bonus"] == 20
    assert {a["code"] for a in result["new_achievements"]} == {"first_test"}
    assert len(result["review"]) == 7 and result["review"][1]["is_correct"] is False
    # 10 (answer) + 20 (completion) + 20 (achievement)
    assert result["total_points"] == 50

    # finishing again is idempotent; answering a finished attempt fails
    again = client.post(f"/api/v1/attempts/{attempt['id']}/finish", headers=abiturient).json()
    assert again["total_points"] == 50
    assert _answer(client, abiturient, attempt["id"], attempt["questions"][3]["id"], 0).status_code == 409


def test_streak_multiplier_and_perfect_score(client, db, abiturient):
    topic = _topic(db)
    attempt = _start(client, abiturient, test_type="topic_test", reference_id=topic.id)
    awarded = []
    for q in attempt["questions"]:
        r = _answer(client, abiturient, attempt["id"], q["id"], _correct(db, q["id"])).json()
        awarded.append(r["points_awarded"])
    # 5 correct in a row, then x1.5
    assert awarded == [10, 10, 10, 10, 10, 15, 15]
    result = client.post(f"/api/v1/attempts/{attempt['id']}/finish", headers=abiturient).json()
    assert result["accuracy"] == 100
    assert {"first_test", "perfect_score"} <= {a["code"] for a in result["new_achievements"]}

    # the completion bonus is paid only once per test
    second = _start(client, abiturient, test_type="topic_test", reference_id=topic.id)
    result2 = client.post(f"/api/v1/attempts/{second['id']}/finish", headers=abiturient).json()
    assert result2["completion_bonus"] == 0


def test_unfinished_attempt_is_resumed(client, db, abiturient):
    topic = _topic(db)
    first = _start(client, abiturient, test_type="topic_test", reference_id=topic.id)
    qid = first["questions"][0]["id"]
    _answer(client, abiturient, first["id"], qid, 0)
    again = _start(client, abiturient, test_type="topic_test", reference_id=topic.id)
    assert again["id"] == first["id"] and len(again["answers"]) == 1
    state = client.get(f"/api/v1/attempts/{first['id']}", headers=abiturient).json()
    assert state["answers"][0]["question_id"] == qid


def test_official_sample_exam_hides_feedback_and_scales_to_500(client, db, abiturient):
    exam = db.scalar(select(ExamTest))
    attempt = _start(client, abiturient, test_type="exam_test", reference_id=exam.id)
    assert attempt["shows_feedback"] is False and attempt["is_timed"] is True
    ids = [q["id"] for q in attempt["questions"]]
    assert ids == [q.id for q in exam.questions]  # fixed order, like the real exam
    assert len(ids) == 12  # 3 sample tasks x 4 subtests

    # correct in Tajik language (A1) and mathematics (A2), wrong in chemistry and physics
    for i, qid in enumerate(ids):
        option = _correct(db, qid) if i < 6 else _wrong(db, qid)
        r = _answer(client, abiturient, attempt["id"], qid, option).json()
        assert r["is_correct"] is None and r["explanation"] is None and r["correct_answer"] is None

    # no points are visible before the end
    assert db.scalar(select(PointsLedger).where(PointsLedger.attempt_id == attempt["id"])) is None

    result = client.post(f"/api/v1/attempts/{attempt['id']}/finish", headers=abiturient).json()
    assert result["correct_count"] == 6 and result["points"] == 6 and result["max_points"] == 12
    assert [(s["title"], s["points"], s["max_points"], s["score"]) for s in result["subjects"]] == [
        ("Таджикский язык", 3, 3, 75.0), ("Математика", 3, 3, 175.0), ("Химия", 0, 3, 0.0), ("Физика", 0, 3, 0.0),
    ]
    assert result["mmt_score"] == 250 and result["mmt_max"] == 500
    assert result["completion_bonus"] == 100
    assert "first_exam" in {a["code"] for a in result["new_achievements"]}
    exams = client.get("/api/v1/exam-tests", headers=abiturient).json()
    assert exams[0]["best_mmt_score"] == 250


def test_mock_exam_follows_official_structure(client, db, abiturient):
    attempt = _start(client, abiturient, test_type="mock_exam", reference_id=cluster_id(db))
    assert attempt["shows_feedback"] is False and attempt["is_timed"] is True
    questions = attempt["questions"]
    codes = [db.get(Question, q["id"]).subject.code for q in questions]
    assert list(dict.fromkeys(codes)) == ["tj_lang", "math", "chemistry", "physics"]

    def structure(code):
        types = [q["question_type"] for q, c in zip(questions, codes, strict=True) if c == code]
        return types.count("single"), types.count("matching"), types.count("numeric")

    assert structure("tj_lang") == (20, 4, 2)
    assert structure("math") == (18, 2, 7)
    # every subtest is worth 40 official points, like the real exam
    assert sum(q["max_points"] for q in questions) == 160
    started = datetime.fromisoformat(attempt["started_at"][:19])
    expires = datetime.fromisoformat(attempt["expires_at"][:19])
    assert expires - started == timedelta(minutes=220)


def test_mock_exam_picks_literature_by_language(client, db):
    def mock_subjects(lang):
        headers = auth_headers(register(client, email=f"c3{lang}@example.com", language=lang))
        body = {"role": "abiturient", "abiturient": {"cluster_id": cluster_id(db, "c3"), "target_year": 2027}}
        client.post("/api/v1/profile/role", json=body, headers=headers)
        attempt = _start(client, headers, test_type="mock_exam", reference_id=cluster_id(db, "c3"))
        return list(dict.fromkeys(db.get(Question, q["id"]).subject.code for q in attempt["questions"]))

    assert mock_subjects("tj") == ["tj_lang", "history", "tj_lit", "english"]
    assert mock_subjects("ru") == ["tj_lang", "history", "ru_lang_lit", "english"]


def _official_question(db, qtype, code="math"):
    return db.scalar(
        select(Question).join(Subject, Subject.id == Question.subject_id).where(
            Subject.code == code, Question.question_type == QuestionType(qtype), Question.topic_id.is_not(None)
        )
    )


def test_matching_and_numeric_answers(client, db, abiturient):
    matching = _official_question(db, "matching")
    numeric = _official_question(db, "numeric")
    attempt = _start(client, abiturient, test_type="topic_test", reference_id=matching.topic_id)
    q = next(x for x in attempt["questions"] if x["id"] == matching.id)
    assert q["question_type"] == "matching" and q["matching_left"] == ["l1", "l2", "l3", "l4"]
    assert q["max_points"] == 4 and "correct_answer" not in q

    url = f"/api/v1/attempts/{attempt['id']}/answer"
    # wrong shapes are rejected
    assert client.post(url, json={"question_id": matching.id, "answer": [1, 0]}, headers=abiturient).status_code == 422
    # 2 of 4 pairs right -> 2 official points, not fully correct, 20 app points
    r = client.post(url, json={"question_id": matching.id, "answer": [1, 0, 2, 3]}, headers=abiturient).json()
    assert (r["points"], r["max_points"], r["is_correct"], r["points_awarded"]) == (2, 4, False, 20)
    assert r["correct_answer"] == [1, 0, 3, 2]

    attempt = _start(client, abiturient, test_type="topic_test", reference_id=numeric.topic_id)
    url = f"/api/v1/attempts/{attempt['id']}/answer"
    answer = numeric.correct_answer
    r = client.post(url, json={"question_id": numeric.id, "answer": " 0" + answer}, headers=abiturient).json()
    assert (r["points"], r["is_correct"], r["points_awarded"], r["correct_answer"]) == (2, True, 20, answer)
    other = next(x["id"] for x in attempt["questions"] if x["id"] != numeric.id)
    assert client.post(url, json={"question_id": other, "answer": "abc"}, headers=abiturient).status_code == 422


def test_time_limit(client, db, abiturient):
    exam = db.scalar(select(ExamTest))
    attempt = _start(client, abiturient, test_type="exam_test", reference_id=exam.id)
    row = db.get(TestAttempt, attempt["id"])
    row.expires_at = row.started_at - timedelta(minutes=1)
    db.commit()
    r = _answer(client, abiturient, attempt["id"], attempt["questions"][0]["id"], 0)
    assert r.status_code == 409 and r.json()["detail"] == "Time is up"
    # starting again closes the expired attempt and gives a fresh one
    fresh = _start(client, abiturient, test_type="exam_test", reference_id=exam.id)
    assert fresh["id"] != attempt["id"]
    db.expire_all()
    assert db.get(TestAttempt, attempt["id"]).status.value == "finished"


def test_timed_topic_test(client, db, abiturient):
    attempt = _start(client, abiturient, test_type="topic_test", reference_id=_topic(db).id, timed=True)
    assert attempt["is_timed"] is True and attempt["expires_at"] is not None


def test_mistakes_and_marks(client, db, abiturient):
    topic = _topic(db)
    attempt = _start(client, abiturient, test_type="topic_test", reference_id=topic.id)
    wrong_q = attempt["questions"][0]["id"]
    marked_q = attempt["questions"][1]["id"]
    _answer(client, abiturient, attempt["id"], wrong_q, _wrong(db, wrong_q))
    assert client.post(f"/api/v1/questions/{marked_q}/mark", headers=abiturient).status_code == 204
    client.post(f"/api/v1/attempts/{attempt['id']}/finish", headers=abiturient)

    pool = [q["id"] for q in client.get("/api/v1/review/questions", headers=abiturient).json()]
    assert set(pool) == {wrong_q, marked_q}

    mistakes = _start(client, abiturient, test_type="mistakes")
    assert {q["id"] for q in mistakes["questions"]} == {wrong_q, marked_q}
    # fixing the mistake removes it from the pool; unmarking removes the marked one
    _answer(client, abiturient, mistakes["id"], wrong_q, _correct(db, wrong_q))
    client.delete(f"/api/v1/questions/{marked_q}/mark", headers=abiturient)
    assert client.get("/api/v1/review/questions", headers=abiturient).json() == []


def test_lesson_check_and_practice(client, db, abiturient):
    topic = _topic(db)
    lesson_id = topic.lessons[0].id
    check = _start(client, abiturient, test_type="lesson_check", reference_id=lesson_id)
    assert len(check["questions"]) == 3
    practice = _start(client, abiturient, test_type="practice", reference_id=subject_id(db), question_count=5)
    assert len(practice["questions"]) == 5 and practice["is_timed"] is False


def test_section_test(client, db, abiturient):
    section = _topic(db, "Краткая теория: Алгебра")
    attempt = _start(client, abiturient, test_type="section_test", reference_id=section.id)
    assert len(attempt["questions"]) == 20  # 7 + 7 + 6 topic questions


def test_missing_references(client, abiturient):
    r = client.post("/api/v1/attempts", json={"test_type": "topic_test", "reference_id": 99999}, headers=abiturient)
    assert r.status_code == 404
    r = client.post("/api/v1/attempts", json={"test_type": "mistakes"}, headers=abiturient)
    assert r.status_code == 404  # nothing to repeat yet


def test_attempts_are_private(client, db, abiturient, schoolboy):
    attempt = _start(client, abiturient, test_type="topic_test", reference_id=_topic(db).id)
    assert client.get(f"/api/v1/attempts/{attempt['id']}", headers=schoolboy).status_code == 404
