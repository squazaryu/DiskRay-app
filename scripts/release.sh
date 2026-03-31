#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "Usage: ./scripts/release.sh <version-tag>"
  exit 1
fi

BUILD_NUMBER="${2:-$(date +%Y%m%d%H%M)}"

./scripts/package_release.sh "${VERSION}" "${BUILD_NUMBER}"

if [[ "${AUTO_TAG_PUSH:-0}" == "1" ]]; then
  git tag -a "${VERSION}" -m "DRay ${VERSION}"
  git push origin "${VERSION}"
  echo "Tagged and pushed: ${VERSION}"
else
  echo "Packaging complete. Tag/push skipped (set AUTO_TAG_PUSH=1 to enable)."
fi
