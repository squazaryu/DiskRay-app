# DRay 2.1.1 Uninstaller Smoke/Regression Pass

Date: 2026-05-08

## Scope

Verification pass for Uninstaller and Search-delete-adjacent flows after 2.1.1 UI and cleanup changes.

## Commands executed

- `swift test`
- `./scripts/ui_smoke.sh`

## Test result summary

- `swift test`: 87/87 passed
- `ui_smoke`: pass=5 fail=0

## Required smoke checklist coverage

- [x] first-load app list refresh  
  Covered by `UninstallerFeatureControllerTests.loadInstalledAppsAndRemnantsUpdatesState`.
- [x] app selection  
  Covered by installed apps/remnants state wiring + unchanged section routing in `RootSectionRouter`.
- [x] uninstall flow  
  Covered by `UninstallerFeatureControllerTests.uninstallUpdatesVerifyStateAndSessions`.
- [x] remnant verification  
  Covered by `UninstallerUseCaseTests.uninstallAndVerifyRunsValidationThenBuildsVerifyReport` and `runVerifyPassUsesProvidedValidation`.
- [x] remaining cleanup  
  Covered by `SafeFileOperationServiceTests.moveToTrashIgnoresChildWhenParentAlsoSelected` and protected-path tests.
- [x] Deep Sweep  
  Covered by `UninstallerFeatureControllerTests.deepSweepRemainingRecordsAddsOrphanCandidates`.
- [x] rollback/recovery handoff  
  Covered by `UninstallSessionUseCaseTests` and `RecoveryFeatureControllerTests`.
- [x] refresh after deletion  
  Covered by `UninstallObservedAppsUseCaseTests` disappearance/reappearance transitions and verify refresh paths.
- [x] stale selected app state  
  No regressions observed; selection guard/refresh logic in `UninstallerView` unchanged except completion messaging fix.
- [x] empty state behavior  
  Covered by existing UI guards in `UninstallerView` plus no failing tests in session/recovery/remnant pipelines.

## Code changes during P7

- No Uninstaller redesign.
- Regression bug fix already present: Remaining tab action message now resolves from pending operation completion when loading finishes.

## Risk notes

- Automated coverage for UI-level empty states remains indirect (state-driven + controller tests).
- No new behavior introduced in uninstall engine or rollback semantics.
