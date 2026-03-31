# DRay Roadmap to CleanMyMac-Level Parity

## Goal
Build feature parity with CleanMyMac-class utility while keeping DRay's own brand and implementation.

## Milestone M1: Smart Scan Foundation (done)
- [x] Unified Smart Scan orchestration across modules.
- [x] Review model with categories, item counts, and bytes.
- [x] Safe clean actions with Trash-first policy.
- [x] `CleanupAnalyzer` protocol and module runner.
- [x] Initial analyzers: User Logs, User Caches, Downloads Old Files.
- [x] `Smart Care` UI tab for scan/review/clean.

## Milestone M2: Cleanup Expansion (in progress)
- [x] Add analyzers:
  - [x] Mail attachments
  - [x] Xcode junk
  - [x] iOS backups
  - [x] language files
- [x] Exclusion system per path and per analyzer.
- [x] Risk scoring and confidence labels.
- [x] Add cleanup protection rules for "critical user folders" (Desktop/Documents/Downloads/iCloud Drive presets).
- [x] Add analyzer execution telemetry (duration, item count, bytes, excluded state).

## Milestone M3: Space Lens + Search Pro (in progress)
- [x] Full drill-down + detail pane + bulk actions in Space Lens.
- [x] Advanced search filters: regex/date/depth/type/owner.
- [x] Saved searches + indexed/live modes.
- [x] Space Lens index-map build moved off main thread (selection panel no longer blocks UI on large trees).
- [x] Space Lens bubble overlap relaxation + smoother animated relayout.
- [x] Space Lens list/bubble hover sync + multi-selection hardening.

## Milestone M4: Uninstaller + Repair Module (in progress)
- [x] App bundle artifact discovery.
- [x] Complete uninstall flow with preview.
- [x] Conflict-safe uninstall plans and rollback metadata.
- [x] Post-uninstall residue sweep (mandatory):
  - [x] leftover files in `~/Library` and `/Library` (preferences, caches, logs, containers, group containers)
  - [x] login items / startup objects cleanup
  - [x] launch agents / helper tools cleanup
  - [x] validation pass after uninstall with report of what was removed vs skipped
- [x] App Repair tab with artifact scan, selective repair and optional relaunch.
- [x] App Repair rollback sessions.
- [x] Add "repair strategy presets" (`Safe Reset`, `Deep Reset`) with explicit risk hints.

## Milestone M5: Performance Module (in progress)
- [x] Login items management baseline.
- [x] LaunchAgent/LaunchDaemon diagnostics.
- [x] Disk pressure + reclaim recommendations.
- [x] Live load cards (CPU/RAM/Network/Battery).
- [x] In-app load reduction actions (de-prioritize heavy processes + restore priorities).
- [x] Add sustained-load detection windows (5m/15m) and trend sparkline.

## Milestone M6: Privacy & Security Module (done baseline)
- [x] Browser traces and local artifact review.
- [x] Safe cleanup with explicit category opt-in.
- [x] Transparency report before delete.

## Milestone M7: Release Engineering (in progress)
- [x] Signed `.app` in `/Applications` pipeline baseline.
- [x] Notarization + hardened runtime pipeline baseline.
- [x] Operation logs + JSON export.
- [x] Crash telemetry ingestion baseline (unclean shutdown detection + persistent crash events log).
- [x] Crash symbolication workflow (`scripts/symbolicate_crash.sh` + docs).
- [x] UI smoke tests baseline for core launch/runtime flows (`standard`, `open-section`, `helper-startup`, `quit-handoff`).

## Milestone M8: Menu Bar Runtime Split (done)
- [x] Main app can transition into helper-owned menu bar runtime.
- [x] Popup actions can re-open the main window in target module.
- [x] Add dedicated helper target (`DRayMenuBarHelper`) for LaunchAgent startup path.
- [x] Full architectural decoupling: popup UI hosted in dedicated helper app process (not DRay main executable).
- [x] Add explicit startup/login control for menu-bar lifecycle (`Start at Login` toggle in popup).

## Milestone M9: Permissions & Access Reliability (in progress)
- [x] First-run permissions onboarding (folder/full-disk access) with explicit guided steps.
- [x] Runtime permission status checker with clear degraded-mode warnings per module.
- [x] One-click permission recovery (`Restore permissions`) for rebuild/update scenarios.
- [x] Pre-action permission validation for scan/delete/repair operations with actionable remediation hints.

## Milestone M10: UX Parity + Hardening (in progress)
- [x] Runtime split hardening: helper startup/quit handoff/open-section flows covered by smoke checks.
- [x] Performance `Live Load` cards aligned into a single row (no horizontal scroll drift).
- [x] Performance battery trend baseline (sparkline + 5m/15m windows).
- [x] Unified module header system (`ModuleHeaderCard`) adopted in `Smart Care`, `My Clutter`, `Uninstaller`, `Space Lens`, `Performance`.
- [x] `App Repair` UI aligned with unified header/selection styling used in `Uninstaller`.
- [x] Visual parity pass for `Smart Care`, `My Clutter`, `Uninstaller`, `Space Lens`, `Performance` (spacing, hierarchy, states, readability).
- [x] Battery insights expansion in popup: richer history intervals and diagnostics drill-down UX.
- [x] App Repair advanced presets: "Safe/Deep" UX polish + safer preview/explainability.
- [x] Pre-release stabilization for `1.0.0-alpha` (`dmg` + `zip`, release notes, final regression pass).
- [ ] Publish GitHub pre-release for `1.0.0-alpha` with attached `dmg`/`zip` artifacts.

## Acceptance Criteria for Parity
- One-click Smart Scan with meaningful multi-module findings.
- Review/clean UX with safe defaults and confirmations.
- Stable performance on large home directories.
- Production packaging flow and permission recovery workflows.
