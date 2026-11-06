# <copyright file="_Repair-PSDataManifestSection.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _Repair-PSDataManifestSection {
    <#
        .SYNOPSIS
            Prepares the 'PrivateData.PSData' section of a module manifest, so that Update-PSModuleManifest can update it.

        .DESCRIPTION
            PSResourceGet's Update-PSModuleManifest regenerates the manifest with New-ModuleManifest, and fails
            on some valid manifests. This function changes the manifest file so that the update succeeds:

            - When the manifest has no 'PrivateData' section, or 'PrivateData' has no 'PSData' section, an empty
              'PSData' section is added. Update-PSModuleManifest fails without one. Other 'PrivateData' entries
              are kept.
            - Empty 'PSData' entries are removed, because New-ModuleManifest fails on them (e.g.
              "ExternalModuleDependencies = @()" or "ReleaseNotes = ''"). An entry is empty when its value is
              '@()', '' or $null. An empty entry has the same meaning as a missing entry.
            - When 'RemovePrerelease' is set, the 'PSData.Prerelease' entry is removed. Update-PSModuleManifest
              keeps an existing pre-release label when it is not given a new one, so a stable build must remove it.

            The rest of the manifest is not changed. The file is only written when something is changed.

        .PARAMETER Path
            The path to the module manifest (.psd1).

        .PARAMETER RemovePrerelease
            When set, the 'PrivateData.PSData.Prerelease' entry is removed, whatever its value.

        .INPUTS
            None. You can't pipe objects to _Repair-PSDataManifestSection.

        .OUTPUTS
            None.

        .EXAMPLE
            PS:> _Repair-PSDataManifestSection -Path ./module/MyModule.psd1 -RemovePrerelease
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter()]
        [switch] $RemovePrerelease
    )

    $resolvedPath = (Resolve-Path $Path).ProviderPath
    $content = [IO.File]::ReadAllText($resolvedPath)
    # Keep the file's UTF-8 byte order mark, if it has one
    $bytes = [IO.File]::ReadAllBytes($resolvedPath)
    $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF

    $parseErrors = $null
    $tokens = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors) {
        throw "Unable to parse the module manifest '$resolvedPath': $($parseErrors[0].Message)"
    }

    # Finds the key/value pair with the given key, ignoring the case of the key and any quotes around it
    function Get-HashtablePair([System.Management.Automation.Language.HashtableAst] $Hashtable, [string] $Key) {
        $Hashtable.KeyValuePairs | Where-Object { $_.Item1.Extent.Text.Trim("'`"") -eq $Key } | Select-Object -First 1
    }

    $manifest = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.HashtableAst] }, $false)
    if (!$manifest) {
        throw "The module manifest '$resolvedPath' does not contain a hashtable"
    }

    # The changes to make, as text edits. They are applied from the end of the file first, so that the
    # offsets of the earlier edits stay valid.
    $edits = [System.Collections.Generic.List[object]]::new()
    function Add-Edit([int] $Start, [int] $End, [string] $Text, [string] $Description) {
        Write-Verbose "$Description in the module manifest '$resolvedPath'"
        $edits.Add([pscustomobject]@{ Start = $Start; End = $End; Text = $Text })
    }

    $privateDataPair = Get-HashtablePair $manifest 'PrivateData'
    $privateData = $privateDataPair ? ($privateDataPair.Item2.GetPureExpression() -as [System.Management.Automation.Language.HashtableAst]) : $null
    $psDataPair = $privateData ? (Get-HashtablePair $privateData 'PSData') : $null
    $psData = $psDataPair ? ($psDataPair.Item2.GetPureExpression() -as [System.Management.Automation.Language.HashtableAst]) : $null

    if (!$privateDataPair) {
        # Insert before the closing '}' of the manifest. A newline separates it from the previous entry.
        $closingBrace = $manifest.Extent.EndOffset - 1
        Add-Edit $closingBrace $closingBrace "`n    PrivateData = @{ PSData = @{} }`n" "Adding an empty 'PrivateData.PSData' section"
    }
    elseif (!$privateData) {
        Write-Verbose "The 'PrivateData' of the module manifest '$resolvedPath' is not a hashtable literal, so it is not changed"
    }
    elseif (!$psDataPair) {
        # Insert after the opening '@{' of PrivateData. A newline separates it from the next entry.
        $afterOpeningBrace = $privateData.Extent.StartOffset + 2
        Add-Edit $afterOpeningBrace $afterOpeningBrace "`n        PSData = @{}`n" "Adding an empty 'PrivateData.PSData' section"
    }
    elseif (!$psData) {
        Write-Verbose "The 'PrivateData.PSData' of the module manifest '$resolvedPath' is not a hashtable literal, so it is not changed"
    }
    else {
        $entriesToRemove = $psData.KeyValuePairs | Where-Object {
            $value = $_.Item2.GetPureExpression()
            ($RemovePrerelease -and $_.Item1.Extent.Text.Trim("'`"") -eq 'Prerelease') -or
            ($value -is [System.Management.Automation.Language.ArrayExpressionAst] -and $value.SubExpression.Statements.Count -eq 0) -or
            ($value -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $value.Value -eq '') -or
            ($value -is [System.Management.Automation.Language.VariableExpressionAst] -and $value.VariablePath.UserPath -eq 'null')
        }
        foreach ($entry in $entriesToRemove) {
            $start = $entry.Item1.Extent.StartOffset
            $end = $entry.Item2.Extent.EndOffset
            # Also remove a ';' that separates the entry from the next one, which would otherwise be left at
            # the start of the hashtable and make it invalid. Comments and newlines can come before the ';'.
            $separator = $tokens |
                Where-Object { $_.Extent.StartOffset -ge $end -and $_.Kind -notin 'Comment', 'NewLine', 'LineContinuation' } |
                Select-Object -First 1
            if ($separator -and $separator.Kind -eq 'Semi') {
                $end = $separator.Extent.EndOffset
            }
            Add-Edit $start $end '' "Removing the entry 'PrivateData.PSData.$($entry.Item1.Extent.Text)'"
        }
    }

    if (!$edits.Count) {
        return
    }

    foreach ($edit in ($edits | Sort-Object Start -Descending)) {
        $content = $content.Remove($edit.Start, $edit.End - $edit.Start).Insert($edit.Start, $edit.Text)
    }

    [void][System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$parseErrors)
    if ($parseErrors) {
        throw "Repairing the 'PrivateData.PSData' section of the module manifest '$resolvedPath' made it invalid: $($parseErrors[0].Message)"
    }

    [IO.File]::WriteAllText($resolvedPath, $content, [Text.UTF8Encoding]::new($hasBom))
}
