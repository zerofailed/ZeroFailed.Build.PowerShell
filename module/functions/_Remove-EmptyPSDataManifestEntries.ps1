# <copyright file="_Remove-EmptyPSDataManifestEntries.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _Remove-EmptyPSDataManifestEntries {
    <#
        .SYNOPSIS
            Removes the empty entries from the 'PrivateData.PSData' section of a module manifest.

        .DESCRIPTION
            PSResourceGet's Update-PSModuleManifest regenerates the manifest with New-ModuleManifest, which
            fails when a 'PrivateData.PSData' entry is empty (e.g. "ExternalModuleDependencies = @()" or
            "ReleaseNotes = ''"). An empty entry has the same meaning as a missing entry, so this function
            removes them from the manifest file before it is updated.

            An entry is empty when its value is '@()', '' or $null. Only entries in 'PrivateData.PSData' are
            removed: the rest of the manifest is not changed. The file is only written when an entry is removed.

        .PARAMETER Path
            The path to the module manifest (.psd1).

        .INPUTS
            None. You can't pipe objects to _Remove-EmptyPSDataManifestEntries.

        .OUTPUTS
            None.

        .EXAMPLE
            PS:> _Remove-EmptyPSDataManifestEntries -Path ./module/MyModule.psd1
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    $resolvedPath = (Resolve-Path $Path).ProviderPath
    $content = [IO.File]::ReadAllText($resolvedPath)
    # Keep the file's UTF-8 byte order mark, if it has one
    $bytes = [IO.File]::ReadAllBytes($resolvedPath)
    $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF

    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$parseErrors)
    if ($parseErrors) {
        throw "Unable to parse the module manifest '$resolvedPath': $($parseErrors[0].Message)"
    }

    # Finds the hashtable that is the value of the given key, ignoring the case of the key
    function Get-HashtableValue([System.Management.Automation.Language.HashtableAst] $Hashtable, [string] $Key) {
        if (!$Hashtable) {
            return
        }
        $pair = $Hashtable.KeyValuePairs | Where-Object { $_.Item1.Extent.Text.Trim("'`"") -eq $Key } | Select-Object -First 1
        if ($pair) {
            $pair.Item2.GetPureExpression() -as [System.Management.Automation.Language.HashtableAst]
        }
    }

    $manifest = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.HashtableAst] }, $false)
    $psData = $manifest ? (Get-HashtableValue (Get-HashtableValue $manifest 'PrivateData') 'PSData') : $null
    if (!$psData) {
        Write-Verbose "The module manifest '$resolvedPath' has no 'PrivateData.PSData' section"
        return
    }

    $emptyEntries = $psData.KeyValuePairs | Where-Object {
        $value = $_.Item2.GetPureExpression()
        ($value -is [System.Management.Automation.Language.ArrayExpressionAst] -and $value.SubExpression.Statements.Count -eq 0) -or
        ($value -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $value.Value -eq '') -or
        ($value -is [System.Management.Automation.Language.VariableExpressionAst] -and $value.VariablePath.UserPath -eq 'null')
    }
    if (!$emptyEntries) {
        return
    }

    # Remove the entries from the end of the file first, so that the offsets of the earlier entries stay valid
    foreach ($entry in ($emptyEntries | Sort-Object { $_.Item1.Extent.StartOffset } -Descending)) {
        Write-Verbose "Removing the empty entry 'PrivateData.PSData.$($entry.Item1.Extent.Text)' from the module manifest '$resolvedPath'"
        $start = $entry.Item1.Extent.StartOffset
        $end = $entry.Item2.Extent.EndOffset
        # Also remove a ';' that separates the entry from the next one on the same line, which would
        # otherwise be left at the start of the hashtable and make it invalid
        $separator = [regex]::Match($content.Substring($end), '^[ \t]*;')
        if ($separator.Success) {
            $end += $separator.Length
        }
        $content = $content.Remove($start, $end - $start)
    }

    [void][System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$parseErrors)
    if ($parseErrors) {
        throw "Removing the empty 'PrivateData.PSData' entries from the module manifest '$resolvedPath' made it invalid: $($parseErrors[0].Message)"
    }

    [IO.File]::WriteAllText($resolvedPath, $content, [Text.UTF8Encoding]::new($hasBom))
}
