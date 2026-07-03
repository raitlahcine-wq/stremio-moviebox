# Build stage
FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim AS builder
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy
WORKDIR /app
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-install-project --no-dev
COPY . /app
RUN uv sync --frozen --no-dev

# Final stage
FROM python:3.12-slim-bookworm
RUN groupadd -r appuser && useradd -r -g appuser appuser
WORKDIR /app

# Install curl for healthcheck
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Copy application files securely
COPY --from=builder --chown=appuser:appuser /app /app

# THE MAGIC TRICK: Direct the global system python to read the venv packages
ENV PYTHONPATH="/app/.venv/lib/python3.12/site-packages"

USER appuser
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:$PORT/health || exit 1

# Launch using the global python binary instead of the restricted venv one
CMD ["sh", "-c", "python -m uvicorn server.main:app --host 0.0.0.0 --port $PORT"]
