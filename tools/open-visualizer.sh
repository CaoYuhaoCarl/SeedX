#!/usr/bin/env bash
set -euo pipefail

# Open Question-to-Mastery Harness Visualizer with auto-loading + auto-refresh.
# Usage:
#   tools/open-visualizer.sh [project-name] [port]
# Examples:
#   tools/open-visualizer.sh
#   tools/open-visualizer.sh ai-agent-memory
#   tools/open-visualizer.sh ai-agent-memory 8765

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

if command -v open >/dev/null 2>&1; then
  open "$URL"
elif command -v xdg-open >/dev/null 2>&1; then
  xdg-open "$URL"
else
  echo "$URL"
fi

echo "Visualizer: $URL"
echo "Static server: http://${HOST}:${PORT}/"
echo "Log: /tmp/harness-visualizer-${PORT}.log"
