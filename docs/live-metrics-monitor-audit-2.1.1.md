# DRay 2.1.1 Live Metrics Monitor Audit

Date: 2026-05-08

## Scope

All `LiveSystemMetricsMonitor` instantiations in main app and menu bar helper.

## Inventory

| File | Owner / surface | Update interval | Heavy sample period | Start trigger | Stop trigger | Consumer sampling | Hidden behavior | Process | Verdict |
|---|---|---:|---:|---|---|---|---|---|---|
| `DRay/Features/Overview/OverviewView.swift` | `OverviewView` dashboard | `1.2s` | `5.0s` | `.onAppear { monitor.start() }` | `.onDisappear { monitor.stop() }` | Enabled (monitor default) | Does not run when section hidden | Main app | Acceptable |
| `DRay/Features/Performance/PerformanceView.swift` | `PerformanceView` diagnostics | `1.0s` (default) | `4.0s` (default) | `.onAppear { monitor.start() }` | `.onDisappear { monitor.stop() }` | Enabled (monitor default) | Does not run when section hidden | Main app | Acceptable |
| `DRayMenuBarHelper/MenuBarHelperApp.swift` + `DRayMenuBarHelper/MenuBarPopupView.swift` | Menu bar helper status + popup | `1.0s` | `4.0s` | Helper app init starts monitor | Helper app termination | Disabled by default in helper init, enabled only while popup visible via `setConsumerSamplingEnabled(true)` in popup `.onAppear`, disabled in `.onDisappear` | Background keeps light snapshot refresh; heavy consumer sampling off while popup hidden | Helper process | Acceptable |

## Duplication assessment

- Main app and helper run in separate processes and serve different visible surfaces; duplication is expected and acceptable.
- In main app, only the currently routed section owns an active monitor.
- In helper, consumer sampling is explicitly suppressed while popup is hidden; no change required.

## Changes made after audit

- No lifecycle code changes required.
- Existing behavior already satisfies hidden heavy-sampling constraint and start/stop discipline.
