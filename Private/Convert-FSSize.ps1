function Convert-FSSize
{
    <#
        .SYNOPSIS
            Formats a byte count for display. Display only; never parse the result back.
    #>
    [OutputType([string])]
    param
    (
        [Parameter(Mandatory)]
        [AllowNull()]
        [Nullable[double]]$Bytes
    )

    if ($null -eq $Bytes) { return '0 B' }

    $value = [double]$Bytes
    $negative = $value -lt 0
    if ($negative) { $value = - $value }

    $units = @('B', 'KB', 'MB', 'GB', 'TB', 'PB')
    $order = 0
    while ($value -ge 1024 -and $order -lt ($units.Length - 1))
    {
        $value = $value / 1024
        $order++
    }

    $rounded = [math]::Round($value, 2)
    if ($negative) { $rounded = - $rounded }

    return ('{0} {1}' -f $rounded, $units[$order])
}
