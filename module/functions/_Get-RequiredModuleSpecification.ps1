# <copyright file="_Get-RequiredModuleSpecification.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _Get-RequiredModuleSpecification {
    <#
        .SYNOPSIS
            Converts an entry from a module manifest's 'RequiredModules' to a module name and a NuGet version range.

        .DESCRIPTION
            A 'RequiredModules' entry is either a module name, or a hashtable with the key 'ModuleName' and
            the version keys 'RequiredVersion', 'ModuleVersion' (minimum) and 'MaximumVersion'. PSResourceGet
            takes a version as a NuGet version range, so the version keys are converted:

            - RequiredVersion '1.2.3'                    -> '[1.2.3]'
            - ModuleVersion '1.0'                        -> '[1.0, )'
            - MaximumVersion '2.0'                       -> '(, 2.0]'
            - ModuleVersion '1.0', MaximumVersion '2.0'  -> '[1.0, 2.0]'
            - MaximumVersion '5.*'                       -> '(, 6)'     (any 5.x version)
            - MaximumVersion '5.2.*'                     -> '(, 5.3)'   (any 5.2.x version)
            - MaximumVersion '*'                         -> no maximum

            When the entry has no version keys, 'Version' is $null, which means any version.

        .PARAMETER RequiredModule
            An entry from a module manifest's 'RequiredModules': a module name or a hashtable.

        .INPUTS
            None. You can't pipe objects to _Get-RequiredModuleSpecification.

        .OUTPUTS
            A PSCustomObject with the properties 'Name' and 'Version'.

        .EXAMPLE
            PS:> _Get-RequiredModuleSpecification -RequiredModule @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [object] $RequiredModule
    )

    if ($RequiredModule -isnot [hashtable]) {
        return [pscustomobject]@{ Name = [string]$RequiredModule; Version = $null }
    }

    $version = $null
    $minimum = $RequiredModule['ModuleVersion']
    $maximum = $RequiredModule['MaximumVersion']
    $maximumIsInclusive = $true

    # A wildcard maximum version (e.g. '5.*') allows any version that starts with the part before the '*',
    # so it becomes an exclusive maximum with the last number of that part increased by one (e.g. '6')
    if ($maximum -match '\*') {
        $prefix = $maximum -replace '\.?\*$', ''
        if ($prefix) {
            $parts = $prefix.Split('.')
            $parts[-1] = [int]$parts[-1] + 1
            $maximum = $parts -join '.'
            $maximumIsInclusive = $false
        }
        else {
            $maximum = $null
        }
    }

    if ($RequiredModule['RequiredVersion']) {
        $version = "[$($RequiredModule['RequiredVersion'])]"
    }
    elseif ($minimum -or $maximum) {
        $version = '{0}{1}, {2}{3}' -f ($minimum ? '[' : '('), $minimum, $maximum, (($maximum -and $maximumIsInclusive) ? ']' : ')')
    }

    [pscustomobject]@{ Name = [string]$RequiredModule['ModuleName']; Version = $version }
}
