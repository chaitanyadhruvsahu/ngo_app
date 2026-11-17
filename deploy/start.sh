#!/bin/sh
set -eu
python manage.py check --deploy --fail-level ERROR
exec gunicorn config.wsgi:application \
  --bind "0.0.0.0:${PORT:-8000}" \
  --workers "${WEB_CONCURRENCY:-1}" --threads 2 \
  --timeout 120 --graceful-timeout 30 \
  --access-logfile - --error-logfile -
