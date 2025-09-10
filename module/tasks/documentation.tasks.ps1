# <copyright file="documentation.tasks.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

. $PSScriptRoot/documentation.properties.ps1

# Synopsis: Ensures the required PlatyPS module is available
task EnsurePlatyPSModule -Before setupModules {

    if (!$RequiredPowerShellModules.ContainsKey('Microsoft.PowerShell.PlatyPS')) {
        $script:RequiredPowerShellModules += @{
            'Microsoft.PowerShell.PlatyPS' = @{
                version = '[1.0,2.0)'
                repository = 'PSGallery'
            }
        }
    }
}

# This scriptblock is used as a compensation task to ensure that if we are using
# the 'flattened' output path option for Markdown files, then our special handling in
# 'MoveMarkdownFilesBeforePlatyPS' gets reverted even if an error happens during
# processing.
$_moveMarkdownFilesToOutputPath = {
    foreach ($module in $PowerShellModulesToPublish) {

        $moduleName = Split-Path -LeafBase $module.ModulePath
        $outputPathExpectedByPlatyPS = Join-Path $PSMarkdownDocsOutputPath $moduleName

        # Handle the scenario where we had an error before anything actually got moved
        if (Test-Path $outputPathExpectedByPlatyPS) {
            # Move the markdown files back to where we want them
            Move-Item -Path $outputPathExpectedByPlatyPS\*.md -Destination $PSMarkdownDocsOutputPath\
            Remove-Item $outputPathExpectedByPlatyPS
        }
    }
}

# Synopsis: Ensures existing markdown files in the place that PlatyPS expects them when using a custom output path
task MoveMarkdownFilesBeforePlatyPS -If { $PSMarkdownDocsFlattenOutputPath } {

    # Setup compensation task to ensure that these files get moved back if an error happens that
    # would otherwise prevent the later 'MoveMarkdownFilesToOutputPath' task from running.
    $script:OnExitActions.Add($_moveMarkdownFilesToOutputPath)

    # PlatyPS expects to find existing markdown files in a folder named after the module, but
    # this is not always desirable when a repo only contains a single module.  We need to temporarily
    # move the files around to keep PlatyPS happy.
    foreach ($module in $PowerShellModulesToPublish) {

        $moduleName = Split-Path -LeafBase $module.ModulePath
        $outputPathExpectedByPlatyPS = Join-Path $PSMarkdownDocsOutputPath $moduleName
    
        # Put .md files where the New-MarkdownCommandHelp cmdlet expects to find them
        New-Item $outputPathExpectedByPlatyPS -ItemType Directory -Force | Out-Null
        Move-Item -Path $PSMarkdownDocsOutputPath\*.md -Destination $outputPathExpectedByPlatyPS\
    }
}

task ReturnMarkdownFilesAfterPlatyPS `
    -If { $PSMarkdownDocsFlattenOutputPath } `
    -After GeneratePowerShellMarkdownDocumentation `
    -Jobs {

    # Call the compensation function to move the markdown files back to their original path
    $_moveMarkdownFilesToOutputPath.Invoke()

    # Disable the compensation function from running at the end of the build, since we know it's not needed now
    $script:OnExitActions.Remove($_moveMarkdownFilesToOutputPath) | Out-Null
}

# Synopsis: Uses PlatyPS to generate/update existing markdown documentation
task GeneratePowerShellMarkdownDocumentation `
    -If { !$SkipGenerateMarkdownDocumentation } `
    -After BuildCore `
    -Jobs GitVersion,EnsurePlatyPSModule,MoveMarkdownFilesBeforePlatyPS,{

    foreach ($module in $PowerShellModulesToPublish) {

        $moduleName = Split-Path -LeafBase $module.ModulePath
        Write-Build White "Generating/updating markdown help documentation: $moduleName"

        # Ensure latest version of module is imported
        Import-Module $module.ModulePath -Force
    
        # Generate any markdown files for new functions
        $newMarkdownCommandHelpSplat = @{
            ModuleInfo = Get-Module $moduleName
            OutputFolder = $PSMarkdownDocsOutputPath
            HelpVersion = $Gitversion.AssemblySemVer
            WithModulePage = $PSMarkdownDocsIncludeModulePage 
            WarningAction = 'SilentlyContinue'  # suppress warnings about pre-existing files
        }
        $newFiles = New-MarkdownCommandHelp @newMarkdownCommandHelpSplat

        if ($newFiles) {
            Write-Build White "New files:`n`t$($newFiles.Name -join "`n`t")"
        }
    
        # Derive path where the existing markdown files actually reside
        $existingMarkdownFilePath = Join-Path $PSMarkdownDocsOutputPath $moduleName

        if (Test-Path $existingMarkdownFilePath) {
            # Update existing markdown files to reflect changes in latest version
            $updatedFiles = Measure-PlatyPSMarkdown -Path $existingMarkdownFilePath\*.md |
                                Where-Object Filetype -match 'CommandHelp' |
                                Update-CommandHelp -Path {$_.FilePath} |
                                Export-MarkdownCommandHelp -OutputFolder $PSMarkdownDocsOutputPath -Force
            
            if ($updatedFiles) {
                Write-Build White "Updated files:`n`t$($updatedFiles.Name -join "`n`t")"
            }
        }
    }
}
