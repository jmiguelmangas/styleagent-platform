#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export STYLEAGENT_SMOKE_USE_REAL_AI=1
export STYLEAGENT_AI_PROVIDER="${STYLEAGENT_AI_PROVIDER:-ollama}"
export STYLEAGENT_AI_MODEL="${STYLEAGENT_AI_MODEL:-llama3.1:8b}"
export STYLEAGENT_AI_BASE_URL="${STYLEAGENT_AI_BASE_URL:-http://host.docker.internal:11434}"
export STYLEAGENT_AI_TIMEOUT_SECONDS="${STYLEAGENT_AI_TIMEOUT_SECONDS:-45}"
export STYLEAGENT_AI_COLD_START_TIMEOUT_SECONDS="${STYLEAGENT_AI_COLD_START_TIMEOUT_SECONDS:-120}"
export SMOKE_ARTIFACTS_DIR="${SMOKE_ARTIFACTS_DIR:-$ROOT_DIR/.artifacts/integration-smoke-ollama}"

echo "Running integration smoke with real Ollama provider..."
echo "provider=$STYLEAGENT_AI_PROVIDER"
echo "model=$STYLEAGENT_AI_MODEL"
echo "base_url=$STYLEAGENT_AI_BASE_URL"

"$ROOT_DIR/scripts/integration_smoke.sh"
