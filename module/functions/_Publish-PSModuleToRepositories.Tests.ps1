# <copyright file="_Publish-PSModuleToRepositories.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    . (Join-Path $PSScriptRoot '_Publish-PSModuleToRepositories.ps1')
    . (Join-Path $PSScriptRoot '_Test-IsDuplicatePublishError.ps1')

    function New-TestErrorRecord {
        param([string] $Message, [string] $ErrorId = 'FailedToPublishTheModule,Publish-Module')
        [System.Management.Automation.ErrorRecord]::new(
            [System.InvalidOperationException]::new($Message),
            $ErrorId,
            [System.Management.Automation.ErrorCategory]::InvalidOperation,
            $null
        )
    }

    $modulePath = 'TestDrive:/module/MyModule.psd1'
    $repos = @(
        @{ Name = 'PSGallery'; ApiKey = 'gallery-key' }
        @{ Name = 'GitHubPackages'; ApiKey = 'ghp-key'; Credential = [pscredential]::new('github-actions', (ConvertTo-SecureString 'token' -AsPlainText -Force)) }
    )
}

Describe '_Publish-PSModuleToRepositories' {

    BeforeEach {
        Mock Write-Host {}
        Mock Write-Warning {}
        Mock Find-Module {}
        Mock Publish-Module {}
    }

    Context 'Publishing' {

        It 'publishes to every repository with its API key, and passes credentials only when set' {
            _Publish-PSModuleToRepositories -ModulePath $modulePath -Version '1.2.3' -Repositories $repos -SkipDuplicates

            Should -Invoke Publish-Module -Times 2 -Exactly
            Should -Invoke Publish-Module -Times 1 -Exactly -ParameterFilter {
                $Name -eq $modulePath -and $Repository -eq 'PSGallery' -and $NuGetApiKey -eq 'gallery-key' -and $null -eq $Credential
            }
            Should -Invoke Publish-Module -Times 1 -Exactly -ParameterFilter {
                $Repository -eq 'GitHubPackages' -and $NuGetApiKey -eq 'ghp-key' -and $Credential.UserName -eq 'github-actions'
            }
        }

        It 'passes AllowPrerelease and Force through to Publish-Module' {
            _Publish-PSModuleToRepositories -ModulePath $modulePath -Version '1.2.3-beta0001' -Repositories $repos[0] -AllowPrerelease -Force

            Should -Invoke Publish-Module -Times 1 -Exactly -ParameterFilter { $AllowPrerelease -and $Force }
        }

        It 'does nothing when there are no repositories' {
            _Publish-PSModuleToRepositories -ModulePath $modulePath -Version '1.2.3' -Repositories @() -SkipDuplicates

            Should -Invoke Publish-Module -Times 0 -Exactly
        }
    }

    Context 'Skipping duplicates' {

        It 'looks for the exact version, using the repository credential' {
            _Publish-PSModuleToRepositories -ModulePath $modulePath -Version '1.2.3-beta0001' -Repositories $repos -AllowPrerelease -SkipDuplicates

            Should -Invoke Find-Module -Times 1 -Exactly -ParameterFilter {
                $Name -eq 'MyModule' -and $RequiredVersion -eq '1.2.3-beta0001' -and $AllowPrerelease -and
                $Repository -eq 'PSGallery' -and $null -eq $Credential
            }
            Should -Invoke Find-Module -Times 1 -Exactly -ParameterFilter {
                $Repository -eq 'GitHubPackages' -and $Credential.UserName -eq 'github-actions'
            }
        }

        It 'skips a repository that already holds the version and publishes to the rest' {
            Mock Find-Module { [pscustomobject]@{ Name = 'MyModule'; Version = '1.2.3' } } -ParameterFilter { $Repository -eq 'PSGallery' }

            _Publish-PSModuleToRepositories -ModulePath $modulePath -Version '1.2.3' -Repositories $repos -SkipDuplicates

            Should -Invoke Publish-Module -Times 0 -Exactly -ParameterFilter { $Repository -eq 'PSGallery' }
            Should -Invoke Publish-Module -Times 1 -Exactly -ParameterFilter { $Repository -eq 'GitHubPackages' }
            Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like "*'PSGallery'*already published*" }
        }

        It 'skips a repository when publishing fails with a duplicate error: <ErrorId>' -ForEach @(
            @{ ErrorId = 'ModuleVersionIsAlreadyAvailableInTheGallery,Publish-Module'; Message = 'already available' }
            @{ ErrorId = 'FailedToPublishTheModule,Publish-Module'; Message = 'Response status code does not indicate success: 409 (Conflict - The feed already contains ''MyModule 1.2.3''.)' }
        ) {
            $record = New-TestErrorRecord -Message $Message -ErrorId $ErrorId
            Mock Publish-Module { throw $record } -ParameterFilter { $Repository -eq 'GitHubPackages' }

            { _Publish-PSModuleToRepositories -ModulePath $modulePath -Version '1.2.3' -Repositories $repos -SkipDuplicates } |
                Should -Not -Throw

            Should -Invoke Publish-Module -Times 2 -Exactly
            Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like "*'GitHubPackages'*already published*" }
        }

        It 'does not look for existing versions when SkipDuplicates is not set' {
            _Publish-PSModuleToRepositories -ModulePath $modulePath -Version '1.2.3' -Repositories $repos

            Should -Invoke Find-Module -Times 0 -Exactly
            Should -Invoke Publish-Module -Times 2 -Exactly
        }

        It 'fails on a duplicate error when SkipDuplicates is not set' {
            $record = New-TestErrorRecord -Message 'already available' -ErrorId 'ModuleVersionIsAlreadyAvailableInTheGallery,Publish-Module'
            Mock Publish-Module { throw $record } -ParameterFilter { $Repository -eq 'PSGallery' }

            { _Publish-PSModuleToRepositories -ModulePath $modulePath -Version '1.2.3' -Repositories $repos } |
                Should -Throw '*1 of 2 repositories*PSGallery: already available*'

            Should -Invoke Publish-Module -Times 1 -Exactly -ParameterFilter { $Repository -eq 'GitHubPackages' }
        }
    }

    Context 'Failures' {

        It 'attempts every repository when an earlier one fails, then throws' {
            Mock Publish-Module { throw (New-TestErrorRecord -Message '401 (Unauthorized)') } -ParameterFilter { $Repository -eq 'PSGallery' }

            { _Publish-PSModuleToRepositories -ModulePath $modulePath -Version '1.2.3' -Repositories $repos -SkipDuplicates } |
                Should -Throw '*MyModule v1.2.3 to 1 of 2 repositories*PSGallery: 401 (Unauthorized)*'

            Should -Invoke Publish-Module -Times 1 -Exactly -ParameterFilter { $Repository -eq 'GitHubPackages' }
        }

        It 'lists every failed repository in the error' {
            Mock Publish-Module { throw (New-TestErrorRecord -Message "boom-$Repository") }

            $err = { _Publish-PSModuleToRepositories -ModulePath $modulePath -Version '1.2.3' -Repositories $repos -SkipDuplicates } |
                Should -Throw -PassThru

            $err.Exception.Message | Should -BeLike '*2 of 2 repositories*'
            $err.Exception.Message | Should -BeLike '*- PSGallery: boom-PSGallery*'
            $err.Exception.Message | Should -BeLike '*- GitHubPackages: boom-GitHubPackages*'
        }

        It 'publishes when the duplicate check itself fails' {
            Mock Find-Module { throw 'feed unreachable' }

            _Publish-PSModuleToRepositories -ModulePath $modulePath -Version '1.2.3' -Repositories $repos -SkipDuplicates

            Should -Invoke Publish-Module -Times 2 -Exactly
        }
    }
}
