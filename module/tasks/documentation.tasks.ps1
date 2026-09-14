# <copyright file="documentation.tasks.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

. $PSScriptRoot/documentation.properties.ps1

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

        $commandHelp = _Get-ReconciledPSCommandHelp -ModuleName $moduleName -ExistingDocsPath $targetPath -Locale $PSMarkdownDocsLocale

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

            $result = _Sync-GeneratedPSMarkdownDoc -GeneratedPath (Join-Path $tempOutputFolder $moduleName) -TargetPath $targetPath

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
