#requires -version 5.0

$psVersion = $PSVersionTable.PSVersion
if ($psVersion.Major -ne 5) {
    Write-Error "This script requires PowerShell version 5.x."
    exit
}

import-module ps2exe

####################

if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") { 
       $ScriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition 
} else { $ScriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
       if (!$ScriptPath) {
              $ScriptPath = "." 
       } 
}

# $existingVersion = Get-Content 

$opts = @{
       inputFile = "$ScriptPath\Get-FreeSpace.ps1"
       outputFile = "$ScriptPath\Get-FreeSpace.exe"
       version = "1.2.1.0"
       product = "Get-FreeSpace1"
       title = "Utility to free up temporary space consumed by Autodesk and Windows" # Goes in the file property description
       copyright = "2024"
       company = "Dailen"
       iconFile = "$ScriptPath\get-freespace.ico"
       requireAdmin = $true
}

ps2exe @opts
