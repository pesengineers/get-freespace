@{
	RootModule            = 'Get-FreeSpace.psm1'
	ModuleVersion         = '2.0.0'
	GUID                  = '13c7199e-25a5-413d-9044-163bff1ea894'
	Author                = 'Dailen Gunter'
	CompanyName           = 'Dailen'
	Copyright             = '(c) 2024-2026 Dailen Gunter. All rights reserved.'
	Description           = 'Reclaims temporary space consumed by Autodesk and Windows, with per item retention windows so recent files such as Revit journals survive a scheduled cleanup.'
	PowerShellVersion     = '5.1'
	CompatiblePSEditions  = @('Desktop', 'Core')
	FunctionsToExport     = @('Get-FreeSpace', 'Invoke-FreeSpace')
	CmdletsToExport       = @()
	VariablesToExport     = @()
	AliasesToExport       = @()
	FileList              = @('Get-FreeSpace.psm1', 'Get-FreeSpace.psd1', 'Get-FreeSpace.ps1', 'paths.json')

	PrivateData           = @{
		PSData = @{
			Tags         = @('Autodesk', 'Revit', 'Cleanup', 'DiskSpace', 'Windows', 'RMM')
			LicenseUri   = 'https://github.com/DailenG/get-freespace/blob/main/LICENSE'
			ProjectUri   = 'https://github.com/DailenG/get-freespace'
			ReleaseNotes = @'
2.0.0
- Retention is now per item instead of per folder. retain_days keeps files whose activity
  is newer than N days; the deprecated aged key is still honored as an alias.
- Activity is the newest of LastWriteTime, CreationTime and, when NTFS still records it,
  LastAccessTime, so components that are read but rarely rewritten are not deleted.
- New global -RetainDays floor that overrides the published list, for scheduled runs.
- scope 'folder' keeps a child folder whole when anything inside it is recent, which is how
  CollaborationCache is used; scope 'file' is the default.
- Restructured from a single script into a module with -WhatIf support on every
  destructive path.
- Selection UI picks Out-ConsoleGridView on PowerShell 7 and Out-GridView on 5.1.
- Unattended runs gain -LogPath, -AsJson and -Quiet, plus an elevation warning.
- Freed space is measured from confirmed deletions instead of parsed from display strings.
'@
		}
	}
}
