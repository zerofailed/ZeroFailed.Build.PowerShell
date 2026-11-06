# <copyright file="_Register-PSRepositoryIfMissing.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    . (Join-Path $PSScriptRoot '_Register-PSRepositoryIfMissing.ps1')
}

Describe '_Register-PSRepositoryIfMissing' {

    BeforeEach {
        Mock Register-PSResourceRepository {}
        Mock Write-Warning {}
    }

    It 'does nothing when the repository is already registered' {
        Mock Get-PSResourceRepository { [pscustomobject]@{ Name = 'PSGallery' } }

        _Register-PSRepositoryIfMissing -Name 'PSGallery'

        Should -Invoke Register-PSResourceRepository -Times 0 -Exactly
    }

    It 'registers a missing repository as trusted, using SourceLocation as its URI' {
        Mock Get-PSResourceRepository {}

        _Register-PSRepositoryIfMissing -Name 'GitHubPackages' -SourceLocation 'https://nuget.pkg.github.com/org/index.json'

        Should -Invoke Register-PSResourceRepository -Times 1 -Exactly -ParameterFilter {
            $Name -eq 'GitHubPackages' -and
            $Uri -eq 'https://nuget.pkg.github.com/org/index.json' -and
            $Trusted
        }
        Should -Invoke Write-Warning -Times 0 -Exactly
    }

    It 'does not warn when PublishLocation is the same as SourceLocation' {
        Mock Get-PSResourceRepository {}

        _Register-PSRepositoryIfMissing -Name 'Feed' -SourceLocation 'https://feed/index.json' -PublishLocation 'https://feed/index.json'

        Should -Invoke Write-Warning -Times 0 -Exactly
    }

    It 'warns that a different PublishLocation is not used' {
        Mock Get-PSResourceRepository {}

        _Register-PSRepositoryIfMissing -Name 'Feed' -SourceLocation 'https://feed/index.json' -PublishLocation 'https://feed/publish'

        Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like "*'PublishLocation'*'Feed'*not used*" }
        Should -Invoke Register-PSResourceRepository -Times 1 -Exactly -ParameterFilter { $Uri -eq 'https://feed/index.json' }
    }

    It 'throws when the repository is missing and no SourceLocation is given' {
        Mock Get-PSResourceRepository {}

        { _Register-PSRepositoryIfMissing -Name 'Unknown' } | Should -Throw "*not registered*"
        Should -Invoke Register-PSResourceRepository -Times 0 -Exactly
    }
}
