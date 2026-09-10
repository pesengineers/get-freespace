function Get-FreeSpace
{
    <#
        .SYNOPSIS
            Scans the cleanup list and reports reclaimable space, honoring retention.

        .DESCRIPTION
            Read only. Every returned row is one resolved folder (the wildcards in the
            cleanup list expand per user profile) and carries both what retention allows to
            be deleted and what it protects, plus the exact item objects behind those
            numbers so Invoke-FreeSpace deletes precisely what was reported.

            Retention for a row is the larger of the entry's retain_days and the global
            -RetainDays floor, so an RMM job can guarantee a grace period no matter what
            the published list says.

        .PARAMETER Source
            URL or local path of the cleanup list JSON.

        .PARAMETER RetainDays
            Global minimum retention in days. Applied as a floor over every entry.

        .PARAMETER SkipWindowsTemp
            Omit the machine wide C:\Windows\Temp entry, which is appended automatically.

        .EXAMPLE
            Get-FreeSpace -RetainDays 3 | Format-Table Name, Path, ReclaimableSize, RetainedSize

        .OUTPUTS
            GetFreeSpace.Target
    #>
    [CmdletBinding()]
    [OutputType('GetFreeSpace.Target')]
    param
    (
        [ValidateNotNullOrEmpty()]
        [string]$Source = 'https://raw.githubusercontent.com/DailenG/FreespacePaths/main/paths.json',

        [ValidateRange(0, 3650)]
        [int]$RetainDays = 0,

        [switch]$SkipWindowsTemp
    )

    $entries = @(Get-FSCleanupList -Source $Source)
    Write-Verbose "Loaded $($entries.Count) cleanup entries from $Source"

    if (-not $SkipWindowsTemp)
    {
        $entries += [pscustomobject]@{
            Name        = 'Windows Temp'
            Path        = Join-Path $env:SystemRoot 'Temp'
            Description = 'Machine wide Windows temp folder'
            RetainDays  = 0
            Scope       = 'file'
        }
    }

    $trackLastAccess = Test-FSLastAccessTracking
    if (-not $trackLastAccess)
    {
        Write-Warning 'NTFS last access updates are disabled on this machine, so retention uses LastWriteTime and CreationTime only. Files that are read but never rewritten may look older than they are.'
    }

    $now = Get-Date

    foreach ($entry in $entries)
    {
        $effectiveRetain = [math]::Max([int]$entry.RetainDays, $RetainDays)
        $cutoff = $now.AddDays(- $effectiveRetain)

        # Cleanup list paths carry wildcards and a trailing separator, so this resolves to
        # the target containers themselves (one per matching profile), not their children.
        $targets = @(Get-ChildItem -Path $entry.Path -Force -Directory -ErrorAction SilentlyContinue)
        if ($targets.Count -eq 0)
        {
            Write-Verbose "No targets matched '$($entry.Path)' for entry '$($entry.Name)'."
            continue
        }

        foreach ($target in $targets)
        {
            $plan = Get-FSTargetPlan -Path $target.FullName -Scope $entry.Scope -Cutoff $cutoff -IncludeLastAccess:$trackLastAccess

            [pscustomobject]@{
                PSTypeName       = 'GetFreeSpace.Target'
                Name             = $entry.Name
                Path             = $target.FullName
                Scope            = $entry.Scope
                RetainDays       = $effectiveRetain
                Cutoff           = $cutoff
                ReclaimableBytes = $plan.ReclaimableBytes
                ReclaimableSize  = Convert-FSSize -Bytes $plan.ReclaimableBytes
                ReclaimableCount = $plan.ReclaimableCount
                RetainedBytes    = $plan.RetainedBytes
                RetainedSize     = Convert-FSSize -Bytes $plan.RetainedBytes
                RetainedCount    = $plan.RetainedCount
                Items            = $plan.Items
            }
        }
    }
}
