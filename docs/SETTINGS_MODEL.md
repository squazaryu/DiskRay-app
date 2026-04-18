# Settings Model (Current)

`Settings` is a global control center for DRay behavior, safety, and diagnostics actions.

## Sections
1. **General**
- Language
- Appearance
- Version
- Launch at Login

2. **Permissions**
- Folder Access status
- Full Disk Access status
- Permission actions (`Grant Folder`, `Open Full Disk`, `Restore`)
- Feature-impact hints grounded in real permission gates

3. **Scanning & Cleanup**
- Default scan target
- Auto-rescan after cleanup
- Hidden files default
- Package contents default
- Exclude Trash default
- Default Smart Care profile

4. **Recovery & Safety**
- Confirmation before destructive actions
- Confirmation before startup cleanup
- Confirmation before repair/reset
- Auto-rescan after restore
- Clear recovery history

5. **Diagnostics**
- Export operation log
- Export diagnostic report
- Reveal crash telemetry
- Clear cached snapshots
- Reset saved target bookmarks

## Persistence
Settings are persisted via existing store patterns (`UISettingsStore` and existing Root wiring).
No new persistence framework is introduced.

## Permission Clarity Rule
Permission impact text should describe real blocked/limited flows only.
Do not introduce conceptual warnings that are not backed by actual gate usage.

## Maintenance Rule
Do not turn `Settings` into feature-toggle storage.
Only global behavior and support-relevant controls belong here.
