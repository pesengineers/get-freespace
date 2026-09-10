function Write-FSLog
{
    <#
        .SYNOPSIS
            Emits a message to the chosen stream and, when configured, to a log file.

        .DESCRIPTION
            Unattended RMM runs need a durable record, so $script:FSLogPath is set by the
            public functions and every message is appended there with a timestamp. Console
            output is suppressed when $script:FSQuiet is set, but file logging continues.
    #>
    param
    (
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [string]$Message,

        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )

    if ($script:FSLogPath)
    {
        $line = '{0} [{1}] {2}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'), $Level.ToUpperInvariant(), $Message
        try
        {
            Add-Content -LiteralPath $script:FSLogPath -Value $line -Encoding UTF8 -ErrorAction Stop
        }
        catch
        {
            Write-Warning "Unable to write to log '$script:FSLogPath': $($_.Exception.Message)"
            $script:FSLogPath = $null
        }
    }

    switch ($Level)
    {
        'Warning' { Write-Warning $Message }
        'Error'   { Write-Error $Message }
        default
        {
            if (-not $script:FSQuiet) { Write-Output $Message }
        }
    }
}
