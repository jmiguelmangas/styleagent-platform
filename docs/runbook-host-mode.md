# Host Mode Runbook (Capture One)

This runbook is for operating and troubleshooting host-mode execution (`execution_mode=host`) in StyleAgent.

## Scope

Use this document when:
- runner jobs in host mode fail
- Capture One does not import `.costyle`
- CI/local host checks are flaky

If GitHub host workflow is not starting, see **GitHub Workflow Readiness** below.

## Fast Path

1. Run backend + mongodb:

```bash
docker compose up -d mongodb backend
```

2. Run runner preflight:

```bash
cd runner
source .venv/bin/activate
styleagent-runner doctor
```

3. Run one-command local integration check:

```bash
cd ..
./scripts/integration_runner_host_local.sh
```

4. If still failing, run full host E2E:

```bash
./scripts/integration_captureone_host.sh
```

This writes evidence to:

```bash
.artifacts/host-captureone-e2e/
```

## Required Preconditions

- macOS host with Capture One installed
- backend reachable (`GET /health` returns `{"status":"ok"}`)
- runner virtualenv installed (`runner/.venv`)
- import directory writable (default: `~/.styleagent/captureone/imports`)
- macOS Automation permission granted when required

## Key Environment Variables

- `RUNNER_EXECUTION_MODE=host`
- `RUNNER_CAPTUREONE_APP_PATH=/Applications/Capture One.app`
- `RUNNER_CAPTUREONE_IMPORT_DIR=~/.styleagent/captureone/imports`
- `RUNNER_CAPTUREONE_LAUNCH_MODE=auto|open|cli`
- `RUNNER_CAPTUREONE_CLI_COMMAND='captureone-cli import --style {costyle_path}'` (if `cli`/`auto` with CLI path)
- `RUNNER_CAPTUREONE_OPEN_TIMEOUT_SECONDS=15`

## Error Code Map

`APP_NOT_INSTALLED`
- Meaning: Capture One app path does not exist or CLI mode lacks command.
- Action: verify `RUNNER_CAPTUREONE_APP_PATH`; if `LAUNCH_MODE=cli`, set `RUNNER_CAPTUREONE_CLI_COMMAND`.

`APPLE_EVENT_DENIED`
- Meaning: macOS automation/open/CLI invocation denied or failed.
- Action: grant permissions in `System Settings > Privacy & Security > Automation`; retry.

`OPEN_TIMEOUT`
- Meaning: app open/import command exceeded timeout.
- Action: increase `RUNNER_CAPTUREONE_OPEN_TIMEOUT_SECONDS`; verify app responsiveness.

`IMPORT_DIR_NOT_WRITABLE`
- Meaning: runner cannot create/write import directory.
- Action: fix permissions/ownership on `RUNNER_CAPTUREONE_IMPORT_DIR`.

`DOWNLOAD_FAILED`
- Meaning: runner failed fetching artifact from backend.
- Action: verify backend health/network; inspect backend logs and job payload URLs.

## Correlation and Logs

Runner now sends trace headers to backend:
- `X-Request-ID`
- `X-Runner-Job-ID` (job-scoped calls)

For job calls, request id pattern is:
- `runner-<action>-<job_id>-<suffix>`

Use these to correlate runner output with backend logs.

Examples:

```bash
# backend service logs (docker compose)
docker compose logs backend --tail=200

# search by request id or job id
docker compose logs backend | rg "runner-(claim|heartbeat|complete)-"
docker compose logs backend | rg "job_"
```

## Verification Checklist (after fix)

- `styleagent-runner doctor` exits 0
- `./scripts/integration_runner_host_local.sh` passes
- host job ends in `succeeded`
- `result.host_integration.imported_costyle_path` exists on disk
- `.artifacts/host-captureone-e2e/api/job-status.json` contains the final successful job payload

## GitHub Workflow Readiness

Workflow: `Host Integration (macOS)` (repository: `styleagent-runner`)

Required runner labels:
- `self-hosted`
- `macOS`
- `captureone`

Quick status check:

```bash
gh api repos/jmiguelmangas/styleagent-runner/actions/runners \
  --jq '.total_count, [.runners[] | {name, status, busy, labels: [.labels[].name]}]'
```

If `total_count` is `0`, host workflow jobs will remain in `queued`.

Manual trigger:

```bash
gh workflow run "Host Integration (macOS)" -R jmiguelmangas/styleagent-runner --ref main
gh run list -R jmiguelmangas/styleagent-runner --workflow "Host Integration (macOS)" --limit 5
```

## Escalation Data to Attach

When opening an issue/incident, include:
- runner command used + env vars (mask secrets)
- runner job id
- `host_integration.error_code`, `error_message`, `error_details`
- relevant backend log lines with correlated `X-Request-ID`
- output of `styleagent-runner doctor`
