function Remove-FSEmptyDirectory
{
    <#
        .SYNOPSIS
            Removes directories left empty by a purge, deepest first.

        .DESCRIPTION
            File scoped cleanup deletes files and leaves the skeleton behind. This prunes
            that skeleton without touching the target root itself and without removing any
            directory that still holds retained data.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) { return }

    $directories = @(Get-ChildItem -LiteralPath $Path -Force -Recurse -Directory -ErrorAction SilentlyContinue) |
        Sort-Object -Property { $_.FullName.Length } -Descending

    foreach ($directory in $directories)
    {
        if (@(Get-ChildItem -LiteralPath $directory.FullName -Force -ErrorAction SilentlyContinue).Count -ne 0)
        {
            continue
        }

        if ($PSCmdlet.ShouldProcess($directory.FullName, 'Remove empty directory'))
        {
            Remove-Item -LiteralPath $directory.FullName -Force -ErrorAction SilentlyContinue
        }
    }
}
