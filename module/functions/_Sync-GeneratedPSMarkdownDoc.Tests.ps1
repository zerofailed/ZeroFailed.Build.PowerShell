# <copyright file="_Sync-GeneratedPSMarkdownDoc.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    . (Join-Path $PSScriptRoot '_ConvertTo-NormalisedPSMarkdownContent.ps1')
    . (Join-Path $PSScriptRoot '_Sync-GeneratedPSMarkdownDoc.ps1')
}

Describe '_Sync-GeneratedPSMarkdownDoc' {

    BeforeEach {
        $script:generated = Join-Path $TestDrive ([Guid]::NewGuid().ToString('N') + '-gen')
        $script:target = Join-Path $TestDrive ([Guid]::NewGuid().ToString('N') + '-target')
        New-Item -ItemType Directory -Path $script:generated -Force | Out-Null
    }

    It 'copies files that do not yet exist in the target' {
        Set-Content -LiteralPath (Join-Path $script:generated 'New-Thing.md') -Value "ms.date: 09/10/2026`nhelp"

        $result = _Sync-GeneratedPSMarkdownDoc -GeneratedPath $script:generated -TargetPath $script:target

        $result.New | Should -Contain 'New-Thing.md'
        Join-Path $script:target 'New-Thing.md' | Should -Exist
    }

    It 'does not rewrite a target that differs only by volatile frontmatter' {
        New-Item -ItemType Directory -Path $script:target -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $script:target 'Get-Thing.md') -Value "ms.date: 01/01/2026`nhelp"
        Set-Content -LiteralPath (Join-Path $script:generated 'Get-Thing.md') -Value "ms.date: 09/10/2026`nhelp"
        $before = Get-Content -Raw -LiteralPath (Join-Path $script:target 'Get-Thing.md')

        $result = _Sync-GeneratedPSMarkdownDoc -GeneratedPath $script:generated -TargetPath $script:target

        $result.New | Should -BeNullOrEmpty
        $result.Updated | Should -BeNullOrEmpty
        Get-Content -Raw -LiteralPath (Join-Path $script:target 'Get-Thing.md') | Should -BeExactly $before
    }

    It 'overwrites a target whose help content has drifted' {
        New-Item -ItemType Directory -Path $script:target -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $script:target 'Get-Thing.md') -Value "ms.date: 09/10/2026`nhelp`nhelp (duplicated)"
        Set-Content -LiteralPath (Join-Path $script:generated 'Get-Thing.md') -Value "ms.date: 09/10/2026`nhelp"

        $result = _Sync-GeneratedPSMarkdownDoc -GeneratedPath $script:generated -TargetPath $script:target

        $result.Updated | Should -Contain 'Get-Thing.md'
        Get-Content -Raw -LiteralPath (Join-Path $script:target 'Get-Thing.md') | Should -Not -Match 'duplicated'
    }
}
