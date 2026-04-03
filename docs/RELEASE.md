# DRay Release Pipeline

## Local Release

1. Build + smoke + package artifacts (`zip` + `dmg`):
```bash
./scripts/package_release.sh 1.0.1-beta
```

2. Optional signed + notarized release:
```bash
export DEVELOPER_ID_APP="Developer ID Application: YOUR_NAME (TEAMID)"
export NOTARY_PROFILE="dray-notary"
./scripts/package_release.sh 1.0.1-beta
```

Result artifacts:
- `dist/DRay-1.0.1-beta.zip`
- `dist/DRay-1.0.1-beta.dmg`

3. Tag + push:
```bash
git tag -a v1.0.1-beta -m "DRay v1.0.1-beta"
git push origin main --tags
```

4. Publish GitHub release via `gh`:
```bash
gh release create v1.0.1-beta \
  dist/DRay-1.0.1-beta.zip \
  dist/DRay-1.0.1-beta.dmg \
  --title "DRay 1.0.1-beta" \
  --notes-file docs/releases/1.0.1-beta.md \
  --latest
```

## CI Release

Workflow:
- `.github/workflows/release.yml`

Manual inputs:
- `version` (required): tag value, example `v1.0.1-beta`
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
./scripts/notarize.sh dist/DRay-1.0.1-beta.zip /Applications/DRay.app
```
