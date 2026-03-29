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

## Done (Recent)
- [x] Added Smart Care advanced cleanup flow (scan/review/clean) — commit `f267cda`
- [x] Added Smart Care risk labels, recommendations, and safeguards — commit `61ff069`
- [x] Added profiles, recommendation reasons, and initial Uninstaller module — commit `8946dfb`
- [x] Added mandatory residue sweep requirement to roadmap — commit `b39f9be`
