# The web app and API share one HTTPS origin. No credentials enter build layers.
FROM debian:bookworm-slim AS frontend
ARG FLUTTER_VERSION=3.47.4
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git unzip xz-utils libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch ${FLUTTER_VERSION} https://github.com/flutter/flutter.git /opt/flutter
ENV PATH=/opt/flutter/bin:$PATH
WORKDIR /build/app
COPY app/pubspec.yaml app/pubspec.lock ./
RUN flutter config --no-analytics && flutter pub get
COPY app/ ./
RUN flutter build web --release --no-wasm-dry-run --pwa-strategy=none

FROM python:3.12-slim AS dependencies
WORKDIR /build
COPY backend/requirements.txt .
RUN python -m venv /opt/venv && /opt/venv/bin/pip install --no-cache-dir -r requirements.txt

FROM python:3.12-slim AS runtime
ENV PATH=/opt/venv/bin:$PATH \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DJANGO_SETTINGS_MODULE=config.production \
    WEB_BUILD_ROOT=/app/web
COPY --from=dependencies /opt/venv /opt/venv
WORKDIR /app/backend
COPY backend/ ./
COPY deploy/ /app/deploy/
COPY --from=frontend /build/app/build/web /app/web/
# Static collection does not contact a database or need deployment secrets.
RUN DJANGO_SETTINGS_MODULE=config.settings DATABASE_URL=sqlite:///:memory: \
    python manage.py collectstatic --noinput --skip-checks \
    && python -m whitenoise.compress /app/web \
    && useradd --create-home appuser
USER appuser
EXPOSE 8000
CMD ["sh", "/app/deploy/start.sh"]
