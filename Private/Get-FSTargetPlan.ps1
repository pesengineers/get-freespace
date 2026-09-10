function Get-FSTargetPlan
{
    <#
        .SYNOPSIS
            Splits one resolved target folder into what may be deleted and what retention
            protects.

        .DESCRIPTION
            scope 'file': every file under the target is judged on its own activity, so a
            journal written this morning survives while last month's journals go.

            scope 'folder': each immediate child folder is judged as a unit using the
            newest activity found anywhere inside it, so a model's collaboration cache is
            kept whole or removed whole. Loose files sitting directly in the target are
            still judged individually.

            The returned plan carries the actual item objects, so the purge deletes exactly
            what was measured and shown to the operator instead of re-globbing later.
    #>
    [OutputType([pscustomobject])]
    param
    (
        [Parameter(Mandatory)]
        [string]$Path,

        [ValidateSet('file', 'folder')]
        [string]$Scope = 'file',

        [Parameter(Mandatory)]
        [datetime]$Cutoff,

        [switch]$IncludeLastAccess
    )

    $reclaim = New-Object 'System.Collections.Generic.List[object]'
    $reclaimBytes = [int64]0
    $retainBytes = [int64]0
    $retainCount = 0

    if (-not (Test-Path -LiteralPath $Path))
    {
        return [pscustomobject]@{
            Items            = @()
            ReclaimableBytes = [int64]0
            ReclaimableCount = 0
            RetainedBytes    = [int64]0
            RetainedCount    = 0
        }
    }

    if ($Scope -eq 'folder')
    {
        foreach ($child in @(Get-ChildItem -LiteralPath $Path -Force -Directory -ErrorAction SilentlyContinue))
        {
            $descendants = @(Get-ChildItem -LiteralPath $child.FullName -Force -Recurse -ErrorAction SilentlyContinue)
            $bytes = [int64]0
            $newest = Get-FSActivityTime -Item $child -IncludeLastAccess:$IncludeLastAccess

            foreach ($item in $descendants)
            {
                if ($item -is [System.IO.FileInfo]) { $bytes += $item.Length }
                $activity = Get-FSActivityTime -Item $item -IncludeLastAccess:$IncludeLastAccess
                if ($activity -gt $newest) { $newest = $activity }
            }

            if ($newest -lt $Cutoff)
            {
                $reclaim.Add($child)
                $reclaimBytes += $bytes
            }
            else
            {
                $retainBytes += $bytes
                $retainCount++
            }
        }

        $loose = @(Get-ChildItem -LiteralPath $Path -Force -File -ErrorAction SilentlyContinue)
    }
    else
    {
        $loose = @(Get-ChildItem -LiteralPath $Path -Force -File -Recurse -ErrorAction SilentlyContinue)
    }

    foreach ($file in $loose)
    {
        $activity = Get-FSActivityTime -Item $file -IncludeLastAccess:$IncludeLastAccess
        if ($activity -lt $Cutoff)
        {
            $reclaim.Add($file)
            $reclaimBytes += $file.Length
        }
        else
        {
            $retainBytes += $file.Length
            $retainCount++
        }
    }

    return [pscustomobject]@{
        Items            = $reclaim.ToArray()
        ReclaimableBytes = $reclaimBytes
        ReclaimableCount = $reclaim.Count
        RetainedBytes    = $retainBytes
        RetainedCount    = $retainCount
    }
}
