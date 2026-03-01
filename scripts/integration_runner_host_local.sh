#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$ROOT_DIR/docker-compose.yml"
RUNNER_DIR="$ROOT_DIR/runner"
RUNNER_VENV="$RUNNER_DIR/.venv"

RUNNER_API_BASE_URL="${RUNNER_API_BASE_URL:-http://localhost:8000}"
RUNNER_CAPTUREONE_APP_PATH="${RUNNER_CAPTUREONE_APP_PATH:-/Applications/Capture One.app}"
RUNNER_CAPTUREONE_IMPORT_DIR="${RUNNER_CAPTUREONE_IMPORT_DIR:-$HOME/.styleagent/captureone/imports}"
RUNNER_CAPTUREONE_LAUNCH_MODE="${RUNNER_CAPTUREONE_LAUNCH_MODE:-auto}"
RUNNER_CAPTUREONE_CLI_COMMAND="${RUNNER_CAPTUREONE_CLI_COMMAND:-}"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required"
  exit 1
fi
if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required"
  exit 1
fi
if [[ ! -f "$RUNNER_VENV/bin/activate" ]]; then
  echo "runner virtualenv not found at $RUNNER_VENV"
  echo "run: cd runner && python3 -m venv .venv && source .venv/bin/activate && pip install -e '.[dev]'"
  exit 1
fi

cleanup() {
  docker compose -f "$COMPOSE_FILE" down >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "Starting backend stack (mongodb + backend)..."
docker compose -f "$COMPOSE_FILE" up -d mongodb backend

echo "Waiting for backend health..."
for _ in {1..60}; do
  if curl -fsS "$RUNNER_API_BASE_URL/health" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! curl -fsS "$RUNNER_API_BASE_URL/health" >/dev/null 2>&1; then
  echo "backend is not reachable at $RUNNER_API_BASE_URL"
  exit 1
fi

echo "Running runner local host integration pytest..."
(
  cd "$RUNNER_DIR"
  source .venv/bin/activate
  RUNNER_HOST_IT=1 \
  RUNNER_API_BASE_URL="$RUNNER_API_BASE_URL" \
  RUNNER_EXECUTION_MODE=host \
  RUNNER_CAPTUREONE_APP_PATH="$RUNNER_CAPTUREONE_APP_PATH" \
  RUNNER_CAPTUREONE_IMPORT_DIR="$RUNNER_CAPTUREONE_IMPORT_DIR" \
  RUNNER_CAPTUREONE_LAUNCH_MODE="$RUNNER_CAPTUREONE_LAUNCH_MODE" \
  RUNNER_CAPTUREONE_CLI_COMMAND="$RUNNER_CAPTUREONE_CLI_COMMAND" \
  pytest -q tests/integration/test_host_local_integration.py
)

echo "Runner host local integration passed."
