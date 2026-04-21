# Performance Workspace (Current Model)

## Product Structure
`Performance` is a diagnostics workspace with 5 tabs:
1. Overview
2. System Load
3. Battery & Energy
4. Startup
5. Network

## Code Structure
- Shell/lifecycle: `DRay/Features/Performance/PerformanceView.swift`
- Workspace content:
  - `.../PerformanceView+WorkspaceOverview.swift`
  - `.../PerformanceView+WorkspaceSystemLoad.swift`
  - `.../PerformanceView+WorkspaceBatteryEnergy.swift`
  - `.../PerformanceView+WorkspaceStartup.swift`
  - `.../PerformanceView+WorkspaceNetwork.swift`
- Reusable workspace components: `.../PerformanceView+WorkspaceComponents.swift`
- Presentation/ranking/format helpers:
  - `.../PerformanceView+LiveLoadHelpers.swift`
  - `.../PerformanceView+StartupNetworkHelpers.swift`
  - `.../PerformanceView+FormattingHelpers.swift`
- Shared local types: `.../PerformanceViewTypes.swift`

## Design Rules
- Keep IA and command model stable unless task explicitly asks redesign.
- Prefer extraction/decomposition over behavior rewrites.
- Presentation helpers must stay deterministic and side-effect free.
- `PerformanceViewModel` should stay thin unless there is a clear presentation-state need.

## Data & Sampling
- Live load data comes from `LiveSystemMetricsMonitor`.
- Trend/history visuals are in-session only.
- Network history in this pass is session-level (not persisted store).
- No additional persistence/store layer for performance presentation state.

## Local Action Ownership
- Global strip: run diagnostics + export/reveal actions.
- Workspace-local actions stay in their workspace (load relief, startup cleanup, network test).

## Regression Checklist
- All 5 tabs switch correctly.
- Diagnostics action still triggers same flow.
- Startup cleanup behavior and confirmations unchanged.
- Network test remains on-demand.
- Build/tests pass: `swift build`, `swift test`.
