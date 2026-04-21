# DRay Architecture 2X (Practical)

This document describes the current maintainable boundaries after staged cleanup.

## Runtime Topology
- **Main app (`DRay`)**: feature workspaces, orchestration, persistence-backed settings.
- **Menu bar helper (`DRayMenuBarHelper`)**: lightweight telemetry popup and quick actions.

## App Shell
- `RootViewModel` remains the app coordinator.
- Focused collaborators under `DRay/App/Root/` hold extracted helper responsibilities:
  - `RootDomainModels`
  - `RootScanTargetCoordinator`
  - `RootDiagnosticsExporter`
  - `RootTargetBookmarkCoordinator`
  - `RootTrashResultMessageFormatter`
  - `RootUnifiedScanCoordinator`

The coordinator owns state; collaborators are stateless/operation-focused.

## Features
- Feature controllers own feature state and call use-cases/services.
- `Performance` UI is decomposed by role:
  - view shell: `PerformanceView.swift`
  - workspace composition:
    - `PerformanceView+WorkspaceOverview.swift`
    - `PerformanceView+WorkspaceSystemLoad.swift`
    - `PerformanceView+WorkspaceBatteryEnergy.swift`
    - `PerformanceView+WorkspaceStartup.swift`
    - `PerformanceView+WorkspaceNetwork.swift`
  - shared UI pieces: `PerformanceView+WorkspaceComponents.swift`
  - presentation helpers:
    - `PerformanceView+LiveLoadHelpers.swift`
    - `PerformanceView+StartupNetworkHelpers.swift`
    - `PerformanceView+FormattingHelpers.swift`
  - shared types: `PerformanceViewTypes.swift`

## Settings
- `Settings` is a global control center (not per-screen preference dump).
- Sections are decomposed from main view shell:
  - `SettingsView.swift`
  - `SettingsView+SectionScaffold.swift`
  - `SettingsView+GeneralScanningSections.swift`
  - `SettingsView+PermissionsSection.swift`
  - `SettingsView+RecoveryDiagnosticsSections.swift`
  - `SettingsPermissionAvailability.swift`

## Permissions
- Permission semantics remain centralized in `AppPermissionService` + `PermissionGateUseCase`.
- UI-level impact messaging in Settings is descriptive and grounded in real gate usage.

## Helper Hygiene
- Helper monitor uses adaptive sampling cadence:
  - dense full sampling while popup is active,
  - reduced full sampling while hidden.
- Battery details refresh is scoped to visible battery sheet lifecycle (no always-on hidden timer).

## Non-goals
- No new architecture framework.
- No dependency-graph rewrite.
- No duplicated state ownership across extracted files.
