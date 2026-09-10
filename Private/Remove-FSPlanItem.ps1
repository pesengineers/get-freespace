function Remove-FSPlanItem
{
    <#
        .SYNOPSIS
            Deletes the items a scan selected and reports bytes actually reclaimed.

        .DESCRIPTION
            Freed space is measured, not estimated: each item's size is taken immediately
            before deletion and only counted once the item is confirmed gone. Locked files
            therefore reduce the reported total instead of inflating it, and every failure
            is returned rather than swallowed.
    #>
    [OutputType([pscustomobject])]
    # Confirmation is the caller's job (grid selection, console prompt, or -Force), so
    # this only participates in ShouldProcess to inherit -WhatIf.
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    param
    (
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Item
    )

    $freed = [int64]0
    $removed = 0
    $failures = New-Object 'System.Collections.Generic.List[string]'

    foreach ($entry in $Item)
    {
        if (-not $entry) { continue }

        $path = $entry.FullName
        if (-not (Test-Path -LiteralPath $path)) { continue }

        $size = [int64]0
        try
        {
            if ($entry -is [System.IO.DirectoryInfo])
            {
                foreach ($file in @(Get-ChildItem -LiteralPath $path -Force -Recurse -File -ErrorAction SilentlyContinue))
                {
                    $size += $file.Length
                }
            }
            else
            {
                $size = [int64]$entry.Length
            }
        }
        catch
        {
            $size = 0
        }

        if (-not $PSCmdlet.ShouldProcess($path, 'Delete'))
        {
            continue
        }

        try
        {
            Remove-Item -LiteralPath $path -Force -Recurse -ErrorAction Stop
        }
        catch
        {
            $failures.Add("$path : $($_.Exception.Message)")
            continue
        }

        if (Test-Path -LiteralPath $path)
        {
            $failures.Add("$path : still present after deletion")
            continue
        }

        $freed += $size
        $removed++
    }

    return [pscustomobject]@{
        FreedBytes   = $freed
        RemovedCount = $removed
        Failures     = $failures.ToArray()
    }
}
