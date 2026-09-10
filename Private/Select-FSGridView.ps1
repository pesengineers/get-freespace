function Select-FSGridView
{
    <#
        .SYNOPSIS
            Multi-select picker that adapts to the host: Out-GridView on Windows
            PowerShell, Out-ConsoleGridView on PowerShell 7.

        .DESCRIPTION
            Preference order:
                Out-ConsoleGridView   PowerShell 7 with Microsoft.PowerShell.ConsoleGuiTools
                Out-GridView          Windows PowerShell 5.1, or PS7 with GraphicalTools
            Neither available returns $null so the caller can fall back to a prompt.

            Pass -Prefer to force one of them; unavailable preferences fall through to the
            normal order rather than failing.
    #>
    param
    (
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$InputObject,

        [Parameter(Mandatory)]
        [string]$Title,

        [ValidateSet('Auto', 'Console', 'Window')]
        [string]$Prefer = 'Auto'
    )

    $console = Get-Command -Name 'Out-ConsoleGridView' -ErrorAction SilentlyContinue
    if (-not $console -and $PSVersionTable.PSVersion.Major -ge 6)
    {
        if (Get-Module -ListAvailable -Name 'Microsoft.PowerShell.ConsoleGuiTools' -ErrorAction SilentlyContinue)
        {
            Import-Module -Name 'Microsoft.PowerShell.ConsoleGuiTools' -ErrorAction SilentlyContinue
            $console = Get-Command -Name 'Out-ConsoleGridView' -ErrorAction SilentlyContinue
        }
    }

    $window = Get-Command -Name 'Out-GridView' -ErrorAction SilentlyContinue

    $order = switch ($Prefer)
    {
        'Console' { @($console, $window) }
        'Window'  { @($window, $console) }
        default
        {
            if ($PSVersionTable.PSVersion.Major -ge 6) { @($console, $window) } else { @($window, $console) }
        }
    }

    $candidates = @($order | Where-Object { $_ })
    if ($candidates.Count -eq 0)
    {
        Write-Verbose 'No grid view command is available.'
        return $null
    }

    foreach ($picker in $candidates)
    {
        # Out-ConsoleGridView caps the title width, and it refuses to run when stdin is
        # redirected (scheduled tasks, RMM agents, piped shells). Try the next picker
        # rather than failing the whole run.
        $safeTitle = $Title
        if ($picker.Name -eq 'Out-ConsoleGridView' -and $safeTitle.Length -gt 78)
        {
            $safeTitle = $safeTitle.Substring(0, 78)
        }

        try
        {
            $selection = @($InputObject | & $picker.Name -Title $safeTitle -OutputMode Multiple)
            Write-Verbose "Selection UI: $($picker.Name)"
            return $selection
        }
        catch
        {
            Write-Verbose "$($picker.Name) unavailable: $($_.Exception.Message)"
        }
    }

    return $null
}
