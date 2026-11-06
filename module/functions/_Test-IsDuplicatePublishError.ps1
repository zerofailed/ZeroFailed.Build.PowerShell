# <copyright file="_Test-IsDuplicatePublishError.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _Test-IsDuplicatePublishError {
    <#
        .SYNOPSIS
            Returns true when a publish error reports that the module version already exists in the repository.

        .DESCRIPTION
            Recognises the PowerShellGet 'ModuleVersionIsAlreadyAvailableInTheGallery' error and the NuGet
            '409 Conflict' response that feeds such as GitHub Packages and PSGallery return when the
            version has already been pushed.

        .PARAMETER ErrorRecord
            The error record to inspect.

        .INPUTS
            None. You can't pipe objects to _Test-IsDuplicatePublishError.

        .OUTPUTS
            System.Boolean.

        .EXAMPLE
            PS:> try { Publish-Module ... } catch { if (_Test-IsDuplicatePublishError -ErrorRecord $_) { ... } }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorRecord] $ErrorRecord
    )

    if ($ErrorRecord.FullyQualifiedErrorId -like 'ModuleVersionIsAlreadyAvailableInTheGallery*') {
        return $true
    }

    return [bool]($ErrorRecord.Exception.Message -match '409 \(?Conflict|feed already contains')
}
