#!/usr/bin/env bash
set -euo pipefail

APP_NAME="DRay.app"
APP_PATH="/Applications/${APP_NAME}"
BUNDLE_ID="com.squazaryu.DRay"
VERSION="${1:-0.0.3-alpha}"
BUILD_NUMBER="${2:-1}"

ICON_BASENAME="DRay"
ICON_THEME="${DRAY_ICON_THEME:-light}"
if [[ "$ICON_THEME" == "auto" ]]; then
  if [[ "$(defaults read -g AppleInterfaceStyle 2>/dev/null || true)" == "Dark" ]]; then
    ICON_THEME="dark"
  else
    ICON_THEME="light"
  fi
fi
echo "Packaging icon set: DRay / DRayLight / DRayDark (active base: $ICON_THEME)"

swift build -c release >/dev/null
BIN_DIR="$(swift build -c release --show-bin-path)"
EXECUTABLE="${BIN_DIR}/DRay"
HELPER_EXECUTABLE="${BIN_DIR}/DRayMenuBarHelper"

if [[ ! -x "$EXECUTABLE" ]]; then
  echo "Release executable not found: $EXECUTABLE"
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

BUNDLE_ROOT="${TMP_DIR}/${APP_NAME}"
mkdir -p "${BUNDLE_ROOT}/Contents/MacOS" "${BUNDLE_ROOT}/Contents/Resources" "${BUNDLE_ROOT}/Contents/Helpers"

cat > "${BUNDLE_ROOT}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>DRay</string>
  <key>CFBundleDisplayName</key><string>DRay</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
  <key>CFBundleExecutable</key><string>DRay</string>
  <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleIconFile</key><string>${ICON_BASENAME}</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

cp "$EXECUTABLE" "${BUNDLE_ROOT}/Contents/MacOS/DRay"
chmod +x "${BUNDLE_ROOT}/Contents/MacOS/DRay"
if [[ -x "$HELPER_EXECUTABLE" ]]; then
  cp "$HELPER_EXECUTABLE" "${BUNDLE_ROOT}/Contents/Helpers/DRayMenuBarHelper"
  chmod +x "${BUNDLE_ROOT}/Contents/Helpers/DRayMenuBarHelper"
fi
if [[ -f "assets/DRay.icns" ]]; then
  cp "assets/DRay.icns" "${BUNDLE_ROOT}/Contents/Resources/DRay.icns"
fi
if [[ -f "assets/DRayLight.icns" ]]; then
  cp "assets/DRayLight.icns" "${BUNDLE_ROOT}/Contents/Resources/DRayLight.icns"
fi
if [[ -f "assets/DRayDark.icns" ]]; then
  cp "assets/DRayDark.icns" "${BUNDLE_ROOT}/Contents/Resources/DRayDark.icns"
fi

# Closed-app default icon (helper keeps it synced to current system theme at runtime).
if [[ "$ICON_THEME" == "dark" && -f "assets/DRayDark.icns" ]]; then
  cp "assets/DRayDark.icns" "${BUNDLE_ROOT}/Contents/Resources/DRay.icns"
elif [[ "$ICON_THEME" == "light" && -f "assets/DRayLight.icns" ]]; then
  cp "assets/DRayLight.icns" "${BUNDLE_ROOT}/Contents/Resources/DRay.icns"
fi

codesign --force --deep --sign - "${BUNDLE_ROOT}" >/dev/null 2>&1 || true

pkill -x DRay >/dev/null 2>&1 || true
pkill -x DRayMenuBarHelper >/dev/null 2>&1 || true
rm -rf "$APP_PATH"
cp -R "${BUNDLE_ROOT}" "$APP_PATH"

echo "Installed: $APP_PATH"
