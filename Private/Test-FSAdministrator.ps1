function Test-FSAdministrator
{
    <#
        .SYNOPSIS
            True when the session is elevated.

        .DESCRIPTION
            Without elevation the wildcard expansion over C:\Users silently sees only the
            current profile, so an unattended run would report a fraction of the real
            reclaimable space and look successful. Callers warn instead of failing quietly.
    #>
    [OutputType([bool])]
    param ()

    try
    {
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch
    {
        return $false
    }
}
