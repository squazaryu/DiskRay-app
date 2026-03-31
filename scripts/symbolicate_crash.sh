#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <crash-report-file> [path-to-DRay.dSYM]"
  exit 1
fi

CRASH_FILE="$1"
if [[ ! -f "$CRASH_FILE" ]]; then
  echo "Crash report not found: $CRASH_FILE"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DSYM_PATH="${2:-}"
if [[ -z "$DSYM_PATH" ]]; then
  DSYM_PATH="$(find .build -type d -name "DRay.dSYM" -print | head -n 1 || true)"
fi

if [[ -z "$DSYM_PATH" || ! -d "$DSYM_PATH" ]]; then
  echo "DRay.dSYM not found. Build a release with debug symbols first."
  echo "Hint: swift build -c release"
  exit 1
fi

SYMBOLICATE_TOOL="$(xcrun --find symbolicatecrash 2>/dev/null || true)"
if [[ -z "$SYMBOLICATE_TOOL" ]]; then
  echo "symbolicatecrash tool is not available via xcrun."
  echo "Install Xcode command line tools or full Xcode and retry."
  exit 1
fi

OUT_DIR="${ROOT_DIR}/.build/crash-reports"
mkdir -p "$OUT_DIR"

BASE_NAME="$(basename "$CRASH_FILE")"
OUT_FILE="${OUT_DIR}/symbolicated-${BASE_NAME}"

"$SYMBOLICATE_TOOL" "$CRASH_FILE" "$DSYM_PATH" > "$OUT_FILE"

echo "Symbolicated crash report:"
echo "$OUT_FILE"
