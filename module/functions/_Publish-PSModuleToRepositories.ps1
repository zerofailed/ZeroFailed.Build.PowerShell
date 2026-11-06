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

        .PARAMETER ModulePath
            The path to the module manifest (.psd1) to publish. The version in the manifest, including any
            pre-release label, is the version that is published.

        .PARAMETER Version
            The full version of the module, including any pre-release tag (e.g. '1.2.3' or '1.2.3-beta0001').

        .PARAMETER Repositories
            The repositories to publish to, as returned by _Resolve-PSPublishRepositories. Each hashtable
            uses the keys 'Name', 'ApiKey' and 'Credential'.

        .PARAMETER AllowPrerelease
            Passed to Find-PSResource as 'Prerelease', so that the duplicate check can find a pre-release version.

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

            Publish-PSResource -Path $ModulePath `
                               -Repository $repo.Name `
                               -ApiKey $repo.ApiKey `
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
