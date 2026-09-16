# <copyright file="_Get-ReconciledPSCommandHelp.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

# Evaluated at discovery time so it can gate the integration Describe block below.
$platyPSAvailable = [bool](Get-Module -ListAvailable Microsoft.PowerShell.PlatyPS)

BeforeAll {
    . (Join-Path $PSScriptRoot '_ConvertTo-NormalisedPSMarkdownContent.ps1')
    . (Join-Path $PSScriptRoot '_Get-ReconciledPSCommandHelp.ps1')
    . (Join-Path $PSScriptRoot '_Sync-GeneratedPSMarkdownDoc.ps1')

    Import-Module Microsoft.PowerShell.PlatyPS -ErrorAction SilentlyContinue

    # A fixture module whose comment-based help has a multi-sentence parameter description -
    # the shape that the old Update-CommandHelp merge duplicated on every run.
    function New-FixtureModule {
        param([string] $Root)

        $moduleDir = Join-Path $Root 'Fixture'
        New-Item -ItemType Directory -Path $moduleDir -Force | Out-Null

        Set-Content -LiteralPath (Join-Path $moduleDir 'Fixture.psm1') -Value @'
function Get-FixtureThing {
    <#
    .SYNOPSIS
        Gets a fixture thing.
    .DESCRIPTION
        Returns a fixture thing for test purposes.
        This description deliberately spans several sentences.
        It exists to exercise the sentence-boundary reflow behaviour of PlatyPS.
    .PARAMETER Name
        The name of the thing to get.
        This description deliberately spans several sentences.
        It is here to exercise the sentence-boundary reflow behaviour of PlatyPS.
    .EXAMPLE
        Get-FixtureThing -Name 'widget'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Name
    )
    $Name
}
'@

        Set-Content -LiteralPath (Join-Path $moduleDir 'Fixture.psd1') -Value @'
@{
    RootModule        = 'Fixture.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'd7c2b8e0-1f3a-4c5b-9d6e-0a1b2c3d4e5f'
    FunctionsToExport = @('Get-FixtureThing')
}
'@

        Join-Path $moduleDir 'Fixture.psd1'
    }

    # Runs the generation the same way the GeneratePSMarkdownDocs task does: reconcile
    # CommandHelp, export to a temp folder, then sync into the target.
    function Invoke-FixtureDocGeneration {
        param(
            [string] $ManifestPath,
            [string] $TargetPath
        )

        Import-Module $ManifestPath -Force
        $moduleName = Split-Path -LeafBase $ManifestPath

        $commandHelp = _Get-ReconciledPSCommandHelp -ModuleName $moduleName -ExistingDocsPath $TargetPath

        $temp = Join-Path ([System.IO.Path]::GetTempPath()) ("zf-psdocs-test-" + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $temp -Force | Out-Null
        try {
            $commandHelp | Export-MarkdownCommandHelp -OutputFolder $temp -Force | Out-Null
            _Sync-GeneratedPSMarkdownDoc -GeneratedPath (Join-Path $temp $moduleName) -TargetPath $TargetPath
        }
        finally {
            Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe '_Get-ReconciledPSCommandHelp' -Skip:(-not $platyPSAvailable) {

    BeforeEach {
        $script:manifest = New-FixtureModule -Root (Join-Path $TestDrive ([Guid]::NewGuid().ToString('N')))
        $script:docs = Join-Path $TestDrive ([Guid]::NewGuid().ToString('N') + '-docs')
    }

    It 'produces no changes on a second run with unchanged source' {
        $first = Invoke-FixtureDocGeneration -ManifestPath $script:manifest -TargetPath $script:docs
        $first.New | Should -Contain 'Get-FixtureThing.md'

        $second = Invoke-FixtureDocGeneration -ManifestPath $script:manifest -TargetPath $script:docs
        $second.New | Should -BeNullOrEmpty
        $second.Updated | Should -BeNullOrEmpty
    }

    It 'does not accumulate duplicated parameter descriptions across many runs' {
        $sentence = 'It is here to exercise the sentence-boundary reflow behaviour of PlatyPS.'
        1..5 | ForEach-Object { Invoke-FixtureDocGeneration -ManifestPath $script:manifest -TargetPath $script:docs | Out-Null }

        $content = Get-Content -Raw -LiteralPath (Join-Path $script:docs 'Get-FixtureThing.md')
        ([regex]::Matches($content, [regex]::Escape($sentence))).Count | Should -Be 1
    }

    It 'preserves a hand-authored section that comment-based help cannot express' {
        Invoke-FixtureDocGeneration -ManifestPath $script:manifest -TargetPath $script:docs | Out-Null
        $file = Join-Path $script:docs 'Get-FixtureThing.md'

        # Author a RELATED LINKS entry directly in the markdown (as a maintainer would).
        $withLink = (Get-Content -Raw -LiteralPath $file) -replace
            '(?s)## RELATED LINKS.*$', "## RELATED LINKS`n`n- [Fabric REST API](https://learn.microsoft.com/rest/api/fabric/)`n"
        Set-Content -LiteralPath $file -Value $withLink -NoNewline

        $result = Invoke-FixtureDocGeneration -ManifestPath $script:manifest -TargetPath $script:docs
        $result.Updated | Should -Not -Contain 'Get-FixtureThing.md'
        Get-Content -Raw -LiteralPath $file | Should -Match ([regex]::Escape('- [Fabric REST API](https://learn.microsoft.com/rest/api/fabric/)'))
    }

    It 'restores a parameter description that was manually duplicated' {
        Invoke-FixtureDocGeneration -ManifestPath $script:manifest -TargetPath $script:docs | Out-Null
        $file = Join-Path $script:docs 'Get-FixtureThing.md'

        $drifted = (Get-Content -Raw -LiteralPath $file) -replace
            'The name of the thing to get\.', "The name of the thing to get.`nThe name of the thing to get."
        Set-Content -LiteralPath $file -Value $drifted -NoNewline

        $result = Invoke-FixtureDocGeneration -ManifestPath $script:manifest -TargetPath $script:docs
        $result.Updated | Should -Contain 'Get-FixtureThing.md'
        ([regex]::Matches((Get-Content -Raw -LiteralPath $file), 'The name of the thing to get\.')).Count |
            Should -Be 1
    }
}
