# DRay

DRay is a macOS disk explorer that combines:
- Space visualization similar to Space Lens
- Fast file search similar to FindAnyFile

## Current scaffold
- SwiftUI app shell with `Space Lens` and `Search` tabs
- Recursive disk scanner (`FileScanner`) with pause/cancel/progress
- SQLite snapshot index for fast restore between scans
- Advanced in-memory query engine (`QueryEngine`) with filters and presets
- Bubble-map drill-down navigation for folder hierarchy
- File actions: reveal in Finder, open, move to trash
- Permissions flow with `Restore` for TCC resets

## Run
```bash
swift run
```

## Next milestones
1. Replace full-rescan strategy with true incremental index updates.
2. Add date/regex/depth filters and background deep-search mode.
3. Add richer item panel with preview, safety checks, and undo stack.
4. Build signed `.app` bundle via Xcode release pipeline.
