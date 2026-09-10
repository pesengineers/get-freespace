function Test-FSLastAccessTracking
{
    <#
        .SYNOPSIS
            Reports whether NTFS last access time updates are enabled on this machine.

        .DESCRIPTION
            HKLM\SYSTEM\CurrentControlSet\Control\FileSystem\NtfsDisableLastAccessUpdate
            carries the setting in bit 0: 0 means updates are enabled, 1 means disabled.
            Bit 1 distinguishes system managed from user managed and is irrelevant here.
            When the value is missing, Windows defaults to system managed and enabled.

            This matters because a frozen LastAccessTime makes every file look untouched,
            which would let retention delete data that is actively in use. Callers drop
            LastAccessTime from the activity calculation when this returns $false.

            Result is cached for the life of the session.
    #>
    [OutputType([bool])]
    param
    (
        [switch]$Refresh
    )

    if ($Refresh) { $script:FSLastAccessTracking = $null }
    if ($null -ne $script:FSLastAccessTracking) { return $script:FSLastAccessTracking }

    $enabled = $true
    try
    {
        $key = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'NtfsDisableLastAccessUpdate' -ErrorAction Stop
        $raw = [int64]$key.NtfsDisableLastAccessUpdate
        $enabled = (($raw -band 1) -eq 0)
    }
    catch
    {
        $enabled = $true
    }

    $script:FSLastAccessTracking = $enabled
    return $enabled
}
