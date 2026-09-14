# <copyright file="_Sync-GeneratedPSMarkdownDoc.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _Sync-GeneratedPSMarkdownDoc {
    <#
        .SYNOPSIS
            Reconciles freshly generated markdown help files against the tracked copies.

        .DESCRIPTION
            Copies a freshly generated markdown help file into the tracked target location,
            overwriting a tracked file only when its help content has actually changed (ignoring
            volatile frontmatter, via _ConvertTo-NormalisedPSMarkdownContent). This keeps
            generation idempotent: re-running it with no source changes leaves the working tree
            clean.

        .PARAMETER GeneratedPath
            The folder containing the freshly generated markdown files.

        .PARAMETER TargetPath
            The tracked folder that generated files should be reconciled into. Created if it
            does not already exist.

        .INPUTS
            None. You can't pipe objects to _Sync-GeneratedPSMarkdownDoc.

        .OUTPUTS
            System.Collections.Hashtable.

            A hashtable with 'New' and 'Updated' file-name arrays.

        .EXAMPLE
            PS:> _Sync-GeneratedPSMarkdownDoc -GeneratedPath ./temp/docs -TargetPath ./docs
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $GeneratedPath,

        [Parameter(Mandatory)]
        [string] $TargetPath
    )

    if (!(Test-Path $TargetPath)) {
        New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
    }

    $new = [System.Collections.Generic.List[string]]::new()
    $updated = [System.Collections.Generic.List[string]]::new()

    foreach ($generatedFile in Get-ChildItem -Path $GeneratedPath -Filter *.md -ErrorAction SilentlyContinue) {
        $targetFile = Join-Path $TargetPath $generatedFile.Name

        if (!(Test-Path $targetFile)) {
            Copy-Item -LiteralPath $generatedFile.FullName -Destination $targetFile
            $new.Add($generatedFile.Name)
            continue
        }

        $targetContent = _ConvertTo-NormalisedPSMarkdownContent -Path $targetFile
        $generatedContent = _ConvertTo-NormalisedPSMarkdownContent -Path $generatedFile.FullName

        if ($targetContent -ne $generatedContent) {
            Copy-Item -LiteralPath $generatedFile.FullName -Destination $targetFile -Force
            $updated.Add($generatedFile.Name)
        }
    }

    @{ New = $new.ToArray(); Updated = $updated.ToArray() }
}
