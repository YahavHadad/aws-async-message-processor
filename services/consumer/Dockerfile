FROM python:3.12-slim AS base

WORKDIR /app

RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser

COPY services/consumer/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY services/shared /app/shared
COPY services/consumer/app /app/app

ENV PYTHONPATH=/app

USER appuser

CMD ["python", "-m", "app.main"]
