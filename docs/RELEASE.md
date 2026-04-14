# DRay Release Pipeline

## Local Release

1. Build + smoke + package artifacts (`zip` + `dmg`):
```bash
./scripts/package_release.sh 2.0.0
```

2. Optional signed + notarized release:
```bash
export DEVELOPER_ID_APP="Developer ID Application: YOUR_NAME (TEAMID)"
export NOTARY_PROFILE="dray-notary"
./scripts/package_release.sh 2.0.0
```

Result artifacts:
- `dist/DRay-2.0.0.zip`
- `dist/DRay-2.0.0.dmg`

3. Tag + push:
```bash
git tag -a v2.0.0 -m "DRay v2.0.0"
git push origin main --tags
```

4. Publish GitHub release via `gh`:
```bash
gh release create v2.0.0 \
  dist/DRay-2.0.0.zip \
  dist/DRay-2.0.0.dmg \
  --title "DRay 2.0.0" \
  --notes-file docs/releases/2.0.0.md
```

## CI Release

Workflow:
- `.github/workflows/release.yml`

Manual inputs:
- `version` (required): tag value, example `v2.0.0`
- `build_number` (optional)

The workflow runs smoke checks, builds `/Applications/DRay.app`, packages `zip` + `dmg`, and uploads both artifacts.

## Notarization Setup

Create keychain profile once:
```bash
xcrun notarytool store-credentials "dray-notary" \
  --apple-id "YOUR_APPLE_ID" \
  --team-id "YOUR_TEAM_ID" \
  --password "APP_SPECIFIC_PASSWORD"
```

Standalone notarization command:
```bash
./scripts/notarize.sh dist/DRay-2.0.0.zip /Applications/DRay.app
```
