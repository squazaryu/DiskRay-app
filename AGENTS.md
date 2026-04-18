# DRay Agent Guide

Practical repository guidance for Codex/human contributors.

## Scope Discipline
- Prefer staged, behavior-safe changes.
- Avoid broad rewrites and unrelated refactors.
- Keep `RootViewModel` as coordinator; extract helpers only when boundaries become clearer.
- Never introduce a new state owner by accident.

## Project Layout
- `DRay/`: main app features and app shell.
- `DRayMenuBarHelper/`: menu bar helper app.
- `Tests/`: Swift Testing suites.
- `docs/`: architecture/release/workspace docs.
- `scripts/`: build/install/package/smoke utilities.

## Key Files (high caution)
- `DRay/App/RootViewModel.swift`
- `DRay/App/DRayApp.swift`
- `DRay/App/AppPermissionService.swift`
- `DRayMenuBarHelper/MenuBarHelperApp.swift`

Touch these only with explicit need and narrow blast radius.

## Build & Test
- Build: `swift build`
- Tests: `swift test`
- App install (example): `./scripts/install_app.sh 2.0.3 3`
- Release artifacts: `./scripts/package_release.sh 2.0.3 3`

## Validation Baseline (after non-trivial change)
- App launches.
- Target workspace opens and actions still work.
- Permission-gated flows show expected blocking/allow behavior.
- Menu bar helper remains responsive and does not over-refresh while hidden.

## Stage-Oriented Working Style
1. Structural extraction first (behavior-preserving).
2. Feature-local decomposition second.
3. Settings/permissions clarity third.
4. Helper/diagnostics hygiene fourth.
5. Docs last.

## Git Hygiene
- Make atomic commits (prefer Conventional Commits).
- Exclude generated noise and secrets.
- Before release: run smoke checks and verify packaged artifacts.
