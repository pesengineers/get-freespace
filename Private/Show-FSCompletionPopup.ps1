function Show-FSCompletionPopup
{
    <#
        .SYNOPSIS
            Shows the completion message box, degrading to console output when WPF is not
            available (PowerShell 7 on a machine without the desktop runtime, Server Core).
    #>
    param
    (
        [Parameter(Mandatory)]
        [string]$Message,

        [string]$Title = 'Space Freed'
    )

    try
    {
        Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
        [void][System.Windows.MessageBox]::Show($Message, $Title, 'OK', 'Information')
    }
    catch
    {
        Write-Verbose "Popup unavailable: $($_.Exception.Message)"
        Write-Output $Message
    }
}
