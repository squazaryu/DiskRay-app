# DRay Issues Implementation Batch 2 / Release 2.2.1

Date: 2026-07-30
Branch: `2.2.0-ui-refactor`
Target release: `2.2.1 (1)`
Scope: issues #4, #7, staged Network/Uninstaller UI decomposition for #12, installation, and GitHub release.

## Constraints
- Preserve Force Remove, admin fallback, App Store app deletion, Remaining cleanup, Search, Network tools, and high-risk controls.
- Network geolocation must be explicit opt-in; disabled capabilities must not make external requests.
- Deep Sweep must not treat weak identifier matches, shared containers, or installed nested helpers as safe automatic cleanup.
- Keep `RootViewModel` as coordinator and do not introduce duplicate state owners.
- Do not touch `codex-pets`.
- Release only after full-Xcode debug/release builds, tests, package verification, and installation verification pass.

## Plan
- [x] Verify branch state, latest release, and open issue scope.
- [x] Issue #4: split public-IP and endpoint geolocation consent, default both off, and add cache clearing.
- [x] Issue #7: add Deep Sweep evidence/confidence and keep weak/shared matches review-only.
- [x] Issue #12: extract repeated Network and Remaining presentation without changing state ownership.
- [x] Run focused tests after each functional change.
- [x] Run full debug/release builds, full tests, and `git diff --check`.
- [x] Update version/docs for `2.2.1 (1)` and prepare release notes.
- [x] Build/package and install `/Applications/DRay.app`.
- [x] Verify bundle identity, helper, signatures, checksums, and launch.
- [ ] Push reviewed commits, update `main`, create `v2.2.1`, and publish the GitHub release.
- [ ] Record CI/release evidence and update implemented GitHub issues.

## Issue #4: Network Geolocation Privacy
- Public IP profile lookup and remote endpoint geolocation have independent stored controls.
- Both controls default to disabled and require current consent before an old stored preference can re-enable endpoint lookup.
- Disabled capabilities do not call the resolver.
- The Network workspace exposes both controls and a geolocation cache reset.
- Focused tests cover disabled behavior, independent capabilities, disabling cleanup, and cache clearing.

## Issue #7: Deep Sweep Ownership Confidence
- [x] Add typed ownership confidence and evidence to runtime and persisted Remaining records.
- [x] Exclude identities found in installed app bundles and nested helpers/plugins.
- [x] Treat shared/group containers and ambiguous identifiers as low confidence.
- [x] Require exact identity plus package receipt for high-confidence automatic cleanup.
- [x] Keep low/medium-confidence candidates visible but out of record/all automatic cleanup.
- [x] Complete focused and full test validation.

## Issue #12: UI Decomposition
- [x] Extract repeated Network list/privacy presentation into stateless feature-local components.
- [x] Extract Remaining record/issue presentation into stateless feature-local components.
- [x] Keep actions and observable state in existing feature controllers/views.
- [x] Verify compact/full-size behavior through smoke and launch checks.

## Release Validation
- [x] `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build`
- [x] `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build -c release`
- [x] `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`
- [x] `git diff --check`
- [x] Package/install scripts pass for `2.2.1 (1)`.
- [x] `/Applications/DRay.app` reports `CFBundleShortVersionString=2.2.1` and `CFBundleVersion=1`.
- [ ] GitHub tag/release and CI are verified.

## Batch 2 Validation Evidence
- Focused privacy/Deep Sweep/controller suite: 14 tests passed.
- Full suite: 154 tests in 40 suites passed.
- UI smoke: 5/5 scenarios passed.
- PII scan: passed after repository allowlist filtering.
- Installed bundle: `com.squazaryu.DRay`, version `2.2.1`, build `1`.
- Embedded helper: present, executable, and launched from `/Applications/DRay.app`.
- Signature: ad-hoc verified with `codesign --verify --deep --strict`.
- Distribution limitation: no Developer ID identity or notary profile is available in the local release environment.
- ZIP SHA256: `c6dac9ec70b354592969c51240c039edade09ccad9db5fc5eca154aa6574254f`.
- DMG SHA256: `fc889e6259e3230956d64ba02fdbbb5023c73bb7654af442a254a9e6249089a4`.
- GitHub Release: `https://github.com/squazaryu/DiskRay-app/releases/tag/v2.2.1`.
- First `main` CI run `30572691837` failed before build because toolchain verification incorrectly expected Swift at `Developer/usr/bin/swift`.
- CI/release workflows now select full Xcode through `/Applications/Xcode.app` and verify Swift through `xcrun --find swift`; source and published artifact hashes are unchanged.
- Successful retry `30573033124`: full-Xcode debug/release builds and all tests passed with Xcode 26.5.
- A later runner was provisioned with the older supported image during the rollout, so the workflow now accepts only documented Xcode 26.4.1 or 26.5 and prints the selected version before validation.
- Workflows use `actions/checkout@v5` to avoid the Node.js 20 deprecation warning.

---

# DRay Issues Implementation Batch 1

Date: 2026-07-30
Branch: `2.2.0-ui-refactor`
Scope: issues #1, #3, #5, #6 and the first behavior-preserving shared UI cleanup for #12.

## Constraints
- Preserve Force Remove, admin fallback, App Store app deletion, Remaining cleanup, and high-risk controls.
- Do not change the app version, release tag, bundle identifiers, or packaging behavior.
- Keep `RootViewModel` as coordinator and do not introduce duplicate state owners.
- Refactor repeated presentation only where an existing shared component is the correct owner.
- Tests must not perform destructive, privileged, or real network operations.

## Plan
- [x] Verify clean worktree and current open issues.
- [x] Baseline `swift build` and `swift test` with the full Xcode toolchain.
- [x] Issue #1: add required PR/push CI, pin full Xcode, and remove obsolete external `swift-testing`.
- [x] Issue #3: stream stdout/stderr, bound captured output, and close launch/cancel/timeout races.
- [x] Issue #5: make SQLite snapshots atomic, root-scoped, indexed, and recoverable.
- [x] Issue #6: persist typed Remaining category/remediation and migrate legacy records.
- [x] UI refactor: replace repeated summary/status tiles with shared components and remove dead helpers.
- [x] Run debug/release builds, full tests, and `git diff --check`.
- [x] Update GitHub issues with implementation evidence after local commits exist.

## Baseline
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build`: passed.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`: passed, 128 tests.
- Current worktree was clean at `2093ec9`.

## Implemented

### Issue #1: CI and toolchain
- Added required PR and `main` push CI with stale-run cancellation.
- CI and release verification use the full Xcode 26.4.1 toolchain on `macos-26`.
- Both workflows run clean, debug build, release build, and the full test suite.
- Removed the obsolete external `swift-testing` dependency and its resolved package file; tests now use the toolchain-provided Testing library.

### Issue #3: command execution
- stdout and stderr are drained concurrently while the child process is running.
- Captured output is bounded and reports truncation instead of allowing unbounded memory growth.
- Launch failure, normal completion, timeout, and cancellation converge on one locked completion path.
- Cancellation before launch and during execution is covered by focused tests; timeout/cancel escalates from termination to `SIGKILL`.

### Issue #5: SQLite snapshots
- Added a root-scoped `file_index_v2` schema with a composite root/path key and indexed root/parent lookup.
- Snapshot replacement uses `BEGIN IMMEDIATE`, checks every prepare/bind/step/commit result, and guarantees rollback before returning on failure.
- SQL now loads only the requested root.
- Added a controlled rebuild for `SQLITE_CORRUPT` / `SQLITE_NOTADB`; this only discards the rebuildable index cache.
- Tests cover root-only snapshots, replacement, insert rollback, injected commit rollback, multiple roots, cache clearing, and corruption recovery.

### Issue #6: Remaining classification
- Added typed Remaining category and remediation fields while retaining the original technical reason.
- Classification now happens in the domain layer; SwiftUI filters no longer parse localized reason text.
- Legacy records migrate deterministically, including correction of ordinary `~/Library/Preferences/*.plist` records previously labeled SIP/TCC.
- LaunchDaemon and PrivilegedHelper records keep separate admin guidance.

### Issue #12: shared UI cleanup, first stage
- Added shared compact `DRaySummaryMetricCard` and `DRayStatusTile` components to the existing visual foundation.
- Replaced repeated local implementations across Clutter, Repair, Settings, Smart Care, Recovery, Space Lens, and Performance Network.
- Removed dead summary/status helper code from Clutter, Privacy, Recovery, Search, Smart Care, and Space Lens.
- State ownership and feature actions are unchanged. Larger Network/Uninstaller decomposition remains open under issue #12.

## Tests Added
- `SystemCommandRunnerTests`: large stdout, output bounds, timeout, cancellation during execution, cancellation before launch.
- `SQLiteIndexStoreTests`: root-only and replacement snapshots, insert rollback, commit rollback, multiple roots, clear, corruption rebuild.
- `UninstallRemainingIssueClassificationTests`: preference migration, daemon/helper categories, typed Codable roundtrip, permission denial, system-protected path.
- `UninstallPlanningUseCaseTests`: typed preference and LaunchDaemon classification assertions.

## Validation
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift package clean`: passed.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build`: passed.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build -c release`: passed.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`: passed, 144 tests in 38 suites.
- `git diff --check`: passed.
- Added local implementation evidence to GitHub issues #1, #3, #5, #6, and #12. Issues remain open until the branch is pushed and CI runs.

## Remaining Risks / Next Batch
- CI has not run on GitHub because this local branch has not been pushed.
- `SystemCommandRunner` reliably terminates the launched process; explicit child process-group ownership would require replacing Foundation `Process` with a lower-level spawn implementation and remains a focused follow-up if shell-command descendants are introduced.
- Issue #12 remains open for staged Network and Uninstaller presentation decomposition and manual compact/full-size RU/EN visual QA.
- Recommended next functional batch: geolocation privacy opt-in (#4), Deep Sweep confidence model (#7), then Search streaming/backpressure (#8).

---

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
Brief: DRay_Calm_Liquid_Glass_Redesign_Prompt.md (local product brief)

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

## Visual QA Agent Report

### Pass/fail
- Main app visual delta: PASS
- Menu bar visual delta: PASS
- Calm Liquid Glass direction: PASS
- Functionality preserved: PASS

### Evidence
- Screens reviewed:
  - `/tmp/dray-ui-refactor-qa/screens/relaunch-light.png`: temporary QA app bundle, light appearance, English labels, full-size Overview after current shared/module/menu commits.
  - `/tmp/dray-ui-refactor-qa/screens/main-light-overview.png`: temporary QA app bundle, first light Overview capture before coordinate-driven navigation attempts.
  - Source/diff review for Overview, Smart Care, Search, Uninstaller/Remaining, Performance, Network, Settings, and Menu Bar surfaces after the final menu bar commit.
- Remaining visual issues:
  - Setup Required permission banner still uses a bright system-blue primary button because it is a permission onboarding CTA; this can be softened later without changing access flow.
  - Some semantic charts still retain colored progress lines for readability; they are less saturated, but not monochrome.
  - Automated screenshot navigation across all modules was unreliable in this desktop session because the QA bundle and installed `/Applications/DRay.app` were both running and macOS Accessibility coordinate clicks sometimes targeted the wrong Space/window.
- Must-fix before merge:
  - None found in build/test or the checked Overview/Menu Bar source pass.
  - Recommended before merge: one interactive human pass through Smart Care, Search, Uninstaller, Performance Network tab, Settings, and the menu bar dark/scan-running states.

## Manual Visual QA

Manual visual QA was executed with a temporary `/tmp/DRayQA.app` bundle built from this branch. The bundle was not installed into `/Applications`, no release package/tag/version bump was created, and production DRay defaults changed during QA were restored to their original values.

Screenshots captured:
- `/tmp/dray-uiqa2/contact-light-ru.png`: Overview, Smart Care, Search, Uninstaller, Performance, Space Lens in light/Russian pass.
- `/tmp/dray-uiqa2/contact-dark-en.png`: Overview, Smart Care, Search, Uninstaller, Performance, Settings, Space Lens in dark/English pass.
- `/tmp/dray-uiqa2/settings-fixed2-light.png`: Settings after the adaptive board crash fix.
- `/tmp/dray-uiqa-final/menubar-open.png`: Menu bar helper normal popover state.
- `/tmp/dray-ui-refactor-qa/screens/menu-bar-popover-dark-system.png`: menu bar helper in true macOS dark appearance.
- `/tmp/dray-ui-refactor-qa/screens/menu-bar-metrics-equal-no-graphs.png`: menu bar helper after equal-size metric cards and graph removal.

Finding fixed during QA:
- Settings crashed during launch/layout in the adaptive board. The root cause was unstable generic `@ViewBuilder` column composition across adaptive branches. Reworked Settings board rendering to use explicit card slots and a guarded width fallback; Settings now renders in the QA bundle.

### Light mode
- [x] Main app checked
- [x] Menu bar checked

### Dark mode
- [x] Main app checked
- [x] Menu bar checked

### Compact layout
- [x] Overview
- [ ] Smart Care
- [ ] Search
- [ ] Uninstaller
- [ ] Performance
- [ ] Network
- [x] Settings
- [x] Menu bar

## Follow-up UI Polish Pass

### Changed
- Softened the shared `DRayPrimaryButtonStyle` so primary actions are accent-tinted instead of saturated blue filled buttons.
- Replaced remaining `.borderedProminent` usage in the main app target with `DRayPrimaryButtonStyle()`.
- Added `ViewThatFits` fallbacks to the permission onboarding banner so steps/actions wrap cleanly in compact windows.
- Added `MenuBarSoftButtonStyle` with primary/secondary/danger tones and removed remaining system prominent/bordered menu bar buttons.
- Neutralized menu bar popover shell/card surfaces so desktop wallpaper color no longer creates a blue wash through heavy `.thinMaterial`.
- Made menu bar Storage/Memory/Battery/CPU metric cards equal height and removed their sparkline/progress micrographs so the tiles read as compact controls instead of mini charts.

### Files touched in this pass
- `DRay/App/GlassTheme.swift`
- `DRay/App/Root/RootPermissionOnboardingCard.swift`
- `DRay/Features/Clutter/ClutterView.swift`
- `DRay/Features/Health/HealthPopupView.swift`
- `DRay/Features/Performance/PerformanceView+WorkspaceNetwork.swift`
- `DRay/Features/Performance/PerformanceView+WorkspaceOverview.swift`
- `DRay/Features/Performance/PerformanceView+WorkspaceStartup.swift`
- `DRay/Features/Privacy/PrivacyView.swift`
- `DRay/Features/Recovery/RecoveryView.swift`
- `DRay/Features/Repair/RepairView.swift`
- `DRay/Features/SmartCare/SmartCareView.swift`
- `DRay/Features/SpaceLens/BubbleMapView.swift`
- `DRay/Features/SpaceLens/SpaceLensView.swift`
- `DRay/Features/Uninstaller/UninstallerView.swift`
- `DRayMenuBarHelper/BatteryDetailsSheetView.swift`
- `DRayMenuBarHelper/MenuBarHealthDetailsPopover.swift`
- `DRayMenuBarHelper/MenuBarPopupCards.swift`
- `DRayMenuBarHelper/MenuBarPopupOverlays.swift`
- `DRayMenuBarHelper/MenuBarPopupView.swift`

### QA evidence
- `/tmp/dray-ui-refactor-qa/screens/compact-dark-overview-after.png`: compact Overview in forced dark app appearance; permission onboarding wraps cleanly and primary actions are no longer saturated blue.
- `/tmp/dray-ui-refactor-qa/screens/menu-bar-popover-neutral-after.png`: live menu bar helper popover from the temporary QA helper; installed helper was restored afterward.
- `/tmp/dray-ui-refactor-qa/screens/menu-bar-popover-dark-forced.png`: attempted process-local `-AppleInterfaceStyle Dark` helper launch. Cocoa did not switch the popover to dark while the system global appearance was Light, so true dark menu bar QA still requires switching macOS appearance or testing on a dark-system session.
- `/tmp/dray-ui-refactor-qa/screens/menu-bar-popover-dark-system.png`: true dark-system menu bar pass after temporarily switching macOS appearance, then restoring the original appearance.
- `/tmp/dray-ui-refactor-qa/screens/menu-bar-metrics-equal-no-graphs.png`: follow-up menu bar metric cards pass; Storage/Memory/Battery/CPU tiles are equal-sized and no longer render charts/progress lines.

### Validation
- `swift build`: passed.
- `swift test`: passed, 115 tests.
- `git diff --check`: passed before final staging.
- Follow-up metric cards pass `swift build`: passed.
- Follow-up metric cards pass `swift test`: passed, 115 tests.
- Production `/Applications/DRay.app` menu bar launch agent was restored after temporary helper QA.

## Follow-up Menu Bar Metric Cards Pass

### Visual QA Agent Findings
- Menu bar metric request: PASS.
- Storage/Memory/Battery/CPU cards are fixed to the same height and no longer accept or render sparkline/progress inputs.
- Secondary actions remain subdued through `MenuBarSoftButtonStyle` and updated DRay button hierarchy.
- Destructive actions reviewed by the read-only QA agent remain styled as danger where expected.

### Changed
- Removed menu bar metric sparkline/progress helpers from `DRayMenuBarHelper/MenuBarPopupCards.swift`.
- Removed `cpuTrend`, `memoryTrend`, `appendTrend`, `diskUsedRatio`, and graph/progress arguments from `DRayMenuBarHelper/MenuBarPopupView.swift`.
- Made shared DRay button styles control-size aware, including `.extraLarge`, so replacing system `.bordered` buttons does not inflate dense controls.
- Converted remaining main-app `.bordered` buttons to calm secondary/danger styles where appropriate.

### Preserved
- Smart Scan remains the menu bar primary CTA.
- Metric actions remain available: Free Up, Inspect, Details, Diagnose.
- Top Consumers still keeps compact load markers because those are diagnostic ranking indicators, not the four metric card micrographs.
- No deletion, Search, Network, permission, Remaining, or high-risk business logic was changed.

## Manual UI QA Pass 2026-05-22

### Environment
- Branch: `2.2.0-ui-refactor`.
- QA bundle: `/tmp/dray-ui-manual-qa/DRay.app`.
- Installed `/Applications/DRay.app` was not replaced.
- Production menu bar helper was restored after temporary helper checks.
- macOS appearance was temporarily switched for dark-mode screenshots and then restored.
- Temporary QA bundle TCC prompts were dismissed/reset where possible; no cleanup/destructive actions were executed.

### Screenshots
- Light/full-size:
  - `/tmp/dray-ui-manual-qa/screens/light-qapass-overview.png`
  - `/tmp/dray-ui-manual-qa/screens/light-qapass-smart-care.png`
  - `/tmp/dray-ui-manual-qa/screens/light-qapass-clutter.png`
  - `/tmp/dray-ui-manual-qa/screens/light-qapass-uninstaller.png`
  - `/tmp/dray-ui-manual-qa/screens/light-qapass-repair.png`
  - `/tmp/dray-ui-manual-qa/screens/light-qapass-space-lens.png`
  - `/tmp/dray-ui-manual-qa/screens/light-qapass-search.png`
  - `/tmp/dray-ui-manual-qa/screens/light-qapass-privacy.png`
  - `/tmp/dray-ui-manual-qa/screens/light-qapass-recovery.png`
  - `/tmp/dray-ui-manual-qa/screens/light-qapass-settings.png`
- Dark/full-size:
  - `/tmp/dray-ui-manual-qa/screens/dark-overview.png`
  - `/tmp/dray-ui-manual-qa/screens/dark-smart-care.png`
  - `/tmp/dray-ui-manual-qa/screens/dark-search.png`
  - `/tmp/dray-ui-manual-qa/screens/dark-uninstaller.png`
  - `/tmp/dray-ui-manual-qa/screens/dark-settings.png`
- Compact:
  - `/tmp/dray-ui-manual-qa/screens/compact-overview.png`
  - `/tmp/dray-ui-manual-qa/screens/compact-smart-care.png`
  - `/tmp/dray-ui-manual-qa/screens/compact-search.png`
  - `/tmp/dray-ui-manual-qa/screens/compact-uninstaller.png`
  - `/tmp/dray-ui-manual-qa/screens/compact-settings.png`
- Menu bar:
  - `/tmp/dray-ui-manual-qa/screens/menubar-light-normal.png`
  - `/tmp/dray-ui-manual-qa/screens/menubar-dark-normal.png`
  - `/tmp/dray-ui-manual-qa/screens/menubar-light-after-smart-scan.png`

### Pass/fail
- Main app visual delta: PASS.
- Menu bar visual delta: PASS.
- Calm Liquid Glass direction: PASS.
- Compact layout: PASS for Overview/Search/Settings; partial for Smart Care/Uninstaller because only first viewport was checked.
- Functionality preserved: PASS at code/build level; no business logic was changed in this pass.

### Findings
- Menu bar Storage/Memory/Battery/CPU cards are equal-sized and graph-free in light and dark screenshots.
- Menu bar dark mode is coherent: no blue wash, quiet cards, readable controls, Smart Scan remains the only strong CTA.
- Compact Overview no longer shows overly compressed metric modules; the 2-column metric layout remains readable.
- Search filters remain visible in full-size and compact layouts.
- Uninstaller keeps removal controls, risk/remnant context, and destructive actions visible.
- Settings Full Disk Access diagnostics remain explicit and readable.

### Limitations
- The temporary QA bundle uses a different path/bundle context, so macOS does not grant it the same Full Disk Access as the installed app. Performance and Smart Scan launch-action screenshots are therefore blocked by permission dialogs in this QA environment.
- Scan-running menu bar state could not be captured honestly because Smart Scan from the temporary helper was blocked by Full Disk Access. The normal and post-click menu bar states were captured, but no running-progress state was confirmed.
- Network workspace was not separately opened in Performance because the temporary bundle permission gate blocked clean Performance navigation.

### Visual backlog from QA
- Selected segmented controls still use a fairly saturated system blue in Search, Uninstaller, Space Lens, Settings, and Smart Care tabs. This is functional and consistent, but could be softened in a future shared segmented-control pass.
- Overview/Performance main metric cards still include sparklines/progress lines. That was not part of the menu bar metric-card request, but can be revisited if the same "no mini graphs" direction should apply globally.
- Permission setup banner dominates temporary QA screenshots when Full Disk Access is missing. It is readable and actionable, but still consumes significant vertical space in compact windows.

## Network Map / Scroll Audit

### Map implementation
- Files:
  - `DRay/Features/Performance/PerformanceView+WorkspaceNetwork.swift`
- Current Map style:
  - SwiftUI `Map(initialPosition:)` with `.standard(elevation: .realistic)`.
  - Map content is clipped but not visually muted, so the native map looks brighter than surrounding calm cards.
- Current overlays/annotations:
  - Local Mac annotation uses a laptop icon with accent fill.
  - Remote host annotations use colored circles from `endpointTint`.
  - Connection lines use `MapPolyline` with host tint and opacity.
- Current visual issue:
  - The map still reads as a vivid embedded MapKit component instead of an integrated diagnostic surface.
  - Endpoint pins and route lines are readable but still more saturated than the Calm Liquid Glass pass.

### Nested scroll zones found
- File: `DRay/Features/Performance/PerformanceView+WorkspaceNetwork.swift`
- Component: `networkMapSummaryCard`
- Problem:
  - A vertical `ScrollView` lives inside the Live Map side summary card with a fixed max height, creating a small nested scrollbar inside an already scrollable page.
- Proposed fix:
  - Replace the inner scroll with a normal `VStack`, show top remote hosts/processes, and let the page own vertical scrolling.
- File: `DRay/Features/Performance/PerformanceView+WorkspaceNetwork.swift`
- Component: `networkListCard`
- Problem:
  - Hosts/Services/Programs cards use inner vertical `ScrollView` with `frame(minHeight:maxHeight:)`, producing dashboard cards with small scrollbars.
- Proposed fix:
  - Render `prefix(6)` diagnostic rows directly in the card and show a quiet `Showing top 6 of N` footer for long lists.

### Constraints
- Keep Network functionality.
- Avoid nested vertical scroll unless absolutely necessary.
- Keep compact layout usable.
- Do not change Network diagnostics logic, sampling, geolocation, port scanning, WOL, or speed-test behavior.

## Network Map / Scroll Visual QA

### Screenshots
- Live Map full-size: `/tmp/dray-network-scroll-qa/network-live-map-final-window.png`
- Network Overview full-size: `/tmp/dray-network-scroll-qa/network-overview-window.png`
- Network Tools full-size: `/tmp/dray-network-scroll-qa/network-tools-window.png`
- Live Map compact/window crop: `/tmp/dray-network-scroll-qa/network-live-map-compact-window.png`
- Overview ring check: `/tmp/dray-network-scroll-qa/overview-ring-final-window.png`

### Live Map
- [x] Map is less saturated.
- [x] Map is visually integrated with Calm Liquid Glass.
- [x] Markers are readable but not neon.
- [x] Route/connection lines are muted.
- [x] Map card border/background matches the rest of the app.
- [x] Live Map remains functional.

### Scroll behavior
- [x] No strange nested vertical scrollbars in Network Overview.
- [x] No strange nested vertical scrollbars in Live Map side panels.
- [x] No strange nested vertical scrollbars in Network Tools.
- [x] Main page scroll remains smooth.
- [x] Compact window layout checked.
- [x] Full-size window layout checked.

### Functionality preserved
- [x] Network hosts/services/programs still visible.
- [x] Public IP card still visible.
- [x] Latency still visible.
- [x] Port scanner still usable.
- [x] Wake-on-LAN still usable.
- [x] Speed test still visible.

### Implementation notes
- Live Map now uses flat MapKit styling with POI/traffic removed, lower saturation/contrast, a subtle window-background veil, and a calm border.
- Endpoint markers and routes were muted; selected endpoints still have visible accent emphasis.
- `networkMapSummaryCard` no longer owns a vertical `ScrollView`.
- Hosts/Services/Programs cards render top rows directly in the page flow and show a quiet `Showing top N of M` footer.

## Ring Indicator Semantics QA
- [x] System Health ring matches Excellent/Good/Fair/Poor-style status semantics; Overview maps local `Excellent` to a near-full visual ring and lower statuses to partial category progress.
- [x] Menu Bar health ring uses the same visual semantics: `Good` is near-full, `Fair` is partial, attention state is low.
- [x] Numeric rings show numeric score when progress is not category-based; Smart Care/Network/Recovery donut charts keep center numeric values.
- [x] Excellent does not appear visually incomplete.
- [x] Smart Care donut/ring remains meaningful and not misleading.

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
- [x] Manual 2026-05-22 pass: menu bar metric cards checked in light/dark and compact main app screenshots captured.

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
- Follow-up metric cards `swift build`: passed.
- Follow-up metric cards `swift test`: passed, 115 tests.
- Manual UI QA 2026-05-22: screenshot-based pass completed; no code changes required from this pass.
- Network map / scroll pass `swift build`: passed.
- Network map / scroll pass `swift test`: passed, 115 tests.
- Network map / scroll pass `git diff --check`: passed.
- Installed current branch to `/Applications/DRay.app` as `2.1.3 (1)` for visual QA; no release package, tag, or version bump was created.

## Backlog / Risks
- Permission onboarding banner was softened after the Visual QA report: primary permission actions now use a calm accent-tinted style, permission steps use near-flat nested cards, and the banner container uses `calmGlass(.section)` instead of the heavier `glassSurface`.
- Manual QA still not fully exhaustive: scan-running menu bar state and clean Performance/Network sweep require a signed/installed build with Full Disk Access, not the temporary QA bundle.
- No release package, tag, version bump, or remote push was performed for this branch.
- Changes are presentation-layer focused; no destructive operations were run and no real App Store app deletion was tested in this UI refactor pass.

## Overview Text-First Density Pass
- Replaced the shared dashboard metric tile with fixed-height text-first cards: no sparkline, no progress bar, no large icon badge; only a small semantic color strip remains.
- Reduced dashboard metric tile heights for compact and adaptive density.
- Reworked Overview hero into a text-first System Health + Index layout; removed the large status ring and health trend chart from the hero.
- Replaced Overview Top Consumers bars with compact diagnostic text rows.
- Preserved Overview actions, navigation targets, system health score, metrics, recommendations and activity rows.

### Validation
- [x] swift build
- [x] swift test
- [x] git diff --check

## Global Text-First Density Pass
- Extended the Overview-style text-first treatment across shared cards and ranked rows.
- Updated `DRayCompactInfoTile`, `DRayMetricTile`, and `DRayRankedBarRow` to remove large icon badges, progress bars, and graph-like row indicators.
- Reworked Smart Care hero/category cards to use text metrics instead of the status ring/donut/category progress bars.
- Reworked Search query scope card to use text summary instead of icon/progress treatment.
- Reworked Recovery hero and overview protection card to use text status/metrics instead of ring/donut visuals.
- Reworked Space Lens storage summary to use text summary and ranked rows instead of donut/progress visuals.
- Reworked remaining Performance overview/system/network cards to use live text metrics instead of sparklines/donut visuals.
- Reworked menu bar health/metric/consumer rows to match compact text-first density.
- Preserved operational controls and flows: Smart Care scan/clean, Search filters/results, Recovery restore/rollback, Space Lens actions, Performance relief/network tools, menu bar Smart Scan/Open actions.

### Validation
- [x] swift build
- [x] swift test
- [x] git diff --check

## Performance Text-First Follow-up
- Battery & Energy: removed remaining per-consumer progress bars; rows now use text metrics and a small semantic strip.
- Startup: replaced burden/proportion bars and startup item size bars with text-first diagnostics; reduced burden card height.
- Network Overview: replaced the tall traffic chart with compact incoming/outgoing/history metrics.
- Network Live Map: restored visible connection routes with stronger muted opacity and line width, without returning to neon styling.
- Preserved Performance diagnostics logic, Battery estimates, Startup selection/disable actions, Network Overview, Live Map and Tools behavior.

### Validation
- [x] swift build
- [x] swift test
- [x] git diff --check

## P0 Smart Care Preference Safety Fix
- Problem: generic Smart Care orphan preference cleanup could classify active `~/Library/Preferences/*.plist` files as removable, including macOS settings such as Dock, menu bar, keyboard, trackpad, wallpaper, shortcuts and login items.
- Fix: removed `OrphanPreferencesAnalyzer` from default Smart Care analyzers and from the Smart Care analyzer options UI.
- Fix: `PathSafetyPolicy` now treats `~/Library/Preferences` as manual-only user setting state, so safe cleanup skips it even if a preference plist reaches the cleanup pipeline.
- Fix: the orphan preference enumerator now rejects critical macOS preference domains such as `com.apple.*`, `apple.*`, `.GlobalPreferences`, `GlobalPreferences` and `NSGlobalDomain`.
- Preserved: Uninstaller/Remaining app-bound preference cleanup logic is unchanged; Force Remove, admin deletion and App Store app deletion behavior were not touched.

### Validation
- [x] swift build
- [x] swift test
- [x] git diff --check

## Default Cleanup Safety Audit

### Goal
Protect active macOS/user settings and system state from default or recommended cleanup paths while preserving explicit Uninstaller/Remaining and high-risk/admin flows.

### Audit scope
- [x] Smart Care analyzers and cleanup execution.
- [x] Privacy scan/recommended cleanup.
- [x] Performance Startup recommendations and cleanup.
- [x] Duplicate recommended selection and SafeFileOperation path gate.
- [x] Search/Space Lens manual trash path gate.
- [x] Repair/Uninstaller app-bound cleanup preservation.

### Initial findings
- Smart Care generic orphan preferences was already removed from default scan, but broader default/recommended flows still need a shared default-cleanup exclusion layer.
- `PathSafetyPolicy.shouldSkipForSafeCleanup` protects admin/system paths, but recommended selection logic can still surface user settings/state paths before deletion.
- Privacy `recent-docs` includes macOS state paths (`com.apple.sharedfilelist`, `com.apple.recentitems.plist`) and should not be selected by default/recommended cleanup.
- Privacy medium-risk app profile paths under `~/Library/Application Support` should not be selected by recommended cleanup because they can contain active app state, not disposable cache.
- Performance startup recommendations can select LaunchAgents/LaunchDaemons; recommendations should not auto-select Apple/system launch configuration.
- Duplicate recommended cleanup should avoid selecting protected settings/state paths, even if manual trash remains available where policy permits it.

### Protected-by-default classes
- [x] User and system preferences.
- [x] LaunchAgents / LaunchDaemons / StartupItems.
- [x] Keychains and security identity stores.
- [x] Apple/system Application Support state.
- [x] Active app profile state under `~/Library/Application Support`.
- [x] Containers / Group Containers / Application Scripts.
- [x] Mail, Messages, Contacts, Calendar, Photos, Mobile Documents, MobileSync backups.
- [x] Safari bookmarks/session state and other browser account/profile roots where relevant.

### Validation
- [x] swift build
- [x] swift test
- [x] git diff --check

## Battery Energy Mode Control

### Goal
Allow DRay to read and set macOS energy mode separately for Battery Power and AC Power without changing diagnostics or cleanup behavior.

### Scope
- [x] Add pmset-backed energy mode service.
- [x] Surface Battery Power and AC Power modes in Battery & Energy.
- [x] Keep existing battery diagnostics and estimated drain reporting intact.
- [x] Add tests for parsing and command arguments.

### Constraints
- Do not change app version/release/tag.
- Do not weaken cleanup/uninstaller/search/network behavior.
- Use `pmset powermode` with `-b` and `-c` only for explicit user selection.
- Show clear failure message if macOS denies or does not support the setting.

### Validation
- [x] swift build
- [x] swift test
- [x] git diff --check

## Energy Mode Root Authorization Fix

### Finding
- Direct `pmset -b/-c powermode` can fail with `must be run as root` even though reads work without authorization.
- `AuthorizationExecuteWithPrivileges` is unavailable to Swift on current macOS SDKs, so a direct Security.framework root execution path is not viable for this app shape.

### Fix
- [x] Keep direct `/usr/bin/pmset` as the first write attempt.
- [x] Retry only root-required failures through a narrow administrator-authorized `pmset powermode` fallback.
- [x] Keep read paths (`pmset -g custom`, `-g cap`, `-g batt`) direct and non-elevated.
- [x] Add test coverage for root-required retry.

### Validation
- [x] swift build
- [x] swift test
- [x] git diff --check

## Remaining Preferences Classification Fix

### Finding
- `~/Library/Preferences/*.plist` was intentionally marked `manualOnly` to keep Smart Care from deleting user/macOS settings by default.
- Remaining/Uninstaller reused the same `manualOnly` signal as `SIP/TCC`, so ordinary app preference leftovers were shown as system-protected and skipped by Remaining cleanup.
- The screenshot paths (`org.cindori.Sensei.plist`, `com.rileytestut.AltServer.plist`) are app preference plist leftovers, not necessarily Login Items. Login/background items usually appear as LaunchAgents, BackgroundTaskManagement data, or startup references.

### Fix
- [x] Keep user preferences excluded from default Smart Care cleanup.
- [x] Stop treating user preference plist leftovers as `SystemPathProtection`.
- [x] Show Remaining preference leftovers as `Preferences`, not `SIP/TCC`.
- [x] Allow explicit Remaining cleanup to attempt deletion of app-bound preference leftovers.
- [x] Keep real SIP/system paths protected.

### Validation
- [x] swift build
- [x] swift test
