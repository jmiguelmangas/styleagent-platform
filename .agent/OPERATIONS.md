# StyleAgent - Operations and Procedures

## Purpose
This file captures the repeated procedures we used while stabilizing StyleAgent across:
- `platform`
- `backend`
- `frontend`
- `runner`

Use this before doing repo maintenance, CI cleanup, or submodule sync work.

## Repo model
- Root repo: `styleagent-platform`
- Submodules:
  - `backend`
  - `frontend`
  - `runner`

Rule:
- publish changes in the submodule repo first
- then update the submodule pointer in `platform`
- then open/merge the `platform` PR

## Standard workflow for submodule changes
1. Make and validate the change in the submodule repo.
2. Commit in the submodule.
3. Push the submodule commit to its remote.
4. In `platform`, update the submodule pointer.
5. Commit the pointer update in `platform`.
6. Open a PR in `platform`.
7. Wait for `platform` checks:
   - `docker-compose-smoke`
   - `CodeQL`
   - `GitGuardian`
8. Merge the `platform` PR.

## Common failure mode: platform CI cannot fetch submodule commit
Symptom:
- `platform` CI fails during checkout with:
  - `not our ref`
  - `Fetched in submodule path ..., but it did not contain ...`

Cause:
- `platform` points at a submodule commit that exists locally but has not been pushed to the submodule remote yet.

Fix:
1. Identify the missing submodule commit from the CI log.
2. Push that commit to the submodule repo `main`.
3. Rerun `platform` checks or refresh the PR.

## Common failure mode: branch protection on platform main
Symptom:
- direct push to `platform/main` rejected
- message says changes must be made through a PR

Fix:
1. Create a branch with prefix `codex/`
2. Push the branch
3. Open a PR
4. Merge via GitHub after checks pass

## Host runner workflow policy
Status:
- host runner workflows in `runner` are manual-only

Why:
- scheduled runs created noisy failures when the self-hosted macOS Capture One runner was offline

Relevant files:
- `/Users/josemiguelmangas/PROGRAMACION/styleagent/styleagent-platform/runner/.github/workflows/host-runner-readiness.yml`
- `/Users/josemiguelmangas/PROGRAMACION/styleagent/styleagent-platform/runner/.github/workflows/host-integration.yml`

## AI stack operational notes
Backend endpoints:
- `GET /health`
- `GET /ai/health`
- `POST /ai/generate-style-spec`
- `POST /ai/debug/prompt-preview`
- chat session endpoints under `/ai/chat/...`

Frontend behavior:
- header shows backend health
- AI health is shown in header, model details in hover tooltip

Docker/Ollama notes:
- backend in Docker uses Ollama through `host.docker.internal`
- if frontend shows `mock`, check backend env wiring in root compose

## Dependency maintenance policy
Safe to merge directly when green:
- small dependabot bumps with passing CI
- workflow action major bumps when syntax is unchanged

Do not force blindly:
- ecosystem upgrades with peer dependency conflicts
- example: `eslint@10` was intentionally not merged because `eslint-plugin-react-hooks` currently supports ESLint 9 only

## Frontend maintenance procedure
When updating frontend dependencies:
1. rebase or branch from `origin/main`
2. apply the bump
3. run:
```bash
npm run lint
npm run test -- --run
npm run build
```
4. only then push/merge

Recent validated example:
- `jsdom@28.1.0` was validated this way and published in `frontend/main` commit `5926128`

## Runner maintenance procedure
When a workflow action bump PR cannot be merged by token permissions:
1. edit the workflow manually in `runner`
2. commit on `runner/main`
3. push to remote
4. close the dependabot PR with a note referencing the resolving commit

Recent validated example:
- `actions/upload-artifact@v7` was applied manually in `runner/main` commit `d0069ae`

## Platform maintenance procedure
After submodule maintenance:
1. check:
```bash
git diff --submodule=log origin/main..HEAD
```
2. open `platform` PR with only submodule pointer changes
3. watch checks:
```bash
gh pr checks <number> --watch
```
4. merge with repository-supported strategy

Note:
- `platform` rejects merge commits; use squash if needed.

## Current reference commits
- `backend/main`: `f9cd0ff`
- `frontend/main`: `5926128`
- `runner/main`: `d0069ae`
- `platform` latest maintenance sync merged in PR `#67`

## Local commands
Bring up stack:
```bash
cd /Users/josemiguelmangas/PROGRAMACION/styleagent/styleagent-platform
docker compose up -d --build
```

Check health:
```bash
curl http://localhost:8000/health
curl http://localhost:8000/ai/health
```

Check prompt preview:
```bash
curl -X POST http://localhost:8000/ai/debug/prompt-preview \
  -H "Content-Type: application/json" \
  -d '{"prompt":"moody cinematic portrait","intent":["cinematic","portrait"]}'
```
