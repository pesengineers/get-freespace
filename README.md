# Get-FreeSpace

Open source utility to free up temporary space consumed by Autodesk and Windows, with
**retention windows** so a scheduled cleanup does not destroy the files someone needs the
next morning.

It scans a list of well known cache and temp locations, reports what can be freed and what
retention is protecting, lets you pick what to purge (grid view, console prompt, or
unattended), then reports what was actually reclaimed.

## Why retention matters

The original tool deleted the contents of a matched folder wholesale. If cleanup ran
Wednesday at midnight and an engineer hit a Revit problem Tuesday afternoon, Tuesday's
journals were gone before anyone could read them.

Now every list entry carries `retain_days`, and a global `-RetainDays` floor can override
the published list. Anything whose activity falls inside that window is left alone and is
reported separately as retained.

**Activity** is the newest of `LastWriteTime`, `CreationTime` and, when NTFS is still
recording it, `LastAccessTime`. Large Autodesk projects contain components that are read
constantly but not rewritten for months; write time alone would delete live data. Where
last access tracking is disabled machine wide
(`fsutil behavior query DisableLastAccess`), that signal is dropped and the run warns,
because a frozen timestamp makes everything look abandoned.

## Usage

Run elevated. Without elevation the wildcard expansion over `C:\Users` silently sees only
the current profile, and the run says so.

```powershell
# Interactive: grid view selection
.\Get-FreeSpace.ps1

# See exactly what would go, delete nothing
.\Get-FreeSpace.ps1 -WhatIf

# Console prompt instead of a grid view
.\Get-FreeSpace.ps1 -NoDisplay

# Scheduled/RMM: purge everything older than 3 days, log it, return JSON
.\Get-FreeSpace.ps1 -Force -RetainDays 3 -Quiet -AsJson -LogPath 'C:\ProgramData\Get-FreeSpace\cleanup.log'
```

Or use it as a module:

```powershell
Import-Module .\Get-FreeSpace.psd1

Get-FreeSpace -RetainDays 3 | Format-Table Name, Path, ReclaimableSize, RetainedSize
Invoke-FreeSpace -RetainDays 3 -WhatIf
```

| Parameter | Type | Effect |
| --- | --- | --- |
| `-Source` | string | Cleanup list URL or local path. Defaults to `DailenG/FreespacePaths`. Falls back to the bundled `paths.json` if the URL is unreachable. |
| `-RetainDays` | int | Global retention floor in days. Applied as a maximum against each entry's own value, never a reduction. |
| `-Force` | switch | Purge everything reclaimable, no prompt, no popup. |
| `-NoDisplay` | switch | Console Y/N prompt instead of a grid view. |
| `-GridView` | Auto/Console/Window | Picker choice. Auto uses `Out-ConsoleGridView` on PowerShell 7 and `Out-GridView` on 5.1. |
| `-SkipWindowsTemp` | switch | Omit the machine wide `C:\Windows\Temp` entry. |
| `-LogPath` | string | Append a timestamped transcript of the run. |
| `-AsJson` | switch | Emit the run summary as JSON. Implies `-Quiet`. |
| `-Quiet` | switch | Suppress console output. File logging is unaffected. |
| `-WhatIf` / `-Confirm` | switch | Standard ShouldProcess behavior on every destructive path. |

The selection UI degrades safely: `Out-ConsoleGridView` refuses to run when stdin is
redirected (scheduled tasks, RMM agents), so the picker falls back to `Out-GridView` and
then to a console prompt.

## Cleanup list

The path list is data, not code. It lives in
[DailenG/FreespacePaths](https://github.com/DailenG/FreespacePaths) and is fetched at
runtime; [`paths.json`](paths.json) here is a snapshot and the offline fallback.

```json
{
  "name": "Revit Journals",
  "path": "C:\\Users\\*\\AppData\\Local\\Autodesk\\Revit\\*Revit*202*\\Journals\\",
  "description": "Revit journal files for all users and 202x versions",
  "retain_days": 7,
  "scope": "file"
}
```

| Field | Meaning |
| --- | --- |
| `name` | Display label. |
| `path` | Target, wildcards allowed. Expands to one target folder per matching profile. |
| `description` | Free text. |
| `retain_days` | Keep anything whose activity is newer than this many days. `0` keeps nothing. |
| `aged` | Deprecated alias for `retain_days`, still honored so unpatched clients keep working. |
| `scope` | `file` (default) judges each file on its own. `folder` judges each immediate child folder as a unit, keeping it whole if anything inside is recent. |

`scope: file` is what Revit Journals needs. `scope: folder` matches how
`CollaborationCache` is used, where a model's cache is only useful intact.

`C:\Windows\Temp\` is appended by the tool itself and is not part of the list.

## Output

`Get-FreeSpace` returns one `GetFreeSpace.Target` per resolved folder with
`ReclaimableBytes`, `RetainedBytes`, counts, the effective `RetainDays`, the `Cutoff`, and
the exact `Items` behind those numbers, so a purge deletes precisely what was measured.

`Invoke-FreeSpace` returns a `GetFreeSpace.Summary` with per location results, totals,
duration, and every failure. Freed space is summed from confirmed deletions, so locked
files reduce the number instead of inflating it.

## Repository layout

| Path | What it is |
| --- | --- |
| `Get-FreeSpace.ps1` | CLI entry point. Thin wrapper over the module. |
| `Get-FreeSpace.psd1` / `.psm1` | Module manifest and loader. |
| `Public/`, `Private/` | Module functions. |
| `Tests/` | Pester 5 suite; passes on Windows PowerShell 5.1 and PowerShell 7. |
| `paths.json` | Cleanup list snapshot and offline fallback. |
| `get_freespace.ico` | Application icon, for whatever packager you use. |
| `docs/DISTRIBUTION.md` | How to ship it: module publish, optional exe, installer identity. |

## Compatibility

Windows PowerShell 5.1 and PowerShell 7, verified by the test suite on both. There is no
build step and no IDE dependency; see [`docs/DISTRIBUTION.md`](docs/DISTRIBUTION.md) to
publish or package it.

## Author

Dailen Gunter

## License

See [LICENSE](LICENSE).
