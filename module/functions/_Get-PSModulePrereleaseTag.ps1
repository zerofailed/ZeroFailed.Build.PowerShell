# <copyright file="_Get-PSModulePrereleaseTag.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _Get-PSModulePrereleaseTag {
    <#
        .SYNOPSIS
            Returns the 'Prerelease' value for a PowerShell module manifest, from the GitVersion output.

        .DESCRIPTION
            Gets the NuGet pre-release tag with '_Get-NuGetPreReleaseTag', which supports GitVersion v5 and
            v6. Then it removes every character that is not an ASCII letter or digit, because a PowerShell
            module's 'Prerelease' value can only contain these characters (e.g. 'my-feature-2-0004' becomes
            'myfeature20004').

            A build without a pre-release label (i.e. a release) returns an empty string.

        .PARAMETER GitVersion
            The GitVersion output, as a dictionary of output property names to values (e.g. the
            '$GitVersion' variable that ZeroFailed.Build.Common sets).

        .INPUTS
            None. You can't pipe objects to _Get-PSModulePrereleaseTag.

        .OUTPUTS
            System.String.

        .EXAMPLE
            PS:> _Get-PSModulePrereleaseTag -GitVersion @{ PreReleaseLabel = 'my-feature'; PreReleaseNumber = 4 }
            myfeature0004
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [System.Collections.IDictionary] $GitVersion
    )

    # Case-sensitive, so that only ASCII letters match the character ranges
    return (_Get-NuGetPreReleaseTag -GitVersion $GitVersion) -creplace '[^A-Za-z0-9]', ''
}
