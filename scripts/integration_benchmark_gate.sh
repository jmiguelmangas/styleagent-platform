#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$ROOT_DIR/docker-compose.yml"
ARTIFACTS_DIR="${BENCHMARK_ARTIFACTS_DIR:-$ROOT_DIR/.artifacts/benchmark-gate}"
LOGS_DIR="$ARTIFACTS_DIR/logs"
BENCHMARK_DIR="$ARTIFACTS_DIR/benchmark"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required"
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required"
  exit 1
fi

cleanup() {
  mkdir -p "$LOGS_DIR"
  docker compose -f "$COMPOSE_FILE" ps >"$LOGS_DIR/docker-compose-ps.txt" 2>&1 || true
  docker compose -f "$COMPOSE_FILE" logs --no-color >"$LOGS_DIR/docker-compose.log" 2>&1 || true
  docker compose -f "$COMPOSE_FILE" down -v >/dev/null 2>&1 || true
}
trap cleanup EXIT

mkdir -p "$ARTIFACTS_DIR" "$LOGS_DIR"

export STYLEAGENT_AI_PROVIDER="${STYLEAGENT_AI_PROVIDER:-mock}"
export STYLEAGENT_AI_MODEL="${STYLEAGENT_AI_MODEL:-mock-v1}"

echo "Starting benchmark gate stack..."
docker compose -f "$COMPOSE_FILE" up -d --build mongodb backend

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

wait_mongodb_ready 90
wait_http_ok "http://localhost:8000/health" '"status":"ok"' 90
wait_http_ok "http://localhost:8000/ai/health" '"available":true' 90

python3 "$ROOT_DIR/scripts/run_preset_benchmark.py" \
  --suite canon \
  --output-dir "$BENCHMARK_DIR" \
  --enforce-gates

cat >"$ARTIFACTS_DIR/SUMMARY.md" <<EOF
# Benchmark Gate Summary

- timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
- ai_provider: ${STYLEAGENT_AI_PROVIDER}
- ai_model: ${STYLEAGENT_AI_MODEL}
- benchmark_dir: \`benchmark/\`

## Evidence

- gate results: \`benchmark/gate-results.json\`
- suite summary: \`benchmark/canon/summary.json\`
- markdown report: \`benchmark/REPORT.md\`
- compose logs: \`logs/docker-compose.log\`
- compose ps: \`logs/docker-compose-ps.txt\`
EOF

echo "$ARTIFACTS_DIR" >"$ARTIFACTS_DIR/ARTIFACTS_DIR.txt"
echo "Benchmark gate passed."
