#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "Usage: ./scripts/package_release.sh <version> [build_number]"
  exit 1
fi

BUILD_NUMBER="${2:-$(date +%Y%m%d%H%M)}"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z]+)*$ ]]; then
  echo "Invalid app version: ${VERSION}. Use a semantic version without a leading v."
  exit 1
fi
if [[ ! "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "Invalid build number: ${BUILD_NUMBER}. Use a positive integer."
  exit 1
fi

APP_NAME="DRay.app"
APP_PATH="/Applications/${APP_NAME}"
OUT_DIR="dist"
ZIP_PATH="${OUT_DIR}/DRay-${VERSION}.zip"
DMG_PATH="${OUT_DIR}/DRay-${VERSION}.dmg"
CHECKSUM_PATH="${OUT_DIR}/DRay-${VERSION}-SHA256SUMS.txt"

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
elif [[ "${REQUIRE_DISTRIBUTION_SIGNING:-0}" == "1" ]]; then
  echo "Distribution signing is required, but DEVELOPER_ID_APP is not configured."
  exit 1
else
  echo "Warning: Developer ID is not configured; keeping the ad-hoc signature."
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
elif [[ "${REQUIRE_NOTARIZATION:-0}" == "1" ]]; then
  echo "Notarization is required, but NOTARY_PROFILE is not configured."
  exit 1
fi

codesign --verify --deep --strict "${APP_PATH}"

echo "Creating SHA256 manifest..."
rm -f "${CHECKSUM_PATH}"
(
  cd "${OUT_DIR}"
  shasum -a 256 \
    "$(basename "${ZIP_PATH}")" \
    "$(basename "${DMG_PATH}")" \
    > "$(basename "${CHECKSUM_PATH}")"
)

echo "Artifacts:"
echo " - ${ZIP_PATH}"
echo " - ${DMG_PATH}"
echo " - ${CHECKSUM_PATH}"
cat "${CHECKSUM_PATH}"
