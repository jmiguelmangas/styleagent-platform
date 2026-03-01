# Host Integration Discovery (Step 1)

Date: 2026-03-01  
Scope: Verify local host prerequisites for desktop app automation and document command surface.

## Summary

- Capture One is installed on this host.
- Lightroom is not currently installed on this host.
- AppleScript runtime (`osascript`) is available and can address Capture One by bundle id.
- No dedicated Capture One CLI binary was identified beyond the app executable.

## Evidence (from `scripts/discover_host_integrations.sh`)

- `capture_one_installed: true`
- `bundle_identifier: com.captureone.captureone16`
- `bundle_version: 16.7.2.32`
- `binary_path: /Applications/Capture One.app/Contents/MacOS/Capture One`
- `lightroom_installed: false`
- `osascript_path: /usr/bin/osascript`
- `capture_one_appleevent_id: com.captureone.captureone16`

## Supported Host Commands (Current)

These commands are considered safe and supported for host-mode integration scaffolding:

1. App discovery and metadata:
   - `ls /Applications`
   - `plutil -extract ... /Applications/<App>.app/Contents/Info.plist`
2. AppleScript transport check:
   - `osascript -e 'return "ok"'`
   - `osascript -e 'tell application "Capture One" to id'`
3. App launch/activation (future runner host mode):
   - `open -a "Capture One"`

Not yet validated in this step:

1. Capture One compile/export via AppleScript or plugin API.
2. Lightroom automation commands.
3. Deterministic headless export behavior from either app.

## Constraints and Risks

1. Host integration is macOS-only for now (`osascript`, `.app` bundle assumptions).
2. GUI app automation requires user session and may require accessibility/automation permissions.
3. Desktop app version changes can break automation semantics.
4. CI cannot run real Capture One/Lightroom integration; CI must keep mock adapter tests.

## Decision for Next PRs

1. Keep backend/runner API stable.
2. Introduce host adapter behind runner execution mode toggle.
3. Use strict adapter interface documented in `/Users/josemiguelmangas/PROGRAMACION/styleagent/styleagent-platform/docs/Runner-Host-Adapter-Contract.md`.
