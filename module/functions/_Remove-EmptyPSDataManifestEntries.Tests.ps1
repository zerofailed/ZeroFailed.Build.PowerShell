# <copyright file="_Remove-EmptyPSDataManifestEntries.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    . (Join-Path $PSScriptRoot '_Remove-EmptyPSDataManifestEntries.ps1')

    function New-TestManifest {
        param([string] $Content, [switch] $WithBom)
        $path = Join-Path $TestDrive "$([guid]::NewGuid()).psd1"
        [IO.File]::WriteAllText($path, $Content, [Text.UTF8Encoding]::new([bool]$WithBom))
        $path
    }
}

Describe '_Remove-EmptyPSDataManifestEntries' {

    It 'removes empty PSData entries and keeps the others' {
        $path = New-TestManifest @'
@{
    ModuleVersion = '0.0.1'
    PrivateData = @{
        PSData = @{
            Tags = @('ZeroFailed')
            ProjectUri = ''
            ReleaseNotes = ""
            Prerelease = $null
            ExternalModuleDependencies = @()
            LicenseUri = 'https://example.com/license'
        }
    }
}
'@

        _Remove-EmptyPSDataManifestEntries -Path $path

        $psData = (Import-PowerShellDataFile $path).PrivateData.PSData
        $psData.Keys | Sort-Object | Should -Be @('LicenseUri', 'Tags')
        $psData.Tags | Should -Be 'ZeroFailed'
    }

    It 'does not change empty entries outside PSData' {
        $path = New-TestManifest @'
@{
    ModuleVersion = '0.0.1'
    CmdletsToExport = @()
    PrivateData = @{
        Other = @{ Empty = @() }
        PSData = @{ Tags = @() }
    }
}
'@

        _Remove-EmptyPSDataManifestEntries -Path $path

        $manifest = Import-PowerShellDataFile $path
        $manifest.ContainsKey('CmdletsToExport') | Should -BeTrue
        $manifest.PrivateData.Other.ContainsKey('Empty') | Should -BeTrue
        $manifest.PrivateData.PSData.Keys.Count | Should -Be 0
    }

    It 'handles entries separated by semicolons on one line' {
        $path = New-TestManifest "@{ PrivateData = @{ PSData = @{ Tags = @(); ProjectUri = 'https://example.com'; ReleaseNotes = '' } } }"

        _Remove-EmptyPSDataManifestEntries -Path $path

        $psData = (Import-PowerShellDataFile $path).PrivateData.PSData
        $psData.Keys | Should -Be @('ProjectUri')
    }

    It 'matches the PrivateData and PSData keys case-insensitively, including quoted keys' {
        $path = New-TestManifest "@{ privatedata = @{ 'psdata' = @{ Tags = @() } } }"

        _Remove-EmptyPSDataManifestEntries -Path $path

        (Import-PowerShellDataFile $path).privatedata.psdata.Keys.Count | Should -Be 0
    }

    It 'does not write the file when there is nothing to remove: <Name>' -ForEach @(
        @{ Name = 'no empty entries'; Content = "@{ PrivateData = @{ PSData = @{ Tags = @('a') } } }" }
        @{ Name = 'no PSData'; Content = "@{ PrivateData = @{ Other = @{ Tags = @() } } }" }
        @{ Name = 'no PrivateData'; Content = "@{ ModuleVersion = '1.0.0' }" }
    ) {
        $path = New-TestManifest $Content
        $before = [datetime]::new(2000, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)
        (Get-Item $path).LastWriteTimeUtc = $before

        _Remove-EmptyPSDataManifestEntries -Path $path

        (Get-Item $path).LastWriteTimeUtc | Should -Be $before
        [IO.File]::ReadAllText($path) | Should -Be $Content
    }

    It 'keeps a UTF-8 byte order mark when <WithBom>' -ForEach @(
        @{ WithBom = $true }
        @{ WithBom = $false }
    ) {
        $path = New-TestManifest "@{ PrivateData = @{ PSData = @{ Tags = @() } } }" -WithBom:$WithBom

        _Remove-EmptyPSDataManifestEntries -Path $path

        $bytes = [IO.File]::ReadAllBytes($path)
        ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) | Should -Be $WithBom
    }

    It 'throws when the manifest cannot be parsed' {
        $path = New-TestManifest "@{ PrivateData = @{ "

        { _Remove-EmptyPSDataManifestEntries -Path $path } | Should -Throw '*Unable to parse the module manifest*'
    }

    It "lets Update-PSModuleManifest update this repository's own manifest" {
        # The real manifest has 'ExternalModuleDependencies = @()', which Update-PSModuleManifest cannot handle
        $moduleDir = Join-Path $TestDrive 'ZeroFailed.Build.PowerShell'
        Copy-Item (Split-Path -Parent $PSScriptRoot) $moduleDir -Recurse
        $path = Join-Path $moduleDir 'ZeroFailed.Build.PowerShell.psd1'

        _Remove-EmptyPSDataManifestEntries -Path $path
        Update-PSModuleManifest -Path $path -ModuleVersion '1.2.3' -Prerelease 'beta0001' -FunctionsToExport @('*') -CmdletsToExport @() -AliasesToExport @() -ErrorAction Stop

        $manifest = Import-PowerShellDataFile $path
        $manifest.ModuleVersion | Should -Be '1.2.3'
        $manifest.PrivateData.PSData.Prerelease | Should -Be 'beta0001'
    }
}
