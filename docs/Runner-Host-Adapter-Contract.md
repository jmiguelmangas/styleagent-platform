# Runner Host Adapter Contract (Step 1)

This contract defines the stable interface for host desktop integrations (Capture One first, Lightroom later).

## Purpose

Allow the runner to execute compile jobs through host app adapters while keeping backend HTTP contracts unchanged.

## Adapter Interface (language-agnostic)

```text
compile_style(
  target: "captureone" | "lightroom",
  style_spec: object,
  output_path: string,
  options?: object
) -> CompileArtifactResult
```

`CompileArtifactResult`:

```json
{
  "ok": true,
  "target": "captureone",
  "output_path": "/absolute/path/to/file.costyle",
  "sha256": "hexstring",
  "metadata": {
    "app_name": "Capture One",
    "app_version": "16.7.2.32",
    "duration_ms": 1200
  }
}
```

On failure:

```json
{
  "ok": false,
  "error_code": "APP_NOT_INSTALLED",
  "error_message": "Capture One.app not found in /Applications",
  "retryable": false,
  "metadata": {
    "target": "captureone"
  }
}
```

## Required Error Codes

1. `APP_NOT_INSTALLED`
2. `APP_NOT_REACHABLE`
3. `AUTOMATION_PERMISSION_DENIED`
4. `UNSUPPORTED_TARGET`
5. `INVALID_STYLE_SPEC`
6. `EXPORT_FAILED`
7. `TIMEOUT`
8. `UNKNOWN`

## Execution Constraints

1. Runner must run on host mode for desktop adapter execution.
2. `output_path` must be absolute and under runner-controlled working directory.
3. Adapter execution timeout must be enforced (default 120s).
4. Commands must use an allowlist per target (no arbitrary shell command execution).
5. Adapter logs must be structured and propagated to backend job logs.

## Current Mapping to Existing Runner Job

- Existing job type: `compile_captureone`
- Existing payload:
  - `style_id: string`
  - `version: string`
- Current behavior: runner calls backend compile endpoint and returns artifact metadata.

Future host mode behavior:

1. Runner fetches style version from backend.
2. Runner calls adapter `compile_style(...)`.
3. Runner uploads/persists produced artifact through backend artifact flow (or backend endpoint extension if needed).

## Non-Goals in Step 1

1. Implement adapter runtime.
2. Implement Lightroom support.
3. Change backend API contracts.
