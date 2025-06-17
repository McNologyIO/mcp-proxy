# Build stage
FROM ghcr.io/astral-sh/uv:python3.12-alpine AS uv

WORKDIR /app
ENV UV_COMPILE_BYTECODE=1
ENV UV_LINK_MODE=copy

RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --frozen --no-install-project --no-dev --no-editable

ADD . /app
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --no-editable

# Final runtime image
FROM python:3.12-alpine

# Create app user (optional security step)
RUN addgroup -S app && adduser -S app -G app

# Copy virtualenv
COPY --from=uv --chown=app:app /app/.venv /app/.venv

# Make sure mcp-proxy is on the PATH
ENV PATH="/app/.venv/bin:$PATH"

# Create entrypoint script
RUN printf '#!/bin/sh\nexec mcp-proxy --port=8000 --host=0.0.0.0 --pass-environment --named-server-config /home/app/.config/google-calendar-mcp/server_config.json\n' \
    > /entrypoint.sh && chmod +x /entrypoint.sh

# Optional: copy config if needed
# COPY server_config.json /root/.config/google-calendar-mcp/server_config.json

USER app

EXPOSE 8000
ENTRYPOINT ["/entrypoint.sh"]
