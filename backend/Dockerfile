FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY app/ ./app/
# Own tasks (data/own) and lessons (data/lessons) loaded by `python -m app.seed`
COPY data/ ./data/
COPY alembic/ ./alembic/
COPY alembic.ini docker-entrypoint.sh ./
# Built offline packs (app/services/packs.py) go to a writable directory
ENV PACKS_DIR=/app/packs
RUN chmod +x docker-entrypoint.sh && useradd --create-home appuser \
    && mkdir -p /app/packs /app/app/static && chown appuser /app/packs /app/app/static
USER appuser

EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"

ENTRYPOINT ["./docker-entrypoint.sh"]
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2", "--proxy-headers"]
