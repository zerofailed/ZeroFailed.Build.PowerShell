# <copyright file="_Repair-PSDataManifestSection.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    . (Join-Path $PSScriptRoot '_Repair-PSDataManifestSection.ps1')

    function New-TestManifest {
        param([string] $Content, [switch] $WithBom)
        $path = Join-Path $TestDrive "$([guid]::NewGuid()).psd1"
        [IO.File]::WriteAllText($path, $Content, [Text.UTF8Encoding]::new([bool]$WithBom))
        $path
    }
}

Describe '_Repair-PSDataManifestSection' {

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

        _Repair-PSDataManifestSection -Path $path

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

        _Repair-PSDataManifestSection -Path $path

        $manifest = Import-PowerShellDataFile $path
        $manifest.ContainsKey('CmdletsToExport') | Should -BeTrue
        $manifest.PrivateData.Other.ContainsKey('Empty') | Should -BeTrue
        $manifest.PrivateData.PSData.Keys.Count | Should -Be 0
    }

    It 'handles entries separated by semicolons on one line' {
        $path = New-TestManifest "@{ PrivateData = @{ PSData = @{ Tags = @(); ProjectUri = 'https://example.com'; ReleaseNotes = '' } } }"

        _Repair-PSDataManifestSection -Path $path

        $psData = (Import-PowerShellDataFile $path).PrivateData.PSData
        $psData.Keys | Should -Be @('ProjectUri')
    }

    It 'matches the PrivateData and PSData keys case-insensitively, including quoted keys' {
        $path = New-TestManifest "@{ privatedata = @{ 'psdata' = @{ Tags = @() } } }"

        _Repair-PSDataManifestSection -Path $path

        (Import-PowerShellDataFile $path).privatedata.psdata.Keys.Count | Should -Be 0
    }

    It 'adds an empty PSData section when <Name>, and keeps the other entries' -ForEach @(
        @{ Name = 'there is no PrivateData'; Content = "@{ ModuleVersion = '1.0.0' }" }
        @{ Name = 'there is no PrivateData, multi-line'; Content = "@{`n    ModuleVersion = '1.0.0'`n}`n" }
        @{ Name = 'PrivateData has no PSData'; Content = "@{ ModuleVersion = '1.0.0'; PrivateData = @{ Other = @{ Tags = @() } } }" }
        @{ Name = 'PrivateData is empty'; Content = "@{ ModuleVersion = '1.0.0'; PrivateData = @{} }" }
    ) {
        $path = New-TestManifest $Content

        _Repair-PSDataManifestSection -Path $path

        $manifest = Import-PowerShellDataFile $path
        $manifest.ModuleVersion | Should -Be '1.0.0'
        $manifest.PrivateData.PSData | Should -BeOfType [hashtable]
        $manifest.PrivateData.PSData.Keys.Count | Should -Be 0
        if ($Content -match 'Other') {
            $manifest.PrivateData.Other.ContainsKey('Tags') | Should -BeTrue
        }
    }

    It 'removes the Prerelease entry only when RemovePrerelease is set: <RemovePrerelease>' -ForEach @(
        @{ RemovePrerelease = $true }
        @{ RemovePrerelease = $false }
    ) {
        $path = New-TestManifest "@{ PrivateData = @{ PSData = @{ Prerelease = 'beta0001'; Tags = @('a') } } }"

        _Repair-PSDataManifestSection -Path $path -RemovePrerelease:$RemovePrerelease

        $psData = (Import-PowerShellDataFile $path).PrivateData.PSData
        $psData.ContainsKey('Prerelease') | Should -Be (!$RemovePrerelease)
        $psData.Tags | Should -Be 'a'
    }

    It 'does not write the file when there is nothing to change: <Name>' -ForEach @(
        @{ Name = 'no empty entries'; Content = "@{ PrivateData = @{ PSData = @{ Tags = @('a') } } }" }
        @{ Name = 'PrivateData is not a hashtable literal'; Content = "@{ PrivateData = `$null }" }
        @{ Name = 'no Prerelease to remove'; Content = "@{ PrivateData = @{ PSData = @{ Tags = @('a') } } }"; RemovePrerelease = $true }
    ) {
        $path = New-TestManifest $Content
        $before = [datetime]::new(2000, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)
        (Get-Item $path).LastWriteTimeUtc = $before

        _Repair-PSDataManifestSection -Path $path -RemovePrerelease:([bool]$RemovePrerelease)

        (Get-Item $path).LastWriteTimeUtc | Should -Be $before
        [IO.File]::ReadAllText($path) | Should -Be $Content
    }

    It 'keeps a UTF-8 byte order mark when <WithBom>' -ForEach @(
        @{ WithBom = $true }
        @{ WithBom = $false }
    ) {
        $path = New-TestManifest "@{ PrivateData = @{ PSData = @{ Tags = @() } } }" -WithBom:$WithBom

        _Repair-PSDataManifestSection -Path $path

        $bytes = [IO.File]::ReadAllBytes($path)
        ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) | Should -Be $WithBom
    }

    It 'throws when the manifest cannot be parsed' {
        $path = New-TestManifest "@{ PrivateData = @{ "

        { _Repair-PSDataManifestSection -Path $path } | Should -Throw '*Unable to parse the module manifest*'
    }

    It "lets Update-PSModuleManifest update this repository's own manifest" {
        # The real manifest has 'ExternalModuleDependencies = @()', which Update-PSModuleManifest cannot handle
        $moduleDir = Join-Path $TestDrive 'ZeroFailed.Build.PowerShell'
        Copy-Item (Split-Path -Parent $PSScriptRoot) $moduleDir -Recurse
        $path = Join-Path $moduleDir 'ZeroFailed.Build.PowerShell.psd1'

        _Repair-PSDataManifestSection -Path $path
        Update-PSModuleManifest -Path $path -ModuleVersion '1.2.3' -Prerelease 'beta0001' -FunctionsToExport @('*') -CmdletsToExport @() -AliasesToExport @() -ErrorAction Stop

        $manifest = Import-PowerShellDataFile $path
        $manifest.ModuleVersion | Should -Be '1.2.3'
        $manifest.PrivateData.PSData.Prerelease | Should -Be 'beta0001'
    }

    Context 'Update-PSModuleManifest, with the real cmdlet' {

        BeforeAll {
            function New-TestModule {
                param([string] $ManifestContent)
                $moduleDir = Join-Path $TestDrive ([guid]::NewGuid())
                New-Item -ItemType Directory $moduleDir | Out-Null
                Set-Content (Join-Path $moduleDir 'TestModule.psm1') ''
                $path = Join-Path $moduleDir 'TestModule.psd1'
                Set-Content $path $ManifestContent
                $path
            }
        }

        It 'can update a manifest when <Name>' -ForEach @(
            @{ Name = 'there is no PrivateData'; Content = "@{ ModuleVersion = '1.0.0'; RootModule = 'TestModule.psm1'; GUID = '9d5e0f43-5a2f-4b5e-9bd2-6a54c1a4c0a1' }" }
            @{ Name = 'PrivateData has no PSData'; Content = "@{ ModuleVersion = '1.0.0'; RootModule = 'TestModule.psm1'; GUID = '9d5e0f43-5a2f-4b5e-9bd2-6a54c1a4c0a1'; PrivateData = @{ Other = 'value' } }" }
        ) {
            $path = New-TestModule $Content

            _Repair-PSDataManifestSection -Path $path
            Update-PSModuleManifest -Path $path -ModuleVersion '1.2.3' -ErrorAction Stop

            (Import-PowerShellDataFile $path).ModuleVersion | Should -Be '1.2.3'
        }

        It 'removes an existing pre-release label for a stable version' {
            $path = New-TestModule "@{ ModuleVersion = '1.0.0'; RootModule = 'TestModule.psm1'; GUID = '9d5e0f43-5a2f-4b5e-9bd2-6a54c1a4c0a1'; PrivateData = @{ PSData = @{ Prerelease = 'beta0001' } } }"

            _Repair-PSDataManifestSection -Path $path -RemovePrerelease
            Update-PSModuleManifest -Path $path -ModuleVersion '1.2.3' -ErrorAction Stop

            $manifest = Import-PowerShellDataFile $path
            $manifest.ModuleVersion | Should -Be '1.2.3'
            $manifest.PrivateData.PSData.Prerelease | Should -BeNullOrEmpty
        }
    }
}
