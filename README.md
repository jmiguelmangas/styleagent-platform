# styleagent-platform

Monorepo root for StyleAgent submodules.

## Services

- `backend` (FastAPI): served on `http://localhost:8000`
- `frontend` (React + Nginx): served on `http://localhost:5173`

## Run Backend + Frontend With Docker Compose

From repository root:

```bash
docker compose up --build
```

Optional env overrides (example):

```bash
FRONTEND_API_BASE_URL=http://localhost:8000 \
FRONTEND_API_TIMEOUT_MS=10000 \
FRONTEND_APP_BASE_PATH=/ \
  docker compose up --build
```

## Stop

```bash
docker compose down
```
