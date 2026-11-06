# <copyright file="_Publish-PSModuleToRepositories.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    . (Join-Path $PSScriptRoot '_Publish-PSModuleToRepositories.ps1')
    . (Join-Path $PSScriptRoot '_Test-IsDuplicatePublishError.ps1')
    . (Join-Path $PSScriptRoot '_Get-RequiredModuleSpecification.ps1')

    function New-TestManifest {
        param([string] $Path, [string] $Content = "@{ ModuleVersion = '1.2.3' }")
        New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
        Set-Content -Path $Path -Value $Content
    }

    function New-TestErrorRecord {
        param([string] $Message, [string] $ErrorId = 'PublishPSResourceError,Microsoft.PowerShell.PSResourceGet.Cmdlets.PublishPSResource')
        [System.Management.Automation.ErrorRecord]::new(
            [System.InvalidOperationException]::new($Message),
            $ErrorId,
            [System.Management.Automation.ErrorCategory]::InvalidOperation,
            $null
        )
    }

    $modulePath = 'TestDrive:/module/MyModule.psd1'
    New-TestManifest -Path $modulePath
    $repos = @(
        @{ Name = 'PSGallery'; ApiKey = 'gallery-key' }
        @{ Name = 'GitHubPackages'; ApiKey = 'ghp-key'; Credential = [pscredential]::new('github-actions', (ConvertTo-SecureString 'token' -AsPlainText -Force)) }
    )
}

Describe '_Publish-PSModuleToRepositories' {

    BeforeEach {
        Mock Write-Host {}
        Mock Write-Warning {}
        Mock Find-PSResource {}
        Mock Publish-PSResource {}
    }

    Context 'Required modules' {

        BeforeAll {
            $depsModulePath = 'TestDrive:/deps/DepsModule.psd1'
            New-TestManifest -Path $depsModulePath -Content @'
@{
    ModuleVersion = '1.2.3'
    RequiredModules = @(
        'Simple'
        @{ ModuleName = 'Ranged'; ModuleVersion = '5.0.0'; MaximumVersion = '5.9.9' }
        @{ ModuleName = 'Az.Accounts'; ModuleVersion = '2.0.0' }
    )
    PrivateData = @{ PSData = @{ ExternalModuleDependencies = @('Az.Accounts') } }
}
'@
        }

        It 'fails before publishing to any repository when a required module has a wildcard MaximumVersion' {
            $wildcardModulePath = 'TestDrive:/wildcard/WildcardModule.psd1'
            New-TestManifest -Path $wildcardModulePath -Content @'
@{
    ModuleVersion = '1.2.3'
    RequiredModules = @(
        @{ ModuleName = 'Ranged'; ModuleVersion = '5.0.0'; MaximumVersion = '5.*' }
        @{ ModuleName = 'Pinned'; ModuleVersion = '1.0.0'; MaximumVersion = '1.9.9' }
        @{ ModuleName = 'Any'; MaximumVersion = '*' }
    )
}
'@

            { _Publish-PSModuleToRepositories -ModulePath $wildcardModulePath -Version '1.2.3' -Repositories $repos -SkipDuplicates } |
                Should -Throw "*cannot publish*wildcard 'MaximumVersion': Ranged (MaximumVersion '5.``*'), Any (MaximumVersion '``*')*"

            Should -Invoke Find-PSResource -Times 0 -Exactly
            Should -Invoke Publish-PSResource -Times 0 -Exactly
        }

        It 'turns off the Publish-PSResource dependency check' {
            _Publish-PSModuleToRepositories -ModulePath $modulePath -Version '1.2.3' -Repositories $repos[0]

            Should -Invoke Publish-PSResource -Times 1 -Exactly -ParameterFilter { $SkipDependenciesCheck }
        }

        It 'looks for each required module that is not external, in each repository, with its version range' {
            Mock Find-PSResource { [pscustomobject]@{ Name = $Name } }

            _Publish-PSModuleToRepositories -ModulePath $depsModulePath -Version '1.2.3' -Repositories $repos

            Should -Invoke Find-PSResource -Times 1 -Exactly -ParameterFilter { $Name -eq 'Simple' -and !$Version -and $Repository -eq 'PSGallery' }
            Should -Invoke Find-PSResource -Times 1 -Exactly -ParameterFilter { $Name -eq 'Ranged' -and $Version -eq '[5.0.0, 5.9.9]' -and $Repository -eq 'PSGallery' }
            Should -Invoke Find-PSResource -Times 1 -Exactly -ParameterFilter {
                $Name -eq 'Simple' -and $Repository -eq 'GitHubPackages' -and $Credential.UserName -eq 'github-actions'
            }
            Should -Invoke Find-PSResource -Times 0 -Exactly -ParameterFilter { $Name -eq 'Az.Accounts' }
            Should -Invoke Publish-PSResource -Times 2 -Exactly
        }

        It 'looks for pre-release versions of the required modules only when <Name>' -ForEach @(
            @{ Name = 'publishing a pre-release'; AllowPrerelease = $true }
            @{ Name = 'not publishing a pre-release'; AllowPrerelease = $false }
        ) {
            Mock Find-PSResource { [pscustomobject]@{ Name = $Name } }

            _Publish-PSModuleToRepositories -ModulePath $depsModulePath -Version '1.2.3' -Repositories $repos[0] -AllowPrerelease:$AllowPrerelease

            Should -Invoke Find-PSResource -Times 2 -Exactly -ParameterFilter { $Name -in 'Simple', 'Ranged' -and [bool]$Prerelease -eq $AllowPrerelease }
        }

        It 'fails a repository that is missing a required module, and still publishes to the others' {
            Mock Find-PSResource { [pscustomobject]@{ Name = $Name } }
            Mock Find-PSResource {} -ParameterFilter { $Name -eq 'Ranged' -and $Repository -eq 'GitHubPackages' }

            { _Publish-PSModuleToRepositories -ModulePath $depsModulePath -Version '1.2.3' -Repositories $repos } |
                Should -Throw "*1 of 2 repositories*GitHubPackages: *not in the repository*Ranged ``[5.0.0, 5.9.9]*"

            Should -Invoke Publish-PSResource -Times 1 -Exactly -ParameterFilter { $Repository -eq 'PSGallery' }
            Should -Invoke Publish-PSResource -Times 0 -Exactly -ParameterFilter { $Repository -eq 'GitHubPackages' }
        }
    }

    Context 'Publishing' {

        It 'publishes to every repository with its API key, and passes credentials only when set' {
            _Publish-PSModuleToRepositories -ModulePath $modulePath -Version '1.2.3' -Repositories $repos -SkipDuplicates

            Should -Invoke Publish-PSResource -Times 2 -Exactly
            Should -Invoke Publish-PSResource -Times 1 -Exactly -ParameterFilter {
                $Path -eq $modulePath -and $Repository -eq 'PSGallery' -and $ApiKey -eq 'gallery-key' -and $null -eq $Credential
            }
            Should -Invoke Publish-PSResource -Times 1 -Exactly -ParameterFilter {
                $Repository -eq 'GitHubPackages' -and $ApiKey -eq 'ghp-key' -and $Credential.UserName -eq 'github-actions'
            }
        }

        It 'publishes a pre-release version from the module manifest path' {
            _Publish-PSModuleToRepositories -ModulePath $modulePath -Version '1.2.3-beta0001' -Repositories $repos[0] -AllowPrerelease

            Should -Invoke Publish-PSResource -Times 1 -Exactly -ParameterFilter { $Path -eq $modulePath -and $Repository -eq 'PSGallery' }
        }

        It 'does nothing when there are no repositories' {
            _Publish-PSModuleToRepositories -ModulePath $modulePath -Version '1.2.3' -Repositories @() -SkipDuplicates

            Should -Invoke Publish-PSResource -Times 0 -Exactly
        }
    }

    Context 'Skipping duplicates' {

        It 'looks for the exact version, using the repository credential' {
            _Publish-PSModuleToRepositories -ModulePath $modulePath -Version '1.2.3-beta0001' -Repositories $repos -AllowPrerelease -SkipDuplicates

            Should -Invoke Find-PSResource -Times 1 -Exactly -ParameterFilter {
                $Name -eq 'MyModule' -and $Version -eq '1.2.3-beta0001' -and $Prerelease -and
                $Repository -eq 'PSGallery' -and $null -eq $Credential
            }
            Should -Invoke Find-PSResource -Times 1 -Exactly -ParameterFilter {
                $Repository -eq 'GitHubPackages' -and $Credential.UserName -eq 'github-actions'
            }
        }

        It 'skips a repository that already holds the version and publishes to the rest' {
            Mock Find-PSResource { [pscustomobject]@{ Name = 'MyModule'; Version = '1.2.3' } } -ParameterFilter { $Repository -eq 'PSGallery' }

            _Publish-PSModuleToRepositories -ModulePath $modulePath -Version '1.2.3' -Repositories $repos -SkipDuplicates

            Should -Invoke Publish-PSResource -Times 0 -Exactly -ParameterFilter { $Repository -eq 'PSGallery' }
            Should -Invoke Publish-PSResource -Times 1 -Exactly -ParameterFilter { $Repository -eq 'GitHubPackages' }
            Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like "*'PSGallery'*already published*" }
        }

        It 'skips a repository when publishing fails with a duplicate error' {
            $record = New-TestErrorRecord -Message 'Response status code does not indicate success: 409 (Conflict - The feed already contains ''MyModule 1.2.3''.)'
            Mock Publish-PSResource { throw $record } -ParameterFilter { $Repository -eq 'GitHubPackages' }

            { _Publish-PSModuleToRepositories -ModulePath $modulePath -Version '1.2.3' -Repositories $repos -SkipDuplicates } |
                Should -Not -Throw

            Should -Invoke Publish-PSResource -Times 2 -Exactly
            Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like "*'GitHubPackages'*already published*" }
        }

        It 'does not look for existing versions when SkipDuplicates is not set' {
            _Publish-PSModuleToRepositories -ModulePath $modulePath -Version '1.2.3' -Repositories $repos

            Should -Invoke Find-PSResource -Times 0 -Exactly
            Should -Invoke Publish-PSResource -Times 2 -Exactly
        }

        It 'fails on a duplicate error when SkipDuplicates is not set' {
            $record = New-TestErrorRecord -Message 'Response status code does not indicate success: 409 (Conflict)'
            Mock Publish-PSResource { throw $record } -ParameterFilter { $Repository -eq 'PSGallery' }

            { _Publish-PSModuleToRepositories -ModulePath $modulePath -Version '1.2.3' -Repositories $repos } |
                Should -Throw '*1 of 2 repositories*PSGallery: *409 (Conflict)*'

            Should -Invoke Publish-PSResource -Times 1 -Exactly -ParameterFilter { $Repository -eq 'GitHubPackages' }
        }
    }

    Context 'Failures' {

        It 'attempts every repository when an earlier one fails, then throws' {
            Mock Publish-PSResource { throw (New-TestErrorRecord -Message '401 (Unauthorized)') } -ParameterFilter { $Repository -eq 'PSGallery' }

            { _Publish-PSModuleToRepositories -ModulePath $modulePath -Version '1.2.3' -Repositories $repos -SkipDuplicates } |
                Should -Throw '*MyModule v1.2.3 to 1 of 2 repositories*PSGallery: 401 (Unauthorized)*'

            Should -Invoke Publish-PSResource -Times 1 -Exactly -ParameterFilter { $Repository -eq 'GitHubPackages' }
        }

        It 'lists every failed repository in the error' {
            Mock Publish-PSResource { throw (New-TestErrorRecord -Message "boom-$Repository") }

            $err = { _Publish-PSModuleToRepositories -ModulePath $modulePath -Version '1.2.3' -Repositories $repos -SkipDuplicates } |
                Should -Throw -PassThru

            $err.Exception.Message | Should -BeLike '*2 of 2 repositories*'
            $err.Exception.Message | Should -BeLike '*- PSGallery: boom-PSGallery*'
            $err.Exception.Message | Should -BeLike '*- GitHubPackages: boom-GitHubPackages*'
        }

        It 'publishes when the duplicate check itself fails' {
            Mock Find-PSResource { throw 'feed unreachable' }

            _Publish-PSModuleToRepositories -ModulePath $modulePath -Version '1.2.3' -Repositories $repos -SkipDuplicates

            Should -Invoke Publish-PSResource -Times 2 -Exactly
        }
    }
}
