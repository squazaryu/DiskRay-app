# DRay Release Pipeline

## Local Release

1. Build + smoke + package artifacts (`zip` + `dmg`):
```bash
./scripts/package_release.sh 1.0.0-alpha
```

2. Optional signed + notarized release:
- export signing identity and notary profile:
```bash
export DEVELOPER_ID_APP="Developer ID Application: YOUR_NAME (TEAMID)"
export NOTARY_PROFILE="dray-notary"
```
- run release:
```bash
./scripts/package_release.sh 1.0.0-alpha
```

Result artifacts:
- `dist/DRay-1.0.0-alpha.zip`
- `dist/DRay-1.0.0-alpha.dmg`

3. Optional tag push (without implicit commit):
```bash
AUTO_TAG_PUSH=1 ./scripts/release.sh 1.0.0-alpha
```

## CI Pre-release

Use GitHub Actions workflow:
- `.github/workflows/release.yml`

Manual run inputs:
- `version`: required tag string
- `build_number`: optional

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
./scripts/notarize.sh dist/DRay-1.0.0-alpha.zip /Applications/DRay.app
```
