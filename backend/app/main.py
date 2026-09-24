import logging
import mimetypes
import time
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text

from app.admin.admin import setup_admin
from app.api.v1 import admin, auth, content, onboarding, profile, testing
from app.core.config import settings
from app.db.database import engine

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
logger = logging.getLogger("eduapp")

app = FastAPI(
    title="EduApp API",
    description="Образовательная платформа для абитуриентов (ММТ) и школьников Таджикистана",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=settings.CORS_ORIGINS != ["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def log_requests(request: Request, call_next):
    started = time.perf_counter()
    response = await call_next(request)
    elapsed_ms = (time.perf_counter() - started) * 1000
    response.headers["X-Process-Time-Ms"] = f"{elapsed_ms:.1f}"
    if elapsed_ms > 300:  # NFR: most requests < 300 ms
        logger.warning("slow request %s %s %.0f ms", request.method, request.url.path, elapsed_ms)
    return response


API = "/api/v1"
app.include_router(auth.router, prefix=f"{API}/auth", tags=["auth"])
app.include_router(onboarding.router, prefix=API, tags=["onboarding"])
app.include_router(content.router, prefix=API, tags=["content"])
app.include_router(testing.router, prefix=API, tags=["testing"])
app.include_router(profile.router, prefix=API, tags=["profile"])
app.include_router(admin.router, prefix=f"{API}/admin", tags=["admin"])

setup_admin(app, engine)

# Images of official tasks (formulas, figures) cropped from the ntc.tj collections
STATIC_DIR = Path(__file__).resolve().parent / "static"
STATIC_DIR.mkdir(exist_ok=True)
mimetypes.add_type("image/webp", ".webp")  # missing from the table of Python < 3.13
app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")


@app.get("/")
def root():
    return {"message": "EduApp API", "docs": "/docs", "admin": "/admin"}


@app.get("/health")
def health_check():
    from app.services.cache import cache

    db_ok = True
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
    except Exception:
        db_ok = False
    redis_ok = cache._client() is not None
    return {"status": "healthy" if db_ok else "degraded", "database": db_ok, "redis": redis_ok}
