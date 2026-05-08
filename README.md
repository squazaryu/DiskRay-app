# DRay

DRay — macOS utility suite for storage cleanup and maintenance with a live Overview dashboard, Space Lens navigation, deep file search, safe cleanup flows, and a realtime menu-bar assistant.

## Why DRay
- Visual disk exploration like Space Lens (bubble map drill-down).
- Live Overview dashboard for health, storage, memory, battery, CPU, recommendations, and recent activity.
- Fast search and bulk actions for files/folders.
- Smart cleanup recommendations with risk/confidence hints.
- Uninstaller with remnant verification, Remaining cleanup, Deep Sweep, and rollback-aware history.
- Live system telemetry in popup: CPU, RAM, battery, network, startup impact.
- UI appearance controls: app theme, accent color, and adaptive/compact density.

## Core Modules

| Module | Purpose | Key actions |
|---|---|---|
| `Overview` | Live system health and action dashboard | Health score, metric tiles, recommendations, top consumers, quick navigation |
| `Smart Care` | Unified cleanup scan with analyzers and profiles | Scan, select recommended, quick clean, confidence/risk review |
| `My Clutter` | Duplicate detection and selective cleanup | Grouped duplicates, keep marker, move selected to Trash |
| `Uninstaller` | App removal with leftover discovery and remaining cleanup | Remove app, inspect remnants, verify, Deep Sweep, clean remaining artifacts |
| `App Repair` | Safe reset/repair of app artifacts | Strategy presets, risk labels, rollback session |
| `Space Lens` | Visual storage map with folder drill-down | Bubble navigation, open/reveal/trash, multi-select |
| `Search` | Advanced file search (live mode) | Filters, presets, bulk actions, reveal/open/trash |
| `Performance` | Startup + live load diagnostics | Run diagnostics, top consumers, reduce CPU/memory pressure |
| `Privacy` | Trace review and cleanup | Risk-based selection, transparency-oriented actions |
| `Recovery` | Restore history for DRay-managed deletions | Restore from Trash, review deleted history |
| `Settings` | Runtime, appearance, scanning, and permissions controls | Language, theme, accent, density, autostart, permission status |

## Menu Bar Helper
`DRayMenuBarHelper` runs popup telemetry and quick actions independently from the main window lifecycle.

- DRay icon + compact battery state in the menu bar, with realtime refresh.
- Compact health hero, metric tiles, sparklines, top consumers, and quick actions open relevant DRay modules.
- Battery details panel (charge/health/cycles/temp/power/ETA).
- Refresh discipline: heavy sampling is reduced while popup is hidden; battery details auto-refresh runs only while its sheet is open.
- Explicit `Quit Completely` path for full exit.

## Architecture (high-level)
- `DRay` (main app): module UI + scan/index/cleanup engines.
- `DRayMenuBarHelper`: popup UI, lightweight telemetry polling, app bootstrap handoff.
- Shared services: scanner/query engines, permission checks, operation logs, rollback metadata.

## Permissions and Platform Limits
DRay works with macOS security model and does **not** bypass SIP/TCC.

For full functionality, grant:
- Folder access for selected scan targets.
- Full Disk Access for system-level coverage.

Some protected/system paths may remain non-removable by design. DRay reports skipped items explicitly.

## Run (dev)
```bash
swift run
```

## Build and Install to `/Applications`
```bash
./scripts/install_app.sh 2.1.1 1
```

## Package Release Artifacts (`zip` + `dmg`)
```bash
./scripts/package_release.sh 2.1.1 1
```
Artifacts are created in `dist`.

## Smoke Check
```bash
./scripts/ui_smoke.sh
```

## PII Scan (pre-release)
```bash
./scripts/pii_scan.sh
```
The script scans tracked text files for personal absolute paths and email-like strings.

Optional:
- skip in packaging: `SKIP_PII_SCAN=1 ./scripts/package_release.sh 2.1.1 1`
- allowlist file: `.pii-allowlist` (one literal token per line, `#` for comments)

## Crash Symbolication
```bash
./scripts/symbolicate_crash.sh <path-to-crash-report> [path-to-DRay.dSYM]
```

## Release Notes and Roadmap
- Release process: `docs/RELEASE.md`
- Roadmap: `docs/ROADMAP.md`
- Past notes: `docs/releases`
- Agent guide: `AGENTS.md`
- Architecture 2X: `docs/ARCHITECTURE_2X.md`
- Performance workspace model: `docs/PERFORMANCE_WORKSPACE.md`
- Settings model: `docs/SETTINGS_MODEL.md`

## Current Channel
`v2.1.1 (build 1)` is the active release channel with DRay-first menu bar identity, shared popup structure parity in light/dark themes, adaptive sidebar modes, tighter live-monitor lifecycle audit coverage, and Search/Uninstaller deletion-flow hardening with explicit SIP/TCC-safe behavior.
