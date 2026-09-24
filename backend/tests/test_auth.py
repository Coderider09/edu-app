from unittest.mock import patch

from app.core.config import settings
from app.models import User
from tests.conftest import auth_headers, cluster_id, login, register


def test_register_and_login_by_email_and_phone(client):
    token = register(client, email="A@Example.com", phone="+992 900 12-34-56")
    assert token["needs_onboarding"] is True
    assert login(client, "a@example.com", "password123").status_code == 200
    assert login(client, "+992900123456", "password123").status_code == 200
    assert login(client, "a@example.com", "wrong-pass").status_code == 401


def test_register_validation(client):
    r = client.post("/api/v1/auth/register", json={"password": "password123", "name": "X"})
    assert r.status_code == 422  # email or phone required
    r = client.post("/api/v1/auth/register", json={"email": "x@example.com", "password": "short", "name": "X"})
    assert r.status_code == 422
    register(client, email="dup@example.com")
    r = client.post("/api/v1/auth/register", json={"email": "DUP@example.com", "password": "password123", "name": "X"})
    assert r.status_code == 409


def test_login_rate_limit(client):
    register(client, email="brute@example.com")
    codes = [login(client, "brute@example.com", "bad-password").status_code for _ in range(settings.LOGIN_RATE_LIMIT)]
    assert set(codes) == {401}
    assert login(client, "brute@example.com", "password123").status_code == 429


def test_refresh_token(client):
    token = register(client)
    r = client.post("/api/v1/auth/refresh", json={"refresh_token": token["refresh_token"]})
    assert r.status_code == 200
    # an access token must not work as a refresh token
    r = client.post("/api/v1/auth/refresh", json={"refresh_token": token["access_token"]})
    assert r.status_code == 401


def test_blocked_user_is_rejected(client, db):
    token = register(client, email="bad@example.com")
    user = db.query(User).filter_by(email="bad@example.com").one()
    user.is_active = False
    db.commit()
    assert client.get("/api/v1/profile/me", headers=auth_headers(token)).status_code == 403
    assert login(client, "bad@example.com", "password123").status_code == 403


def test_google_oauth_creates_and_links_user(client, db, monkeypatch):
    register(client, email="g@example.com")
    claims = {"sub": "google-123", "email": "g@example.com", "email_verified": True, "name": "G"}
    with patch("app.services.google_auth.verify", return_value=claims):
        r = client.post("/api/v1/auth/oauth/google", json={"id_token": "x" * 20})
    assert r.status_code == 200
    user = db.query(User).filter_by(email="g@example.com").one()
    assert user.google_sub == "google-123"

    with patch("app.services.google_auth.verify", return_value=None):
        assert client.post("/api/v1/auth/oauth/google", json={"id_token": "x" * 20}).status_code == 401


def test_role_selection_is_required(client, db):
    headers = auth_headers(register(client))
    assert client.get("/api/v1/dashboard", headers=headers).status_code == 409
    r = client.post(
        "/api/v1/profile/role",
        json={"role": "abiturient", "abiturient": {"cluster_id": cluster_id(db), "target_year": 2027}},
        headers=headers,
    )
    assert r.status_code == 200
    body = r.json()
    assert body["roles"] == ["abiturient"] and body["active_role"] == "abiturient"
    assert client.get("/api/v1/dashboard", headers=headers).status_code == 200
    # the same role cannot be chosen twice
    r = client.post(
        "/api/v1/profile/role",
        json={"role": "abiturient", "abiturient": {"cluster_id": cluster_id(db), "target_year": 2027}},
        headers=headers,
    )
    assert r.status_code == 409


def test_role_survey_is_validated(client):
    headers = auth_headers(register(client))
    r = client.post("/api/v1/profile/role", json={"role": "schoolboy"}, headers=headers)
    assert r.status_code == 422
    r = client.post("/api/v1/profile/role", json={"role": "schoolboy", "school": {"grade": 12}}, headers=headers)
    assert r.status_code == 422
    r = client.post(
        "/api/v1/profile/role",
        json={"role": "abiturient", "abiturient": {"cluster_id": 9999, "target_year": 2027}},
        headers=headers,
    )
    assert r.status_code == 422


def test_second_role_and_switch(client, abiturient):
    r = client.post(
        "/api/v1/profile/role", json={"role": "schoolboy", "school": {"grade": 3}}, headers=abiturient
    )
    assert r.status_code == 200
    assert set(r.json()["roles"]) == {"abiturient", "schoolboy"}
    assert r.json()["active_role"] == "schoolboy"
    r = client.patch("/api/v1/profile/me", json={"active_role": "abiturient"}, headers=abiturient)
    assert r.json()["active_role"] == "abiturient"


def test_profile_settings(client, schoolboy):
    r = client.patch(
        "/api/v1/profile/me",
        json={"avatar_id": "fox", "language": "ru", "theme": "dark", "notifications_enabled": False},
        headers=schoolboy,
    )
    assert r.status_code == 200
    body = r.json()
    assert (body["avatar_id"], body["language"], body["theme"], body["notifications_enabled"]) == (
        "fox", "ru", "dark", False
    )
    assert client.patch("/api/v1/profile/me", json={"avatar_id": "photo.jpg"}, headers=schoolboy).status_code == 422
    assert client.patch("/api/v1/profile/me", json={"active_role": "abiturient"}, headers=schoolboy).status_code == 400
