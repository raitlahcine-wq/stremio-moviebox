# Use the official Python 3.14 slim image to match your project requirements
FROM python:3.14-slim-bookworm

# Install uv directly from its official image
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Optimize package compilation
ENV UV_COMPILE_BYTECODE=1

WORKDIR /app

# Create a secure non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Install curl for the container healthcheck
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Copy configuration files and sync dependencies into a local .venv environment
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-install-project --no-dev

# Copy the rest of your Stremio application files and sync them
COPY . /app
RUN uv sync --frozen --no-dev

# Ensure the non-root user completely owns the app directory and the new .venv
RUN chown -R appuser:appuser /app

# Drop root privileges safely
USER appuser
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:$PORT/health || exit 1

# Use 'uv run' to seamlessly execute uvicorn within the project environment
CMD ["sh", "-c", "uv run uvicorn server.main:app --host 0.0.0.0 --port $PORT"]
