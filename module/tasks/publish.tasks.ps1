# <copyright file="publish.tasks.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

. $PSScriptRoot/publish.properties.ps1

# Synopsis: Publishes PowerShell Modules to one or more PowerShell Repositories (e.g. PSGallery, GitHub Packages)
task PublishPowerShellModules `
    -If { !$SkipPowerShellPublish } `
    -After PublishCore `
    Version,{

    # A nominal attempt to make a NuGet-compatible pre-release tag compatible with the
    # additional restrictions enforced by PowerShell Gallery
    $safePreReleaseTag = $env:GITVERSION_NuGetPreReleaseTag -replace "-",""
    $isPreRelease = ![string]::IsNullOrEmpty($script:GitVersion.NuGetPreReleaseTag)

    $repositories = _Resolve-PSPublishRepositories -Repositories $PowerShellRepositories `
                                                   -DefaultRepository $PowerShellRepository `
                                                   -DefaultApiKey $PSRepositoryApiKey `
                                                   -PreRelease:$isPreRelease

    if (!$repositories) {
        Write-Build White "No PowerShell repositories to publish to"
        return
    }

    foreach ($repo in $repositories) {
        _Register-PSRepositoryIfMissing -Name $repo.Name `
                                        -SourceLocation $repo.SourceLocation `
                                        -PublishLocation $repo.PublishLocation
    }

    if ($EnablePowerShellModuleForcePublish) {
        Write-Warning "'EnablePowerShellModuleForcePublish' has no effect: Publish-PSResource does not have a '-Force' parameter"
    }

    foreach ($module in $PowerShellModulesToPublish) {

        Write-Build White "Publishing module: $($module.ModulePath)"

        # Ensure any required modules are installed, because publishing validates the module manifest
        $manifest = Get-Content -Raw $module.ModulePath | Invoke-Expression
        $manifest.RequiredModules |
            Where-Object { $_ } |
            ForEach-Object {
                $requiredModule = _Get-RequiredModuleSpecification -RequiredModule $_
                $installArgs = @{ Name = $requiredModule.Name; Scope = 'CurrentUser'; TrustRepository = $true; Repository = 'PSGallery' }
                if ($requiredModule.Version) {
                    $installArgs.Version = $requiredModule.Version
                }
                Install-PSResource @installArgs
            }

        $manifestArgs = @{
            ModuleVersion = $script:GitVersion.MajorMinorPatch
            FunctionsToExport = $module.FunctionsToExport
            CmdletsToExport = $module.CmdletsToExport
            AliasesToExport = $module.AliasesToExport
        }
        # Update-PSModuleManifest does not accept an empty pre-release label
        if ($safePreReleaseTag) {
            $manifestArgs.Prerelease = $safePreReleaseTag
        }
        # Update-PSModuleManifest fails when the manifest has no PSData section, or an empty PSData entry
        # (e.g. "ExternalModuleDependencies = @()"). It also keeps an existing pre-release label when it is not
        # given one, so remove that label for a stable build.
        _Repair-PSDataManifestSection -Path $module.ModulePath -RemovePrerelease:(!$safePreReleaseTag)
        # Update-PSModuleManifest writes a hashtable in PrivateData (e.g. the 'ZeroFailed' metadata) as the text
        # 'System.Collections.Hashtable', so those entries are put back after the update
        _Update-PSModuleManifestKeepingPrivateData -Path $module.ModulePath -UpdateArguments $manifestArgs

        $moduleVersion = $script:GitVersion.MajorMinorPatch
        if ($safePreReleaseTag) {
            $moduleVersion += "-$safePreReleaseTag"
        }

        _Publish-PSModuleToRepositories -ModulePath $module.ModulePath `
                                        -Version $moduleVersion `
                                        -Repositories $repositories `
                                        -AllowPrerelease:$isPreRelease `
                                        -SkipDuplicates:$PowerShellModulePublishSkipDuplicates
    }
}
