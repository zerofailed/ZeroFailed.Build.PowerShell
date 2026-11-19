# <copyright file="_Get-NuGetPreReleaseTag.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _Get-NuGetPreReleaseTag {
    <#
        .SYNOPSIS
            Returns the GitVersion v5 'NuGetPreReleaseTag' value for the given GitVersion output, for any version of GitVersion.

        .DESCRIPTION
            GitVersion v6 no longer outputs 'NuGetPreReleaseTag'. This function returns the same value
            that GitVersion v5 outputs, so that a commit gets the same pre-release tag with either version.

            When the GitVersion output has a 'NuGetPreReleaseTag' value (GitVersion v5, or an override that
            sets it), that value is returned unchanged.

            Otherwise the value is made from 'PreReleaseLabel' and 'PreReleaseNumber' (GitVersion v5 and v6
            both output these), or from 'PreReleaseTag' when those are missing. The rules are the same as
            the ones GitVersion v5 uses:

            - The label is converted to lower case.
            - The number has leading zeros, to a minimum of 4 digits (e.g. '0012'). NuGet compares older
              (SemVer 1.0) pre-release tags as text, so this keeps 'preview0010' after 'preview0009'.
            - When the label ends with a digit, a '-' is put between the label and the number.
            - The label is shortened so that the result is no longer than 20 characters.

            A build without a pre-release label (i.e. a release) returns an empty string.

        .PARAMETER GitVersion
            The GitVersion output, as a dictionary of output property names to values (e.g. the
            '$GitVersion' variable that ZeroFailed.Build.Common sets).

        .INPUTS
            None. You can't pipe objects to _Get-NuGetPreReleaseTag.

        .OUTPUTS
            System.String.

        .EXAMPLE
            PS:> _Get-NuGetPreReleaseTag -GitVersion @{ PreReleaseLabel = 'preview'; PreReleaseNumber = 12 }
            preview0012

        .EXAMPLE
            PS:> _Get-NuGetPreReleaseTag -GitVersion @{ PreReleaseTag = 'my-feature-2.4' }
            my-feature-2-0004
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [System.Collections.IDictionary] $GitVersion
    )

    # The maximum length of a pre-release tag in GitVersion v5's legacy SemVer formats
    $maxLength = 20

    if (!$GitVersion) {
        return ''
    }

    $nuGetPreReleaseTag = [string]$GitVersion['NuGetPreReleaseTag']
    if (![string]::IsNullOrWhiteSpace($nuGetPreReleaseTag)) {
        return $nuGetPreReleaseTag
    }

    $label = [string]$GitVersion['PreReleaseLabel']
    $number = [string]$GitVersion['PreReleaseNumber']

    if ([string]::IsNullOrWhiteSpace($label)) {
        # 'PreReleaseTag' has the format '<label>.<number>' (e.g. 'preview.12'), or only '<label>'
        $preReleaseTag = [string]$GitVersion['PreReleaseTag']
        if ([string]::IsNullOrWhiteSpace($preReleaseTag)) {
            return ''
        }
        if ($preReleaseTag -match '^(?<label>.*?)\.(?<number>\d+)$') {
            $label = $Matches.label
            $number = $Matches.number
        }
        else {
            $label = $preReleaseTag
            $number = ''
        }
    }

    $label = $label.Trim().ToLowerInvariant()
    if (!$label) {
        return ''
    }

    $suffix = ''
    $number = $number.Trim()
    if ($number) {
        $parsedNumber = 0L
        if (![long]::TryParse($number, [System.Globalization.NumberStyles]::None, [cultureinfo]::InvariantCulture, [ref]$parsedNumber)) {
            throw "The GitVersion pre-release number '$number' is not a whole number"
        }
        $suffix = $parsedNumber.ToString('D4', [cultureinfo]::InvariantCulture)
        # Keeps the label and number apart (e.g. 'ver2-0004' instead of 'ver20004'). GitVersion v5 tests the
        # label before it is shortened.
        if ([char]::IsDigit($label[-1])) {
            $suffix = "-$suffix"
        }
    }

    $maxLabelLength = [Math]::Max(0, $maxLength - $suffix.Length)
    if ($label.Length -gt $maxLabelLength) {
        $label = $label.Substring(0, $maxLabelLength)
    }

    return "$label$suffix"
}
