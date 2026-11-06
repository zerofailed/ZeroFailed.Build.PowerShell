# <copyright file="_Update-PSModuleManifestKeepingPrivateData.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _Update-PSModuleManifestKeepingPrivateData {
    <#
        .SYNOPSIS
            Updates a module manifest with Update-PSModuleManifest, keeping the 'PrivateData' entries other than 'PSData'.

        .DESCRIPTION
            Update-PSModuleManifest regenerates the manifest with New-ModuleManifest, which writes a hashtable in
            'PrivateData' (other than 'PSData') as the text 'System.Collections.Hashtable'. That loses metadata
            such as 'PrivateData.ZeroFailed', which holds a ZeroFailed extension's dependencies.

            This function runs Update-PSModuleManifest, then puts back the original text of each 'PrivateData'
            entry other than 'PSData', including any comments in it. It then checks that the values of those
            entries are the same as before the update.

        .PARAMETER Path
            The path to the module manifest (.psd1).

        .PARAMETER UpdateArguments
            The other arguments to pass to Update-PSModuleManifest (e.g. 'ModuleVersion' and 'FunctionsToExport').

        .INPUTS
            None. You can't pipe objects to _Update-PSModuleManifestKeepingPrivateData.

        .OUTPUTS
            None.

        .EXAMPLE
            PS:> _Update-PSModuleManifestKeepingPrivateData -Path ./module/MyModule.psd1 -UpdateArguments @{ ModuleVersion = '1.2.3' }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter()]
        [hashtable] $UpdateArguments = @{}
    )

    $resolvedPath = (Resolve-Path $Path).ProviderPath

    # Returns the manifest's text, and the key/value pairs of its 'PrivateData' entries other than 'PSData'
    function Get-PrivateDataEntries {
        $content = [IO.File]::ReadAllText($resolvedPath)
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$parseErrors)
        if ($parseErrors) {
            throw "Unable to parse the module manifest '$resolvedPath': $($parseErrors[0].Message)"
        }
        $manifest = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.HashtableAst] }, $false)
        $privateDataPair = $manifest ? ($manifest.KeyValuePairs | Where-Object { $_.Item1.Extent.Text.Trim("'`"") -eq 'PrivateData' } | Select-Object -First 1) : $null
        $privateData = $privateDataPair ? ($privateDataPair.Item2.GetPureExpression() -as [System.Management.Automation.Language.HashtableAst]) : $null
        [pscustomobject]@{
            Content = $content
            Entries = @($privateData ? ($privateData.KeyValuePairs | Where-Object { $_.Item1.Extent.Text.Trim("'`"") -ne 'PSData' }) : @())
        }
    }

    $before = Get-PrivateDataEntries
    $originalValues = (Import-PowerShellDataFile -Path $resolvedPath).PrivateData
    # The original text of each entry's value, by key
    $originalText = [ordered]@{}
    foreach ($entry in $before.Entries) {
        $originalText[$entry.Item1.Extent.Text.Trim("'`"")] = $entry.Item2.Extent.Text
    }

    Update-PSModuleManifest -Path $resolvedPath @UpdateArguments

    if (!$originalText.Count) {
        return
    }

    $after = Get-PrivateDataEntries
    $content = $after.Content
    $restored = @{}
    # Replace each value from the end of the file first, so that the offsets of the earlier values stay valid
    foreach ($entry in ($after.Entries | Sort-Object { $_.Item2.Extent.StartOffset } -Descending)) {
        $key = $entry.Item1.Extent.Text.Trim("'`"")
        if ($originalText.Contains($key)) {
            Write-Verbose "Restoring the entry 'PrivateData.$key' in the module manifest '$resolvedPath'"
            $start = $entry.Item2.Extent.StartOffset
            $content = $content.Remove($start, $entry.Item2.Extent.EndOffset - $start).Insert($start, $originalText[$key])
            $restored[$key] = $true
        }
    }

    $missing = @($originalText.Keys | Where-Object { !$restored.ContainsKey($_) })
    if ($missing) {
        throw "Update-PSModuleManifest removed these 'PrivateData' entries from the module manifest '$resolvedPath', so they could not be restored: $($missing -join ', ')"
    }

    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$parseErrors)
    if ($parseErrors) {
        throw "Restoring the 'PrivateData' entries of the module manifest '$resolvedPath' made it invalid: $($parseErrors[0].Message)"
    }

    # Update-PSModuleManifest writes UTF-8 without a byte order mark
    [IO.File]::WriteAllText($resolvedPath, $content, [Text.UTF8Encoding]::new($false))

    # Check that every restored entry has the same value as before the update
    $restoredValues = (Import-PowerShellDataFile -Path $resolvedPath).PrivateData
    foreach ($key in $originalText.Keys) {
        $expected = ConvertTo-Json -InputObject $originalValues[$key] -Depth 20 -Compress
        $actual = ConvertTo-Json -InputObject $restoredValues[$key] -Depth 20 -Compress
        if ($actual -ne $expected) {
            throw "The entry 'PrivateData.$key' in the module manifest '$resolvedPath' has a different value after the update: '$actual' instead of '$expected'"
        }
    }
}
