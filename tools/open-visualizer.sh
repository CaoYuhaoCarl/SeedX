#!/usr/bin/env bash
set -euo pipefail

# Open SeedX Harness Visualizer with auto-loading + auto-refresh.
# Usage:
#   tools/open-visualizer.sh [project-name] [port]
# Examples:
#   tools/open-visualizer.sh
#   tools/open-visualizer.sh meme-ai-agent-260509-215509
#   tools/open-visualizer.sh meme-ai-agent-260509-215509 8765

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="${1:-}"
PORT="${2:-8765}"
HOST="127.0.0.1"

cd "$ROOT_DIR"

if [[ -z "$PROJECT" ]]; then
  # Pick newest output project directory by mtime if available.
  if [[ -d output ]]; then
    PROJECT="$(find output -mindepth 1 -maxdepth 1 -type d -printf '%T@ %f\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2- || true)"
  fi
fi

URL="http://${HOST}:${PORT}/tools/harness-visualizer.html"
if [[ -n "$PROJECT" ]]; then
  URL="${URL}?project=${PROJECT}"
fi
OPEN_STAMP="/tmp/harness-visualizer-${PORT}-$(printf '%s' "${PROJECT:-default}" | tr -c '[:alnum:]_.-' '_').open"

# Reuse an existing server only if it can serve the visualizer file from this workspace.
# A port may already be occupied by a stale http.server whose root is wrong; in that case
# the root URL responds, but /tools/harness-visualizer.html returns 404. Restart it.
if command -v python3 >/dev/null 2>&1; then
  if ! python3 - <<PY >/dev/null 2>&1
import urllib.request
urllib.request.urlopen('${URL}', timeout=0.5).read(1)
PY
  then
    if command -v lsof >/dev/null 2>&1; then
      OLD_PIDS="$(lsof -tiTCP:"$PORT" -sTCP:LISTEN 2>/dev/null || true)"
      if [[ -n "$OLD_PIDS" ]]; then
        kill $OLD_PIDS 2>/dev/null || true
        sleep 0.3
      fi
    fi

    : > /tmp/harness-visualizer-${PORT}.log
    nohup python3 -m http.server "$PORT" --bind "$HOST" --directory "$ROOT_DIR" > /tmp/harness-visualizer-${PORT}.log 2>&1 &
    echo $! > /tmp/harness-visualizer-${PORT}.pid
    sleep 0.6
  fi
else
  echo "python3 not found; cannot start local static server" >&2
  exit 1
fi

if ! python3 - <<PY >/dev/null 2>&1
import urllib.request
urllib.request.urlopen('${URL}', timeout=1.0).read(1)
PY
then
  echo "Failed to serve visualizer from: $ROOT_DIR" >&2
  echo "Tried URL: $URL" >&2
  echo "Log: /tmp/harness-visualizer-${PORT}.log" >&2
  exit 1
fi

SHOULD_OPEN=1
OPEN_TTL_SECONDS="${Q2M_VISUALIZER_OPEN_TTL_SECONDS:-60}"
if [[ -f "$OPEN_STAMP" ]]; then
  NOW_SECONDS="$(date +%s)"
  STAMP_SECONDS="$(stat -f %m "$OPEN_STAMP" 2>/dev/null || stat -c %Y "$OPEN_STAMP" 2>/dev/null || echo 0)"
  if (( NOW_SECONDS - STAMP_SECONDS < OPEN_TTL_SECONDS )); then
    SHOULD_OPEN=0
  fi
fi

if [[ "$SHOULD_OPEN" == "1" ]]; then
  : > "$OPEN_STAMP"
  if command -v open >/dev/null 2>&1; then
    open "$URL"
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$URL"
  else
    echo "$URL"
  fi
fi

echo "Visualizer: $URL"
echo "Static server: http://${HOST}:${PORT}/"
echo "Log: /tmp/harness-visualizer-${PORT}.log"
