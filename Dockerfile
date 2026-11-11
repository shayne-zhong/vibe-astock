FROM node:24-bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    VRA_DATA_ROOT=/data

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        chromium \
        python3 \
        python3-pip \
        python3-venv \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY orchestrator/package.json orchestrator/package-lock.json ./orchestrator/
COPY desktop/package.json desktop/package-lock.json ./desktop/

RUN npm ci --prefix orchestrator --no-audit --no-fund \
    && npm ci --prefix desktop --no-audit --no-fund

COPY . .

RUN python3 -m venv /app/.venv \
    && /app/.venv/bin/python -m pip install --no-cache-dir --upgrade pip \
    && /app/.venv/bin/python -m pip install --no-cache-dir \
        -r .agents/skills/data-access/scripts/requirements.txt \
    && npm run build --prefix desktop \
    && chmod +x scripts/start deploy/container-entrypoint.sh \
    && mkdir -p /data

EXPOSE 5940

ENTRYPOINT ["/app/deploy/container-entrypoint.sh"]
