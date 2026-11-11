#!/usr/bin/env sh
set -eu

VRA_DATA_ROOT="${VRA_DATA_ROOT:-/data}"
UI_PORT="${PORT:-5940}"
API_PORT="${VRA_API_PORT:-8770}"

if [ "$UI_PORT" = "$API_PORT" ]; then
  API_PORT=8771
fi

PUBLIC_URL="${VRA_PUBLIC_URL:-}"
if [ -z "$PUBLIC_URL" ] && [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
  case "$RAILWAY_PUBLIC_DOMAIN" in
    http://*|https://*) PUBLIC_URL="$RAILWAY_PUBLIC_DOMAIN" ;;
    *) PUBLIC_URL="https://$RAILWAY_PUBLIC_DOMAIN" ;;
  esac
fi
if [ -z "$PUBLIC_URL" ] && [ -n "${RENDER_EXTERNAL_URL:-}" ]; then
  PUBLIC_URL="$RENDER_EXTERNAL_URL"
fi
if [ -z "$PUBLIC_URL" ]; then
  echo "[deploy] 请设置 VRA_PUBLIC_URL，或由 Railway/Render 提供公开域名。" >&2
  exit 2
fi

export VRA_DATA_ROOT

if [ "${VRA_CONTAINER_DRY_RUN:-}" = "1" ]; then
  printf 'VRA_DATA_ROOT=%s\nUI_PORT=%s\nAPI_PORT=%s\nPUBLIC_URL=%s\n' \
    "$VRA_DATA_ROOT" "$UI_PORT" "$API_PORT" "$PUBLIC_URL"
  exit 0
fi

cd /app
umask 077
mkdir -p \
  "$VRA_DATA_ROOT/runs" \
  "$VRA_DATA_ROOT/knowledge" \
  "$VRA_DATA_ROOT/providers" \
  "$VRA_DATA_ROOT/mcp"

# scripts/init 只接受仓库内的数据根；云平台把持久卷挂在仓库外，
# 所以这里按相同的最小结构幂等初始化，已有用户配置绝不覆盖。
if [ ! -f "$VRA_DATA_ROOT/config.json" ]; then
  CONFIG_TMP="$VRA_DATA_ROOT/config.json.tmp.$$"
  printf '%s\n' \
    '{' \
    '  "python": "/app/.venv/bin/python",' \
    '  "provider": { "profile": null },' \
    '  "defaults": { "model": null }' \
    '}' > "$CONFIG_TMP"
  mv "$CONFIG_TMP" "$VRA_DATA_ROOT/config.json"
fi

exec scripts/start \
  --remote \
  --prebuilt \
  --no-open \
  --port "$UI_PORT" \
  --api-port "$API_PORT" \
  --public-url "$PUBLIC_URL"
