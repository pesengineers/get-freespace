function Get-FSCleanupList
{
    <#
        .SYNOPSIS
            Loads and normalizes the cleanup list from a URL or a local file.

        .DESCRIPTION
            Entry schema:
                name          required, display label
                path          required, may contain wildcards, may end in a separator
                description   optional
                retain_days   optional, keep items whose activity is newer than N days
                aged          deprecated alias for retain_days, still honored
                scope         optional, 'file' (default) or 'folder'

            scope 'file' evaluates every file under the target individually, which is what
            Revit Journals needs. scope 'folder' evaluates each immediate child folder as a
            unit and keeps the whole folder if anything inside it is recent, which is how
            CollaborationCache is used.
    #>
    [OutputType([pscustomobject])]
    param
    (
        [Parameter(Mandatory)]
        [string]$Source
    )

    $raw = $null
    if (Test-Path -LiteralPath $Source)
    {
        $raw = Get-Content -LiteralPath $Source -Raw -ErrorAction Stop
    }
    else
    {
        $previous = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        try
        {
            $response = Invoke-WebRequest -Uri $Source -UseBasicParsing -ErrorAction Stop
            $raw = [string]$response.Content
        }
        finally
        {
            $ProgressPreference = $previous
        }
    }

    if ([string]::IsNullOrWhiteSpace($raw))
    {
        throw "Cleanup list at '$Source' was empty."
    }

    try
    {
        $parsed = $raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch
    {
        throw "Cleanup list at '$Source' is not valid JSON. $($_.Exception.Message)"
    }

    $entries = @($parsed.cleanup_paths)
    if ($entries.Count -eq 0)
    {
        throw "Cleanup list at '$Source' contains no cleanup_paths entries."
    }

    foreach ($entry in $entries)
    {
        if ([string]::IsNullOrWhiteSpace($entry.path))
        {
            Write-Warning "Skipping cleanup list entry with no path: $($entry.name)"
            continue
        }

        $retain = 0
        $names = @($entry.PSObject.Properties.Name)
        if ($names -contains 'retain_days' -and $null -ne $entry.retain_days)
        {
            $retain = [int]$entry.retain_days
        }
        elseif ($names -contains 'aged' -and $null -ne $entry.aged)
        {
            $retain = [int]$entry.aged
        }
        if ($retain -lt 0) { $retain = 0 }

        $scope = 'file'
        if ($names -contains 'scope' -and -not [string]::IsNullOrWhiteSpace($entry.scope))
        {
            $candidate = ([string]$entry.scope).Trim().ToLowerInvariant()
            if ($candidate -in @('file', 'folder'))
            {
                $scope = $candidate
            }
            else
            {
                Write-Warning "Entry '$($entry.name)' has unknown scope '$($entry.scope)'; using 'file'."
            }
        }

        $label = $entry.name
        if ([string]::IsNullOrWhiteSpace($label)) { $label = $entry.path }

        [pscustomobject]@{
            Name        = [string]$label
            Path        = [string]$entry.path
            Description = [string]$entry.description
            RetainDays  = $retain
            Scope       = $scope
        }
    }
}
