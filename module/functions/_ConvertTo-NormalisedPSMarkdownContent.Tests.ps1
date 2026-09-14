# <copyright file="_ConvertTo-NormalisedPSMarkdownContent.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    . (Join-Path $PSScriptRoot '_ConvertTo-NormalisedPSMarkdownContent.ps1')
}

Describe '_ConvertTo-NormalisedPSMarkdownContent' {

    It 'ignores differences in volatile frontmatter (ms.date)' {
        $a = Join-Path $TestDrive 'a.md'
        $b = Join-Path $TestDrive 'b.md'
        Set-Content -LiteralPath $a -Value "---`nms.date: 01/01/2026`ntitle: Foo`n---`nbody"
        Set-Content -LiteralPath $b -Value "---`nms.date: 09/10/2026`ntitle: Foo`n---`nbody"

        (_ConvertTo-NormalisedPSMarkdownContent -Path $a) |
            Should -BeExactly (_ConvertTo-NormalisedPSMarkdownContent -Path $b)
    }

    It 'still reflects real content differences' {
        $a = Join-Path $TestDrive 'c.md'
        $b = Join-Path $TestDrive 'd.md'
        Set-Content -LiteralPath $a -Value "ms.date: 01/01/2026`nThe description."
        Set-Content -LiteralPath $b -Value "ms.date: 01/01/2026`nThe description.`nThe description."

        (_ConvertTo-NormalisedPSMarkdownContent -Path $a) |
            Should -Not -BeExactly (_ConvertTo-NormalisedPSMarkdownContent -Path $b)
    }
}
