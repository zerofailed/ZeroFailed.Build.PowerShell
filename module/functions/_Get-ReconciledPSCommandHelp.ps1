# <copyright file="_Get-ReconciledPSCommandHelp.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _Get-ReconciledPSCommandHelp {
    <#
        .SYNOPSIS
            Builds the set of PlatyPS CommandHelp objects to export for a module.

        .DESCRIPTION
            PlatyPS' Update-CommandHelp merges a module's live comment-based help into existing
            markdown. That merge preserves hand-authored sections that comment-based help can't
            express (OUTPUTS descriptions, RELATED LINKS, ALIASES) and normalises the file (e.g.
            the [<CommonParameters>] syntax token) - but it *appends* to the SYNOPSIS,
            DESCRIPTION, parameter descriptions and example remarks rather than replacing them,
            so those sections grow a duplicate copy on every build.

            To get the best of both, every command is put through the same pipeline: a freshly
            generated markdown file (authoritative, deterministic) is used as the starting point,
            the existing hand-edited file is layered on top where one exists, Update-CommandHelp
            merges and normalises, and finally the comment-based-help-derived sections are reset
            from the freshly generated object to undo the append behaviour. That
            merge/normalise/reset cycle is repeated until the rendered output stabilises (PlatyPS
            occasionally needs a second pass, e.g. when a parameter that was missing from the
            existing file is re-introduced), so a single call produces the final result.

        .PARAMETER ModuleName
            The name of the imported module to build CommandHelp objects for.

        .PARAMETER ExistingDocsPath
            The folder containing the tracked markdown files to layer hand-authored content from.
            Pass an empty string when there are no existing docs (e.g. first run).

        .PARAMETER Locale
            The locale to pin on the generated CommandHelp objects, so that frontmatter does not
            vary with the build agent's culture. Optional.

        .INPUTS
            None. You can't pipe objects to _Get-ReconciledPSCommandHelp.

        .OUTPUTS
            Microsoft.PowerShell.PlatyPS.Model.CommandHelp[].

        .EXAMPLE
            PS:> _Get-ReconciledPSCommandHelp -ModuleName MyModule -ExistingDocsPath ./docs -Locale en-US
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $ModuleName,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $ExistingDocsPath,

        [Parameter()]
        [string] $Locale
    )

    $commands = (Get-Module $ModuleName).ExportedCommands.Values |
                    Where-Object CommandType -in 'Function', 'Cmdlet'

    $freshByTitle = @{}
    $commands | New-CommandHelp -WarningAction SilentlyContinue | ForEach-Object { $freshByTitle[$_.Title] = $_ }

    # Stage one markdown file per command. PlatyPS always nests exports under a module-name
    # sub-folder, so mirror that for the hand-edited files copied in alongside.
    $workRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("zf-psdocs-stage-" + [Guid]::NewGuid().ToString('N'))
    $stagePath = Join-Path $workRoot $ModuleName
    New-Item -ItemType Directory -Path $stagePath -Force | Out-Null

    $merged = $null
    try {
        $freshByTitle.Values | Export-MarkdownCommandHelp -OutputFolder $workRoot -Force | Out-Null

        # Layer the existing hand-edited files on top of the freshly generated ones.
        if ($ExistingDocsPath -and (Test-Path $ExistingDocsPath)) {
            Get-ChildItem -Path (Join-Path $ExistingDocsPath '*.md') |
                Where-Object { $freshByTitle.ContainsKey([System.IO.Path]::GetFileNameWithoutExtension($_.Name)) } |
                Copy-Item -Destination $stagePath -Force
        }

        $previousRender = $null
        for ($pass = 1; $pass -le 3; $pass++) {

            $merged = @(Measure-PlatyPSMarkdown -Path (Join-Path $stagePath '*.md') |
                        Where-Object Filetype -match 'CommandHelp' |
                        Update-CommandHelp -Path { $_.FilePath })

            foreach ($commandHelp in $merged) {
                $fresh = $freshByTitle[$commandHelp.Title]
                if (!$fresh) { continue }

                # Reset the sections Update-CommandHelp appends to, from the authoritative source.
                $commandHelp.Synopsis = $fresh.Synopsis
                $commandHelp.Description = $fresh.Description

                # Pin the locale so generated frontmatter doesn't vary with the build agent's culture.
                if ($Locale) {
                    $commandHelp.Locale = [System.Globalization.CultureInfo]::GetCultureInfo($Locale)
                    if ($commandHelp.Metadata -and $commandHelp.Metadata.Contains('Locale')) {
                        $commandHelp.Metadata['Locale'] = $Locale
                    }
                }

                foreach ($parameter in $commandHelp.Parameters) {
                    $freshParameter = $fresh.Parameters | Where-Object Name -eq $parameter.Name | Select-Object -First 1
                    if ($freshParameter) {
                        $parameter.Description = $freshParameter.Description
                    }
                }

                for ($i = 0; $i -lt $commandHelp.Examples.Count -and $i -lt $fresh.Examples.Count; $i++) {
                    $commandHelp.Examples[$i].Remarks = $fresh.Examples[$i].Remarks
                }
            }

            # Re-render and compare (ignoring volatile frontmatter) to see whether another pass
            # would change anything.
            Remove-Item -Path (Join-Path $stagePath '*.md') -Force
            $merged | Export-MarkdownCommandHelp -OutputFolder $workRoot -Force | Out-Null

            $render = Get-ChildItem -Path (Join-Path $stagePath '*.md') | Sort-Object Name |
                        ForEach-Object { _ConvertTo-NormalisedPSMarkdownContent -Path $_.FullName } | Out-String

            if ($render -eq $previousRender) { break }
            $previousRender = $render
        }
    }
    finally {
        Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    , $merged
}
