# DRay Stability / Predictability Task

Date: 2026-05-20
Owner: Codex
Scope: Force Remove / Uninstaller transparency, shared path safety, bounded command execution, focused tests, regex validation.

## Constraints
- Do not remove Force Remove, elevated deletion, admin removal, or advanced deletion paths.
- Do not weaken App Store-managed app removal capability when advanced/high-risk mode is enabled.
- Respect high-risk / advanced Settings as explicit user consent for advanced operations.
- Avoid broad architecture rewrites and unnecessary file splitting.
- Do not touch `.codex-pets/`.
- Tests must not perform real destructive, admin, or network operations.

## Plan
- [x] Audit current Uninstaller, SafeFileOperation, Search, Smart Care, Network command paths.
- [x] Task 1: preserve removal fallback chain and expose removal method / verification details in model, report, UI, and tests.
- [x] Task 2: add shared PathSafetyPolicy and wire key modules through it without reducing capability.
- [x] Task 3: add injectable SystemCommandRunner with timeout/cancellation and migrate key command paths.
- [x] Task 4: add focused tests for path policy, network parsers, port scanner, latency parsing, uninstaller fallback/unresolved behavior.
- [x] Task 5: make invalid regex in Live Search a validation error instead of substring fallback.
- [x] Task 6/P2: applied stable CleanupItem/CleanupCategoryResult IDs, Full Disk Access diagnostic probes, and persisted Network workspace preferences.
- [x] Run `swift build`.
- [x] Run `swift test`.
- [x] Update this file with results, changed files, tests, risks, and next steps.

## Findings
- Uninstaller already had fallback chain: FileManager trash, Finder recycle, admin move to Trash, admin hard remove. The result model only reported generic `.removed`, so UI/report could not distinguish the method.
- `experimentalElevatedDeletionEnabled` existed in root/controller state, but `AppUninstallerService` did not receive it when deciding the admin hard-remove fallback.
- Remaining already received verify leftovers through `UninstallRemainingUseCase.upsert`, but failed app bundle/action paths could be lost when not returned by remnant scanning.
- `SystemPathProtection` was narrow and duplicated by `SmartScanService.protectedPathPrefixes`, which was broader and local to Smart Care cleanup.
- Network `nettop`, `ping`, `nc`, and Live Search `mdfind` used direct `Process` calls without shared timeout/cancellation handling.
- Live Search compiled invalid regex with `try?`; invalid regex silently fell back to substring matching.

## Done
- Added `PathSafetyPolicy` with classification and operation disposition for protected system paths, admin-sensitive paths, user data, cache-safe paths, app bundles, remnants, and unknown paths.
- Wired `SystemPathProtection` and Smart Care cleanup through the shared path policy.
- Added `SystemCommandRunner` with executable path, arguments, timeout, stdout/stderr, exit code, timeout flag, cancellation flag, and process termination on timeout/cancel.
- Migrated `NetworkConnectionsMonitor` (`nettop`), `NetworkLatencyProbeService` (`ping`), `NetworkPortScannerService` (`nc`), and `LiveSearchService` (`mdfind`) to the shared runner.
- Removed double timer registration in `NetworkConnectionsMonitor` by switching from `scheduledTimer` plus manual add to a single `Timer(timeInterval:)` registration.
- Added `UninstallRemovalMethod` and populated standard trash, Finder recycle, admin trash, force-admin remove, skipped, missing, and failed paths.
- Threaded `experimentalElevatedDeletionEnabled` into Uninstaller execution so admin hard-remove is gated by high-risk mode while standard/admin trash fallbacks remain available.
- Added injected App Uninstaller operations for non-destructive fallback tests.
- Expanded post-uninstall verification so unresolved selected/action paths that still exist are added to `UninstallVerifyReport.remaining`, which feeds Remaining cleanup records.
- Updated Uninstaller UI report rows to show the removal method.
- Changed Live Search invalid regex behavior to a validation error and displayed a localized UI message instead of returning substring fallback results.
- Added stable IDs for `CleanupItem` and `CleanupCategoryResult` to reduce selection/diffing resets after rescans.
- Added Full Disk Access diagnostic reporting with explicit probe paths, readable/denied/missing state, and `likelyGranted` / `likelyMissing` / `partial` / `unknown` status while preserving the existing boolean permission flow.
- Displayed Full Disk Access diagnostics in Settings so users can see which protected locations were checked instead of only a coarse true/false result.
- Persisted Network workspace preferences: Resolve locations toggle, data representation, and last port scanner host/start/end values.
- Fixed `DRayMenuBarHelper` startup crash caused by reading `NSApp.effectiveAppearance` before `NSApplication` was initialized; the helper now uses a safe appearance fallback and keeps the menu bar icon alive after app launch.
- Preserved the prior menu-bar helper icon theme fix in the working tree; `.codex-pets/` was not touched.

## Changed Files
- `DRay/Core/System/PathSafetyPolicy.swift`
- `DRay/Core/System/SystemCommandRunner.swift`
- `DRay/Core/System/SystemPathProtection.swift`
- `DRay/Core/Cleanup/SmartScanService.swift`
- `DRay/Core/Query/LiveSearchService.swift`
- `DRay/Core/Telemetry/NetworkConnectionsMonitor.swift`
- `DRay/Core/Telemetry/NetworkLatencyMonitor.swift`
- `DRay/Core/Telemetry/NetworkPortScannerService.swift`
- `DRay/Core/Uninstaller/AppUninstallerService.swift`
- `DRay/Core/Uninstaller/UninstallerModels.swift`
- `DRay/Features/Search/SearchFeatureController.swift`
- `DRay/Features/Search/SearchView.swift`
- `DRay/App/AppPermissionService.swift`
- `DRay/Features/Performance/PerformanceView.swift`
- `DRay/Features/Settings/SettingsView+PermissionsSection.swift`
- `DRay/Features/Uninstaller/UninstallPlanningUseCase.swift`
- `DRay/Features/Uninstaller/UninstallerFeatureController.swift`
- `DRay/Features/Uninstaller/UninstallerUseCase.swift`
- `DRay/Features/Uninstaller/UninstallerView.swift`
- `DRayMenuBarHelper/HelperServices.swift`
- `Tests/AppPermissionServiceDiagnosticsTests.swift`
- `Tests/AppUninstallerServiceFallbackTests.swift`
- `Tests/LiveSearchRegexTests.swift`
- `Tests/NetworkConnectionsMonitorParserTests.swift`
- `Tests/NetworkLatencyProbeServiceTests.swift`
- `Tests/NetworkPortScannerServiceTests.swift`
- `Tests/PathSafetyPolicyTests.swift`
- Existing test stubs updated for the new Uninstaller protocol signature.
- `SmartCareUseCaseTests`: stable cleanup item/category IDs for rescan diffing.

## Tests Added / Updated
- `PathSafetyPolicyTests`: protected paths, `/Applications/*.app`, user caches, LaunchDaemons, PrivilegedHelperTools.
- `NetworkConnectionsMonitorParserTests`: tcp4, udp4, listen ignored, local/reserved IP geolocation priority, program normalization.
- `NetworkLatencyProbeServiceTests`: packet loss, average latency, failed ping output with fake runner.
- `NetworkPortScannerServiceTests`: invalid host, invalid range, fake open port runner.
- `LiveSearchRegexTests`: invalid regex error, valid regex still matches, controller message/no fallback.
- `AppUninstallerServiceFallbackTests`: standard trash, admin trash fallback, force remove gated by high-risk mode, unresolved app bundle preserved for Remaining/report.
- `AppPermissionServiceDiagnosticsTests`: likely granted, likely missing, partial, and unknown Full Disk Access diagnostic states with fake probes.
- Updated existing Uninstaller/Repair stubs for `allowForceRemove`.

## Verification
- `swift build` passed.
- `swift test` passed: 115 tests.
- Installed local app bundle to `/Applications/DRay.app` as `2.1.3 (1)`.
- Verified installed bundle metadata: `CFBundleShortVersionString=2.1.3`, `CFBundleVersion=1`, helper executable present.
- `spctl --assess --type execute --verbose /Applications/DRay.app` accepted in the current local signing environment.
- Relaunched `/Applications/DRay.app` and verified both runtime processes are alive: `DRay` and `DRayMenuBarHelper --app-path /Applications/DRay.app`.
- Prepared release docs for `2.1.3 (1)` and packaged release artifacts with `./scripts/package_release.sh 2.1.3 1`.
- Release artifact SHA256:
  - `70e5d6cbd1ead462e9ed639f1510d3f63b35fdaaa4c371b9f221e75b9479314d  DRay-2.1.3.zip`
  - `d68170b63de42ffda268be7201f31424378b1543a7ccd8038246bb1ca6577b85  DRay-2.1.3.dmg`

## Risks / Follow-up
- AppUninstallerService still uses direct `osascript` for admin authorization because changing that flow to async command execution would touch the macOS authorization prompt behavior. It is injectable and covered by fake operations in tests; migrating it to `SystemCommandRunner` can be done as a narrow follow-up.
- Existing Swift Testing deprecation warnings remain because `Package.swift` still depends on `swift-testing`; not changed in this task.
- No P2 items from the original scoped list remain open.

---

# DRay 2.2.0 UI Refactor

Date: 2026-05-21
Branch: 2.2.0-ui-refactor
Scope: Calm Liquid Glass visual refactor for main app and menu bar helper without reducing functionality.
Brief: /Users/tumowuh/Downloads/DRay_Calm_Liquid_Glass_Redesign_Prompt.md

## Goal
Calm Liquid Glass redesign without reducing functionality, diagnostics, removal power, or operational clarity.

## Constraints
- Do not remove Force Remove.
- Do not weaken App Store app deletion.
- Do not remove Search filters.
- Do not remove Network tools.
- Do not remove Full Disk Access diagnostics.
- Do not hide risk/status/removal details.
- Do not hide high-risk controls.
- Do not remove Remaining cleanup details.
- Do not rewrite business logic unless required to support presentation state.
- Avoid unnecessary file splitting.
- Do not add external dependencies.
- Do not change app version.
- Do not create release/tag.
- Do not push branch unless explicitly requested.
- Keep codex-pets out of this branch.

## Phases
- [x] Baseline build/test
- [x] Visual helper audit
- [x] Design tokens / calm surface system
- [x] Shared components pass
- [x] Overview redesign
- [x] Smart Care redesign
- [x] Search redesign
- [x] Uninstaller / Remaining redesign
- [x] Performance redesign
- [x] Network redesign
- [x] Settings redesign
- [x] Menu bar helper redesign
- [ ] Light/dark/compact manual review
- [x] Final build/test

## Visual Guardrails
- Nested cards are mostly flat or near-flat.
- Heavy blur is limited to major surfaces.
- Primary buttons are not overused.
- Secondary actions are visually quieter.
- Semantic colors remain for errors, warnings, destructive actions, high-risk states, success states, and scan/cleanup progress.
- Text contrast must remain readable in light and dark mode.
- Search filters remain quickly accessible.
- Network tools remain visible and usable.
- Uninstaller removal methods, risk, failure reasons, and remediation hints remain explicit.
- Menu bar popover should be calmer and compact, not taller or more decorative without layout need.

## Visual Audit Notes
- `DRay/App/GlassTheme.swift` is the current shared visual layer: `glassSurface`, `ModuleHeaderCard`, sidebar rows, progress bars, metric tiles, bottom strip, pills, and action rows.
- `DRay/App/DRayInfographics.swift` owns shared icon badges, sparkline, donut chart, dashboard tiles, ranked rows, and activity rows.
- Main modules depend heavily on shared helpers: Overview, Smart Care, Search, Uninstaller/Remaining, Performance, Settings, Privacy, Clutter, Repair, Recovery, and Space Lens.
- Menu bar UI is separate target code in `DRayMenuBarHelper/MenuBarPopupView.swift`, `MenuBarPopupCards.swift`, `MenuBarPopupOverlays.swift`, `MenuBarStatusIcon.swift`, and `BatteryDetailsSheetView.swift`; it cannot reuse DRay target types directly.
- Heaviest visual noise before changes: saturated app background accents, high shadow radii in `glassSurface`, nested `.regularMaterial` surfaces, bright circular icon badges, blue/cyan status rings, and prominent color on secondary actions.

## Visual Audit Agent Findings
- Current visual issues:
  - Saturated blue/cyan still defined the product feel through default accents, selected states, primary controls, rings, progress bars, and menu bar tints.
  - Glass remained too layered: shell gradients, radial washes, surface overlays, highlight strokes, borders, and shadows were stacking across most screens.
  - Color semantics were overused as decoration: many cards had colored icons, pills, bars, sparklines, or donut segments even when the color did not communicate risk/status.
  - Secondary buttons still read too loud because default `.bordered` / `.borderedProminent` controls appeared in dense toolbars and action centers.
  - Network and menu bar still looked like glossy dashboards rather than calm professional utility surfaces.
- Components that still look too loud:
  - `GlassSurfaceModifier`, `GlassShellBackground`, `DRayLiquidStatusRing`, `DRayProgressBar`, `DRayIconBadge`, `DRayDashboardMetricTile`, `DRayCompactInfoTile`, `GlassPillBadge`, `StatusChip`, `DRaySparklineView`, `DRayDonutChartView`.
  - Menu bar local surfaces: `MenuBarPopupView.shellBackground`, `MenuBarPopupView.cardBackground`, `MenuBarMetricTileCard`, `MenuBarMiniRing`, `MenuBarCompactRowSurface`.
- Screens requiring real redesign:
  - Overview: dominant ring, metric cards, progress bars, top consumers, and activity cards still read dashboard-first.
  - Smart Care: hero ring, donut, badges, segmented tabs, and full-width primary action competed for attention.
  - Search: focused input, prominent Search button, bright mode segment, colored status tiles, and empty-state panel looked like a blue control panel.
  - Uninstaller / Remaining: structure was workable, but toolbar/action hierarchy, blue tabs, multiple pills, and destructive actions were visually loud.
  - Performance: too many equal-weight cards/charts and a bright diagnostics CTA.
  - Network: map/chart/control-card stack remained too neon; endpoints, polylines, traffic chart, and speed-test CTA needed muting.
  - Settings: improved but still too card-heavy and colorful for a System Settings-like surface.
  - Menu Bar: shell, hero, metrics, consumers, recommendation, quick actions, and telemetry competed inside a blue/glossy panel.
- What must visibly change in this pass:
  - Reduce blue/cyan saturation globally; reserve stronger color for one primary action and real semantic state.
  - Flatten nested glass by reducing material layering, glossy overlays, highlight strokes, and shadows.
  - Enforce one primary CTA per section; make secondary actions neutral.
  - Quiet large rings/donuts, charts, badges, and selected states.
  - Make Network map/list tooling calmer and less neon.
  - Make menu bar popover a compact utility panel with muted metrics and quiet footer telemetry.

## Design System Agent Plan
- Existing visual foundation found in:
  - `DRay/App/GlassTheme.swift`: `DRaySurfaceLevel`, `DRayCalmGlassModifier`, `.calmGlass(...)`, `DRaySemanticTone`, `DRayQuietIconBadge`, primary/secondary/danger button styles, `glassSurface`, `ModuleHeaderCard`, sidebar rows, metric tiles, pills, and action rows.
  - `DRay/App/DRayInfographics.swift`: `DRayIconBadge`, dashboard tiles, ranked rows, sparklines, donut charts.
  - `DRayMenuBarHelper/MenuBarPopupView.swift` and `DRayMenuBarHelper/MenuBarPopupCards.swift`: separate helper visual system that must be reduced locally.
- Shared helpers to change:
  - Make `DRayCalmGlassModifier` / surface levels the real visual source of truth and reduce `glassSurface` defaults.
  - Reduce `GlassShellBackground` radial blue/cyan/indigo washes.
  - Quiet `DRayIconBadge`, `DRayQuietIconBadge`, `GlassPillBadge`, progress bars, rings, sparklines, and donuts.
  - Move settings section cards to calm section surfaces instead of parameterized heavy glass.
  - Reduce menu bar shell/card/row surfaces in the helper target.
- New/updated tokens:
  - Keep `DRaySurfaceLevel`, but tune `panelShell`, `moduleHeader`, `section`, `card`, and `nestedCard` so nested surfaces are mostly flat.
  - Keep `DRaySemanticTone`, but use tones as semantic signals instead of decorative variety.
  - Keep button hierarchy: primary for one main action, neutral secondary, calm danger.
- Components affected globally:
  - `ModuleHeaderCard`, `DRayMetricTile`, `DRayBottomStatusStrip`, `DRayCompactInfoTile`, `DRayActionRow`, `GlassPillBadge`, `DRayIconBadge`, `DRayDashboardMetricTile`, `DRayProgressBar`, `DRaySparklineView`, `DRayDonutChartView`, settings section cards, performance `StatusChip`, and menu bar cards/rows.

## Design System Changes
- Added `DRaySurfaceLevel` for calm surface hierarchy.
- Added `DRaySemanticTone` and `DRayQuietIconBadge` for softer semantic badges.
- Added `DRayCalmGlassModifier` and `.calmGlass(...)` while preserving existing `glassSurface(...)` API.
- Calmed app background, `glassSurface` fills, borders, shadows, module header surface, sidebar selected state, progress bars, status ring, pills, compact tiles, and minimal button style.
- Added `DRayPrimaryButtonStyle`, `DRaySecondaryButtonStyle`, and `DRayDangerButtonStyle` for module-level adoption.
- Calmed shared infographics: icon badges, sparklines, and donut chart segments.

## Main App Modules Updated
- Overview uses the calmer shared hero, metric, action-row, sparkline, progress, and nested-card styling while keeping health calculation, recommendations, and bottom telemetry intact.
- Smart Care keeps the scan/clean flow, category cards, progress banners, risk labels, exclusions, analyzer telemetry, and primary CTA while nested cards/actions now use near-flat calm surfaces.
- Search keeps scope controls, filters, presets, regex validation, table/tree/grid results, selection menus, and bulk actions; selected rows now use subtle accent tint plus a left accent bar instead of saturated blocks.
- Uninstaller/Remaining keeps removal methods, risk labels, failure reasons, Force Remove/high-risk flows, Remaining cleanup, daemon/helper guidance, and reports; selected app/remaining actions now use calm selected states and danger styling for destructive cleanup.
- Performance keeps live metrics, diagnostics, battery, startup, relief actions, and charts; helper cards/chips/bars are calmer and nested rows are flatter.
- Network keeps traffic charts, live map, public IP, latency, port scanner, WOL, speed test history, focus filters, and persisted preferences; map lines/selection states and technical cards are less saturated.
- Settings keeps permissions, Full Disk Access diagnostics, high-risk settings, appearance, scanning defaults, diagnostics, and recovery controls; section icons and nested rows are calmer.

## Main App Module Refactor Agent Report

### Module: Overview
Changed:
- Replaced prominent bordered secondary hero actions with explicit calm primary/secondary hierarchy.
- Moved hero, recommendations, top consumers, and activity panels to `calmGlass` section/card surfaces.
- Reduced bright status color usage in activity rows, health color, bottom telemetry, and icon backgrounds.

Preserved:
- System health score, storage/memory/battery/CPU cards, health explanation, recommendations, top consumers, activity shortcuts, and bottom telemetry.

Visual delta:
- Overview reads less like a glossy blue dashboard; major surfaces are calmer and secondary actions no longer compete with Smart Scan.

### Module: Smart Care
Changed:
- Replaced heavy category/exclusion/action-center cards with calm section/card surfaces.
- Muted SMART CARE label, profile/selected pills, onboarding icon, category container surfaces, and action row icon tints.
- Reworked the main Smart Care action into a single muted primary action instead of a detached bright blue block.

Preserved:
- Smart Scan, Clean Recommended/Clean Selected flow, category cards, progress/status banners, exclusions, risk labels, recommendations, analyzer telemetry, and cleanup gating.

Visual delta:
- Smart Care is less gamified/glossy while keeping the maintenance flow obvious and actionable.

### Module: Search
Changed:
- Search toolbar, filter panel, query workspace, and actions cards now use calm section/card surfaces.
- Search remains the primary CTA while stop/save/reveal/select/tree actions use neutral secondary styling.
- Table/tree headers and tree root selection states use flatter low-opacity fills.

Preserved:
- Scope selection, query input, fast/deep mode, filters, presets, regex validation, result views, selection menus, bulk actions, and destructive Trash Selected action.

Visual delta:
- Search remains dense and power-user oriented, but controls no longer look like a saturated blue command panel.

### Module: Uninstaller / Remaining
Changed:
- Uninstaller action toolbar now uses a calm section surface.
- Destructive uninstall/clear-list actions use the calm danger button style instead of generic prominent blue/neutral buttons.

Preserved:
- Applications, rollback, Remaining cleanup, removal method reporting, failure reasons, risk/status badges, Force Remove/high-risk flows, daemon/helper guidance, and cleanup reports.

Visual delta:
- Operational controls read more clearly as destructive/admin actions without making the whole Uninstaller workspace visually louder.

### Module: Performance
Changed:
- Diagnostics CTA uses the primary button hierarchy; export/reveal actions are neutral secondary actions.
- Workspace segmented navigation and scan-running status use calmer surfaces.
- Performance infographics were already muted through the shared component pass.

Preserved:
- CPU, memory, battery, startup, process metrics, charts, diagnostics, export/reveal actions, and relief actions.

Visual delta:
- Performance keeps live diagnostic density but loses the previous glossy dashboard emphasis.

### Module: Network
Changed:
- Speed Test remains the primary action, while network chart colors, map polylines, local marker, endpoint tints, donut segments, and incoming-rate labels are less saturated.
- Traffic chart fill/line opacity and map line weight were reduced for a more technical, less neon appearance.

Preserved:
- Public IP, live map, traffic charts, host/program/service lists, latency, port scanner, Wake-on-LAN, speed test history, filters, and persisted preferences.

Visual delta:
- Network tools remain visible and usable, but the map/chart area no longer dominates as a neon visualization.

### Module: Settings
Changed:
- Settings section scaffolding moved from heavy colored glass cards to calmer section surfaces during the shared pass.
- Section icons and nested rows are visually quieter while keeping the adaptive board stability fix.

Preserved:
- Permissions, Full Disk Access diagnostics, appearance/density/sidebar controls, high-risk settings, scanning defaults, diagnostics, recovery/safety controls, and reset actions.

Visual delta:
- Settings is closer to a grouped macOS System Settings surface without hiding risk or permission details.

## Menu Bar Changes
- Calmed the menu bar shell background by reducing cyan/indigo wash, border contrast, and shadow strength while keeping the existing compact `430` point width.
- Calmed menu bar hero, top-consumers, recommendation, quick-actions, and telemetry surfaces with lower accent opacity and flatter nested rows.
- Kept Smart Scan as the only prominent menu bar CTA; the duplicate Smart Scan quick action remains visible but uses secondary styling to avoid competing primary buttons.
- Reduced menu bar health ring, metric icon badge, sparkline, progress bar, and row-accent saturation.
- Kept Storage, Memory, Battery, CPU, Top Consumers, Recommendation, Quick Actions, Telemetry, Open DRay, More, and Quit Completely available.

## Menu Bar Visual Refactor
Changed:
- Removed the remaining cyan/indigo radial wash from the popover shell and reduced border/shadow strength.
- Changed menu bar cards from glossy regular-material surfaces to quieter thin-material cards with lower accent overlays.
- Replaced bright metric tints with calmer storage, memory, battery, CPU, diagnostic, telemetry, and danger tones.
- Flattened metric badges, progress bars, sparklines, compact rows, and nested surfaces.
- Reworked Top Consumers from stacked glossy mini cards into compact diagnostic rows with a small vertical load marker and muted values.
- Made Open DRay, More, metric actions, and regular utility actions neutral secondary controls.
- Changed Quit Completely from a loud destructive role button into a calm danger-tinted secondary action.

Preserved:
- Mac Health, Smart Scan, Storage, Memory, Battery, CPU, Top Consumers, Recommendation, Quick Actions, Telemetry, Open DRay, More, and Quit Completely.
- Existing compact popover width and layout structure.
- Menu bar helper runtime behavior and visibility logic.

Visual delta:
- The popover now reads as a compact utility panel instead of a blue mini-dashboard.
- Smart Scan remains the only dominant primary CTA; other actions are visible but quieter.
- Telemetry is now a quiet footer/status area instead of competing with diagnostic cards.

Manual notes:
- normal state: checked via temporary QA bundle popover screenshot in the prior QA pass; this pass reduces shell/card/row saturation further.
- scan-running state: not fully interactively captured in this pass; scan control and progress surfaces were preserved in code.
- dark popover: not fully interactively captured in this pass; dark-mode opacities were reduced together with light-mode opacities.

## Changed Files
- `DRay/App/GlassTheme.swift`
- `DRay/App/DRayInfographics.swift`
- `DRay/Features/Overview/OverviewView.swift`
- `DRay/Features/SmartCare/SmartCareView.swift`
- `DRay/Features/Search/SearchView.swift`
- `DRay/Features/Uninstaller/UninstallerView.swift`
- `DRay/Features/Performance/PerformanceInfographics.swift`
- `DRay/Features/Performance/PerformanceView+WorkspaceComponents.swift`
- `DRay/Features/Performance/PerformanceView+WorkspaceNetwork.swift`
- `DRay/Features/Performance/PerformanceView+WorkspaceOverview.swift`
- `DRay/Features/Settings/SettingsView.swift`
- `DRay/Features/Settings/SettingsView+PermissionsSection.swift`
- `DRay/Features/Settings/SettingsView+SectionScaffold.swift`
- `DRayMenuBarHelper/MenuBarPopupCards.swift`
- `DRayMenuBarHelper/MenuBarPopupView.swift`
- `task.md`

## Manual Visual QA

Manual visual QA was executed with a temporary `/tmp/DRayQA.app` bundle built from this branch. The bundle was not installed into `/Applications`, no release package/tag/version bump was created, and production DRay defaults changed during QA were restored to their original values.

Screenshots captured:
- `/tmp/dray-uiqa2/contact-light-ru.png`: Overview, Smart Care, Search, Uninstaller, Performance, Space Lens in light/Russian pass.
- `/tmp/dray-uiqa2/contact-dark-en.png`: Overview, Smart Care, Search, Uninstaller, Performance, Settings, Space Lens in dark/English pass.
- `/tmp/dray-uiqa2/settings-fixed2-light.png`: Settings after the adaptive board crash fix.
- `/tmp/dray-uiqa-final/menubar-open.png`: Menu bar helper normal popover state.

Finding fixed during QA:
- Settings crashed during launch/layout in the adaptive board. The root cause was unstable generic `@ViewBuilder` column composition across adaptive branches. Reworked Settings board rendering to use explicit card slots and a guarded width fallback; Settings now renders in the QA bundle.

### Light mode
- [x] Main app checked
- [x] Menu bar checked

### Dark mode
- [x] Main app checked
- [ ] Menu bar checked

### Compact layout
- [ ] Overview
- [ ] Smart Care
- [ ] Search
- [ ] Uninstaller
- [ ] Performance
- [ ] Network
- [x] Settings
- [ ] Menu bar

## Visual Guardrails QA
- [x] Nested cards are mostly flat or near-flat in checked screens.
- [x] Heavy blur is limited to major surfaces in checked screens.
- [x] Primary buttons are not overused in checked screens.
- [x] Secondary actions are visually quieter in checked screens.
- [x] Semantic colors still communicate state clearly.
- [x] Text contrast remains readable in light mode.
- [x] Text contrast remains readable in dark mode.
- [x] Overview is calmer but still informative.
- [x] Smart Care remains actionable.
- [x] Search filters remain quickly accessible.
- [x] Uninstaller removal methods and risks remain visible.
- [x] Remaining cleanup reasons and remediation hints remain visible.
- [x] Performance metrics remain readable.
- [x] Network tools remain fully usable at code/build level; Space Lens was visually checked.
- [x] Settings permissions and high-risk controls remain explicit.
- [x] Menu bar popover is calmer and not visually louder than the main app.
- [x] Menu bar popover did not become unnecessarily taller; width remains the existing 430 point layout.
- [x] Smart Scan is the only main primary CTA in the menu bar.
- [x] Quick actions remain visible.
- [x] Top Consumers remain readable.
- [x] Telemetry is quiet and readable.
- [x] Quit Completely remains available.

## Functionality Preservation QA
- [x] Force Remove still visible/available where expected at code level; no removal pipeline behavior was changed in this UI refactor.
- [x] App Store app deletion behavior unchanged; no Uninstaller deletion service logic was changed.
- [x] Search filters intact; Search UI controls remain present and tests pass.
- [x] Regex validation intact; existing regex validation tests pass.
- [x] Network tools intact; Network UI/tooling code paths remain present and tests pass.
- [x] Full Disk Access diagnostics intact; Settings diagnostics remain present and tests pass.
- [x] High-risk setting intact; Settings high-risk controls were not removed.
- [x] Remaining cleanup details intact; Remaining/Uninstaller report rows were not removed.
- [x] Removal method reporting intact; Uninstaller reporting remains present.
- [x] LaunchDaemon / PrivilegedHelper guidance intact; remediation/reporting code was not removed.

## Validation
- Baseline `swift build`: passed.
- Baseline `swift test`: passed, 115 tests.
- After visual foundation `swift build`: passed.
- After visual foundation `swift test`: passed, 115 tests.
- After shared component pass `swift build`: passed.
- After shared component pass `swift test`: passed, 115 tests.
- After main module pass `swift build`: passed.
- After main module pass `swift test`: passed, 115 tests.
- After menu bar pass `swift build`: passed.
- After menu bar pass `swift test`: passed, 115 tests.
- Final `swift build`: passed.
- Final `swift test`: passed, 115 tests.
- Manual QA fix `swift build`: passed.
- Manual QA fix `swift test`: passed, 115 tests.

## Backlog / Risks
- Manual QA still not fully exhaustive: dark menu bar popover, scan-running menu bar state, and full compact sweep for every module remain best done in an interactive pass before merge.
- No release package, tag, version bump, or remote push was performed for this branch.
- Changes are presentation-layer focused; no destructive operations were run and no real App Store app deletion was tested in this UI refactor pass.
