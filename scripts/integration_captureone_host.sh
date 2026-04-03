#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$ROOT_DIR/docker-compose.yml"
ARTIFACTS_DIR="${HOST_E2E_ARTIFACTS_DIR:-$ROOT_DIR/.artifacts/host-captureone-e2e}"
API_DIR="$ARTIFACTS_DIR/api"
LOGS_DIR="$ARTIFACTS_DIR/logs"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required"
  exit 1
fi
if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required"
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required"
  exit 1
fi

RUNNER_VENV="$ROOT_DIR/runner/.venv"
if [[ ! -f "$RUNNER_VENV/bin/activate" ]]; then
  echo "runner virtualenv not found at $RUNNER_VENV"
  echo "run: cd runner && python3 -m venv .venv && source .venv/bin/activate && pip install -e '.[dev]'"
  exit 1
fi

cleanup() {
  mkdir -p "$LOGS_DIR"
  docker compose -f "$COMPOSE_FILE" ps >"$LOGS_DIR/docker-compose-ps.txt" 2>&1 || true
  docker compose -f "$COMPOSE_FILE" logs --no-color >"$LOGS_DIR/docker-compose.log" 2>&1 || true
  docker compose -f "$COMPOSE_FILE" down >/dev/null 2>&1 || true
}
trap cleanup EXIT

mkdir -p "$ARTIFACTS_DIR" "$API_DIR" "$LOGS_DIR"

echo "Starting backend stack (mongodb + backend)..."
docker compose -f "$COMPOSE_FILE" up -d mongodb backend

echo "Waiting for backend health..."
for _ in {1..60}; do
  if curl -fsS "http://localhost:8000/health" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

STYLE_NAME="CaptureOne Host E2E $(date +%s)"
STYLE_RESPONSE="$(curl -fsS -X POST "http://localhost:8000/styles" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"$STYLE_NAME\"}")"
printf '%s' "$STYLE_RESPONSE" >"$API_DIR/style-create.json"
STYLE_ID="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["style_id"])' <<<"$STYLE_RESPONSE")"

VERSION_PAYLOAD="$(cat <<EOF
{
  "version": "v1",
  "style_spec": {
    "name": "$STYLE_NAME",
    "intent": ["host", "captureone", "e2e"],
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

JOB_RESPONSE="$(curl -fsS -X POST "http://localhost:8000/runner/jobs" \
  -H "Content-Type: application/json" \
  -d "{\"job_type\":\"compile_captureone\",\"payload\":{\"style_id\":\"$STYLE_ID\",\"version\":\"v1\",\"execution_mode\":\"host\"}}")"
printf '%s' "$JOB_RESPONSE" >"$API_DIR/job-create.json"
JOB_ID="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["job_id"])' <<<"$JOB_RESPONSE")"
echo "Queued runner job: $JOB_ID"

echo "Running runner in host mode..."
(
  cd "$ROOT_DIR/runner"
  source .venv/bin/activate
  RUNNER_API_BASE_URL="http://localhost:8000" \
  RUNNER_EXECUTION_MODE="host" \
  RUNNER_CAPTUREONE_APP_PATH="/Applications/Capture One.app" \
  styleagent-runner poll --once
)

echo "Waiting for terminal runner job status..."
FINAL_STATUS=""
IMPORTED_PATH=""
for _ in {1..60}; do
  JOB="$(curl -fsS "http://localhost:8000/runner/jobs/$JOB_ID")"
  printf '%s' "$JOB" >"$API_DIR/job-status.json"
  FINAL_STATUS="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["status"])' <<<"$JOB")"
  if [[ "$FINAL_STATUS" == "succeeded" || "$FINAL_STATUS" == "failed" ]]; then
    IMPORTED_PATH="$(python3 -c 'import json,sys; j=json.load(sys.stdin); print(((j.get("result") or {}).get("host_integration") or {}).get("imported_costyle_path") or "")' <<<"$JOB")"
    break
  fi
  sleep 1
done

if [[ "$FINAL_STATUS" != "succeeded" ]]; then
  echo "Host E2E failed: job status=$FINAL_STATUS"
  curl -fsS "http://localhost:8000/runner/jobs/$JOB_ID"
  exit 1
fi

if [[ -z "$IMPORTED_PATH" || ! -f "$IMPORTED_PATH" ]]; then
  echo "Host E2E failed: imported file missing path=$IMPORTED_PATH"
  exit 1
fi

cat >"$ARTIFACTS_DIR/SUMMARY.md" <<EOF
# Capture One Host E2E Summary

- timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
- style_id: ${STYLE_ID}
- job_id: ${JOB_ID}
- final_status: ${FINAL_STATUS}
- imported_costyle_path: ${IMPORTED_PATH}

## Evidence

- style create: \`api/style-create.json\`
- style version create: \`api/style-version-create.json\`
- job create: \`api/job-create.json\`
- job status: \`api/job-status.json\`
- compose logs: \`logs/docker-compose.log\`
- compose ps: \`logs/docker-compose-ps.txt\`
- imported path marker: \`imported-costyle-path.txt\`
EOF

echo "$IMPORTED_PATH" >"$ARTIFACTS_DIR/imported-costyle-path.txt"
echo "Host E2E passed."
echo "style_id=$STYLE_ID"
echo "job_id=$JOB_ID"
echo "imported_costyle_path=$IMPORTED_PATH"
