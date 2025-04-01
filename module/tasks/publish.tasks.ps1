# <copyright file="publish.tasks.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

. $PSScriptRoot/publish.properties.ps1

# Synopsis: Publishes PowerShell Modules to a registered PowerShell Repository (e.g. PSGallery)
task PublishPowerShellModules `
    -If { !$SkipPowerShellPublish } `
    -After PublishCore `
    Version,{

    # A nominal attempt to make a NuGet-compatible pre-release tag compatible with the
    # additional restrictions enforced by PowerShell Gallery
    $safePreReleaseTag = $env:GITVERSION_NuGetPreReleaseTag -replace "-",""
    
    foreach ($module in $PowerShellModulesToPublish) {

        Write-Build White "Publishing module: $($module.ModulePath)"

        # Ensure any required modules are installed
        $manifest = Get-Content -Raw $module.ModulePath | Invoke-Expression
        $manifest.RequiredModules |
            Where-Object { $_ } |
            ForEach-Object { Install-Module -Name $_ -Scope CurrentUser -Force -Repository PSGallery }

        Update-ModuleManifest -Path $module.ModulePath `
                              -ModuleVersion $script:GitVersion.MajorMinorPatch `
                              -Prerelease $safePreReleaseTag `
                              -FunctionsToExport $module.FunctionsToExport `
                              -CmdletsToExport $module.CmdletsToExport `
                              -AliasesToExport $module.AliasesToExport
        
        Publish-Module -Name $module.ModulePath `
                       -Repository $PowerShellRepository `
                       -NuGetApiKey $PSRepositoryApiKey `
                       -AllowPrerelease:$(![string]::IsNullOrEmpty($script:GitVersion.NuGetPreReleaseTag)) `
                       -Force:$EnablePowerShellModuleForcePublish `
                       -Verbose
        }
}
