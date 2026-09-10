#Requires -Version 5.1

$script:Public = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -ErrorAction SilentlyContinue)
$script:Private = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -ErrorAction SilentlyContinue)

foreach ($file in @($script:Private + $script:Public))
{
    . $file.FullName
}

Export-ModuleMember -Function $script:Public.BaseName
