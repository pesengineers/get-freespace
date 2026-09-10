# Build and packaging notes

Everything here was recovered from `get-freespace.ps1.psbuild` (SAPIEN PowerShell Studio
project settings, UTF-16 INI) and the scattered PowerShell Studio workspace at
`C:\Syncs\Resilio\Code\Local\PowerShell Studio`. Keep it accurate if packaging changes,
because the GUIDs below define installer upgrade identity for machines already running
Get-FreeSpace.

## Executable package (last shipped: 1.3.5.0)

| Setting | Value |
| --- | --- |
| Output name | `get-freespace` |
| Engine | Microsoft Windows PowerShell (command line), not PowerShell 7 |
| Target | Windows 64-bit only |
| Apartment | STA |
| Hash type | SHA256 |
| Icon | `get_freespace.ico` |
| Product/File version | `1.3.5.0`, auto-increment enabled |
| Product name | Get-FreeSpace |
| Description | Utility to free up temporary space consumed by Autodesk and Windows |
| Company | Dailen |
| Copyright | 2024 |
| Timestamp URL | `http://timestamp.globalsign.com/?signature=sha2` |
| Code signing | none configured |

An earlier build (1.2.7.0) targeted the SAPIEN PowerShell 7.4.2 host and both 32-bit and
64-bit. That was reverted to Windows PowerShell in commit `7332b3b`
("Reimplemented switches, switched PS engine back to Windows PowerShell") because
`Out-GridView` and the packaged PS7 host misbehaved. As of 2.0.0 the code itself runs on
either engine (`Out-ConsoleGridView` on PS7, `Out-GridView` on 5.1, popup degrades to
console), so the remaining unknown is the SAPIEN PS7 host. Re-test the packaged selection
UI and popup before changing the engine setting.

### Payload changed in 2.0.0

`Get-FreeSpace.ps1` is now a wrapper around the module beside it. The package must carry
`Get-FreeSpace.psd1`, `Get-FreeSpace.psm1`, `Public\*.ps1`, `Private\*.ps1` and
`paths.json` next to the exe, or startup fails with "module not found next to this
script". `Tests\` and `legacy\` are not part of the payload.

## MSI installer

| Setting | Value |
| --- | --- |
| ProductGUID | `{DCD33BCE-C996-4E9B-9044-B77CCCB33EAD}` |
| UpgradeGUID | `{21C13EEE-E023-4C8E-BC5B-048D2B669921}` |
| MSI name | `get-freespace` |
| Product type | Script Application |
| Install folder | `[ProgramFiles]\Get-FreeSpace` |
| Scope | All users |
| Elevation | Requires admin (`AsAdmin=1`) |
| Platform | 64-bit package |
| UI | none (`UseUI=0`) |
| Hash type | SHA256 |
| Shortcut | Start Menu\Programs -> `[INSTALLDIR]get-freespace.exe`, icon `get_freespace.ico` |

The MSI payload was the packaged exe plus the SAPIEN PowerShell host runtime DLLs. Those
binaries are build output and are intentionally not committed.

## Recovered artifacts, now local-only

The Get-FreeSpace folders in the PowerShell Studio workspace at
`C:\Syncs\Resilio\Code\Local\PowerShell Studio` (`Files\`, `Projects\`, `Builds\`,
`Builds\*.old*`) were deleted on 2026-09-09 after everything worth keeping was pulled
out. What survived lives in `legacy/`, which is gitignored and therefore never pushed:

- `legacy/builds/get-freespace.exe` (+ `.sha256`), 2024-07-09, 2.5 MB - last locally built
  exe
- `legacy/builds/get-freespace.msi` (+ `.sha256`), 2024-07-09, 1.3 MB - last locally built
  installer
- `legacy/psstudio-module/` - the unfinished module rewrite (see `legacy/README.md`)
- `legacy/psstudio-project/` - PowerShell Studio project scaffolding plus the stale
  1.2.6.0/1.2.7.0 psbuild; the psbuild committed at the repo root is newer (1.3.5.0)

Deliberately discarded, because they carried nothing this repo lacks:

- `Files\Get-FreeSpace\get-freespace.ps1` - byte-identical to commit `e02b1d9`
- `Files\Get-FreeSpace\get-freespace.msi.install.log` - one machine's install log
- `Builds\Get-FreeSpace.old\`, `Builds\Get-FreeSpace.old.old\` - older SAPIEN host runtime
  DLL sets (`SAPIEN.PoshExeHostCore`, `SAPIEN.CoreWinDarkHost`), regenerated on every build

Because `legacy/` is gitignored, `git clean -xfd` in this repo would delete it. Move it
elsewhere if that matters.

## If you drop SAPIEN

Options that preserve behavior without PowerShell Studio:

- Ship as a PowerShell module (PSGallery), which is what `legacy/psstudio-module/` was
  reaching for.
- Package with `ps2exe` or a WiX/`msi` build if the exe/MSI distribution still matters.
  Reuse the ProductGUID/UpgradeGUID above so existing installs upgrade instead of
  side-installing.
