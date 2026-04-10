# DRay Architecture (M13 Baseline)

## Scope
This document defines hard boundaries while `RootViewModel` is being decomposed into feature controllers.

## Current Direction
- `RootViewModel` is the app-shell coordinator.
- Feature-local business logic should live in dedicated feature controllers.
- Views should read feature state from feature controllers (directly or via thin feature view models).

## Invariants
1. Feature-local state lives in feature controller/state types.
2. `RootViewModel` does not own feature business rules as end-state.
3. Permission gating must be explicit before protected operations.
4. File operations must go through safe file operation layer / use-cases.
5. Persistence format details must be hidden behind store/use-case contracts.
6. Feature flows must not write raw `UserDefaults` directly.

## Store Contracts
- `SearchPresetStoring` (`SearchPresetStore`)
- `RecoveryStoring` (`RecoveryStore`)
- `UISettingsStoring` (`UISettingsStore`)

## Feature Boundaries (target)
- Search: query/filters/live task/presets/results.
- Privacy: scan/select/clean/report/delta.
- Recovery: recently deleted + rollback/history.
- Uninstaller: app/remnant discovery, uninstall, verify, sessions.
- Repair: artifact strategy + repair execution + sessions.
- Performance: diagnostics/startup cleanup/load-relief/trends.

## Root Responsibilities (target)
- Selected section/navigation.
- Selected scan target and global permission status refresh.
- App-level language/appearance/lifecycle.
- Cross-feature orchestration only (for example unified scan).

## Migration Rule
- Migrations are incremental and behavior-preserving.
- During migration, root proxy methods are allowed temporarily.
- Proxy methods must be removed when the owning feature controller is fully wired.
