#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "Usage: ./scripts/release.sh <version-tag>"
  exit 1
fi

swift build -c release
git add -A
git commit -m "Release ${VERSION}" || true
git tag -a "$VERSION" -m "DRay ${VERSION}"
git push origin main --tags

echo "Release ${VERSION} prepared and pushed"
