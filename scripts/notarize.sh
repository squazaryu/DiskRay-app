#!/usr/bin/env bash
set -euo pipefail

ZIP_PATH="${1:-}"
APP_PATH="${2:-/Applications/DRay.app}"

if [[ -z "${ZIP_PATH}" ]]; then
  echo "Usage: ./scripts/notarize.sh <zip-path> [app-path]"
  exit 1
fi

if [[ -z "${NOTARY_PROFILE:-}" ]]; then
  echo "Set NOTARY_PROFILE=<keychain-profile-name> before running notarization"
  exit 1
fi

xcrun notarytool submit "${ZIP_PATH}" --keychain-profile "${NOTARY_PROFILE}" --wait
xcrun stapler staple "${APP_PATH}"
echo "Notarization complete and staple applied: ${APP_PATH}"
