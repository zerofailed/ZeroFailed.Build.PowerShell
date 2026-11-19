# <copyright file="_Get-PSModulePrereleaseTag.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    . (Join-Path $PSScriptRoot '_Get-NuGetPreReleaseTag.ps1')
    . (Join-Path $PSScriptRoot '_Get-PSModulePrereleaseTag.ps1')
}

Describe '_Get-PSModulePrereleaseTag' {

    It 'returns <Expected> for GitVersion v6 output with label <Label> and number <Number>' -ForEach @(
        @{ Label = 'preview';                                Number = 2; Expected = 'preview0002' }
        @{ Label = 'spike-thing';                            Number = 4; Expected = 'spikething0004' }
        @{ Label = 'UPPER-Case';                             Number = 3; Expected = 'uppercase0003' }
        @{ Label = 'my-feature-2';                           Number = 4; Expected = 'myfeature20004' }
        @{ Label = 'a-really-long-feature-branch-name-here'; Number = 4; Expected = 'areallylongfe0004' }
    ) {
        _Get-PSModulePrereleaseTag -GitVersion @{ PreReleaseLabel = $Label; PreReleaseNumber = $Number } | Should -BeExactly $Expected
    }

    It 'returns the same value for GitVersion v5 and v6 output of the same commit' {
        $v5 = @{ NuGetPreReleaseTag = 'my-feature-2-0004'; PreReleaseLabel = 'my-feature-2'; PreReleaseNumber = 4; PreReleaseTag = 'my-feature-2.4' }
        $v6 = @{ PreReleaseLabel = 'my-feature-2'; PreReleaseNumber = 4; PreReleaseTag = 'my-feature-2.4' }

        _Get-PSModulePrereleaseTag -GitVersion $v5 | Should -BeExactly (_Get-PSModulePrereleaseTag -GitVersion $v6)
    }

    It 'removes every character that is not an ASCII letter or digit' {
        _Get-PSModulePrereleaseTag -GitVersion @{ NuGetPreReleaseTag = 'a_b.c-d+e/f é1' } | Should -BeExactly 'abcdef1'
    }

    It 'returns an empty string for a release build' {
        _Get-PSModulePrereleaseTag -GitVersion @{ SemVer = '1.2.3'; PreReleaseLabel = ''; PreReleaseNumber = $null; PreReleaseTag = '' } |
            Should -BeExactly ''
    }

    It 'returns an empty string when the output is null' {
        _Get-PSModulePrereleaseTag -GitVersion $null | Should -BeExactly ''
    }
}
