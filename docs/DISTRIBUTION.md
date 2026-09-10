# Distribution

Get-FreeSpace was previously built with SAPIEN PowerShell Studio into `get-freespace.exe`
and an MSI. That dependency is gone: the project is a plain PowerShell module with a CLI
wrapper, and nothing in it requires a proprietary IDE or build host.

Two facts from the old installer are worth preserving and are recorded below, because
machines in the field still carry the 1.3.5.0 MSI.

## Shipping as a module (preferred)

```powershell
Publish-PSResource -Path . -Repository PSGallery -ApiKey $env:PSGallery_API_Key
```

Use `Publish-PSResource` (Microsoft.PowerShell.PSResourceGet), not the legacy
`Publish-Module`, which fails on this machine with a dotnet pack error.

Consumers then get `Install-PSResource Get-FreeSpace` and call `Invoke-FreeSpace`
directly. For RMM use this is the least fragile option: no binary to sign, no installer
identity to manage, and the scheduled command is one line.

Manual deployment is equally valid: copy the repo to
`C:\Program Files\WindowsPowerShell\Modules\Get-FreeSpace\<version>\` and the module is
importable by name.

## Shipping as an executable (only if a binary is still required)

Any packager works, since the entry point is an ordinary script. `ps2exe` is the usual
choice. Whatever is used, the payload must include the module beside the wrapper:

```
Get-FreeSpace.ps1     entry point
Get-FreeSpace.psd1
Get-FreeSpace.psm1
Public\*.ps1
Private\*.ps1
paths.json            offline fallback list
get_freespace.ico     icon, if the packager wants one
```

`Tests\` is not part of the payload. A build that ships only the wrapper fails at startup
with "module not found next to this script".

The tool needs elevation to see other user profiles, so the package should request admin.

## Installer identity, if an MSI is ever rebuilt

Reuse these so existing installs upgrade rather than side-install:

| Setting | Value |
| --- | --- |
| ProductGUID | `{DCD33BCE-C996-4E9B-9044-B77CCCB33EAD}` |
| UpgradeGUID | `{21C13EEE-E023-4C8E-BC5B-048D2B669921}` |
| Last shipped version | `1.3.5.0` (2024) |
| Install folder | `[ProgramFiles]\Get-FreeSpace` |
| Scope | All users, elevated |
| Platform | 64-bit |
| Shortcut | Start Menu\Programs -> `get-freespace.exe`, icon `get_freespace.ico` |

Next release is `2.0.0`, which is a version decrease relative to the old file versioning
scheme (1.3.5.0). An MSI upgrade from the 1.x installer therefore will not trigger
automatically; uninstall the old MSI, or publish the module and retire the installer.

## Engine

The code runs on Windows PowerShell 5.1 and PowerShell 7, and the Pester suite is kept
green on both. The 2024 constraint that pinned packaging to Windows PowerShell
(`Out-GridView` and the `PresentationFramework` popup) no longer applies: the selection UI
falls back across `Out-ConsoleGridView`, `Out-GridView` and a console prompt, and the
popup degrades to console output.
