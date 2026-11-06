# <copyright file="_Register-PSRepositoryIfMissing.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _Register-PSRepositoryIfMissing {
    <#
        .SYNOPSIS
            Ensures a PowerShell repository is registered with PSResourceGet, registering it when necessary.

        .DESCRIPTION
            Does nothing when a PSResourceGet repository with the given name is already registered. Otherwise
            the repository is registered as trusted using the supplied source location. An error is thrown
            when the repository is not registered and no source location is available.

            PSResourceGet keeps its own list of repositories, so a repository registered only with
            PowerShellGet's 'Register-PSRepository' is not found.

            PSResourceGet publishes to the repository's URI, so a separate publish location is not supported.
            When a publish location that differs from the source location is given, a warning is written and
            the publish location is not used.

        .PARAMETER Name
            The name of the PowerShell repository.

        .PARAMETER SourceLocation
            The URI of the repository, used to find, install and publish modules.

        .PARAMETER PublishLocation
            Not supported by PSResourceGet. A warning is written when it differs from SourceLocation.

        .INPUTS
            None. You can't pipe objects to _Register-PSRepositoryIfMissing.

        .OUTPUTS
            None.

        .EXAMPLE
            PS:> _Register-PSRepositoryIfMissing -Name GitHubPackages -SourceLocation https://nuget.pkg.github.com/myorg/index.json
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter()]
        [string] $SourceLocation,

        [Parameter()]
        [string] $PublishLocation
    )

    if (Get-PSResourceRepository -Name $Name -ErrorAction SilentlyContinue) {
        Write-Verbose "PowerShell repository '$Name' is already registered"
        return
    }

    if ([string]::IsNullOrEmpty($SourceLocation)) {
        throw "The PowerShell repository '$Name' is not registered with PSResourceGet and no 'SourceLocation' was specified to register it."
    }

    if (![string]::IsNullOrEmpty($PublishLocation) -and $PublishLocation -ne $SourceLocation) {
        Write-Warning "The 'PublishLocation' of the PowerShell repository '$Name' is not used: PSResourceGet publishes to the 'SourceLocation' ($SourceLocation)"
    }

    Write-Verbose "Registering PowerShell repository '$Name' ($SourceLocation)"
    Register-PSResourceRepository -Name $Name -Uri $SourceLocation -Trusted
}
