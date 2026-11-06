# <copyright file="_Test-IsDuplicatePublishError.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    . (Join-Path $PSScriptRoot '_Test-IsDuplicatePublishError.ps1')

    function New-TestErrorRecord {
        param([string] $Message, [string] $ErrorId = 'SomeError')
        [System.Management.Automation.ErrorRecord]::new(
            [System.InvalidOperationException]::new($Message),
            $ErrorId,
            [System.Management.Automation.ErrorCategory]::InvalidOperation,
            $null
        )
    }
}

Describe '_Test-IsDuplicatePublishError' {

    It 'recognises the PowerShellGet duplicate version error' {
        $record = New-TestErrorRecord -Message 'already available' -ErrorId 'ModuleVersionIsAlreadyAvailableInTheGallery,Publish-Module'

        _Test-IsDuplicatePublishError -ErrorRecord $record | Should -BeTrue
    }

    It 'recognises a NuGet 409 Conflict response: <_>' -ForEach @(
        "Failed to publish module 'MyModule': 'Response status code does not indicate success: 409 (Conflict - The feed already contains 'MyModule 1.0.0'. ...)'."
        "Response status code does not indicate success: 409 Conflict"
        "The feed already contains 'MyModule 1.0.0'."
    ) {
        _Test-IsDuplicatePublishError -ErrorRecord (New-TestErrorRecord -Message $_) | Should -BeTrue
    }

    It 'does not treat other errors as duplicates: <_>' -ForEach @(
        "Response status code does not indicate success: 401 (Unauthorized)."
        "Response status code does not indicate success: 403 (Forbidden)."
        "The module 'MyModule' with version '1.0.0-beta' cannot be published as the current version '1.0.0' is already available in the repository."
    ) {
        _Test-IsDuplicatePublishError -ErrorRecord (New-TestErrorRecord -Message $_) | Should -BeFalse
    }

    It 'does not treat a version-ordering error as a duplicate' {
        $record = New-TestErrorRecord -Message 'version should be greater' -ErrorId 'ModuleVersionShouldBeGreaterThanGalleryVersion,Publish-Module'

        _Test-IsDuplicatePublishError -ErrorRecord $record | Should -BeFalse
    }
}
