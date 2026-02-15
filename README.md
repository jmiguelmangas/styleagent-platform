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
- create style and version via backend API
- compile Capture One artifact and download it
- runner jobs endpoint is reachable

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
