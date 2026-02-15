#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$ROOT_DIR/docker-compose.yml"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required"
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required"
  exit 1
fi

cleanup() {
  docker compose -f "$COMPOSE_FILE" down -v >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "Starting integration stack..."
docker compose -f "$COMPOSE_FILE" up -d --build mongodb backend frontend runner

wait_http_ok() {
  local url="$1"
  local expected="$2"
  local max_tries="${3:-60}"
  local try=1

  while (( try <= max_tries )); do
    if response="$(curl -fsS "$url" 2>/dev/null || true)"; then
      if [[ "$response" == *"$expected"* ]]; then
        return 0
      fi
    fi
    sleep 2
    ((try++))
  done
  echo "Timeout waiting for $url"
  return 1
}

echo "Waiting for backend health..."
wait_http_ok "http://localhost:8000/health" '"status":"ok"' 90

echo "Waiting for frontend..."
wait_http_ok "http://localhost:5173/" "<!doctype html" 90

STYLE_NAME="Integration Smoke $(date +%s)"
CREATE_STYLE_PAYLOAD="$(printf '{"name":"%s"}' "$STYLE_NAME")"
STYLE_RESPONSE="$(curl -fsS -X POST "http://localhost:8000/styles" -H "Content-Type: application/json" -d "$CREATE_STYLE_PAYLOAD")"
STYLE_ID="$(python3 -c 'import json,sys;print(json.load(sys.stdin)["style_id"])' <<<"$STYLE_RESPONSE")"

VERSION_PAYLOAD="$(cat <<EOF
{
  "version": "v1",
  "style_spec": {
    "name": "$STYLE_NAME",
    "intent": ["integration", "smoke"],
    "captureone": {
      "keys": {
        "Exposure": 0.25,
        "Contrast": 8
      }
    }
  }
}
EOF
)"
curl -fsS -X POST "http://localhost:8000/styles/$STYLE_ID/versions" \
  -H "Content-Type: application/json" \
  -d "$VERSION_PAYLOAD" >/dev/null

COMPILE_RESPONSE="$(curl -fsS -X POST "http://localhost:8000/styles/$STYLE_ID/versions/v1/compile?target=captureone")"
ARTIFACT_ID="$(python3 -c 'import json,sys;print(json.load(sys.stdin)["artifact_id"])' <<<"$COMPILE_RESPONSE")"
DOWNLOAD_URL="$(python3 -c 'import json,sys;print(json.load(sys.stdin)["download_url"])' <<<"$COMPILE_RESPONSE")"

if [[ -z "$ARTIFACT_ID" ]] || [[ "$DOWNLOAD_URL" != /artifacts/* ]]; then
  echo "Invalid compile response"
  exit 1
fi

ARTIFACT_CONTENT="$(curl -fsS "http://localhost:8000$DOWNLOAD_URL")"
if [[ "$ARTIFACT_CONTENT" != *"<SL Engine="* ]]; then
  echo "Artifact payload is not a valid .costyle XML"
  exit 1
fi

RUNNER_LIST_RESPONSE="$(curl -fsS "http://localhost:8000/runner/jobs?status=pending&limit=10")"
python3 -c 'import json,sys; jobs=json.load(sys.stdin); assert isinstance(jobs, list)' <<<"$RUNNER_LIST_RESPONSE"

echo "Integration smoke passed."
