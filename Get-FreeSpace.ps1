#Requires -Version 5.1
<#
    .SYNOPSIS
        Command line entry point for Get-FreeSpace. This is the file that gets packaged
        into get-freespace.exe and the MSI.

    .DESCRIPTION
        Thin wrapper over the module that sits beside it. All behavior lives in
        Get-FreeSpace.psm1 so the module and the packaged executable cannot drift apart.

        If the remote cleanup list cannot be fetched, the bundled paths.json next to this
        script is used, so a scheduled run on a machine with no internet still cleans up.

    .PARAMETER Source
        URL or local path of the cleanup list JSON.

    .PARAMETER RetainDays
        Global minimum retention in days, applied as a floor over every list entry. Set
        this on scheduled runs so an incident that happened yesterday is still reviewable
        tomorrow.

    .PARAMETER Force
        Purge everything reclaimable without prompting.

    .PARAMETER NoDisplay
        Use a console prompt instead of a grid view.

    .PARAMETER GridView
        Auto, Console (Out-ConsoleGridView) or Window (Out-GridView).

    .PARAMETER SkipWindowsTemp
        Do not include the machine wide C:\Windows\Temp folder.

    .PARAMETER LogPath
        Append a timestamped transcript of the run to this file.

    .PARAMETER AsJson
        Emit a JSON summary instead of prose. Implies -Quiet.

    .PARAMETER Quiet
        Suppress console output. File logging is unaffected.

    .EXAMPLE
        .\Get-FreeSpace.ps1

    .EXAMPLE
        .\Get-FreeSpace.ps1 -Force -RetainDays 3 -Quiet -AsJson -LogPath 'C:\ProgramData\Get-FreeSpace\cleanup.log'

    .EXAMPLE
        .\Get-FreeSpace.ps1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param
(
    [string]$Source = 'https://raw.githubusercontent.com/pesengineers/FreespacePaths/main/paths.json',

    [ValidateRange(0, 3650)]
    [int]$RetainDays = 0,

    [switch]$Force,

    [switch]$NoDisplay,

    [ValidateSet('Auto', 'Console', 'Window')]
    [string]$GridView = 'Auto',

    [switch]$SkipWindowsTemp,

    [string]$LogPath,

    [switch]$AsJson,

    [switch]$Quiet
)

$manifest = Join-Path $PSScriptRoot 'Get-FreeSpace.psd1'
if (-not (Test-Path -LiteralPath $manifest))
{
    throw "Get-FreeSpace module not found next to this script (expected '$manifest')."
}

Import-Module -Name $manifest -Force -ErrorAction Stop

$effectiveSource = $Source
$bundled = Join-Path $PSScriptRoot 'paths.json'
if ($Source -notmatch '^[a-z]+://')
{
    # Local path, nothing to probe.
}
else
{
    try
    {
        $previousProgress = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        [void](Invoke-WebRequest -Uri $Source -UseBasicParsing -ErrorAction Stop)
    }
    catch
    {
        if (Test-Path -LiteralPath $bundled)
        {
            Write-Warning "Unable to load '$Source' ($($_.Exception.Message)). Falling back to the bundled paths.json."
            $effectiveSource = $bundled
        }
        else
        {
            throw
        }
    }
    finally
    {
        $ProgressPreference = $previousProgress
    }
}

$arguments = @{
    Source          = $effectiveSource
    RetainDays      = $RetainDays
    Force           = $Force
    NoDisplay       = $NoDisplay
    GridView        = $GridView
    SkipWindowsTemp = $SkipWindowsTemp
    AsJson          = $AsJson
    Quiet           = $Quiet
}
if ($LogPath) { $arguments['LogPath'] = $LogPath }
if ($PSBoundParameters.ContainsKey('WhatIf')) { $arguments['WhatIf'] = $WhatIfPreference }
if ($PSBoundParameters.ContainsKey('Confirm')) { $arguments['Confirm'] = $PSBoundParameters['Confirm'] }

Invoke-FreeSpace @arguments
