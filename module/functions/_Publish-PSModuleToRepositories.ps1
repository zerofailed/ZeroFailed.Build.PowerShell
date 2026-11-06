# <copyright file="_Publish-PSModuleToRepositories.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _Publish-PSModuleToRepositories {
    <#
        .SYNOPSIS
            Publishes a PowerShell module to one or more PowerShell repositories.

        .DESCRIPTION
            Publishes the module to each repository in turn. Every repository is attempted, even when
            publishing to an earlier one fails. When any repository fails, a single error that lists
            every failure is thrown after all repositories have been attempted.

            When 'SkipDuplicates' is set, a repository that already holds the module version is skipped
            with a warning instead of failing. This makes a retry safe after a partial failure: the
            repositories that succeeded earlier are skipped, and only the remaining ones are published to.
            A duplicate is detected in two ways:
            - before publishing, by looking for the exact version in the repository (Find-PSResource)
            - after publishing fails, by checking whether the error reports that the version already exists

            Before publishing, each module in the manifest's 'RequiredModules' must exist in the repository,
            so that the published module can be installed from it. Modules listed in the manifest's
            'PrivateData.PSData.ExternalModuleDependencies' are not checked, because they are installed from
            somewhere else. Publish-PSResource's own dependency check is turned off, because it does not skip
            external dependencies.

            An error is thrown before publishing to any repository when a 'RequiredModules' entry has a
            wildcard 'MaximumVersion' (e.g. '5.*'), because Publish-PSResource cannot publish such a module.

        .PARAMETER ModulePath
            The path to the module manifest (.psd1) to publish. The version in the manifest, including any
            pre-release label, is the version that is published.

        .PARAMETER Version
            The full version of the module, including any pre-release tag (e.g. '1.2.3' or '1.2.3-beta0001').

        .PARAMETER Repositories
            The repositories to publish to, as returned by _Resolve-PSPublishRepositories. Each hashtable
            uses the keys 'Name', 'ApiKey' and 'Credential'.

        .PARAMETER AllowPrerelease
            Passed to Find-PSResource as 'Prerelease', so that the duplicate check can find a pre-release version,
            and the required modules check can find a required module that is only available as a pre-release.

        .PARAMETER SkipDuplicates
            When set, repositories that already hold this module version are skipped instead of failing.

        .INPUTS
            None. You can't pipe objects to _Publish-PSModuleToRepositories.

        .OUTPUTS
            None.

        .EXAMPLE
            PS:> _Publish-PSModuleToRepositories -ModulePath ./module/MyModule.psd1 -Version 1.2.3 -Repositories $repos -SkipDuplicates
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $ModulePath,

        [Parameter(Mandatory)]
        [string] $Version,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [hashtable[]] $Repositories,

        [Parameter()]
        [switch] $AllowPrerelease,

        [Parameter()]
        [switch] $SkipDuplicates
    )

    $moduleName = [IO.Path]::GetFileNameWithoutExtension($ModulePath)
    $failures = [System.Collections.Generic.List[string]]::new()

    # The required modules that must be in each repository, i.e. all of them except the external ones
    $manifest = Import-PowerShellDataFile -Path $ModulePath

    # Publish-PSResource cannot pack a module that has a wildcard MaximumVersion (e.g. '5.*') in its
    # RequiredModules, and fails with an unclear error. So fail before publishing to any repository.
    $wildcardModules = @(
        $manifest.RequiredModules |
            Where-Object { $_ -is [hashtable] -and $_['MaximumVersion'] -match '\*' } |
            ForEach-Object { "$($_['ModuleName']) (MaximumVersion '$($_['MaximumVersion'])')" }
    )
    if ($wildcardModules) {
        throw ("Unable to publish $moduleName v${Version}: PSResourceGet cannot publish a module whose 'RequiredModules' has a wildcard 'MaximumVersion': " +
               ($wildcardModules -join ', ') +
               ". Use an explicit 'MaximumVersion' instead (e.g. '5.99999999' instead of '5.*'), or remove it.")
    }

    $externalModules = @($manifest.PrivateData.PSData.ExternalModuleDependencies | Where-Object { $_ })
    $dependencies = @(
        $manifest.RequiredModules |
            Where-Object { $_ } |
            ForEach-Object { _Get-RequiredModuleSpecification -RequiredModule $_ } |
            Where-Object { $_.Name -notin $externalModules }
    )

    foreach ($repo in $Repositories) {
        Write-Host "Publishing $moduleName v$Version to repository: $($repo.Name)"

        $credentialArgs = @{}
        if ($repo.Credential) {
            $credentialArgs.Credential = $repo.Credential
        }

        try {
            if ($SkipDuplicates) {
                # This check is best-effort: if it fails, publish anyway and rely on the error check below
                $existing = $null
                try {
                    $existing = Find-PSResource -Name $moduleName `
                                                -Version $Version `
                                                -Prerelease:$AllowPrerelease `
                                                -Repository $repo.Name `
                                                -ErrorAction SilentlyContinue `
                                                @credentialArgs
                }
                catch {
                    Write-Verbose "Unable to check repository '$($repo.Name)' for an existing version: $($_.Exception.Message)"
                }
                if ($existing) {
                    Write-Warning "Skipping repository '$($repo.Name)': $moduleName v$Version is already published there"
                    continue
                }
            }

            $missingDependencies = @(
                foreach ($dependency in $dependencies) {
                    $versionArgs = $dependency.Version ? @{ Version = $dependency.Version } : @{}
                    # A pre-release module can depend on a module that is only available as a pre-release
                    $found = Find-PSResource -Name $dependency.Name `
                                             -Prerelease:$AllowPrerelease `
                                             -Repository $repo.Name `
                                             -ErrorAction SilentlyContinue `
                                             @versionArgs `
                                             @credentialArgs
                    if (!$found) {
                        $dependency.Version ? "$($dependency.Name) $($dependency.Version)" : $dependency.Name
                    }
                }
            )
            if ($missingDependencies) {
                throw "These required modules are not in the repository, and are not listed in 'ExternalModuleDependencies': $($missingDependencies -join ', ')"
            }

            Publish-PSResource -Path $ModulePath `
                               -Repository $repo.Name `
                               -ApiKey $repo.ApiKey `
                               -SkipDependenciesCheck `
                               -ErrorAction Stop `
                               -Verbose `
                               @credentialArgs
        }
        catch {
            if ($SkipDuplicates -and (_Test-IsDuplicatePublishError -ErrorRecord $_)) {
                Write-Warning "Skipping repository '$($repo.Name)': $moduleName v$Version is already published there ($($_.Exception.Message))"
                continue
            }

            Write-Warning "Failed to publish $moduleName v$Version to repository '$($repo.Name)': $($_.Exception.Message)"
            $failures.Add("$($repo.Name): $($_.Exception.Message)")
        }
    }

    if ($failures.Count -gt 0) {
        throw ("Failed to publish $moduleName v$Version to $($failures.Count) of $($Repositories.Count) repositories:`n- " + ($failures -join "`n- "))
    }
}
