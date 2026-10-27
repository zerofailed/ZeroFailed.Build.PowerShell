# <copyright file="_Resolve-PSPublishRepositories.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _Resolve-PSPublishRepositories {
    <#
        .SYNOPSIS
            Returns the normalised list of PowerShell repositories that modules should be published to.

        .DESCRIPTION
            Converts the user-supplied repository configuration into a consistent set of hashtables.
            When no repositories are configured, a single entry is built from the default repository
            name and API key, so that the legacy single-repository properties keep working.

            Any value supplied as a scriptblock is evaluated (via Resolve-Value), allowing secrets to be
            resolved lazily at publish time. 'PublishLocation' defaults to 'SourceLocation' when omitted.
            'BlockPreReleaseVersions' is normalised to a boolean, defaulting to false.

        .PARAMETER Repositories
            The repository configuration, as an array of hashtables with the keys 'Name' (required),
            'ApiKey', 'SourceLocation', 'PublishLocation', 'Credential' and 'BlockPreReleaseVersions'.

        .PARAMETER DefaultRepository
            The repository name used when no repositories are configured.

        .PARAMETER DefaultApiKey
            The API key used when no repositories are configured.

        .INPUTS
            None. You can't pipe objects to _Resolve-PSPublishRepositories.

        .OUTPUTS
            System.Collections.Hashtable[].

        .EXAMPLE
            PS:> _Resolve-PSPublishRepositories -Repositories @() -DefaultRepository PSGallery -DefaultApiKey $key
    #>
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param(
        [Parameter()]
        [AllowNull()]
        [AllowEmptyCollection()]
        [hashtable[]] $Repositories,

        [Parameter()]
        [string] $DefaultRepository = 'PSGallery',

        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        $DefaultApiKey
    )

    if (!$Repositories -or $Repositories.Count -eq 0) {
        $Repositories = @(
            @{
                Name = $DefaultRepository
                ApiKey = $DefaultApiKey
            }
        )
    }

    $resolved = foreach ($repo in $Repositories) {
        $name = Resolve-Value $repo.Name
        if ([string]::IsNullOrEmpty($name)) {
            throw "Each entry in 'PowerShellRepositories' must specify a 'Name'."
        }

        $sourceLocation = Resolve-Value $repo.SourceLocation
        $publishLocation = Resolve-Value $repo.PublishLocation
        if ([string]::IsNullOrEmpty($publishLocation)) {
            $publishLocation = $sourceLocation
        }

        @{
            Name = $name
            ApiKey = Resolve-Value $repo.ApiKey
            SourceLocation = $sourceLocation
            PublishLocation = $publishLocation
            Credential = Resolve-Value $repo.Credential
            BlockPreReleaseVersions = [bool](Resolve-Value $repo.BlockPreReleaseVersions)
        }
    }

    # Prevent a single-entry array from being unrolled to a bare hashtable
    return ,[hashtable[]]@($resolved)
}
