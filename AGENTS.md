# Get-FreeSpace - Dev Notes

## Provenance

Consolidated 2026-09-09 from the GitHub repo (authoritative, newest) plus files scattered
across the SAPIEN PowerShell Studio workspace at
`C:\Syncs\Resilio\Code\Local\PowerShell Studio` (`Projects\`, `Files\`, `Builds\`).
The scattered `get-freespace.ps1` there matched commit `e02b1d9` exactly, so no source was
lost. The only unique recovery was the unfinished module rewrite. Those workspace folders
have since been deleted; everything salvaged that does not belong in a public repo lives
in `legacy/`, which is gitignored. Build/installer identity is in `docs/BUILD.md`.

## Downstream fork

`pesengineers/get-freespace` is a fork used by a client via RMM automation. It is 2
commits ahead of upstream and the entire delta is the default `-Source` value pointing at
`pesengineers/FreespacePaths` instead of `DailenG/FreespacePaths`. Keep that fork
mergeable: do not restructure the parameter block without checking it, and treat the two
`FreespacePaths` repos as one schema.

## Engine support

The module and CLI run on Windows PowerShell 5.1 and PowerShell 7; the Pester suite is
kept green on both. Two surfaces used to pin it to 5.1 and are now abstracted:

- Selection UI: `Select-FSGridView` prefers `Out-ConsoleGridView` on PS7 (from
  `Microsoft.PowerShell.ConsoleGuiTools`) and `Out-GridView` on 5.1, falling through to
  the other and then to a console prompt. `Out-ConsoleGridView` throws when stdin is
  redirected, which is why the fallback chain exists rather than a version check.
- Completion popup: `Show-FSCompletionPopup` degrades to console output when
  `PresentationFramework` cannot be loaded.

The packaged exe/MSI is still built on the Windows PowerShell engine. Commit `7332b3b`
reverted a PS7 packaging attempt in 2024; the blockers above are gone, but re-test the
SAPIEN PS7 host before switching, since that host is what actually failed.

## Cleanup list is a separate repo

Path data lives in `DailenG/FreespacePaths` (`paths.json`) and is fetched at runtime via
`-Source`. `paths.json` here is a snapshot and the offline fallback. Adding a cleanup
target means a PR there, not here.

Schema: `name`, `path` (wildcards allowed), `description`, `retain_days` (keep items whose
activity is newer than N days), `scope` (`file` default, or `folder`). `aged` is a
deprecated alias for `retain_days` and is still honored, so unpatched clients keep
working. Both `FreespacePaths` repos (`DailenG` and the `pesengineers` fork) must be
updated to the new keys to benefit; until then their `aged` values apply unchanged.

## Retention design, and the bug it replaced

Every list entry ends in a backslash, so `Get-ChildItem -Path '...\Journals\' -Directory`
returns the matched container itself, one per user profile, not its children. Verified on
a synthetic tree, 2026-09-09.

The old `aged` implementation filtered on that container's `LastAccessTime` and then
deleted its entire contents with no age check, so retention was all or nothing per folder
and never protected recent files. That is what let a Wednesday cleanup destroy Tuesday's
journals.

Now `Get-FreeSpace` resolves the container, then `Get-FSTargetPlan` classifies each item
inside it against the cutoff and hands the surviving item objects to `Remove-FSPlanItem`,
so the purge deletes exactly what was measured and shown. Activity is the newest of
`LastWriteTime`, `CreationTime` and `LastAccessTime`, with last access dropped (and a
warning raised) when `NtfsDisableLastAccessUpdate` bit 0 says NTFS is not recording it.
Do not reduce activity to `LastWriteTime` alone: Autodesk projects hold components that
are read for months without being rewritten.

## Remaining rough edges

- Scanning enumerates every file under every target once per run. Large `Temp` trees take
  roughly 20 seconds on a warm cache; there is no parallelism and no size cache.
- `Get-FSTargetPlan` holds `FileInfo` objects for every reclaimable item in memory. Fine
  for hundreds of thousands of files, not audited beyond that.
- Failures are collected and reported per run, but there is no retry for files locked by a
  running Revit.

## Packaging

Read `docs/BUILD.md` before touching packaging. The MSI ProductGUID/UpgradeGUID must stay
stable so existing installs upgrade rather than side-install.

`Get-FreeSpace.ps1` is now a wrapper that imports the module beside it, so the packaged
payload must include `Get-FreeSpace.psd1`, `Get-FreeSpace.psm1`, `Public\`, `Private\` and
`paths.json`. A build that ships only the exe will fail at startup with "module not found
next to this script".

## Commit style

- Atomic commits per logical change, one concern per commit.
- No co-author attribution lines.
- Imperative subject line, body explains the why.
