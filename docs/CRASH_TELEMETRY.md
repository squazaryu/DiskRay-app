# DRay Crash Telemetry Workflow

## Runtime Behavior
- DRay writes a session marker on launch.
- On next launch, if the previous marker was not closed, DRay records an unclean-shutdown event.
- Events are appended to:
  - `~/Library/Application Support/DRay/Telemetry/crash_events.ndjson`

## Reveal Crash Event Log
- Open `Performance` tab.
- Click `Reveal Crash Log`.

## Symbolicate macOS Crash Report
If you have a native macOS crash report (`.ips` / `.crash`) and matching `DRay.dSYM`:

```bash
./scripts/symbolicate_crash.sh <path-to-crash-report> [path-to-DRay.dSYM]
```

Output file is written to:
- `.build/crash-reports/symbolicated-<report-name>`

## Notes
- Symbolication requires symbols from the same build.
- If `symbolicatecrash` is unavailable, install full Xcode + command line tools.
