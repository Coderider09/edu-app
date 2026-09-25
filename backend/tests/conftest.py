import os
import tempfile

_db_file = os.path.join(tempfile.gettempdir(), "eduapp_test.sqlite3")
os.environ["DATABASE_URL"] = f"sqlite:///{_db_file}"
os.environ["REDIS_URL"] = ""  # in-memory cache/rate limiter
os.environ["SECRET_KEY"] = "test-secret"
os.environ["LOGIN_RATE_LIMIT"] = "5"
os.environ["PACKS_DIR"] = os.path.join(tempfile.gettempdir(), "eduapp_test_packs")

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402
from sqlalchemy import select  # noqa: E402

from app import models  # noqa: E402,F401
from app.core.security import get_password_hash  # noqa: E402
from app.db.database import Base, SessionLocal, engine  # noqa: E402
from app.main import app  # noqa: E402
from app.models import AdminRole, Cluster, Subject, User  # noqa: E402
from app.seed import seed_achievements, seed_content  # noqa: E402
from app.services import packs  # noqa: E402
from app.services.cache import cache  # noqa: E402
from tests.fixtures import seed_small_bank  # noqa: E402


@pytest.fixture(autouse=True)
def database():
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    cache.reset_memory()
    packs.invalidate()
    with SessionLocal() as db:
        seed_achievements(db)
        seed_content(db)
        seed_small_bank(db)
        db.commit()
    yield
    Base.metadata.drop_all(bind=engine)


@pytest.fixture
def db():
    with SessionLocal() as session:
        yield session


@pytest.fixture
def client():
    with TestClient(app) as c:
        yield c


def register(client, email="user@example.com", password="password123", name="Test", **extra):
    resp = client.post("/api/v1/auth/register", json={"email": email, "password": password, "name": name, **extra})
    assert resp.status_code == 201, resp.text
    return resp.json()


def auth_headers(token: dict) -> dict:
    return {"Authorization": f"Bearer {token['access_token']}"}


def cluster_id(db, code="c1") -> int:
    return db.scalar(select(Cluster.id).where(Cluster.code == code))


def subject_id(db, code="math") -> int:
    return db.scalar(select(Subject.id).where(Subject.code == code))


@pytest.fixture
def abiturient(client, db):
    token = register(client, email="abi@example.com", name="Абитуриент", language="ru")
    headers = auth_headers(token)
    resp = client.post(
        "/api/v1/profile/role",
        json={"role": "abiturient", "abiturient": {"cluster_id": cluster_id(db), "target_year": 2027,
                                                   "region": "dushanbe"}},
        headers=headers,
    )
    assert resp.status_code == 200, resp.text
    return headers


@pytest.fixture
def schoolboy(client):
    token = register(client, email="kid@example.com", name="Школьник")
    headers = auth_headers(token)
    resp = client.post(
        "/api/v1/profile/role",
        json={"role": "schoolboy", "school": {"grade": 2, "language_of_study": "ru"}},
        headers=headers,
    )
    assert resp.status_code == 200, resp.text
    return headers


def make_admin(db, email: str, role: AdminRole, password="adminpass1") -> None:
    db.add(User(email=email, name="Admin", password_hash=get_password_hash(password), admin_role=role))
    db.commit()


def login(client, username: str, password: str):
    return client.post("/api/v1/auth/login", data={"username": username, "password": password})
