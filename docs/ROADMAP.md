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
- [ ] Search parity vs FindAnyFile:
  - [x] include hidden + package contents controls (enabled by default, no silent skipping)
  - [x] relax default depth limit and increase result cap
  - [x] surface search scope clearly (startup disk vs selected target / mounted volumes)
  - [x] fix search table header spacing and border artifacts

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
- [ ] Add uninstall diagnostics for `permission denied` despite granted Full Disk Access:
  - [ ] classify failure source (`ACL`, `flags`, ownership, TCC scope, running-process lock, App Store protection specifics)
  - [ ] show actionable reason in UI before/after uninstall attempt
  - [ ] add guided remediation flow (quit app/processes, re-check FDA, retry with same plan)
- [ ] Add deep leftover/startup-origin verification for "app relaunches after reboot" cases (e.g. `Ollama`):
  - [ ] scan and correlate all startup vectors: Login Items, LaunchAgents/LaunchDaemons, SMAppService/Background Items
  - [ ] include helper/tools, config references and executable paths even if app bundle artifacts are absent
  - [ ] produce post-uninstall "what can still relaunch and why" report

## Milestone M5: Performance Module (in progress)
- [x] Login items management baseline.
- [x] LaunchAgent/LaunchDaemon diagnostics.
- [x] Disk pressure + reclaim recommendations.
- [x] Live load cards (CPU/RAM/Network/Battery).
- [x] In-app load reduction actions (de-prioritize heavy processes + restore priorities).
- [x] Add sustained-load detection windows (5m/15m) and trend sparkline.
- [ ] Decide on trend history persistence:
  - [ ] persist last N samples across restarts (lightweight store)
  - [x] remove trends from UI if no meaningful history is kept (live metrics only)

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
- [ ] Add permission preflight detail panel for delete operations:
  - [ ] show exact blocker category (no generic "grant access" when access is already granted)
  - [ ] include target path, owning principal, and next-step fix recommendation
  - [ ] avoid full-disk prompt when failure is due to SIP/protected paths (report and skip instead)

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
- [x] Publish GitHub pre-release for `1.0.0-alpha` with attached `dmg`/`zip` artifacts.

## Milestone M11: Functional One-Click Flows (in progress)
- [x] Performance recommendations now include actionable CTA buttons (select startup entries / open Smart Care / rerun diagnostics).
- [x] Privacy module quick actions: `Select Low Risk`, `Select Recommended`, `Quick Clean Safe`, `Quick Clean Recommended`.
- [x] Smart Care quick action: `Quick Clean Recommended`.
- [x] Add post-action delta report (before/after bytes + item counts) for Performance/Privacy quick actions.
- [x] Add rollback snapshot for quick-clean batches (outside Trash) with session metadata in Recovery.
- [x] Prepare and publish `1.0.1-beta` release artifacts (`dmg` + `zip`) with focused notes on one-click automation.

## Milestone M12: Architecture Stabilization (in progress)
- [x] Introduce dedicated use-case layer for Smart Care and Performance flows.
- [x] Add protocol-based service seams for use-case testing (`SmartCareServicing`, `PerformanceServicing`, `ProcessPriorityServicing`).
- [x] Add unit tests for Smart Care and Performance use-cases (delegation + recommendation rules).
- [x] Move operational history persistence from legacy `UserDefaults` blobs to JSON store in `Application Support` with one-time migration.
- [x] Move `LoadReliefResult` to core performance models to remove feature-to-app coupling.
- [x] Introduce `UninstallerUseCase` + `UninstallPlanningUseCase` (service delegation, preview/risk/verify logic).
- [x] Complete Uninstaller/Repair orchestration extraction (session bookkeeping + rollback flows) to further reduce `RootViewModel` ownership.
- [x] Extract search preset persistence/application logic into `SearchPresetUseCase` (reduce storage coupling in `RootViewModel`).
- [x] Extract Smart Care exclusion persistence/toggle logic into `SmartExclusionUseCase` (remove direct `UserDefaults` writes from `RootViewModel` paths).
- [x] Split `RootViewModel` into feature models + root coordinator.
  - [x] Move Search state into `SearchFeatureState` and migrate `SearchView` bindings to `model.search.*`.
  - [x] Move Smart Care state into `SmartCareFeatureState` and migrate `SmartCareView` bindings to `model.smartCare.*`.
  - [x] Move Performance state into `PerformanceFeatureState` and migrate `PerformanceView` bindings to `model.performance.*`.
  - [x] Extract feature-specific observable view models (`SearchViewModel`, `SmartCareViewModel`, `PerformanceViewModel`) coordinated by root shell.
    - [x] `SearchViewModel` extracted and integrated into `SearchView` as feature-level observable coordinator.
    - [x] `SmartCareViewModel` extracted and integrated into `SmartCareView` as feature-level observable coordinator.
    - [x] `PerformanceViewModel` extracted and integrated into `PerformanceView` as feature-level observable coordinator.
- [x] Move operational history from JSON files to structured storage (SQLite) with migrations.
- [x] Cover critical flows with deterministic tests:
  - [x] permission gates
  - [x] uninstall verify pass
  - [x] incremental scan merge

## Milestone M13: RootViewModel Decomposition (in progress)
- [ ] PR1 Shell/Coordinator boundary:
  - [ ] keep only app-level orchestration in `RootViewModel`
  - [ ] route feature-local async/persistence into feature controllers
- [x] PR2 Search extraction:
  - [x] `SearchFeatureController` introduced with `SearchFeatureState`
  - [x] Search live task lifecycle moved out of `RootViewModel`
  - [x] preset operations (`load/save/apply/delete`) moved into controller
  - [x] `SearchViewModel` switched to controller-backed bindings/actions
  - [x] added unit tests for controller orchestration (`SearchFeatureControllerTests`)
- [x] PR3 Privacy extraction (`PrivacyFeatureController`)
  - [x] privacy scan/clean orchestration moved out of `RootViewModel`
  - [x] context-driven permission gating and logging wired through `FeatureContext`
  - [x] controller tests added (`PrivacyFeatureControllerTests`)
- [x] PR4 Recovery extraction (`RecoveryFeatureController`)
  - [x] recently deleted history + rollback sessions moved out of `RootViewModel`
  - [x] restore/remove/rollback orchestration delegated to controller
  - [x] controller tests added (`RecoveryFeatureControllerTests`)
- [x] PR5 Uninstaller + Repair controller split
  - [x] `UninstallerFeatureController` introduced (apps/remnants/uninstall/verify/sessions)
  - [x] `RepairFeatureController` introduced (artifacts/strategy/repair/sessions)
  - [x] rollback restore delegated via feature controllers
  - [x] controller tests added (`UninstallerFeatureControllerTests`, `RepairFeatureControllerTests`)
- [x] PR6 Performance extraction (`PerformanceFeatureController`)
  - [x] diagnostics/startup-cleanup/load-relief orchestration moved out of `RootViewModel`
  - [x] quick-action delta state ownership moved into controller
  - [x] context-driven permission gating/logging applied in controller actions
  - [x] controller tests added (`PerformanceFeatureControllerTests`)
- [x] PR7 Persistence normalization (`Store` contracts, no direct feature writes to `UserDefaults`)
  - [x] `SearchPresetStoring` + `SearchPresetStore` introduced
  - [x] `RecoveryStoring` + `RecoveryStore` introduced
  - [x] `UISettingsStoring` + `UISettingsStore` introduced
  - [x] `RootViewModel` no longer reads/writes raw `UserDefaults` for language/appearance/target-bookmark
- [x] PR8 Cleanup + architecture contract lock (`docs/ARCHITECTURE.md`, remove temporary root proxies)
  - [x] architecture invariants fixed in `docs/ARCHITECTURE.md`
  - [x] `PrivacyView` migrated to `PrivacyViewModel` with direct `PrivacyFeatureController` actions/state access
  - [x] removed root privacy action proxies (`toggle/clear/select/clean`) now owned by privacy controller + feature VM
  - [x] removed root startup-cleanup proxy in favor of direct `PerformanceFeatureController` call from `PerformanceViewModel`
  - [x] `UninstallerView` / `RepairView` switched to direct `uninstaller` / `repair` controller API for load/preview/risk operations
  - [x] removed root uninstaller/repair temporary proxies (`loadInstalledApps`, `loadRemnants`, `loadRepairArtifacts`, `recommendedRepairArtifacts`, `repairRisk`, `uninstallPreview`)
  - [x] remove remaining temporary root proxy API where feature view models can call controllers directly
  - [x] `UninstallerView` / `RepairView` switched from root proxy state access to direct `FeatureController.state` reads

## Acceptance Criteria for Parity
- One-click Smart Scan with meaningful multi-module findings.
- Review/clean UX with safe defaults and confirmations.
- Stable performance on large home directories.
- Production packaging flow and permission recovery workflows.
