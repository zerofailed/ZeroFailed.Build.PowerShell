# <copyright file="_Register-PSRepositoryIfMissing.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    . (Join-Path $PSScriptRoot '_Register-PSRepositoryIfMissing.ps1')
}

Describe '_Register-PSRepositoryIfMissing' {

    BeforeEach {
        Mock Register-PSRepository {}
    }

    It 'does nothing when the repository is already registered' {
        Mock Get-PSRepository { [pscustomobject]@{ Name = 'PSGallery' } }

        _Register-PSRepositoryIfMissing -Name 'PSGallery'

        Should -Invoke Register-PSRepository -Times 0 -Exactly
    }

    It 'registers a missing repository as trusted, defaulting PublishLocation to SourceLocation' {
        Mock Get-PSRepository {}

        _Register-PSRepositoryIfMissing -Name 'GitHubPackages' -SourceLocation 'https://nuget.pkg.github.com/org/index.json'

        Should -Invoke Register-PSRepository -Times 1 -Exactly -ParameterFilter {
            $Name -eq 'GitHubPackages' -and
            $SourceLocation -eq 'https://nuget.pkg.github.com/org/index.json' -and
            $PublishLocation -eq 'https://nuget.pkg.github.com/org/index.json' -and
            $InstallationPolicy -eq 'Trusted' -and
            $null -eq $Credential
        }
    }

    It 'passes an explicit PublishLocation and Credential' {
        Mock Get-PSRepository {}
        $cred = [pscredential]::new('user', (ConvertTo-SecureString 'secret' -AsPlainText -Force))

        _Register-PSRepositoryIfMissing -Name 'Feed' -SourceLocation 'https://feed/index.json' -PublishLocation 'https://feed/publish' -Credential $cred

        Should -Invoke Register-PSRepository -Times 1 -Exactly -ParameterFilter {
            $PublishLocation -eq 'https://feed/publish' -and
            $Credential.UserName -eq 'user'
        }
    }

    It 'throws when the repository is missing and no SourceLocation is given' {
        Mock Get-PSRepository {}

        { _Register-PSRepositoryIfMissing -Name 'Unknown' } | Should -Throw "*not registered*"
        Should -Invoke Register-PSRepository -Times 0 -Exactly
    }
}
