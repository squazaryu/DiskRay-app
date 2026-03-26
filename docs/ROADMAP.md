# DRay Roadmap to CleanMyMac-Level Parity

## Goal
Build feature parity with CleanMyMac-class utility while keeping DRay's own brand and implementation.

## Milestone M1: Smart Scan Foundation (in progress)
- Unified Smart Scan orchestration across modules.
- Review model with categories, item counts, and bytes.
- Safe clean actions with Trash-first policy.
- Deliverables:
  - `CleanupAnalyzer` protocol and module runner.
  - Initial analyzers: User Logs, User Caches, Downloads Old Files.
  - `Smart Care` UI tab for scan/review/clean.

## Milestone M2: Cleanup Expansion
- Add analyzers:
  - Mail attachments, Xcode junk, iOS backups, language files.
- Exclusion system per path and per analyzer.
- Risk scoring and confidence labels.

## Milestone M3: Space Lens + Search Pro
- Full drill-down + detail pane + bulk actions in Space Lens.
- Advanced search filters: regex/date/depth/type/owner.
- Saved searches + indexed/live modes.

## Milestone M4: Uninstaller Module
- App bundle artifact discovery.
- Complete uninstall flow with preview.
- Conflict-safe uninstall plans and rollback metadata.
- Post-uninstall residue sweep (mandatory):
  - leftover files in `~/Library` and `/Library` (preferences, caches, logs, containers, group containers),
  - login items / startup objects cleanup,
  - launch agents / helper tools cleanup,
  - validation pass after uninstall with report of what was removed vs skipped.

## Milestone M5: Performance Module
- Login items management.
- LaunchAgent/LaunchDaemon diagnostics.
- Disk pressure + reclaim recommendations.

## Milestone M6: Privacy & Security Module
- Browser traces and local artifact review.
- Safe cleanup with explicit category opt-in.
- Transparency report before delete.

## Milestone M7: Release Engineering
- Signed `.app` in `/Applications` pipeline.
- Notarization + hardened runtime.
- Crash telemetry, operation logs, and UI tests.

## Acceptance Criteria for Parity
- One-click Smart Scan with meaningful multi-module findings.
- Review/clean UX with safe defaults and confirmations.
- Stable performance on large home directories.
- Production packaging flow and permission recovery workflows.
