FROM python:3.12-slim AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

FROM base AS build
# Pinned dependencies include psycopg's binary wheel; no compiler or system
# libpq is needed in either image.
COPY requirements.txt .
RUN python -m venv /opt/venv && /opt/venv/bin/pip install --no-cache-dir -r requirements.txt

FROM base AS runtime
COPY --from=build /opt/venv /opt/venv
ENV PATH=/opt/venv/bin:$PATH

COPY . .

RUN useradd --create-home appuser
USER appuser

EXPOSE 8000

CMD ["gunicorn", "config.wsgi:application", "--bind", "0.0.0.0:8000"]
