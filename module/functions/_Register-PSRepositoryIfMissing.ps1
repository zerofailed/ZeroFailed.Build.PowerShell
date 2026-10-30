# <copyright file="_Register-PSRepositoryIfMissing.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _Register-PSRepositoryIfMissing {
    <#
        .SYNOPSIS
            Ensures a PowerShell repository is registered, registering it when necessary.

        .DESCRIPTION
            Does nothing when a repository with the given name is already registered. Otherwise the
            repository is registered as trusted using the supplied source and publish locations. An error
            is thrown when the repository is not registered and no source location is available.

        .PARAMETER Name
            The name of the PowerShell repository.

        .PARAMETER SourceLocation
            The URI used to find and install modules from the repository.

        .PARAMETER PublishLocation
            The URI used to publish modules to the repository. Defaults to SourceLocation.

        .PARAMETER Credential
            Optional credentials used to access the repository.

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
        [string] $PublishLocation,

        [Parameter()]
        [pscredential] $Credential
    )

    if (Get-PSRepository -Name $Name -ErrorAction SilentlyContinue) {
        Write-Verbose "PowerShell repository '$Name' is already registered"
        return
    }

    if ([string]::IsNullOrEmpty($SourceLocation)) {
        throw "The PowerShell repository '$Name' is not registered and no 'SourceLocation' was specified to register it."
    }

    $registerArgs = @{
        Name = $Name
        SourceLocation = $SourceLocation
        PublishLocation = if ([string]::IsNullOrEmpty($PublishLocation)) { $SourceLocation } else { $PublishLocation }
        InstallationPolicy = 'Trusted'
    }
    if ($Credential) {
        $registerArgs.Credential = $Credential
    }

    Write-Verbose "Registering PowerShell repository '$Name' ($SourceLocation)"
    Register-PSRepository @registerArgs
}
