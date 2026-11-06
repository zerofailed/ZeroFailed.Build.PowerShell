# <copyright file="_Update-PSModuleManifestKeepingPrivateData.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

# These tests run the real Update-PSModuleManifest, because the problem being fixed is in what it writes.
BeforeAll {
    . (Join-Path $PSScriptRoot '_Update-PSModuleManifestKeepingPrivateData.ps1')
    . (Join-Path $PSScriptRoot '_Repair-PSDataManifestSection.ps1')

    function New-TestModule {
        param([string] $PrivateData)
        $moduleDir = Join-Path $TestDrive ([guid]::NewGuid())
        New-Item -ItemType Directory -Path $moduleDir | Out-Null
        Set-Content -Path (Join-Path $moduleDir 'TestModule.psm1') -Value 'function Get-Foo { 1 }'
        $path = Join-Path $moduleDir 'TestModule.psd1'
        Set-Content -Path $path -Value @"
@{
    RootModule = 'TestModule.psm1'
    ModuleVersion = '0.0.1'
    GUID = '$([guid]::NewGuid())'
    Author = 'Test'
    Description = 'Test module'
    FunctionsToExport = @()
    PrivateData = @{
$PrivateData
    }
}
"@
        $path
    }
}

Describe '_Update-PSModuleManifestKeepingPrivateData' {

    It 'keeps a nested hashtable in PrivateData, which Update-PSModuleManifest alone writes as text' {
        $privateData = @'
        PSData = @{ Tags = @('ZeroFailed') }
        # ZeroFailed metadata
        ZeroFailed = @{
            ExtensionDependencies = @(
                @{
                    # Assume latest stable version
                    Name = 'ZeroFailed.Build.Common'
                    GitRepository = 'https://github.com/zerofailed/ZeroFailed.Build.Common'
                    Process = 'tasks/build.process.ps1'
                }
            )
        }
'@
        $path = New-TestModule -PrivateData $privateData
        $control = New-TestModule -PrivateData $privateData

        _Update-PSModuleManifestKeepingPrivateData -Path $path -UpdateArguments @{ ModuleVersion = '1.2.3'; Prerelease = 'beta0001'; FunctionsToExport = @('Get-Foo') }
        Update-PSModuleManifest -Path $control -ModuleVersion '1.2.3'

        # Without the fix, the hashtable is lost
        (Import-PowerShellDataFile $control).PrivateData.ZeroFailed | Should -Be 'System.Collections.Hashtable'

        $manifest = Import-PowerShellDataFile $path
        $manifest.ModuleVersion | Should -Be '1.2.3'
        $manifest.PrivateData.PSData.Prerelease | Should -Be 'beta0001'
        $manifest.PrivateData.PSData.Tags | Should -Be 'ZeroFailed'
        $manifest.FunctionsToExport | Should -Be 'Get-Foo'
        $manifest.PrivateData.ZeroFailed | Should -BeOfType [hashtable]
        $manifest.PrivateData.ZeroFailed.ExtensionDependencies.Count | Should -Be 1
        $manifest.PrivateData.ZeroFailed.ExtensionDependencies[0].Name | Should -Be 'ZeroFailed.Build.Common'
        $manifest.PrivateData.ZeroFailed.ExtensionDependencies[0].Process | Should -Be 'tasks/build.process.ps1'
        # The original text is put back, including its comments
        Get-Content -Raw $path | Should -BeLike '*# Assume latest stable version*'
    }

    It 'keeps every PrivateData entry other than PSData, including scalars and quoted keys' {
        $path = New-TestModule -PrivateData @'
        PSData = @{ Tags = @('a') }
        'Other' = @{ Nested = @{ Value = 42 }; List = @(1, 2) }
        Flag = $true
        Text = 'hello'
'@

        _Update-PSModuleManifestKeepingPrivateData -Path $path -UpdateArguments @{ ModuleVersion = '2.0.0' }

        $privateData = (Import-PowerShellDataFile $path).PrivateData
        $privateData.Other.Nested.Value | Should -Be 42
        $privateData.Other.List | Should -Be @(1, 2)
        $privateData.Flag | Should -BeTrue
        $privateData.Text | Should -Be 'hello'
    }

    It 'only runs the update when PrivateData has nothing but PSData' {
        $path = New-TestModule -PrivateData "        PSData = @{ Tags = @('a') }"

        _Update-PSModuleManifestKeepingPrivateData -Path $path -UpdateArguments @{ ModuleVersion = '3.0.0' }

        (Import-PowerShellDataFile $path).ModuleVersion | Should -Be '3.0.0'
    }

    It 'throws when the update fails' {
        $path = New-TestModule -PrivateData "        PSData = @{ Tags = @('a') }"

        { _Update-PSModuleManifestKeepingPrivateData -Path $path -UpdateArguments @{ ModuleVersion = 'not-a-version' } -ErrorAction Stop } |
            Should -Throw
    }

    It "keeps this repository's own ZeroFailed metadata when its manifest is updated" {
        $moduleDir = Join-Path $TestDrive 'ZeroFailed.Build.PowerShell'
        Copy-Item (Split-Path -Parent $PSScriptRoot) $moduleDir -Recurse
        $path = Join-Path $moduleDir 'ZeroFailed.Build.PowerShell.psd1'
        $expected = (Import-PowerShellDataFile $path).PrivateData.ZeroFailed | ConvertTo-Json -Depth 20 -Compress

        _Repair-PSDataManifestSection -Path $path
        _Update-PSModuleManifestKeepingPrivateData -Path $path -UpdateArguments @{ ModuleVersion = '1.2.3'; FunctionsToExport = @('*'); CmdletsToExport = @(); AliasesToExport = @() }

        (Import-PowerShellDataFile $path).PrivateData.ZeroFailed | ConvertTo-Json -Depth 20 -Compress | Should -Be $expected
    }
}
