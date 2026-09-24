from sqlalchemy import select

from app.models import AdminRole, Question, Topic, User
from tests.conftest import auth_headers, cluster_id, login, make_admin, register, subject_id


def _pass_topic(client, db, headers, title="Линейные уравнения"):
    topic = db.scalar(select(Topic).where(Topic.title_ru == title))
    attempt = client.post("/api/v1/attempts", json={"test_type": "topic_test", "reference_id": topic.id},
                          headers=headers).json()
    for q in attempt["questions"]:
        correct = db.get(Question, q["id"]).correct_option_index
        client.post(f"/api/v1/attempts/{attempt['id']}/answer",
                    json={"question_id": q["id"], "selected_option_index": correct}, headers=headers)
    return client.post(f"/api/v1/attempts/{attempt['id']}/finish", headers=headers).json()


def test_profile_progress_history_achievements(client, db, abiturient):
    _pass_topic(client, db, abiturient)
    me = client.get("/api/v1/profile/me", headers=abiturient).json()
    assert me["total_points"] > 0 and me["current_streak"] == 1 and me["level"]["code"] == "novice"

    progress = client.get("/api/v1/profile/me/progress", headers=abiturient).json()
    math = next(s for s in progress["subjects"] if s["title"] == "Математика")
    assert math["accuracy"] == 100 and math["completed_items"] == 1

    history = client.get("/api/v1/profile/me/history", headers=abiturient).json()
    assert history[0]["title"] == "Линейные уравнения" and history[0]["accuracy"] == 100

    achievements = client.get("/api/v1/profile/me/achievements", headers=abiturient).json()
    unlocked = {a["code"] for a in achievements if a["unlocked"]}
    assert unlocked == {"first_test", "perfect_score"}
    assert len(achievements) >= 7


def test_progress_is_separate_per_role(client, db, abiturient):
    _pass_topic(client, db, abiturient)
    client.post("/api/v1/profile/role", json={"role": "schoolboy", "school": {"grade": 2}}, headers=abiturient)
    me = client.get("/api/v1/profile/me", headers=abiturient).json()
    assert me["active_role"] == "schoolboy" and me["role_points"] == 0 and me["total_points"] > 0
    assert client.get("/api/v1/profile/me/history", headers=abiturient).json() == []
    abi_history = client.get("/api/v1/profile/me/history?role=abiturient", headers=abiturient).json()
    assert len(abi_history) == 1


def test_leaderboard(client, db, abiturient):
    other = auth_headers(register(client, email="other@example.com", name="Other"))
    client.post("/api/v1/profile/role",
                json={"role": "abiturient", "abiturient": {"cluster_id": cluster_id(db), "target_year": 2027}},
                headers=other)
    _pass_topic(client, db, other)

    board = client.get("/api/v1/leaderboard?scope=cluster&period=all", headers=abiturient).json()
    assert board["entries"][0]["name"] == "Other"
    assert board["me"]["rank"] == 2 and board["me"]["points"] == 0

    week = client.get("/api/v1/leaderboard?period=week", headers=other).json()
    assert week["me"]["rank"] == 1

    region = client.get("/api/v1/leaderboard?scope=region", headers=abiturient).json()
    assert region["entries"] == []  # "Other" has no region
    assert client.get("/api/v1/leaderboard?scope=grade", headers=abiturient).status_code == 400


def test_dashboard(client, db, abiturient, schoolboy):
    abi = client.get("/api/v1/dashboard", headers=abiturient).json()
    assert abi["role"] == "abiturient" and abi["cluster"]["id"] == cluster_id(db) and len(abi["subjects"]) == 4
    school = client.get("/api/v1/dashboard", headers=schoolboy).json()
    assert school["grade"] == 2 and {s["title"] for s in school["subjects"]} == {"Математика", "Окружающий мир"}


def test_admin_content_crud_and_permissions(client, db, abiturient):
    body = {"title_ru": "Геометрия-2", "code": "geometry2"}
    assert client.post("/api/v1/admin/subjects", json=body, headers=abiturient).status_code == 403

    make_admin(db, "cm@example.com", AdminRole.CONTENT_MANAGER)
    cm = {"Authorization": f"Bearer {login(client, 'cm@example.com', 'adminpass1').json()['access_token']}"}
    r = client.post("/api/v1/admin/subjects", json=body, headers=cm)
    assert r.status_code == 201
    new_subject = r.json()["id"]
    r = client.post("/api/v1/admin/topics", json={"subject_id": new_subject, "title_ru": "Тема"}, headers=cm)
    topic_id = r.json()["id"]
    bad_q = {"topic_id": topic_id, "text": "2+2?", "options": ["3", "4"], "correct_option_index": 5}
    assert client.post("/api/v1/admin/questions", json=bad_q, headers=cm).status_code == 422
    good_q = {**bad_q, "correct_option_index": 1}
    assert client.post("/api/v1/admin/questions", json=good_q, headers=cm).status_code == 201
    link = {"cluster_id": cluster_id(db), "subject_id": new_subject, "position": 5, "max_score": 0}
    assert client.post("/api/v1/admin/cluster-subjects", json=link, headers=cm).status_code == 201
    matching = {"topic_id": topic_id, "question_type": "matching", "text": "Соотнесите",
                "matching_left": ["a", "b"], "options": ["1", "2", "3"], "correct_answer": [2, 0]}
    assert client.post("/api/v1/admin/questions", json=matching, headers=cm).status_code == 201
    numeric = {"topic_id": topic_id, "question_type": "numeric", "text": "2+2", "correct_answer": "x"}
    assert client.post("/api/v1/admin/questions", json=numeric, headers=cm).status_code == 422
    r = client.put(f"/api/v1/admin/subjects/{new_subject}", json={**body, "title_ru": "Renamed"}, headers=cm)
    assert r.json()["title_ru"] == "Renamed"
    # content managers have no access to users/stats
    assert client.get("/api/v1/admin/stats", headers=cm).status_code == 403


def test_superadmin_ban_and_stats(client, db, abiturient):
    make_admin(db, "root@example.com", AdminRole.SUPERADMIN)
    root = {"Authorization": f"Bearer {login(client, 'root@example.com', 'adminpass1').json()['access_token']}"}
    user_id = db.scalar(select(User.id).where(User.email == "abi@example.com"))
    assert client.post(f"/api/v1/admin/users/{user_id}/ban", headers=root).json()["is_active"] is False
    assert client.get("/api/v1/profile/me", headers=abiturient).status_code == 403
    client.post(f"/api/v1/admin/users/{user_id}/unban", headers=root)
    assert client.get("/api/v1/profile/me", headers=abiturient).status_code == 200

    stats = client.get("/api/v1/admin/stats", headers=root).json()
    assert stats["abiturients"] == 1 and len(stats["by_cluster"]) == 5


def test_admin_panel_login(client, db):
    make_admin(db, "root@example.com", AdminRole.SUPERADMIN)
    assert client.get("/admin/", follow_redirects=False).status_code in (302, 303, 307)
    r = client.post("/admin/login", data={"username": "root@example.com", "password": "adminpass1"},
                    follow_redirects=False)
    assert r.status_code in (302, 303)
    assert client.get("/admin/stats").status_code == 200
    assert client.get("/admin/question/list").status_code == 200


def test_health(client):
    assert client.get("/health").json()["database"] is True


def test_subject_id_helper(db):
    assert subject_id(db) is not None
