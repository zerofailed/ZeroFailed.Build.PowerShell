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
                $installArgs = @{ Scope = 'CurrentUser'; TrustRepository = $true; Repository = 'PSGallery' }
                if ($_ -is [hashtable]) {
                    $installArgs.Name = $_['ModuleName']
                    # Convert the manifest's version keys to a NuGet version range
                    if ($_['RequiredVersion']) {
                        $installArgs.Version = "[$($_['RequiredVersion'])]"
                    }
                    elseif ($_['ModuleVersion'] -or $_['MaximumVersion']) {
                        $installArgs.Version = '{0}{1}, {2}{3}' -f ($_['ModuleVersion'] ? '[' : '('), $_['ModuleVersion'], $_['MaximumVersion'], ($_['MaximumVersion'] ? ']' : ')')
                    }
                }
                else {
                    $installArgs.Name = $_
                }
                Install-PSResource @installArgs
            }

        $manifestArgs = @{
            Path = $module.ModulePath
            ModuleVersion = $script:GitVersion.MajorMinorPatch
            FunctionsToExport = $module.FunctionsToExport
            CmdletsToExport = $module.CmdletsToExport
            AliasesToExport = $module.AliasesToExport
        }
        # Update-PSModuleManifest does not accept an empty pre-release label
        if ($safePreReleaseTag) {
            $manifestArgs.Prerelease = $safePreReleaseTag
        }
        Update-PSModuleManifest @manifestArgs

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
