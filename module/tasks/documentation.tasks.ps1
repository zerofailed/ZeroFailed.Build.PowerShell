# <copyright file="documentation.tasks.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

. $PSScriptRoot/documentation.properties.ps1

# Frontmatter keys that PlatyPS regenerates on every run with a volatile value (e.g. the
# current date). Two markdown files that differ only in these lines represent identical help
# and should not churn the working tree.
$script:PSMarkdownVolatileFrontmatterKeys = @('ms.date')

# Synopsis: Returns the content of a generated markdown help file with volatile frontmatter
# lines removed, so that two files can be compared for meaningful (help) differences only.
function ConvertTo-NormalisedPSMarkdownContent {
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    $pattern = '^(?:{0}):\s' -f (($PSMarkdownVolatileFrontmatterKeys | ForEach-Object { [regex]::Escape($_) }) -join '|')
    (Get-Content -LiteralPath $Path) |
        Where-Object { $_ -notmatch $pattern } |
        Out-String
}

# Synopsis: Builds the set of PlatyPS CommandHelp objects to export for a module.
#
# PlatyPS' Update-CommandHelp merges the module's live comment-based help into the existing
# markdown. That merge preserves hand-authored sections that comment-based help can't express
# (OUTPUTS descriptions, RELATED LINKS, ALIASES) and normalises the file (e.g. the
# [<CommonParameters>] syntax token) - but it *appends* to the SYNOPSIS, DESCRIPTION, parameter
# descriptions and example remarks rather than replacing them, so those sections grow a
# duplicate copy on every build.
#
# To get the best of both, every command is put through the same pipeline: a freshly generated
# markdown file (authoritative, deterministic) is used as the starting point, the existing
# hand-edited file is layered on top where one exists, Update-CommandHelp merges and normalises,
# and finally the comment-based-help-derived sections are reset from the freshly generated
# object to undo the append behaviour. That merge/normalise/reset cycle is repeated until the
# rendered output stabilises (PlatyPS occasionally needs a second pass, e.g. when a parameter
# that was missing from the existing file is re-introduced), so a single build produces the
# final result.
function Get-ReconciledPSCommandHelp {
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
                        ForEach-Object { ConvertTo-NormalisedPSMarkdownContent -Path $_.FullName } | Out-String

            if ($render -eq $previousRender) { break }
            $previousRender = $render
        }
    }
    finally {
        Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    , $merged
}

# Synopsis: Reconciles freshly generated markdown help files against the tracked copies,
# overwriting a tracked file only when its help content has actually changed. This keeps the
# generation idempotent: re-running it with no source changes leaves the working tree clean.
# Returns a hashtable with 'New' and 'Updated' file-name arrays.
function Sync-GeneratedPSMarkdownDoc {
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

    foreach ($generatedFile in Get-ChildItem -Path $GeneratedPath -Filter *.md) {
        $targetFile = Join-Path $TargetPath $generatedFile.Name

        if (!(Test-Path $targetFile)) {
            Copy-Item -LiteralPath $generatedFile.FullName -Destination $targetFile
            $new.Add($generatedFile.Name)
            continue
        }

        $targetContent = ConvertTo-NormalisedPSMarkdownContent -Path $targetFile
        $generatedContent = ConvertTo-NormalisedPSMarkdownContent -Path $generatedFile.FullName

        if ($targetContent -ne $generatedContent) {
            Copy-Item -LiteralPath $generatedFile.FullName -Destination $targetFile -Force
            $updated.Add($generatedFile.Name)
        }
    }

    @{ New = $new.ToArray(); Updated = $updated.ToArray() }
}

# Synopsis: Ensures the required PlatyPS module is available
task EnsurePlatyPSModule -If { !$SkipGeneratePSMarkdownDocs } -Before setupModules {

    if (!$RequiredPowerShellModules.ContainsKey('Microsoft.PowerShell.PlatyPS')) {
        $script:RequiredPowerShellModules += @{
            'Microsoft.PowerShell.PlatyPS' = @{
                version = '[1.0,2.0)'
                repository = 'PSGallery'
            }
        }
    }
}

# Synopsis: Ensures the markdown documentation output path exists
task EnsurePSMarkdownDocsOutputPath -If { !$SkipGeneratePSMarkdownDocs } {

    # Support dynamic evaluation of PSMarkdownDocsOutputPath
    $script:PSMarkdownDocsOutputPath = Resolve-Value $PSMarkdownDocsOutputPath

    if (!(Test-Path $PSMarkdownDocsOutputPath)) {
        Write-Build White "Creating PS markdown documentation folder: $PSMarkdownDocsOutputPath"
        New-Item -ItemType Directory $PSMarkdownDocsOutputPath -Force | Out-Null
    }
}

# Synopsis: Uses PlatyPS to generate the markdown help documentation from the module's
# comment-based help. Comment-based-help-derived sections (synopsis, description, parameter
# descriptions, examples) are regenerated in full so that the output is deterministic and does
# not accumulate duplicated content across builds; hand-authored sections in the existing
# markdown (OUTPUTS descriptions, RELATED LINKS, ALIASES) are preserved. Tracked files are only
# rewritten when their help content actually changes.
task GeneratePSMarkdownDocs `
    -If { !$SkipGeneratePSMarkdownDocs } `
    -After BuildCore `
    -Jobs GitVersion,EnsurePlatyPSModule,EnsurePSMarkdownDocsOutputPath,{

    foreach ($module in $PowerShellModulesToPublish) {

        $moduleName = Split-Path -LeafBase $module.ModulePath
        Write-Build White "Generating markdown help documentation: $moduleName"

        # Ensure latest version of module is imported
        Import-Module $module.ModulePath -Force

        # By default PlatyPS nests output under a module-name sub-folder. Consumers with a
        # single module per repo often don't want that extra level - honour that here.
        if ($PSMarkdownDocsFlattenOutputPath) {
            $targetPath = $PSMarkdownDocsOutputPath
        }
        else {
            $targetPath = Join-Path $PSMarkdownDocsOutputPath $moduleName
        }

        $commandHelp = Get-ReconciledPSCommandHelp -ModuleName $moduleName -ExistingDocsPath $targetPath -Locale $PSMarkdownDocsLocale

        # Export into a temporary location and then reconcile against the tracked files, so
        # that the final layout is controlled here and unchanged help doesn't churn the tree.
        $tempOutputFolder = Join-Path ([System.IO.Path]::GetTempPath()) ("zf-psdocs-" + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tempOutputFolder -Force | Out-Null

        try {
            $commandHelp | Export-MarkdownCommandHelp -OutputFolder $tempOutputFolder -Force | Out-Null

            if ($PSMarkdownDocsIncludeModulePage) {
                New-MarkdownModuleFile -CommandHelp $commandHelp `
                                       -OutputFolder $tempOutputFolder `
                                       -HelpVersion $Gitversion.AssemblySemVer `
                                       -Locale $PSMarkdownDocsLocale `
                                       -Force `
                                       -WarningAction SilentlyContinue | Out-Null
            }

            $result = Sync-GeneratedPSMarkdownDoc -GeneratedPath (Join-Path $tempOutputFolder $moduleName) -TargetPath $targetPath

            if ($result.New) {
                Write-Build White "New files:`n`t$($result.New -join "`n`t")"
            }
            if ($result.Updated) {
                Write-Build White "Updated files:`n`t$($result.Updated -join "`n`t")"
            }
            if (!$result.New -and !$result.Updated) {
                Write-Build Green "Markdown help documentation is already up to date"
            }
        }
        finally {
            Remove-Item -LiteralPath $tempOutputFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# Synopsis: Runs linting against markdown documentation (e.g. to ensure no generated placeholder text)
task RunPSMarkdownDocsLinting `
    -If { !$SkipGeneratePSMarkdownDocs } `
    -After GeneratePSMarkdownDocs `
    -Jobs EnsurePSMarkdownDocsOutputPath,{

    $noPlaceholderText = $true
    Measure-PlatyPSMarkdown -Path (Join-Path $PSMarkdownDocsOutputPath '*.md') |
        Where-Object { $_.MarkdownContent.MarkdownLines -imatch '\{\{ .* \}\}' } |
        ForEach-Object {
            Write-Build Red "[PlaceholdersDetected] File '$($_.FilePath.Replace("$here\",''))' contains generated documentation placeholders"
            $noPlaceholderText = $false
        }

    if (!$noPlaceholderText -and $PSMarkdownDocsRequireLinting) {
        throw "PowerShell markdown documentation linting failed - review previous errors"
    }
    elseif (!$noPlaceholderText) {
        Write-Warning "PowerShell markdown documentation linting failed - warn-only mode)"
    }
    else {
        Write-Build Green "PowerShell markdown documentation linting successful"
    }
}
