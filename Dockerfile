# Upgrade the base image to Python 3.14 to match your project's lockfile
FROM python:3.14-slim-bookworm

# Install the ultra-fast uv package manager directly from its official image
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Compile clean bytecode files for optimization
ENV UV_COMPILE_BYTECODE=1

WORKDIR /app

# Create a secure non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Install curl for the container healthcheck
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Copy configuration files first to optimize Docker layer caching
COPY pyproject.toml uv.lock ./

# Use the official --system flag to sync dependencies straight into the global environment
RUN uv sync --frozen --no-install-project --no-dev --system

# Copy the rest of your Stremio application files
COPY . /app
RUN uv sync --frozen --no-dev --system

# Ensure the app user owns the application folder
RUN chown -R appuser:appuser /app

# Drop root privileges safely
USER appuser
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:$PORT/health || exit 1

# Launch uvicorn globally from the system binary path
CMD ["sh", "-c", "uvicorn server.main:app --host 0.0.0.0 --port $PORT"]
