# DRay

DRay is a macOS disk explorer that combines:
- Space visualization similar to Space Lens
- Fast file search similar to FindAnyFile

## Current scaffold
- SwiftUI app shell with `Space Lens` and `Search` tabs
- Recursive disk scanner (`FileScanner`)
- In-memory query engine (`QueryEngine`)
- Bubble-map style visual placeholder for large folders

## Run
```bash
swift run
```

## Next milestones
1. Replace naive scan with incremental index + SQLite.
2. Add advanced query filters (size/date/regex/path depth).
3. Add interactions: open in Finder, quick look, move to trash.
4. Add permissions UX for Full Disk Access.
