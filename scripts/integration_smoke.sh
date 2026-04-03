#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$ROOT_DIR/docker-compose.yml"
ARTIFACTS_DIR="${SMOKE_ARTIFACTS_DIR:-$ROOT_DIR/.artifacts/integration-smoke}"
PLAYWRIGHT_RESULTS_DIR="$ARTIFACTS_DIR/playwright"
DOWNLOADS_DIR="$ARTIFACTS_DIR/downloads"
LOGS_DIR="$ARTIFACTS_DIR/logs"
API_DIR="$ARTIFACTS_DIR/api"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required"
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required"
  exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "npm is required"
  exit 1
fi

cleanup() {
  mkdir -p "$LOGS_DIR"
  docker compose -f "$COMPOSE_FILE" ps >"$LOGS_DIR/docker-compose-ps.txt" 2>&1 || true
  docker compose -f "$COMPOSE_FILE" logs --no-color >"$LOGS_DIR/docker-compose.log" 2>&1 || true
  docker compose -f "$COMPOSE_FILE" down -v >/dev/null 2>&1 || true
}
trap cleanup EXIT

mkdir -p "$PLAYWRIGHT_RESULTS_DIR" "$DOWNLOADS_DIR" "$LOGS_DIR" "$API_DIR"

if [[ "${STYLEAGENT_SMOKE_USE_REAL_AI:-0}" != "1" ]]; then
  export STYLEAGENT_AI_PROVIDER="${STYLEAGENT_AI_PROVIDER:-mock}"
  export STYLEAGENT_AI_MODEL="${STYLEAGENT_AI_MODEL:-mock-v1}"
fi

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

wait_http_up() {
  local url="$1"
  local max_tries="${2:-60}"
  local try=1

  while (( try <= max_tries )); do
    if curl -fsS -o /dev/null "$url" 2>/dev/null; then
      return 0
    fi
    sleep 2
    ((try++))
  done
  echo "Timeout waiting for $url"
  return 1
}

wait_mongodb_ready() {
  local max_tries="${1:-60}"
  local try=1

  while (( try <= max_tries )); do
    if docker compose -f "$COMPOSE_FILE" exec -T mongodb mongosh --quiet --eval "db.runCommand({ ping: 1 }).ok" \
      >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
    ((try++))
  done
  echo "Timeout waiting for mongodb readiness"
  return 1
}

echo "Waiting for mongodb readiness..."
wait_mongodb_ready 90

echo "Waiting for backend health..."
wait_http_ok "http://localhost:8000/health" '"status":"ok"' 90

echo "Waiting for backend storage readiness..."
wait_http_up "http://localhost:8000/styles" 90

echo "Waiting for frontend..."
wait_http_ok "http://localhost:5173/" "<!doctype html" 90

echo "Waiting for AI health..."
wait_http_ok "http://localhost:8000/ai/health" '"available":true' 90
curl -fsS "http://localhost:8000/ai/health" >"$API_DIR/ai-health.json"
curl -fsS "http://localhost:8000/health" >"$API_DIR/backend-health.json"

echo "Installing frontend Playwright dependencies if needed..."
pushd "$ROOT_DIR/frontend" >/dev/null
if [[ ! -d node_modules ]]; then
  npm ci
fi
npx playwright install chromium >/dev/null

echo "Running live-stack Playwright happy path..."
PLAYWRIGHT_LIVE_STACK=1 \
PLAYWRIGHT_BASE_URL="http://127.0.0.1:5173" \
PLAYWRIGHT_HTML_REPORT="$PLAYWRIGHT_RESULTS_DIR/html-report" \
npx playwright test e2e/live-stack.spec.ts --project=chromium --output "$PLAYWRIGHT_RESULTS_DIR/test-results"
popd >/dev/null

STYLE_NAME="Integration Smoke $(date +%s)"
CREATE_STYLE_PAYLOAD="$(printf '{"name":"%s"}' "$STYLE_NAME")"
STYLE_RESPONSE="$(curl -fsS -X POST "http://localhost:8000/styles" -H "Content-Type: application/json" -d "$CREATE_STYLE_PAYLOAD")"
printf '%s' "$STYLE_RESPONSE" >"$API_DIR/style-create.json"
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
  -d "$VERSION_PAYLOAD" >"$API_DIR/style-version-create.json"

COMPILE_RESPONSE="$(curl -fsS -X POST "http://localhost:8000/styles/$STYLE_ID/versions/v1/compile?target=captureone")"
printf '%s' "$COMPILE_RESPONSE" >"$API_DIR/compile-response.json"
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
printf '%s' "$ARTIFACT_CONTENT" >"$DOWNLOADS_DIR/${STYLE_ID}-v1.costyle"

RUNNER_LIST_RESPONSE="$(curl -fsS "http://localhost:8000/runner/jobs?status=pending&limit=10")"
printf '%s' "$RUNNER_LIST_RESPONSE" >"$API_DIR/runner-jobs.json"
python3 -c 'import json,sys; jobs=json.load(sys.stdin); assert isinstance(jobs, list)' <<<"$RUNNER_LIST_RESPONSE"

cat >"$ARTIFACTS_DIR/SUMMARY.md" <<EOF
# Integration Smoke Summary

- timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
- ai_provider: ${STYLEAGENT_AI_PROVIDER}
- ai_model: ${STYLEAGENT_AI_MODEL}
- style_id: ${STYLE_ID}
- artifact_id: ${ARTIFACT_ID}
- download_url: ${DOWNLOAD_URL}

## Evidence

- backend health: \`api/backend-health.json\`
- ai health: \`api/ai-health.json\`
- style create: \`api/style-create.json\`
- style version create: \`api/style-version-create.json\`
- compile response: \`api/compile-response.json\`
- runner jobs: \`api/runner-jobs.json\`
- downloaded costyle: \`downloads/${STYLE_ID}-v1.costyle\`
- compose logs: \`logs/docker-compose.log\`
- compose ps: \`logs/docker-compose-ps.txt\`
- playwright results: \`playwright/test-results/\`
EOF

echo "$ARTIFACTS_DIR" >"$ARTIFACTS_DIR/ARTIFACTS_DIR.txt"
echo "Integration smoke passed."
