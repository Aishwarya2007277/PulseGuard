# PulseGuard Dockerfile
# Multi-stage build for optimized production image
# -------------------------------------------------

# Stage 1: Base image with Python
FROM python:3.13-slim as base

# Set metadata
LABEL maintainer="PulseGuard Team"
LABEL description="Automated DevOps Platform for Application Deployment, Monitoring, and Self-Healing"
LABEL version="1.0.0"

# Set working directory
WORKDIR /app

# Set environment variables
# Prevents Python from writing .pyc files
ENV PYTHONDONTWRITEBYTECODE=1
# Ensures Python output is sent straight to terminal (useful for Docker logs)
ENV PYTHONUNBUFFERED=1
# Set production environment
ENV ENVIRONMENT=production
ENV PORT=5000

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Stage 2: Dependencies
FROM base as dependencies

# Copy requirements file
COPY app/requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Stage 3: Final production image
FROM base as production

# Copy installed dependencies from dependencies stage
COPY --from=dependencies /usr/local/lib/python3.13/site-packages /usr/local/lib/python3.13/site-packages
COPY --from=dependencies /usr/local/bin /usr/local/bin

# Create non-root user for security
RUN useradd -m -u 1000 pulseguard && \
    chown -R pulseguard:pulseguard /app

# Copy application code
COPY app/ /app/

# Switch to non-root user
USER pulseguard

# Expose port 5000
EXPOSE 5000

# Health check
# Kubernetes will also use /health endpoint, but this is for Docker
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')" || exit 1

# Run the application using gunicorn (production WSGI server)
# 4 workers is a good default for production
# timeout of 120 seconds for long-running requests
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "4", "--timeout", "120", "--access-logfile", "-", "--error-logfile", "-", "app:app"]
