# ancu365 backend — multi-stage Docker build
# Stage: single stage (slim) — no compilation needed for psycopg2-binary

FROM python:3.11-slim AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# System deps: libpq5 (psycopg2-binary runtime), libgeos + libproj (shapely/pyproj), curl (healthcheck)
RUN apt-get update && apt-get install -y --no-install-recommends \
        libpq5 \
        libgeos-dev \
        libproj-dev \
        curl \
        ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Install Python deps first (cached layer)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source
COPY . .

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "3000"]
