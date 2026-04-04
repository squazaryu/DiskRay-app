#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ALLOWLIST_FILE="${PII_ALLOWLIST_FILE:-.pii-allowlist}"

if ! command -v rg >/dev/null 2>&1; then
  echo "❌ ripgrep (rg) is required for PII scan."
  exit 2
fi

declare -a PATTERNS=(
  '/Users/[A-Za-z0-9._-]+'
  '/home/[A-Za-z0-9._-]+'
  '[A-Za-z]:\\\\Users\\\\[A-Za-z0-9._ -]+'
  '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'
)

if [[ -n "${PII_SCAN_EXTRA_REGEX:-}" ]]; then
  PATTERNS+=("${PII_SCAN_EXTRA_REGEX}")
fi

# Build tracked text file list.
declare -a FILES=()
while IFS= read -r -d '' file; do
  [[ -f "$file" ]] || continue
  if grep -Iq . "$file"; then
    FILES+=("$file")
  fi
done < <(git ls-files -z)

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "✅ PII scan: no tracked text files found."
  exit 0
fi

tmp_matches="$(mktemp)"
trap 'rm -f "$tmp_matches"' EXIT

for pattern in "${PATTERNS[@]}"; do
  rg -n --no-heading -H -e "$pattern" -- "${FILES[@]}" >>"$tmp_matches" || true
done

if [[ ! -s "$tmp_matches" ]]; then
  echo "✅ PII scan passed: no personal paths/emails detected."
  exit 0
fi

sort -u "$tmp_matches" -o "$tmp_matches"

if [[ -f "$ALLOWLIST_FILE" ]]; then
  while IFS= read -r allow; do
    [[ -z "$allow" || "$allow" =~ ^[[:space:]]*# ]] && continue
    grep -Fv -- "$allow" "$tmp_matches" >"$tmp_matches.filtered" || true
    mv "$tmp_matches.filtered" "$tmp_matches"
  done <"$ALLOWLIST_FILE"
fi

if [[ -s "$tmp_matches" ]]; then
  echo "❌ PII scan failed. Potential personal data found:"
  cat "$tmp_matches"
  echo
  echo "Tip: remove/redact matches or add reviewed exceptions to $ALLOWLIST_FILE"
  exit 1
fi

echo "✅ PII scan passed (after allowlist filtering)."
