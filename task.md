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
