function Invoke-FreeSpace
{
    <#
        .SYNOPSIS
            Scans, selects and purges reclaimable space, honoring retention windows.

        .DESCRIPTION
            Interactive by default: a grid view lists every resolved folder with what can
            be freed and what retention is protecting. -NoDisplay swaps the grid for a
            console prompt, -Force runs unattended.

            Supports -WhatIf and -Confirm. Always returns a summary object, which -AsJson
            renders as JSON for RMM consumption.

        .PARAMETER Source
            URL or local path of the cleanup list JSON.

        .PARAMETER RetainDays
            Global minimum retention in days, applied as a floor over every list entry.
            Use this to guarantee a grace period regardless of the published list.

        .PARAMETER Force
            Purge everything reclaimable without prompting and without the completion
            popup. Still honors -WhatIf.

        .PARAMETER NoDisplay
            Replace the grid view with a console Y/N prompt.

        .PARAMETER GridView
            Which picker to use: Auto (console grid on PowerShell 7, window grid on 5.1),
            Console (Out-ConsoleGridView), or Window (Out-GridView).

        .PARAMETER LogPath
            Append a timestamped transcript of the run to this file.

        .PARAMETER AsJson
            Emit the summary as JSON instead of an object.

        .PARAMETER Quiet
            Suppress progress and table output. File logging is unaffected.

        .EXAMPLE
            Invoke-FreeSpace -Force -RetainDays 3 -LogPath 'C:\ProgramData\Get-FreeSpace\run.log' -Quiet -AsJson

            The unattended RMM shape: purge everything older than three days, log it, and
            return machine readable results.

        .EXAMPLE
            Invoke-FreeSpace -WhatIf

            Report exactly what would be deleted and what retention protects.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([pscustomobject])]
    param
    (
        [ValidateNotNullOrEmpty()]
        [string]$Source = 'https://raw.githubusercontent.com/DailenG/FreespacePaths/main/paths.json',

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

    $started = Get-Date
    $script:FSQuiet = [bool]($Quiet -or $AsJson)
    $script:FSLogPath = $null

    if ($LogPath)
    {
        $logDirectory = Split-Path -Path $LogPath -Parent
        if ($logDirectory -and -not (Test-Path -LiteralPath $logDirectory))
        {
            New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
        }
        $script:FSLogPath = $LogPath
    }

    Write-FSLog "Get-FreeSpace run started on $env:COMPUTERNAME as $env:USERNAME (PowerShell $($PSVersionTable.PSVersion))."
    Write-FSLog "Cleanup list source: $Source"
    Write-FSLog "Global retention floor: $RetainDays day(s)."

    if (-not (Test-FSAdministrator))
    {
        Write-FSLog 'Not running elevated. Only the current user profile and world readable paths will be visible.' -Level Warning
    }

    Write-FSLog 'Scanning for reclaimable space. This can take a while on large temp trees.'

    $targets = @(Get-FreeSpace -Source $Source -RetainDays $RetainDays -SkipWindowsTemp:$SkipWindowsTemp)
    $candidates = @($targets | Where-Object { $_.ReclaimableBytes -gt 0 -or $_.ReclaimableCount -gt 0 })

    $totalReclaimable = [int64]0
    $totalRetained = [int64]0
    foreach ($target in $targets)
    {
        $totalReclaimable += $target.ReclaimableBytes
        $totalRetained += $target.RetainedBytes
    }

    Write-FSLog ("Reclaimable: {0} across {1} location(s). Protected by retention: {2}." -f (Convert-FSSize -Bytes $totalReclaimable), $candidates.Count, (Convert-FSSize -Bytes $totalRetained))

    if (-not $script:FSQuiet -and $targets.Count -gt 0)
    {
        $targets |
            Select-Object Name, Path, @{ N = 'Reclaimable'; E = { $_.ReclaimableSize } }, @{ N = 'Retained'; E = { $_.RetainedSize } }, RetainDays |
            Format-Table -AutoSize |
            Out-String -Width 400 |
            Write-Output
    }

    $selected = @()
    if ($candidates.Count -eq 0)
    {
        Write-FSLog 'Nothing to reclaim.'
    }
    elseif ($Force)
    {
        $selected = $candidates
    }
    elseif ($NoDisplay)
    {
        $answer = Read-Host ("Remove {0} from {1} location(s)? Retention keeps {2}. (Y/N)" -f (Convert-FSSize -Bytes $totalReclaimable), $candidates.Count, (Convert-FSSize -Bytes $totalRetained))
        if ($answer -match '^(y|yes)$')
        {
            $selected = $candidates
        }
        else
        {
            Write-FSLog 'Aborted at the console prompt.'
        }
    }
    else
    {
        $rows = @()
        for ($i = 0; $i -lt $candidates.Count; $i++)
        {
            $rows += [pscustomobject]@{
                Index       = $i
                Name        = $candidates[$i].Name
                Path        = $candidates[$i].Path
                Reclaimable = $candidates[$i].ReclaimableSize
                Items       = $candidates[$i].ReclaimableCount
                Retained    = $candidates[$i].RetainedSize
                KeepDays    = $candidates[$i].RetainDays
            }
        }

        $title = 'Select what to purge. Total reclaimable: {0}' -f (Convert-FSSize -Bytes $totalReclaimable)
        $picked = Select-FSGridView -InputObject $rows -Title $title -Prefer $GridView

        if ($null -eq $picked)
        {
            Write-FSLog 'No grid view is available on this host; falling back to a console prompt.' -Level Warning
            $answer = Read-Host ("Remove {0} from {1} location(s)? (Y/N)" -f (Convert-FSSize -Bytes $totalReclaimable), $candidates.Count)
            if ($answer -match '^(y|yes)$') { $selected = $candidates }
            else { Write-FSLog 'Aborted at the console prompt.' }
        }
        elseif (@($picked).Count -eq 0)
        {
            Write-FSLog 'Nothing selected. Aborted.'
        }
        else
        {
            $selected = @(foreach ($row in $picked) { $candidates[$row.Index] })
        }
    }

    $results = New-Object 'System.Collections.Generic.List[object]'
    $totalFreed = [int64]0
    $failures = New-Object 'System.Collections.Generic.List[string]'

    foreach ($target in $selected)
    {
        Write-FSLog ("Purging {0} from {1} ({2} item(s), keeping {3})." -f $target.ReclaimableSize, $target.Path, $target.ReclaimableCount, $target.RetainedSize)

        # Selection above (grid, prompt, or -Force) is the confirmation, so the helper
        # must not prompt again. -WhatIf still flows through $WhatIfPreference.
        $outcome = Remove-FSPlanItem -Item $target.Items -Confirm:$false
        if (-not $WhatIfPreference)
        {
            Remove-FSEmptyDirectory -Path $target.Path -Confirm:$false
        }

        $totalFreed += $outcome.FreedBytes
        foreach ($failure in $outcome.Failures)
        {
            $failures.Add($failure)
            Write-FSLog $failure -Level Warning
        }

        $results.Add([pscustomobject]@{
                Name             = $target.Name
                Path             = $target.Path
                RetainDays       = $target.RetainDays
                ReclaimableBytes = $target.ReclaimableBytes
                RetainedBytes    = $target.RetainedBytes
                FreedBytes       = $outcome.FreedBytes
                RemovedCount     = $outcome.RemovedCount
                FailureCount     = @($outcome.Failures).Count
            })
    }

    $finished = Get-Date
    $summary = [pscustomobject]@{
        PSTypeName            = 'GetFreeSpace.Summary'
        Computer              = $env:COMPUTERNAME
        StartTime             = $started
        EndTime               = $finished
        DurationSeconds       = [math]::Round(($finished - $started).TotalSeconds, 1)
        Source                = $Source
        RetainDays            = $RetainDays
        WhatIf                = [bool]$WhatIfPreference
        LocationsScanned      = $targets.Count
        LocationsPurged       = $results.Count
        TotalReclaimableBytes = $totalReclaimable
        TotalRetainedBytes    = $totalRetained
        TotalFreedBytes       = $totalFreed
        TotalFreedSize        = Convert-FSSize -Bytes $totalFreed
        FailureCount          = $failures.Count
        Failures              = $failures.ToArray()
        Locations             = $results.ToArray()
    }

    Write-FSLog ("Freed {0} in {1}s across {2} location(s), {3} failure(s)." -f $summary.TotalFreedSize, $summary.DurationSeconds, $summary.LocationsPurged, $summary.FailureCount)

    if (-not $Force -and -not $NoDisplay -and -not $script:FSQuiet -and -not $WhatIfPreference -and $results.Count -gt 0)
    {
        Show-FSCompletionPopup -Message ("Freed space: {0}" -f $summary.TotalFreedSize)
    }

    $script:FSLogPath = $null
    $script:FSQuiet = $false

    if ($AsJson)
    {
        return ($summary | ConvertTo-Json -Depth 5)
    }

    return $summary
}
