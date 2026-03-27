# DRay Release Pipeline

## Local Release

1. Build, package, tag, and push:
```bash
./scripts/release.sh v0.0.4-alpha
```

2. Optional signed + notarized release:
- export signing identity and notary profile:
```bash
export DEVELOPER_ID_APP="Developer ID Application: YOUR_NAME (TEAMID)"
export NOTARY_PROFILE="dray-notary"
```
- run release:
```bash
./scripts/release.sh v0.0.4-alpha
```

Result artifact:
- `dist/DRay-v0.0.4-alpha.zip`

## CI Release

Use GitHub Actions workflow:
- `.github/workflows/release.yml`

Manual run inputs:
- `version`: required tag string
- `build_number`: optional

The workflow builds `/Applications/DRay.app`, zips it, and uploads artifact.

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
./scripts/notarize.sh dist/DRay-v0.0.4-alpha.zip /Applications/DRay.app
```
