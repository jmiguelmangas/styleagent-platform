# StyleAgent - Next Steps Handoff

## Current state
- `platform`, `backend`, `frontend`, and `runner` are all merged and have no open PRs.
- Backend AI stack is live with:
  - Ollama support
  - prompt examples / few-shot injection
  - `POST /ai/debug/prompt-preview`
  - `GET /ai/health`
- Frontend UX is currently on the dark step-by-step wizard flow:
  - `Start`
  - `Create look`
  - `Refine`
  - `Save & export`
- Frontend includes:
  - unified AI entry flow
  - dark visual theme
  - refined `Refine` step grouped into creative sections
  - real AI health chip with hover details
  - integrated brand logo
- Platform Docker stack is working with backend + frontend + runner + mongodb and backend pointed at local Ollama.

## Important latest maintenance work
- `frontend/main` includes `jsdom@28.1.0` in commit `5926128`.
- `runner/main` includes `actions/upload-artifact@v7` in commit `d0069ae`.
- `platform/main` includes those updated submodule pointers via PR `#67`.
- Dependabot cleanup is complete.
- One dependency was intentionally not merged:
  - `eslint@10`
  - reason: `eslint-plugin-react-hooks` still declares compatibility only through ESLint 9.

## High-priority next tasks
1. Refine the `Refine` step UX further
- Add stronger visual grouping and iconography for:
  - `Light`
  - `Color`
  - `Mood`
- Keep technical/output controls secondary.

2. Improve AI conversation UX
- Make chat feel more like an ongoing creative assistant session.
- Keep refinement actions prominent:
  - continue refining
  - apply suggested look
  - save preset

3. Strengthen prompt/example quality loop
- Use `/ai/debug/prompt-preview` during prompt tuning.
- Expand and curate examples from real `.costyle` / `.costylepack` sources.

## Medium-priority tasks
1. Evaluation pipeline
- Benchmark baseline created in `/Users/josemiguelmangas/PROGRAMACION/styleagent/styleagent-platform/docs/AI-Preset-Benchmark.md`.
- Next step: add offline evaluation scripts and persist benchmark outputs under `.artifacts/benchmark/`.

2. Prompt versioning
- Store `prompt_version` in AI generation history.

3. Example ingestion workflow
- Normalize new style packs into reusable prompt examples.

## Known decisions
- Artifacts remain on filesystem for now.
- Mongo is for metadata/state, not artifact bytes.
- Host runner workflows are manual-only on `runner`.
- Do not force `eslint@10` until upstream lint plugin compatibility is available.

## Suggested order
1. Continue frontend UX polish on `Refine` and AI conversation.
2. Build the evaluation pipeline.
3. Improve example ingestion and curation.
4. Revisit the lint toolchain only when ESLint 10 support is real upstream.

## Quick start
```bash
cd /Users/josemiguelmangas/PROGRAMACION/styleagent/styleagent-platform
docker compose up -d --build
```

## Useful checks
```bash
curl http://localhost:8000/health
curl http://localhost:8000/ai/health

curl -X POST http://localhost:8000/ai/debug/prompt-preview \
  -H "Content-Type: application/json" \
  -d '{"prompt":"tokyo night cinematic portrait","intent":["cinematic","portrait"]}'
```
