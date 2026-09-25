from tests.conftest import auth_headers, cluster_id, register, subject_id
from tests.fixtures import EXAM_TITLE


def test_official_clusters_and_subtests(client):
    ru = client.get("/api/v1/clusters?lang=ru").json()
    tj = client.get("/api/v1/clusters?lang=tj").json()
    assert [c["title"] for c in ru] == [
        "Естественный и технический", "Экономика и география", "Филология, педагогика и искусство",
        "Обществоведение и право", "Медицина, биология и спорт",
    ]
    assert tj[0]["title"] == "Табиӣ ва техникӣ"
    # Tajik language is A1 in every cluster
    assert all(c["subjects"][0]["code"] == "tj_lang" and c["subjects"][0]["position"] == 1 for c in ru)
    assert [s["code"] for s in ru[0]["subjects"]] == ["tj_lang", "math", "chemistry", "physics"]
    assert [s["code"] for s in ru[4]["subjects"]] == ["tj_lang", "biology", "chemistry", "physics"]
    # cluster 3: A3 is Tajik literature or Russian language & literature depending on the exam language
    assert [(s["code"], s["position"]) for s in ru[2]["subjects"]] == [
        ("tj_lang", 1), ("history", 2), ("tj_lit", 3), ("ru_lang_lit", 3), ("english", 4),
    ]
    assert [c["duration_minutes"] for c in ru] == [220, 200, 190, 190, 220]


def test_subjects_filter(client, db):
    grade2 = client.get("/api/v1/subjects?grade=2&lang=ru").json()
    assert {s["title"] for s in grade2} == {"Математика", "Окружающий мир"}
    assert all(s["grade"] == 2 for s in grade2)
    c1 = client.get(f"/api/v1/subjects?cluster_id={cluster_id(db)}").json()
    assert [s["position"] for s in c1] == [1, 2, 3, 4]


def test_subject_tree_with_theory_and_task_sections(client, db, abiturient):
    tree = client.get(f"/api/v1/subjects/{subject_id(db)}/topics", headers=abiturient).json()
    titles = [s["title"] for s in tree["sections"]]
    assert titles == [
        "Краткая теория: Алгебра", "Краткая теория: Геометрия", "Уроки и упражнения",
        "Задания повышенной сложности", "Задания с выбором ответа", "Задания на соответствие",
        "Задания открытого типа",
    ]
    by_type = tree["sections"][4]
    assert [t["title"] for t in by_type["topics"]] == ["Тема A", "Тема B"]
    assert by_type["has_final_test"] is True

    topic = tree["sections"][0]["topics"][0]
    lessons = client.get(f"/api/v1/topics/{topic['id']}/lessons", headers=abiturient).json()
    assert len(lessons) == 1 and lessons[0]["check_questions_count"] == 3
    r = client.post(f"/api/v1/lessons/{lessons[0]['id']}/complete", headers=abiturient)
    assert r.json()["completed"] is True
    assert client.post(f"/api/v1/lessons/{lessons[0]['id']}/complete", headers=abiturient).status_code == 200
    tree = client.get(f"/api/v1/subjects/{subject_id(db)}/topics", headers=abiturient).json()
    assert tree["sections"][0]["topics"][0]["progress"]["lessons_completed"] == 1
    assert tree["subject"]["progress_percent"] > 0
    tests = client.get(f"/api/v1/topics/{topic['id']}/tests", headers=abiturient).json()
    assert tests[0]["questions_count"] == 7


def test_content_language_follows_school_language(client, db):
    headers = auth_headers(register(client, email="tj@example.com"))
    client.post("/api/v1/profile/role", json={"role": "schoolboy", "school": {"grade": 2, "language_of_study": "tj"}},
                headers=headers)
    dash = client.get("/api/v1/dashboard", headers=headers).json()
    math = next(s for s in dash["subjects"] if s["title"] == "Математика")
    tree = client.get(f"/api/v1/subjects/{math['id']}/topics", headers=headers).json()
    assert tree["sections"][0]["title"] == "Чоряки 1"
    topic_id = tree["sections"][0]["topics"][0]["id"]
    lessons = client.get(f"/api/v1/topics/{topic_id}/lessons", headers=headers).json()
    assert lessons[0]["language"] == "tj"


def test_fixed_exam_test(client, abiturient):
    exams = client.get("/api/v1/exam-tests", headers=abiturient).json()
    assert len(exams) == 1
    assert exams[0]["year"] == 2026 and exams[0]["title"] == EXAM_TITLE
    assert exams[0]["total_questions"] == 12 and exams[0]["duration_minutes"] == 220
    assert client.get("/api/v1/exam-tests?year=2020", headers=abiturient).json() == []


def test_cluster_screen_with_mock_exam(client, db, abiturient):
    data = client.get(f"/api/v1/clusters/{cluster_id(db)}", headers=abiturient).json()
    assert len(data["subjects"]) == 4 and len(data["exam_tests"]) == 1
    mock = data["mock_exam"]
    assert mock["duration_minutes"] == 220 and mock["max_score"] == 500
    assert [s["questions"] for s in mock["subtests"]] == [26, 27, 27, 27]
    assert [s["max_score"] for s in mock["subtests"]] == [75, 175, 100, 150]
