# DRay Network Module Progress

Last updated: 2026-05-19
Owner: Codex + Tumowuh
Scope: Performance -> Network workspace modernization (observability dashboard)

## Target

Bring the Network workspace closer to a full observability panel:
- live traffic rate (incoming/outgoing) with timeline
- adapter/context and data representation modes
- top hosts / top services / top programs tables
- connection counters (total, TCP/UDP, active apps)
- staged delivery with minimal regressions

## Phase Plan

1. Phase 1 (completed): core observability
   - [x] Define implementation plan and progress tracker
   - [x] Add live connection sampler (`nettop`) and aggregation models
   - [x] Extend live telemetry snapshot (packets/drops/totals/interface)
   - [x] Build new Network workspace layout (traffic + 3 tables)
   - [x] Hook refresh lifecycle and validate build/tests

2. Phase 2 (in progress): endpoint geolocation + map
   - [x] Remote endpoint enrichment pipeline
   - [x] Map rendering and route overlays
   - [x] Public IP/location summary + remote host sidebar
   - [x] Process/endpoint cross-filtering interactions

3. Phase 3 (in progress): advanced tools
   - [x] Public IP/ASN/location panel
   - [x] World latency probes
   - [x] TCP port scan panel
   - [x] Wake-on-LAN panel

## Product Backlog Notes (2026-05-08)

- [x] Refresh app icon set to new lightning/radar glass style reference.
- [x] Remove current "super arcs" style from map routes and replace with calmer route rendering.
- [x] Maximize clickability in Network UI (full-row hit areas, clear interactive affordances, larger tap targets).
- [x] Split Network into 3 dedicated sub-screens (matching reference direction): Overview / Live Map / Tools.
- [x] Keep all three Network sub-screens usable within one window via adaptive card layout (no horizontal overflow at standard app widths).
- [ ] Optional visual design pass in Figma/Canva style board for spacing/typography harmonization across Observability/Live Map/Tools.

## UI Audit (2026-05-12)

- [x] Full root-section visual pass captured from installed app (`/Applications/DRay.app`).
- [x] Performance -> Network detailed pass captured for all three sub-screens (`Overview`, `Live Map`, `Tools`).
- [x] Duplicate `Observability` subsection removed from Network segmented control.
- [x] RU/EN copy audit for Network completed (toolbar/cards/status strings localized consistently for Russian locale).
- [x] Compact-window pass (narrower than current desktop width): adaptive fallbacks added for dense rows/cards to reduce clipping and overflow.

## Progress Log

- 2026-05-08: started phase 1 implementation; analyzed current architecture and data sources (`LiveSystemMetricsMonitor`, `PerformanceView` network workspace, speed test service).
- 2026-05-08: added `NetworkConnectionsMonitor` with periodic `nettop` sampling and aggregations for top hosts/services/programs.
- 2026-05-08: expanded `LiveSystemSnapshot` network data: bytes/packets/drops rates, cumulative counters, primary active interface.
- 2026-05-08: replaced Network workspace UI with observability layout: control panel + live traffic chart + 3 ranking tables + speed-test summary strip.
- 2026-05-08: validation complete — `swift build` and `swift test` passed (87 tests).
- 2026-05-08: started Phase 2 integration — added `NetworkGeolocationMonitor` (public IP profile + endpoint geolocation cache, async resolution, unresolved tracking).
- 2026-05-08: wired geolocation lifecycle into `PerformanceView` and synchronized top-host feed with connection sampler snapshots.
- 2026-05-08: added map block to Network workspace (Apple MapKit): local hub marker (This Mac), remote endpoint markers, geodesic route overlays, adaptive summary panel.
- 2026-05-08: validation after Phase 2 integration — `swift build` and `swift test` passed (87 tests).
- 2026-05-08: app icon assets updated to lightning/radar glass style (`assets/icon.light.master.png`, `assets/icon.dark.master.png`, regenerated iconsets and `.icns` bundle files).
- 2026-05-08: Network workspace split into 3 sub-screens (Observability / Live Map / Tools) with segmented in-module navigation.
- 2026-05-08: replaced geodesic map routes with calmer direct polylines and added focus-aware emphasis for selected host routes.
- 2026-05-08: improved clickability baseline in Network UI (full-row buttons + selection highlight in host/service/program lists and map summary rows).
- 2026-05-09: implemented linked cross-filter graph (`host ↔ service ↔ program`) in network telemetry snapshot and applied it to list/map filtering.
- 2026-05-09: made live map markers clickable and bound them to host selection, so cross-filter now works bi-directionally (`list ↔ map`).
- 2026-05-12: implemented Network Tools surface with working modules for Public IP/ASN, world latency probes, TCP port scanning, and Wake-on-LAN actions.
- 2026-05-12: added `NetworkLatencyMonitor`, `NetworkPortScannerService`, and `WakeOnLANService` with runtime wiring in `PerformanceView`.
- 2026-05-12: fixed live map candidate feed by prioritizing geolocatable remote hosts and adding DNS hostname → IPv4 resolution in geolocation resolver.
- 2026-05-12: fixed geolocation provider outage path (`ipapi.co` paid/limited) by adding fallback providers (`ipinfo.io`, `api.ipify.org`) for public profile and endpoint lookup.
- 2026-05-12: reworked Network workspace adaptive composition so Observability / Live Map / Tools fit a single app window more reliably (responsive card widths, adaptive grids, compact toolbar fallback, speed-test metrics fallback grid).
- 2026-05-12: added `Unified` Network mode to keep Observability + Live Map + Tools in one continuous workspace; set it as default entry for Network tab and tuned Tools grid to stable 2-column/1-column fallback.
- 2026-05-12: removed duplicate Network subsection in UI by dropping `.observability` tab and keeping `Overview / Live Map / Tools` only.
- 2026-05-12: installed fresh local build `2.1.1 (22)` into `/Applications/DRay.app` and captured updated screenshots for root sections and Network sub-screens under `/tmp/dray-ui-audit-2026-05-12-refresh/`.
- 2026-05-12: fixed endpoint geolocation refresh churn in `NetworkGeolocationMonitor` (stop restarting same-host resolution on every sample; keep one in-flight task; mark task completion correctly), which unblocks Live Map population.
- 2026-05-12: updated Settings row scaffold to avoid text clipping in compact widths via horizontal-to-vertical fallback layout (`ViewThatFits`).
- 2026-05-12: completed Network RU localization sweep for remaining mixed English labels/messages in Observability / Live Map / Tools surfaces.
- 2026-05-12: reverted incorrect unified-Overview behavior — Network sub-navigation now maps 1:1 to separate screens (`Overview`, `Live Map`, `Tools`) while retaining adaptive in-screen layouts.
- 2026-05-12: applied focused visual/layout pass for all three Network sub-screens to reduce overflow risk and improve compact-window readability:
  - Observability: adaptive control/traffic split widths + reduced chart height + denser list card heights.
  - Live Map: tuned map/summary proportions and moved summary content to internal scroll container.
  - Tools: replaced brittle two-row HStacks with adaptive grid (`.adaptive(minimum: 360)`) and added compact fallbacks for Port Scanner / Wake-on-LAN field groups.
  - Recent speed-test rows now have horizontal/compact row fallback to avoid clipping on narrow widths.
- 2026-05-12: installed refreshed local build `2.1.1 (25)` into `/Applications/DRay.app` after visual pass.
- 2026-05-12: composition follow-up based on screenshot feedback:
  - removed oversized visual gap in `Overview` by moving connection KPI block out of the left control card into its own grid card and restoring taller traffic chart balance.
  - replaced `Tools` adaptive flow that produced orphan cards/holes with deterministic 2x2 composition (`Public IP | Latency`, `Wake-on-LAN | TCP scanner`) plus single-column fallback.
  - installed refreshed local build `2.1.1 (26)` into `/Applications/DRay.app`.
- 2026-05-12: cross-section layout cleanup for "holes" (empty vertical gaps) based on latest screenshots:
  - root `Overview`: replaced flat 3-card row with adaptive split layout (`recommendations + activity` stack next to `top consumers`), reduced forced card heights, capped consumer preview rows to reduce dead area.
  - `Performance -> Overview`: replaced two rigid HStack rows with adaptive 3-column board (independent vertical stacks) + single-column fallback; removed forced spacer/minHeight patterns that stretched short cards.
  - `Settings`: replaced row-height-coupled `LazyVGrid` with adaptive independent column stacks to eliminate inter-row voids when cards have different content heights.
  - installed refreshed local build `2.1.1 (27)` into `/Applications/DRay.app`.
- 2026-05-12: refreshed app icon from the latest square lightning/radar glass source (`local icon source image`), removed checkerboard export background into transparent alpha, regenerated both iconsets and all `.icns` bundles (`DRay`, `DRayLight`, `DRayDark`), and reinstalled `/Applications/DRay.app` with updated icon resources.
- 2026-05-12: icon theme pass refinement:
  - updated dark-theme icon source to `local dark icon source image`;
  - normalized transparency (checkerboard removal) and matched light/dark visual footprint to avoid size jump between inactive and active Dock icon states;
  - adjusted runtime app icon application to read from bundle file icon (`NSWorkspace.shared.icon(forFile:)`) before assigning `NSApp.applicationIconImage`, reducing active/inactive Dock size mismatch.
- 2026-05-12: icon sizing validation and Dock consistency pass:
  - removed temporary runtime Dock tile override (`NSApplication.applicationIconImage`) so running app uses same file-based icon path as inactive app;
  - reduced icon visual footprint to target `900/1024` canvas for both light and dark masters to align perceived size with neighboring Dock apps;
  - validated alpha-bounding boxes after regeneration: `DRayDark 862x861`, `DRayLight 857x852`, `VSCode 864x864` (close parity).
- 2026-05-12: compact-window hardening pass across core dashboards:
  - `Overview`: hero card now has horizontal + vertical fallback layouts; metric row now adapts `4-up -> 2x2 -> stacked`; reduced forced minimum widths in insights split.
  - `Performance -> Overview`: top metric row now adapts `4-up -> 2x2 -> stacked`; removed fixed min-height from Top Resource Consumers card to reduce empty vertical gaps.
  - `Performance -> Network`: removed fallback variant that could hide Traffic card on very narrow widths; reduced map summary forced height range; added third stacked fallback for speed-test metric summary.
  - `DRayBottomStatusStrip`: added adaptive `HStack -> adaptive grid` fallback to keep footer telemetry readable on narrow windows.
  - validation: `swift build` and `swift test` passed (87 tests); installed refreshed local build `2.1.1 (28)` into `/Applications/DRay.app`.
- 2026-05-12: settings-entry freeze mitigation + icon theme switching reliability:
  - moved Settings permission refresh calls to non-blocking async path (`refreshPermissionStatusAsync`) so entering `Settings` does not block main UI thread on filesystem probes;
  - kept action-time permission gating synchronous for safety-critical operations (delete/scan checks);
  - restored runtime Dock icon refresh on theme change and added `AppleInterfaceThemeChangedNotification` observer fallback for system appearance flips;
  - validation: `swift build` and `swift test` passed (87 tests); installed refreshed local build `2.1.1 (29)` into `/Applications/DRay.app`.
- 2026-05-13: follow-up fix after regression report ("theme/icon do not switch", "settings still freezes"):
  - replaced `Settings` board `ViewThatFits` with explicit width-driven single-branch composition (`3/2/1` columns) to avoid rendering all heavy layout variants at once;
  - switched root-level passive permission refreshes (`RootView` onAppear/scenePhase and folder-import callback) to async path to reduce UI-thread stalls outside action-time permission gates;
  - added `SystemAppearanceObserver` in app shell and bound `preferredColorScheme` to observed system theme when `App Appearance = System`, then re-applied Dock icon on effective scheme changes;
  - moved `LiveSystemMetricsMonitor` periodic process sampling (`ps`) into detached utility task to avoid main-thread stalls while switching sections (especially `Performance -> Settings`);
  - replaced shell-level theme forcing in app shell with explicit AppKit appearance controller (`NSApp.appearance` = `nil`/`aqua`/`darkAqua`) and added system-theme token refresh to force UI rebuild only in `System` mode;
  - reduced Settings first-render layout overhead by removing per-row `ViewThatFits` branching in favor of a single compact/non-compact row branch driven by one environment flag;
  - validation: `swift build` and `swift test` passed (87 tests); installed refreshed local build `2.1.1 (32)` into `/Applications/DRay.app`.
