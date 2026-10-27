# <copyright file="_Resolve-PSPublishRepositories.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    . (Join-Path $PSScriptRoot '_Resolve-PSPublishRepositories.ps1')

    # Resolve-Value is provided by ZeroFailed.DevOps.Common; stub it when running standalone
    if (!(Get-Command Resolve-Value -ErrorAction SilentlyContinue)) {
        function Resolve-Value {
            param([AllowNull()][AllowEmptyString()] $Value)
            if ($Value -is [scriptblock]) { $Value.Invoke() } else { $Value }
        }
    }
}

Describe '_Resolve-PSPublishRepositories' {

    It 'falls back to the default repository and API key when none are configured' {
        $result = _Resolve-PSPublishRepositories -Repositories @() -DefaultRepository 'PSGallery' -DefaultApiKey 'key'

        $result.Count | Should -Be 1
        $result[0].Name | Should -Be 'PSGallery'
        $result[0].ApiKey | Should -Be 'key'
    }

    It 'falls back to the default repository when repositories is null' {
        $result = _Resolve-PSPublishRepositories -Repositories $null -DefaultRepository 'MyRepo' -DefaultApiKey 'key'

        $result.Count | Should -Be 1
        $result[0].Name | Should -Be 'MyRepo'
    }

    It 'returns every configured repository and ignores the defaults' {
        $repos = @(
            @{ Name = 'PSGallery'; ApiKey = 'gallery-key' }
            @{ Name = 'GitHubPackages'; ApiKey = 'ghp-key'; SourceLocation = 'https://nuget.pkg.github.com/org/index.json' }
        )

        $result = _Resolve-PSPublishRepositories -Repositories $repos -DefaultRepository 'Other' -DefaultApiKey 'other-key'

        $result.Count | Should -Be 2
        $result.Name | Should -Be @('PSGallery', 'GitHubPackages')
        $result[1].ApiKey | Should -Be 'ghp-key'
    }

    It 'evaluates scriptblock values' {
        $repos = @(
            @{ Name = { 'Lazy' }; ApiKey = { 'lazy-key' } }
        )

        $result = _Resolve-PSPublishRepositories -Repositories $repos

        $result[0].Name | Should -Be 'Lazy'
        $result[0].ApiKey | Should -Be 'lazy-key'
    }

    It 'defaults PublishLocation to SourceLocation' {
        $repos = @(
            @{ Name = 'Feed'; SourceLocation = 'https://feed/index.json' }
        )

        $result = _Resolve-PSPublishRepositories -Repositories $repos

        $result[0].PublishLocation | Should -Be 'https://feed/index.json'
    }

    It 'keeps an explicit PublishLocation' {
        $repos = @(
            @{ Name = 'Feed'; SourceLocation = 'https://feed/index.json'; PublishLocation = 'https://feed/publish' }
        )

        $result = _Resolve-PSPublishRepositories -Repositories $repos

        $result[0].PublishLocation | Should -Be 'https://feed/publish'
    }

    It 'defaults BlockPreReleaseVersions to false' {
        $result = _Resolve-PSPublishRepositories -Repositories @(@{ Name = 'Feed' })

        $result[0].BlockPreReleaseVersions | Should -BeFalse
    }

    It 'resolves BlockPreReleaseVersions, including from a scriptblock' {
        $repos = @(
            @{ Name = 'Literal'; BlockPreReleaseVersions = $true }
            @{ Name = 'Lazy'; BlockPreReleaseVersions = { $true } }
        )

        $result = _Resolve-PSPublishRepositories -Repositories $repos

        $result[0].BlockPreReleaseVersions | Should -BeTrue
        $result[1].BlockPreReleaseVersions | Should -BeTrue
    }

    It 'throws when an entry has no name' {
        { _Resolve-PSPublishRepositories -Repositories @(@{ ApiKey = 'key' }) } |
            Should -Throw "*must specify a 'Name'*"
    }
}
