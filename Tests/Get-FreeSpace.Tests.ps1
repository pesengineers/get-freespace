#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    $script:Root = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $script:Root 'Get-FreeSpace.psd1') -Force

    function New-TestFile
    {
        param ([string]$Path, [int]$AgeDays, [int]$Bytes = 1024)

        $directory = Split-Path -Parent $Path
        if (-not (Test-Path -LiteralPath $directory)) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }

        [System.IO.File]::WriteAllBytes($Path, (New-Object byte[] $Bytes))
        $stamp = (Get-Date).AddDays(- $AgeDays)
        $item = Get-Item -LiteralPath $Path
        $item.LastWriteTime = $stamp
        $item.CreationTime = $stamp
        $item.LastAccessTime = $stamp
    }

    function Set-TestFolderAge
    {
        param ([string]$Path, [int]$AgeDays)

        $stamp = (Get-Date).AddDays(- $AgeDays)
        $item = Get-Item -LiteralPath $Path
        $item.LastWriteTime = $stamp
        $item.CreationTime = $stamp
        $item.LastAccessTime = $stamp
    }

    function New-TestList
    {
        param ([string]$Path, [string]$TargetPath, [int]$RetainDays, [string]$Scope = 'file', [string]$Key = 'retain_days')

        $json = @"
{
  "cleanup_paths": [
    {
      "name": "Test Target",
      "path": "$($TargetPath -replace '\\', '\\\\')",
      "description": "test",
      "$Key": $RetainDays,
      "scope": "$Scope"
    }
  ]
}
"@
        Set-Content -LiteralPath $Path -Value $json -Encoding UTF8
    }
}

Describe 'Retention windows' {

    BeforeEach {
        $script:Sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("gfs-" + [guid]::NewGuid().ToString('N'))
        $script:Journals = Join-Path $script:Sandbox 'Users\alice\Journals'
        New-TestFile -Path (Join-Path $script:Journals 'journal.old.txt') -AgeDays 30 -Bytes 4096
        New-TestFile -Path (Join-Path $script:Journals 'journal.yesterday.txt') -AgeDays 1 -Bytes 2048
        $script:ListPath = Join-Path $script:Sandbox 'list.json'
        New-TestList -Path $script:ListPath -TargetPath ((Join-Path $script:Sandbox 'Users\*\Journals') + '\') -RetainDays 7
    }

    AfterEach {
        Remove-Item -LiteralPath $script:Sandbox -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'keeps files inside the retention window and reclaims only the older ones' {
        $target = Get-FreeSpace -Source $script:ListPath -SkipWindowsTemp
        $target.ReclaimableBytes | Should -Be 4096
        $target.RetainedBytes | Should -Be 2048
        $target.Items.Name | Should -Be 'journal.old.txt'
    }

    It 'deletes only the stale file and leaves the recent one on disk' {
        $summary = Invoke-FreeSpace -Source $script:ListPath -SkipWindowsTemp -Force -Quiet
        $summary.TotalFreedBytes | Should -Be 4096
        Test-Path (Join-Path $script:Journals 'journal.old.txt') | Should -BeFalse
        Test-Path (Join-Path $script:Journals 'journal.yesterday.txt') | Should -BeTrue
    }

    It 'deletes nothing under -WhatIf' {
        $summary = Invoke-FreeSpace -Source $script:ListPath -SkipWindowsTemp -Force -Quiet -WhatIf
        $summary.TotalFreedBytes | Should -Be 0
        Test-Path (Join-Path $script:Journals 'journal.old.txt') | Should -BeTrue
    }

    It 'applies -RetainDays as a floor over the list value' {
        $target = Get-FreeSpace -Source $script:ListPath -SkipWindowsTemp -RetainDays 90
        $target.RetainDays | Should -Be 90
        $target.ReclaimableBytes | Should -Be 0
        $target.RetainedBytes | Should -Be 6144
    }

    It 'never lowers retention below the list value' {
        $target = Get-FreeSpace -Source $script:ListPath -SkipWindowsTemp -RetainDays 1
        $target.RetainDays | Should -Be 7
    }

    It 'honors the deprecated aged key as an alias for retain_days' {
        New-TestList -Path $script:ListPath -TargetPath ((Join-Path $script:Sandbox 'Users\*\Journals') + '\') -RetainDays 7 -Key 'aged'
        $target = Get-FreeSpace -Source $script:ListPath -SkipWindowsTemp
        $target.RetainDays | Should -Be 7
        $target.ReclaimableBytes | Should -Be 4096
    }
}

Describe 'Scope handling' {

    BeforeEach {
        $script:Sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("gfs-" + [guid]::NewGuid().ToString('N'))
        $script:Cache = Join-Path $script:Sandbox 'Users\alice\CollaborationCache'
        New-TestFile -Path (Join-Path $script:Cache 'ActiveModel\old-chunk.dat') -AgeDays 60 -Bytes 8192
        New-TestFile -Path (Join-Path $script:Cache 'ActiveModel\fresh-chunk.dat') -AgeDays 0 -Bytes 1024
        New-TestFile -Path (Join-Path $script:Cache 'DeadModel\chunk.dat') -AgeDays 60 -Bytes 4096
        # A real abandoned model cache folder is itself old; only the fixture would leave
        # directory timestamps at "now", and folder scope reads those too.
        Set-TestFolderAge -Path (Join-Path $script:Cache 'DeadModel') -AgeDays 60
        Set-TestFolderAge -Path (Join-Path $script:Cache 'ActiveModel') -AgeDays 60
        $script:ListPath = Join-Path $script:Sandbox 'list.json'
        New-TestList -Path $script:ListPath -TargetPath ((Join-Path $script:Sandbox 'Users\*\CollaborationCache') + '\') -RetainDays 7 -Scope 'folder'
    }

    AfterEach {
        Remove-Item -LiteralPath $script:Sandbox -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'keeps a whole folder when any file inside it is recent' {
        $summary = Invoke-FreeSpace -Source $script:ListPath -SkipWindowsTemp -Force -Quiet
        Test-Path (Join-Path $script:Cache 'ActiveModel\old-chunk.dat') | Should -BeTrue
        Test-Path (Join-Path $script:Cache 'DeadModel') | Should -BeFalse
        $summary.TotalFreedBytes | Should -Be 4096
    }
}

Describe 'Activity timestamps' {

    BeforeEach {
        $script:Sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("gfs-" + [guid]::NewGuid().ToString('N'))
        $script:Target = Join-Path $script:Sandbox 'Users\alice\Journals'
        New-TestFile -Path (Join-Path $script:Target 'read-often.dat') -AgeDays 120 -Bytes 2048
        $script:ListPath = Join-Path $script:Sandbox 'list.json'
        New-TestList -Path $script:ListPath -TargetPath ((Join-Path $script:Sandbox 'Users\*\Journals') + '\') -RetainDays 30
    }

    AfterEach {
        Remove-Item -LiteralPath $script:Sandbox -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'protects a file that is old on disk but was read recently' {
        # LastAccessTime only carries signal when NTFS is still recording it. Where it is
        # disabled the module deliberately ignores it, so assert the documented behavior
        # for whichever mode this machine is in.
        $trackingEnabled = $true
        try
        {
            $raw = [int64](Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'NtfsDisableLastAccessUpdate' -ErrorAction Stop).NtfsDisableLastAccessUpdate
            $trackingEnabled = (($raw -band 1) -eq 0)
        }
        catch { $trackingEnabled = $true }

        (Get-Item (Join-Path $script:Target 'read-often.dat')).LastAccessTime = (Get-Date).AddHours(-2)
        $target = Get-FreeSpace -Source $script:ListPath -SkipWindowsTemp -WarningAction SilentlyContinue

        if ($trackingEnabled)
        {
            $target.ReclaimableBytes | Should -Be 0
            $target.RetainedBytes | Should -Be 2048
        }
        else
        {
            $target.ReclaimableBytes | Should -Be 2048
        }
    }
}

Describe 'Unattended output' {

    BeforeEach {
        $script:Sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("gfs-" + [guid]::NewGuid().ToString('N'))
        New-TestFile -Path (Join-Path $script:Sandbox 'Users\alice\Journals\stale.txt') -AgeDays 45 -Bytes 1024
        $script:ListPath = Join-Path $script:Sandbox 'list.json'
        New-TestList -Path $script:ListPath -TargetPath ((Join-Path $script:Sandbox 'Users\*\Journals') + '\') -RetainDays 0
    }

    AfterEach {
        Remove-Item -LiteralPath $script:Sandbox -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'returns parseable JSON and writes a log when asked' {
        $logPath = Join-Path $script:Sandbox 'run.log'
        $json = Invoke-FreeSpace -Source $script:ListPath -SkipWindowsTemp -Force -AsJson -LogPath $logPath
        $summary = $json | ConvertFrom-Json
        $summary.TotalFreedBytes | Should -Be 1024
        $summary.FailureCount | Should -Be 0
        (Get-Content -LiteralPath $logPath -Raw) | Should -Match 'Freed 1 KB'
    }
}

Describe 'Cleanup list validation' {

    It 'fails loudly on malformed JSON instead of scanning nothing' {
        $bad = Join-Path ([System.IO.Path]::GetTempPath()) ("gfs-bad-" + [guid]::NewGuid().ToString('N') + '.json')
        Set-Content -LiteralPath $bad -Value '{ not json' -Encoding UTF8
        { Get-FreeSpace -Source $bad -SkipWindowsTemp } | Should -Throw '*not valid JSON*'
        Remove-Item -LiteralPath $bad -Force
    }
}
