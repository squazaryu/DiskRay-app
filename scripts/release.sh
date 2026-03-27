#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "Usage: ./scripts/release.sh <version-tag>"
  exit 1
fi

BUILD_NUMBER="${2:-$(date +%Y%m%d%H%M)}"
APP_NAME="DRay.app"
OUT_DIR="dist"
ZIP_PATH="${OUT_DIR}/DRay-${VERSION}.zip"
APP_PATH="/Applications/${APP_NAME}"

mkdir -p "${OUT_DIR}"

./scripts/install_app.sh "${VERSION}" "${BUILD_NUMBER}"

if [[ ! -d "${APP_PATH}" ]]; then
  echo "App not found at ${APP_PATH}"
  exit 1
fi

if [[ -n "${DEVELOPER_ID_APP:-}" ]]; then
  codesign --force --deep --options runtime --timestamp --sign "${DEVELOPER_ID_APP}" "${APP_PATH}"
fi

ditto -c -k --sequesterRsrc --keepParent "${APP_PATH}" "${ZIP_PATH}"

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  xcrun notarytool submit "${ZIP_PATH}" --keychain-profile "${NOTARY_PROFILE}" --wait
  xcrun stapler staple "${APP_PATH}"
  ditto -c -k --sequesterRsrc --keepParent "${APP_PATH}" "${ZIP_PATH}"
fi

git add -A
git commit -m "Release ${VERSION}" || true
git tag -a "${VERSION}" -m "DRay ${VERSION}"
git push origin main --tags

echo "Release ${VERSION} is ready: ${ZIP_PATH}"
