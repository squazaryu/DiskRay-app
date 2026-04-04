#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "Usage: ./scripts/package_release.sh <version> [build_number]"
  exit 1
fi

BUILD_NUMBER="${2:-$(date +%Y%m%d%H%M)}"
APP_NAME="DRay.app"
APP_PATH="/Applications/${APP_NAME}"
OUT_DIR="dist"
ZIP_PATH="${OUT_DIR}/DRay-${VERSION}.zip"
DMG_PATH="${OUT_DIR}/DRay-${VERSION}.dmg"

mkdir -p "${OUT_DIR}"

if [[ "${SKIP_PII_SCAN:-0}" != "1" ]]; then
  echo "Running PII scan..."
  ./scripts/pii_scan.sh
fi

if [[ "${SKIP_SMOKE:-0}" != "1" ]]; then
  echo "Running UI smoke checks..."
  ./scripts/ui_smoke.sh
fi

echo "Installing app bundle to /Applications..."
./scripts/install_app.sh "${VERSION}" "${BUILD_NUMBER}"

if [[ ! -d "${APP_PATH}" ]]; then
  echo "App not found at ${APP_PATH}"
  exit 1
fi

if [[ -n "${DEVELOPER_ID_APP:-}" ]]; then
  echo "Signing app with Developer ID..."
  codesign --force --deep --options runtime --timestamp --sign "${DEVELOPER_ID_APP}" "${APP_PATH}"
fi

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  echo "Pre-notarization app archive..."
  ditto -c -k --sequesterRsrc --keepParent "${APP_PATH}" "${ZIP_PATH}"
  xcrun notarytool submit "${ZIP_PATH}" --keychain-profile "${NOTARY_PROFILE}" --wait
  xcrun stapler staple "${APP_PATH}"
fi

echo "Creating release ZIP..."
rm -f "${ZIP_PATH}"
ditto -c -k --sequesterRsrc --keepParent "${APP_PATH}" "${ZIP_PATH}"

echo "Creating release DMG..."
rm -f "${DMG_PATH}"
DMG_STAGING="$(mktemp -d)"
trap 'rm -rf "${DMG_STAGING}"' EXIT

cp -R "${APP_PATH}" "${DMG_STAGING}/DRay.app"
ln -s /Applications "${DMG_STAGING}/Applications"
hdiutil create \
  -volname "DRay ${VERSION}" \
  -srcfolder "${DMG_STAGING}" \
  -ov -format UDZO \
  "${DMG_PATH}" >/dev/null

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  echo "Notarizing DMG..."
  xcrun notarytool submit "${DMG_PATH}" --keychain-profile "${NOTARY_PROFILE}" --wait
  xcrun stapler staple "${DMG_PATH}"
fi

echo "Artifacts:"
echo " - ${ZIP_PATH}"
echo " - ${DMG_PATH}"
shasum -a 256 "${ZIP_PATH}" "${DMG_PATH}"
