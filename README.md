# StyleAgent Platform

Monorepo root for StyleAgent services and submodules.

## Repository Structure

- `backend/` — FastAPI API (`http://localhost:8000`)
- `frontend/` — React app (`http://localhost:5173`)
- `runner/` — Python runner CLI (`styleagent-runner`)
- `docker-compose.yml` — local orchestration for backend + frontend + runner + mongodb

## Submodules

Initialize/update submodules from root:

```bash
git submodule update --init --recursive
```

Sync submodules to remote main branches:

```bash
git submodule update --remote --merge
```

## Run Backend + Frontend + Runner (Docker Compose)

From repository root:

```bash
docker compose up --build
```

Optional frontend env overrides:

```bash
FRONTEND_API_BASE_URL=http://localhost:8000 \
FRONTEND_API_TIMEOUT_MS=10000 \
FRONTEND_APP_BASE_PATH=/ \
RUNNER_API_BASE_URL=http://backend:8000 \
RUNNER_POLL_INTERVAL=5 \
RUNNER_API_KEY= \
RUNNER_HTTP_TIMEOUT_SECONDS=10 \
RUNNER_HTTP_RETRIES=2 \
  docker compose up --build
```

Mongo is included by default in compose:
- `mongodb://localhost:27017` (host access)
- backend internal URL default: `mongodb://mongodb:27017/styleagent`

You can also copy the full env template:

```bash
cp .env.example .env
```

Stop services:

```bash
docker compose down
```

## Integration Smoke Test

Run a full stack integration smoke test (mongodb + backend + frontend + runner):

```bash
./scripts/integration_smoke.sh
```

This same smoke test runs in GitHub Actions on every pull request and push to `main`.

What it validates:
- backend and frontend are reachable
- AI health is available
- a real browser completes the main guided journey with Playwright
- prompt generation works against the running backend
- preset save and `.costyle` export work through the UI
- create style and version via backend API
- compile Capture One artifact and download it
- runner jobs endpoint is reachable

Notes:
- the smoke test forces `STYLEAGENT_AI_PROVIDER=mock` so CI and local smoke runs stay deterministic
- this is separate from manual/local Ollama validation, which can stay enabled in normal docker usage
- smoke artifacts are written to `.artifacts/integration-smoke/` and uploaded by CI

## Capture One Host E2E (Local)

Run a local host-mode E2E check for Capture One integration:

```bash
./scripts/integration_captureone_host.sh
```

What it validates:
- backend + mongodb are started
- style/version/job can be created with `execution_mode=host`
- local runner executes host-mode compile job
- job reaches `succeeded`
- imported `.costyle` file exists on local filesystem

Evidence:
- host E2E artifacts are written to `.artifacts/host-captureone-e2e/`

## Ollama Smoke (Local, Manual)

Run the full smoke against your real local Ollama instance:

```bash
./scripts/integration_smoke_ollama.sh
```

Optional overrides:

```bash
STYLEAGENT_AI_MODEL=llama3.1:8b \
STYLEAGENT_AI_BASE_URL=http://host.docker.internal:11434 \
./scripts/integration_smoke_ollama.sh
```

What it validates:
- the same browser/API happy path as the normal smoke
- real provider health via `/ai/health`
- preset generation through the configured Ollama model
- saved/exported artifact path still completes end to end

Evidence:
- Ollama smoke artifacts are written to `.artifacts/integration-smoke-ollama/`

## Runner Host Integration Test (Local, One Command)

Run the runner local-gated host integration pytest (with backend auto-start):

```bash
./scripts/integration_runner_host_local.sh
```

## Operations Runbook

Host-mode operations and troubleshooting guide:

- `docs/runbook-host-mode.md`

Optional env overrides:

```bash
RUNNER_API_BASE_URL=http://localhost:8000 \
RUNNER_CAPTUREONE_APP_PATH="/Applications/Capture One.app" \
RUNNER_CAPTUREONE_IMPORT_DIR="$HOME/.styleagent/captureone/imports" \
RUNNER_CAPTUREONE_LAUNCH_MODE=auto \
RUNNER_CAPTUREONE_CLI_COMMAND='captureone-cli import --style {costyle_path}' \
./scripts/integration_runner_host_local.sh
```

## Runner (Local CLI)

Runner is currently executed directly from the `runner` submodule:

```bash
cd runner
pip install -e .[dev]
styleagent-runner --help
```

Common commands:

```bash
styleagent-runner poll
styleagent-runner poll --once
styleagent-runner run --job-id <job_id>
```

## Host Integration Docs

- Discovery checklist: `/Users/josemiguelmangas/PROGRAMACION/styleagent/styleagent-platform/docs/Host-Integration-Discovery.md`
- Adapter contract: `/Users/josemiguelmangas/PROGRAMACION/styleagent/styleagent-platform/docs/Runner-Host-Adapter-Contract.md`
- Local host discovery command:

```bash
./scripts/discover_host_integrations.sh
```
