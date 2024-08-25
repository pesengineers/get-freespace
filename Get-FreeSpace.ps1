# Parameters
param (
    [switch]$Force,
    [switch]$NoDisplay,
    [string]$Source="https://raw.githubusercontent.com/DailenG/FreespacePaths/main/paths.json"
)


# Define function to calculate folder size
function Get-FolderSize
{
    param (
        [string]$Path
    )
    $totalSize = 0
    
    if (Test-Path $Path)
    {
        $items = Get-ChildItem -Path $Path -Recurse -ErrorAction SilentlyContinue
        foreach ($item in $items)
        {
            if ($item -is [System.IO.FileInfo])
            {
                $totalSize += $item.Length
            }
        }
    }
    return $totalSize
}

# Define function to convert size to human-readable format
function Convert-Size
{
    param (
        [int64]$Size
    )
    $sizes = "B", "KB", "MB", "GB", "TB"
    $order = 0
    while ($Size -ge 1024 -and $order -lt $sizes.Length - 1)
    {
        $order++
        $Size = [math]::Round($Size / 1024, 2)
    }
    return "{0} {1}" -f $Size, $sizes[$order]
}

# Define function to delete folder contents
function Remove-FolderContents
{
    param (
        [string]$Path,
        [switch]$Force
    )
    
    if ($Force)
    {
        Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
    else
    {
        Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -ErrorAction SilentlyContinue
    }
}

Write-output "Loading list from $Source"
try
{
    $pathsRaw = Invoke-WebRequest $Source -UseBasicParsing
}
catch
{
    Write-Error "Unable to load list from $Source"
}


# $pathsRaw = Get-Content $PSScriptRoot\paths.json
$paths = ($pathsRaw | ConvertFrom-Json).cleanup_paths


# Add C:\Windows\Temp as a single entry
$windowsTempPath = "C:\Windows\Temp\"

$totalSize = 0
$pathSizes = @()

# Inform user about the ongoing size calculation
Write-Output "Please wait...Finding potential free space..."

# Calculate total size and store individual path sizes
foreach ($path in $paths)
{
    $exclusionDate = (Get-Date).AddDays(-$path.aged)
    $expandedPaths = Get-ChildItem -Path $path.path -Directory -ErrorAction SilentlyContinue | Where-Object { $_.LastAccessTime -lt $exclusionDate }
    
    foreach ($expandedPath in $expandedPaths)
    {
        $folderSize = Get-FolderSize -Path $expandedPath
        $totalSize += $folderSize
        $humanReadableSize = Convert-Size -Size $folderSize
        $pathSizes += [PSCustomObject]@{
            'Path' = $expandedPath
            'Size' = $humanReadableSize
        }
    }
}

# Calculate the size for C:\Windows\Temp\ and add to the list
$windowsTempSize = Get-FolderSize -Path $windowsTempPath
$totalSize += $windowsTempSize
$humanReadableTempSize = Convert-Size -Size $windowsTempSize
$pathSizes += [PSCustomObject]@{
    'Path' = $windowsTempPath
    'Size' = $humanReadableTempSize
}

$totalHumanReadableSize = Convert-Size -Size $totalSize

# Add dummy entry for "All Paths"
$pathSizes = ,([PSCustomObject]@{
        'Path' = "All Paths"
        'Size' = $totalHumanReadableSize
    }) + $pathSizes

# Display the sizes in a table
$pathSizes | Format-Table -AutoSize

Write-Output "Total size capable of being freed: $totalHumanReadableSize"

# User selection via Out-GridView or prompt in terminal
if (-Not($Force))
{
    if ($NoDisplay)
    {
        $response = Read-Host "Do you want to remove the contents of all these locations? (Y/N)"
        if ($response -ne "Y")
        {
            Write-Output "Aborted."
            return
        }
        $pathsToDelete = $pathSizes.Path[1 .. ($pathSizes.Count - 1)] # Exclude dummy "All Paths" entry
    }
    else
    {
        $gridViewTitle = "CTRL-Click to select the ones you want to empty - Total Space: $totalHumanReadableSize"
        $selectedPaths = $pathSizes | Out-GridView -Title $gridViewTitle -OutputMode Multiple
        
        if ($null -eq $selectedPaths)
        {
            Write-Output "No paths selected. Aborted."
            return
        }
        if ($selectedPaths.Path -contains "All Paths" -or $selectedPaths.Count -eq 0)
        {
            $pathsToDelete = $pathSizes.Path[1 .. ($pathSizes.Count - 1)] # Exclude dummy "All Paths" entry
        }
        else
        {
            $pathsToDelete = $selectedPaths.Path
        }
    }
}
else
{
    # Force deletion, include all paths
    $pathsToDelete = $pathSizes.Path[1 .. ($pathSizes.Count - 1)] # Exclude dummy "All Paths" entry
}

$freedSize = 0

# Delete contents and calculate freed size
foreach ($path in $pathsToDelete)
{
    Write-Output "Deleting contents of $path"
    $sizeBefore = Get-FolderSize -Path $path
    Remove-FolderContents -Path $path -Force
    $sizeAfter = Get-FolderSize -Path $path
    $freedSize += ($sizeBefore - $sizeAfter)
}

# If we calculate a negative number for some reason, lets just set the space freed to zero
if ($freedSize -lt 0)
{
    $freedSize = 0
}

# Convert freed size to human-readable format
$humanReadableFreedSize = Convert-Size -Size $freedSize

if (-Not($Force))
{
    if(-Not($NoDisplay))
    {
        # Display popup with freed size
        Add-Type -AssemblyName PresentationFramework
        [System.Windows.MessageBox]::Show("Actual freed space: $humanReadableFreedSize", "Space Freed", "OK", "Information")
    }
}

Write-Output "Freed space: $humanReadableFreedSize"
Write-Output "Completed."
    