# DRay

DRay is a macOS disk explorer that combines:
- Space visualization similar to Space Lens
- Fast file search similar to FindAnyFile

## Current status
- SwiftUI app shell with `Smart Care`, `Uninstaller`, `Space Lens`, and `Search` tabs
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

## Run
```bash
swift run
```

## Public TODO
- [x] Smart Care foundation (multi-analyzer scan + safe clean to Trash)
- [x] Smart Care risk labels and recommendation reasons
- [x] Smart Care profiles (`Conservative` / `Balanced` / `Aggressive`)
- [x] Space Lens drill-down and in-view bulk actions
- [x] Search presets and multi-delete flow
- [x] Install script to `/Applications/DRay.app`
- [ ] Incremental index updates (delta scan, not full tree pass)
- [x] Search Pro filters (regex/date/depth/type)
- [x] Search Pro owner filter
- [ ] Smart Care: confidence scoring and explainability per item
- [x] Uninstaller: mandatory residue sweep (`~/Library`, `/Library`, login items, launch agents, helpers)
- [x] Uninstaller: validation report (`removed / skipped / failed`)
- [x] Performance module baseline (startup diagnostics + maintenance recommendations)
- [x] Privacy/Security module baseline (trace review + safe cleanup + transparency report)
- [ ] Signed + notarized production build pipeline

## Done (Recent)
- [x] Added Smart Care advanced cleanup flow (scan/review/clean) — commit `f267cda`
- [x] Added Smart Care risk labels, recommendations, and safeguards — commit `61ff069`
- [x] Added profiles, recommendation reasons, and initial Uninstaller module — commit `8946dfb`
- [x] Added mandatory residue sweep requirement to roadmap — commit `b39f9be`
