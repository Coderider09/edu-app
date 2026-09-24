#!/bin/sh
set -e

# Apply database migrations, then create achievements / demo content / first superadmin (idempotent)
alembic upgrade head
if [ "${SEED_ON_START:-true}" = "true" ]; then
    python -m app.seed
fi

exec "$@"
