# <copyright file="_ConvertTo-NormalisedPSMarkdownContent.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _ConvertTo-NormalisedPSMarkdownContent {
    <#
        .SYNOPSIS
            Returns the content of a generated PlatyPS markdown help file with volatile
            frontmatter lines removed.

        .DESCRIPTION
            PlatyPS regenerates certain frontmatter keys (e.g. 'ms.date') with a volatile value
            on every run. This function strips those lines so that two markdown files can be
            compared for meaningful (help) differences only, without being treated as different
            just because they were generated on different days.

        .PARAMETER Path
            The path to the markdown file to normalise.

        .INPUTS
            None. You can't pipe objects to _ConvertTo-NormalisedPSMarkdownContent.

        .OUTPUTS
            System.String.

            The file content with volatile frontmatter lines removed.

        .EXAMPLE
            PS:> _ConvertTo-NormalisedPSMarkdownContent -Path ./docs/Get-Thing.md
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    # Frontmatter keys that PlatyPS regenerates on every run with a volatile value (e.g. the
    # current date).
    $volatileFrontmatterKeys = @('ms.date')

    $pattern = '^(?:{0}):\s' -f (($volatileFrontmatterKeys | ForEach-Object { [regex]::Escape($_) }) -join '|')
    (Get-Content -LiteralPath $Path) |
        Where-Object { $_ -notmatch $pattern } |
        Out-String
}
