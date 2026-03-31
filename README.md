# DRay

DRay is a macOS disk explorer that combines:
- Space visualization similar to Space Lens
- Fast file search similar to FindAnyFile

## Current status
- SwiftUI app shell with `Smart Care`, `My Clutter`, `Uninstaller`, `Space Lens`, and `Search` tabs
- Recursive disk scanner (`FileScanner`) with pause/cancel/progress
- SQLite snapshot index for fast restore between scans
- Advanced in-memory query engine (`QueryEngine`) with filters and presets
- Bubble-map drill-down navigation for folder hierarchy
- File actions: reveal in Finder, open, move to trash
- Recently deleted history with restore support
- Permissions flow with `Restore` for TCC resets
- Smart Care engine with cleanup analyzers and profile-based recommendations
- Initial Uninstaller with app and remnant discovery
- Performance diagnostics tab (startup entries + maintenance recommendations)
- Privacy diagnostics tab (trace review + explicit opt-in cleanup + transparency report)
- Release pipeline scripts (build/package/sign/notarize) + GitHub Actions release workflow
- Operation diagnostics log store with JSON export for support/debug workflows
- Dedicated Recovery tab for centralized restore of recently deleted items
- One-click unified Smart Scan orchestrating Smart Care + Privacy + Performance
- Menu bar popup window with live system health cards (CPU/RAM/Disk/Battery/Network) and quick actions
- Menu bar popup: interactive health diagnostics + top consumer list (CPU/MEM/Battery impact estimate)
- Popup quick actions: `Reduce CPU` / `Reduce Memory` (de-prioritize heavy processes without force-quit)
- Unified liquid-glass shell UI with minimal top navigation
- Menu bar-first lifecycle: closing/quitting main window keeps DRay background active; explicit quit is available in popup/menu
- Full runtime split: popup is rendered by dedicated `DRayMenuBarHelper` process, main `DRay` process only hosts app window/modules
- Battery diagnostics panel in popup (charge/health/cycles/temperature/power)
- Uninstaller app list with real application icons
- Smart Care analyzer-scope exclusions (enable/disable analyzers per scan)
- Smart Care analyzer telemetry (duration/items/bytes per analyzer)
- App Repair rollback sessions with item-level restore
- App Repair strategy presets (`Safe Reset` / `Deep Reset`) with risk labels
- Performance live load panel includes in-app process de-prioritization and priority rollback
- Performance live trends with 5m/15m averages and sparkline history
- Performance recommendations with one-click actions (select heavy startup items, open Smart Care, rerun diagnostics)
- Privacy quick actions (`Select Low Risk`, `Select Recommended`, `Quick Clean Safe`, `Quick Clean Recommended`)
- Smart Care quick action (`Quick Clean Recommended`)
- Space Lens node index build off main thread to reduce UI stalls on large scans
- Space Lens bubble overlap relaxation and smoother relayout animation
- Space Lens hover/selection sync hardening (including multi-select behavior in bubble view)
- Permission preflight guardrails for scan/delete/repair with unified remediation alert (`Grant Folder Access` / `Open Full Disk Access` / `Restore`)
- First-run permissions onboarding card with step-by-step access setup and status refresh
- Crash telemetry baseline (detects unclean previous shutdown and stores crash events log)
- Menu popup includes `Start at Login` toggle (LaunchAgent-based menu-bar startup)
- Dedicated helper executable `DRayMenuBarHelper` for LaunchAgent startup handoff

## Run
```bash
swift run
```

## Smoke Test
```bash
./scripts/ui_smoke.sh
```
Checks: `standard startup`, `open-section launch`, `helper startup`, `helper -> main bootstrap`, `quit -> helper handoff`.

## Crash Symbolication
```bash
./scripts/symbolicate_crash.sh <path-to-crash-report> [path-to-DRay.dSYM]
```

## Public TODO
- [x] Smart Care foundation (multi-analyzer scan + safe clean to Trash)
- [x] Smart Care risk labels and recommendation reasons
- [x] Smart Care profiles (`Conservative` / `Balanced` / `Aggressive`)
- [x] Space Lens drill-down and in-view bulk actions
- [x] Search presets and multi-delete flow
- [x] Install script to `/Applications/DRay.app`
- [x] Incremental index updates (delta scan, not full tree pass)
- [x] Search Pro filters (regex/date/depth/type)
- [x] Search Pro owner filter
- [x] Smart Care: confidence scoring and explainability per item
- [x] Uninstaller: mandatory residue sweep (`~/Library`, `/Library`, login items, launch agents, helpers)
- [x] Uninstaller: validation report (`removed / skipped / failed`)
- [x] My Clutter baseline (exact duplicates scan + selective delete to Trash)
- [x] Performance module baseline (startup diagnostics + maintenance recommendations)
- [x] Privacy/Security module baseline (trace review + safe cleanup + transparency report)
- [x] Signed + notarized production build pipeline baseline
- [x] Space Lens UI/UX rework (visual quality + selection responsiveness + fix false blue highlight on `Library`)
- [x] Menu bar popup baseline (top-bar quick actions + health mini panel)
- [x] Menu bar popup visual parity with CleanMyMac cards
- [x] Menu bar popup live metrics polling + adaptive light/dark theme
- [x] Light/Dark icon variants for install builds (`DRayLight.icns` / `DRayDark.icns`)
- [x] Popup-to-app navigation (card actions open corresponding DRay module)
- [x] Smart Care analyzer exclusions (per-analyzer scan scope toggles)
- [x] Smart Care analyzer telemetry and scan-cost visibility
- [x] Smart Care critical-folder quick exclusions (Desktop/Documents/Downloads/iCloud Drive)
- [x] App Repair baseline with rollback sessions
- [x] App Repair strategy presets with explicit risk hints
- [x] Main-app quit -> helper runtime transition
- [x] Performance live load actions (`Reduce CPU`, `Reduce Memory`, `Restore Priorities`)
- [x] Performance sustained-load trends (5m/15m windows + sparkline)
- [x] Space Lens async node-index build for smoother selection/actions panel
- [x] Space Lens overlap relaxation + smoother bubble relayout animation
- [x] Space Lens hover/selection hardening + multi-select in bubble map
- [x] Permissions preflight for scan/delete/repair + global remediation alert
- [x] First-run permissions onboarding (Folder Access + Full Disk Access guided flow)
- [x] Crash telemetry baseline + crash log reveal action
- [x] Space Lens interaction/perf polish pass (animation smoothness + overlap stability + selection clarity)
- [x] UI smoke test baseline (`scripts/ui_smoke.sh`)
- [x] Menu-bar launch-at-login control in popup (`Start at Login`)
- [x] Dedicated helper target for menu-bar startup handoff (`DRayMenuBarHelper`)
- [x] Full popup-process decoupling (popup UI in helper app, independent from DRay executable)
- [x] Crash symbolication workflow (`scripts/symbolicate_crash.sh`)
- [x] Runtime split smoke hardening (`helper bootstrap`, `quit handoff`)
- [x] Performance live-load cards in one-row layout
- [x] Performance battery trend card (`Load Trends` with 5m/15m windows)
- [x] Unified module header style (`Smart Care` / `My Clutter` / `Uninstaller` / `Space Lens` / `Performance`)
- [x] `App Repair` visual alignment with `Uninstaller` patterns
- [x] Popup battery diagnostics expansion (history windows `5m/15m/30m/1h/2h`, trend rate, ETA)
- [x] `App Repair` strategy safety UX (Deep Reset confirmation + risk/size preview)
- [x] Full visual parity pass across all primary modules
- [x] `1.0.0-alpha` local pre-release packaging (`dmg` + `zip`) with smoke/regression pass
- [x] `1.0.0-alpha` GitHub pre-release publication (upload `dmg` + `zip`)
- [x] Performance recommendation CTAs with direct actions
- [x] Privacy quick-clean workflows with risk-based selection
- [x] Smart Care quick-clean recommended flow
- [ ] Post-action delta report for quick-action flows (`before/after` reclaim)
- [ ] `1.0.1-alpha` pre-release (`dmg` + `zip`)

## Done (Recent)
- [x] Added Smart Care advanced cleanup flow (scan/review/clean) — commit `f267cda`
- [x] Added Smart Care risk labels, recommendations, and safeguards — commit `61ff069`
- [x] Added profiles, recommendation reasons, and initial Uninstaller module — commit `8946dfb`
- [x] Added mandatory residue sweep requirement to roadmap — commit `b39f9be`
