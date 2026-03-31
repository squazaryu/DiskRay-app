#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

swift build -c release >/dev/null
BIN_DIR="$(swift build -c release --show-bin-path)"
APP_BIN="${BIN_DIR}/DRay"
APP_BUNDLE="/Applications/DRay.app"
HELPER_BIN="${BIN_DIR}/DRayMenuBarHelper"

if [[ ! -x "$APP_BIN" ]]; then
  echo "❌ DRay binary not found: $APP_BIN"
  exit 1
fi

PASS_COUNT=0
FAIL_COUNT=0

cleanup_all() {
  pkill -x DRay >/dev/null 2>&1 || true
  pkill -x DRayMenuBarHelper >/dev/null 2>&1 || true
}

cleanup_process() {
  local pid="$1"
  if [[ -n "${pid:-}" ]] && kill -0 "$pid" >/dev/null 2>&1; then
    kill "$pid" >/dev/null 2>&1 || true
    wait "$pid" >/dev/null 2>&1 || true
  fi
  cleanup_all
}

run_case() {
  local name="$1"
  shift
  echo "→ $name"

  local log_file
  log_file="$(mktemp -t dray-smoke-log)"
  local pid=""

  "$APP_BIN" "$@" >"$log_file" 2>&1 &
  pid=$!

  sleep 4
  if kill -0 "$pid" >/dev/null 2>&1; then
    echo "✅ $name"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "❌ $name (process exited too early)"
    echo "--- log ---"
    cat "$log_file"
    echo "-----------"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi

  cleanup_process "$pid"
  rm -f "$log_file"
  sleep 1
}

run_case "standard startup"
run_case "open section (performance)" "--open-section" "performance"

echo "→ helper target startup"
if [[ -x "$HELPER_BIN" ]]; then
  cleanup_all
  "$HELPER_BIN" --app-path "/Applications/DRay.app" >/dev/null 2>&1 &
  HELPER_PID=$!
  sleep 4
  if kill -0 "$HELPER_PID" >/dev/null 2>&1; then
    echo "✅ helper target startup"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "❌ helper target startup"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
  cleanup_process "$HELPER_PID"
  sleep 1
else
  echo "⚠️ helper target skipped (binary missing)"
fi

echo "→ helper open-section bootstraps main app"
if [[ -x "$HELPER_BIN" && -d "$APP_BUNDLE" ]]; then
  cleanup_all
  "$HELPER_BIN" --app-path "$APP_BUNDLE" --open-section performance >/dev/null 2>&1 &
  HELPER_PID=$!
  sleep 5
  if kill -0 "$HELPER_PID" >/dev/null 2>&1 && pgrep -x DRay >/dev/null 2>&1; then
    echo "✅ helper open-section bootstraps main app"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "❌ helper open-section bootstraps main app"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
  cleanup_process "$HELPER_PID"
  sleep 1
else
  echo "⚠️ helper open-section skipped (missing helper or /Applications/DRay.app)"
fi

echo "→ quit handoff to helper"
if [[ -d "$APP_BUNDLE" ]]; then
  cleanup_all
  open -a "$APP_BUNDLE" >/dev/null 2>&1 || true
  sleep 4
  osascript -e 'tell application "DRay" to quit' >/dev/null 2>&1 || true
  sleep 3
  if ! pgrep -x DRay >/dev/null 2>&1 && pgrep -x DRayMenuBarHelper >/dev/null 2>&1; then
    echo "✅ quit handoff to helper"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "❌ quit handoff to helper"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
  cleanup_all
  sleep 1
else
  echo "⚠️ quit handoff skipped (missing /Applications/DRay.app)"
fi

echo "Smoke summary: pass=$PASS_COUNT fail=$FAIL_COUNT"
if [[ $FAIL_COUNT -gt 0 ]]; then
  exit 1
fi
