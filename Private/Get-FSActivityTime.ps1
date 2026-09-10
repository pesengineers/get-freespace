function Get-FSActivityTime
{
    <#
        .SYNOPSIS
            Returns the most recent evidence that a file or folder is still in use.

        .DESCRIPTION
            Large Autodesk projects contain components that are read constantly but not
            rewritten for months, so LastWriteTime alone would delete live data. Activity
            is therefore the newest of LastWriteTime, CreationTime and, when NTFS is still
            recording it, LastAccessTime.

            Note that NTFS throttles last access updates to roughly one hour, so activity
            is accurate to the hour at best. Retention windows are measured in days, so
            that resolution is not a problem.
    #>
    [OutputType([datetime])]
    param
    (
        [Parameter(Mandatory)]
        [System.IO.FileSystemInfo]$Item,

        [switch]$IncludeLastAccess
    )

    $activity = $Item.LastWriteTime
    if ($Item.CreationTime -gt $activity) { $activity = $Item.CreationTime }
    if ($IncludeLastAccess -and $Item.LastAccessTime -gt $activity) { $activity = $Item.LastAccessTime }

    return $activity
}
