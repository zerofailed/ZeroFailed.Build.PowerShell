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

    # Assigned before filtering, as the function emits the array as a single pipeline object
    $resolvedRepositories = _Resolve-PSPublishRepositories -Repositories $PowerShellRepositories `
                                                           -DefaultRepository $PowerShellRepository `
                                                           -DefaultApiKey $PSRepositoryApiKey
    $repositories = $resolvedRepositories |
                        Where-Object {
                            if ($isPreRelease -and $_.BlockPreReleaseVersions) {
                                Write-Build White "Skipping repository '$($_.Name)' for pre-release version: $($script:GitVersion.SemVer)"
                                return $false
                            }
                            $true
                        }

    if (!$repositories) {
        Write-Build White "No PowerShell repositories to publish to"
        return
    }

    foreach ($repo in $repositories) {
        _Register-PSRepositoryIfMissing -Name $repo.Name `
                                        -SourceLocation $repo.SourceLocation `
                                        -PublishLocation $repo.PublishLocation `
                                        -Credential $repo.Credential
    }

    foreach ($module in $PowerShellModulesToPublish) {

        Write-Build White "Publishing module: $($module.ModulePath)"

        # Ensure any required modules are installed
        $manifest = Get-Content -Raw $module.ModulePath | Invoke-Expression
        $manifest.RequiredModules |
            Where-Object { $_ } |
            ForEach-Object {
                if ($_ -is [hashtable]) {
                    Install-Module -Name $_['ModuleName'] -RequiredVersion $_['RequiredVersion'] -Scope CurrentUser -Force -Repository PSGallery
                }
                else {
                    Install-Module -Name $_ -Scope CurrentUser -Force -Repository PSGallery
                }
            }

        Update-ModuleManifest -Path $module.ModulePath `
                              -ModuleVersion $script:GitVersion.MajorMinorPatch `
                              -Prerelease $safePreReleaseTag `
                              -FunctionsToExport $module.FunctionsToExport `
                              -CmdletsToExport $module.CmdletsToExport `
                              -AliasesToExport $module.AliasesToExport
        
        foreach ($repo in $repositories) {
            Write-Build White "Publishing to repository: $($repo.Name)"

            $publishArgs = @{}
            if ($repo.Credential) {
                $publishArgs.Credential = $repo.Credential
            }

            Publish-Module -Name $module.ModulePath `
                           -Repository $repo.Name `
                           -NuGetApiKey $repo.ApiKey `
                           -AllowPrerelease:$isPreRelease `
                           -Force:$EnablePowerShellModuleForcePublish `
                           -Verbose `
                           @publishArgs
        }
    }
}
