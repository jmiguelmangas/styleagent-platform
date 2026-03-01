#!/usr/bin/env bash
set -euo pipefail

echo "== Host Integration Discovery =="
echo "timestamp_utc: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "host_os: $(sw_vers -productName) $(sw_vers -productVersion)"
echo "host_arch: $(uname -m)"
echo

echo "== Installed photo apps in /Applications =="
ls -1 /Applications | rg -N "Capture One|Lightroom|Adobe" || true
echo

echo "== Capture One app info =="
CAPTURE_ONE_APP="/Applications/Capture One.app"
if [[ -d "$CAPTURE_ONE_APP" ]]; then
  echo "capture_one_installed: true"
  echo "bundle_identifier: $(plutil -extract CFBundleIdentifier raw "$CAPTURE_ONE_APP/Contents/Info.plist")"
  echo "bundle_version: $(plutil -extract CFBundleShortVersionString raw "$CAPTURE_ONE_APP/Contents/Info.plist")"
  echo "binary_path: $CAPTURE_ONE_APP/Contents/MacOS/Capture One"
  if [[ -x "$CAPTURE_ONE_APP/Contents/MacOS/Capture One" ]]; then
    echo "binary_executable: true"
  else
    echo "binary_executable: false"
  fi
else
  echo "capture_one_installed: false"
fi
echo

echo "== Lightroom app info =="
LIGHTROOM_APP="/Applications/Adobe Lightroom.app"
if [[ -d "$LIGHTROOM_APP" ]]; then
  echo "lightroom_installed: true"
  echo "bundle_identifier: $(plutil -extract CFBundleIdentifier raw "$LIGHTROOM_APP/Contents/Info.plist")"
  echo "bundle_version: $(plutil -extract CFBundleShortVersionString raw "$LIGHTROOM_APP/Contents/Info.plist")"
else
  echo "lightroom_installed: false"
fi
echo

echo "== AppleScript availability =="
if command -v osascript >/dev/null 2>&1; then
  echo "osascript_path: $(command -v osascript)"
  echo "osascript_self_test: $(osascript -e 'return "ok"')"
  if [[ -d "$CAPTURE_ONE_APP" ]]; then
    # Non-destructive query to validate app addressability through Apple events.
    echo "capture_one_appleevent_id: $(osascript -e 'tell application "Capture One" to id')"
  fi
else
  echo "osascript_path: missing"
fi
echo

echo "== Notes =="
echo "- This script verifies host-level integration prerequisites only."
echo "- It does not execute compile/export commands inside Capture One or Lightroom."
