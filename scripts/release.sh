#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "Usage: ./scripts/release.sh <version> [build_number]"
  exit 1
fi

BUILD_NUMBER="${2:-$(date +%Y%m%d%H%M)}"
TAG="v${VERSION}"

./scripts/package_release.sh "${VERSION}" "${BUILD_NUMBER}"

if [[ "${AUTO_TAG_PUSH:-0}" == "1" ]]; then
  git tag -a "${TAG}" -m "DRay ${VERSION}"
  git push origin "${TAG}"
  echo "Tagged and pushed: ${TAG}"
else
  echo "Packaging complete. Tag/push skipped (set AUTO_TAG_PUSH=1 to enable)."
fi
