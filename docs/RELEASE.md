# DRay Release Pipeline

## Local Release

1. Build + smoke + package artifacts (`zip` + `dmg`):
```bash
./scripts/package_release.sh 1.2.2
```

2. Optional signed + notarized release:
```bash
export DEVELOPER_ID_APP="Developer ID Application: YOUR_NAME (TEAMID)"
export NOTARY_PROFILE="dray-notary"
./scripts/package_release.sh 1.2.2
```

Result artifacts:
- `dist/DRay-1.2.2.zip`
- `dist/DRay-1.2.2.dmg`

3. Tag + push:
```bash
git tag -a v1.2.2 -m "DRay v1.2.2"
git push origin main --tags
```

4. Publish GitHub release via `gh`:
```bash
gh release create v1.2.2 \
  dist/DRay-1.2.2.zip \
  dist/DRay-1.2.2.dmg \
  --title "DRay 1.2.2" \
  --notes-file docs/releases/1.2.2.md
```

## CI Release

Workflow:
- `.github/workflows/release.yml`

Manual inputs:
- `version` (required): tag value, example `v1.2.2`
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
./scripts/notarize.sh dist/DRay-1.2.2.zip /Applications/DRay.app
```
