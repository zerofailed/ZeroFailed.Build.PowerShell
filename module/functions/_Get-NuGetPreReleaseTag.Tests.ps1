# <copyright file="_Get-NuGetPreReleaseTag.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    . (Join-Path $PSScriptRoot '_Get-NuGetPreReleaseTag.ps1')
}

Describe '_Get-NuGetPreReleaseTag' {

    # Each case is the output of GitVersion 5.8.0 for one commit: its 'PreReleaseLabel' and 'PreReleaseNumber',
    # and the 'NuGetPreReleaseTag' that it made from them. GitVersion v6 outputs the same label and number.
    BeforeDiscovery {
        $gitVersion5Outputs = @(
            @{ Branch = 'main';                                           Label = 'preview';                                Number = 2;   Expected = 'preview0002' }
            @{ Branch = 'feature/foo';                                    Label = 'foo';                                    Number = 5;   Expected = 'foo0005' }
            @{ Branch = 'feature/many';                                   Label = 'many';                                   Number = 14;  Expected = 'many0014' }
            @{ Branch = 'feature/lots';                                   Label = 'lots';                                   Number = 122; Expected = 'lots0122' }
            @{ Branch = 'hotfix/oops';                                    Label = 'beta';                                   Number = 5;   Expected = 'beta0005' }
            @{ Branch = 'release/1.3';                                    Label = 'beta';                                   Number = 2;   Expected = 'beta0002' }
            @{ Branch = 'spike/thing';                                    Label = 'spike-thing';                            Number = 4;   Expected = 'spike-thing0004' }
            @{ Branch = 'dependabot/nuget/Some.Package-1.2.3';            Label = 'dependabot';                             Number = 4;   Expected = 'dependabot0004' }
            @{ Branch = 'feature/some.dotted.name';                       Label = 'some-dotted-name';                       Number = 4;   Expected = 'some-dotted-name0004' }
            @{ Branch = 'feature/UPPER_Case';                             Label = 'UPPER-Case';                             Number = 3;   Expected = 'upper-case0003' }
            @{ Branch = 'feature/my_feature-2';                           Label = 'my-feature-2';                           Number = 4;   Expected = 'my-feature-2-0004' }
            @{ Branch = 'feature/ver2';                                   Label = 'ver2';                                   Number = 4;   Expected = 'ver2-0004' }
            @{ Branch = 'feature/a-really-long-feature-branch-name-here'; Label = 'a-really-long-feature-branch-name-here'; Number = 4;   Expected = 'a-really-long-fe0004' }
            @{ Branch = 'feature/x123456789012345678';                    Label = 'x123456789012345678';                    Number = 3;   Expected = 'x12345678901234-0003' }
            @{ Branch = 'feature/abcdefghijklmno5pqrstu';                 Label = 'abcdefghijklmno5pqrstu';                 Number = 3;   Expected = 'abcdefghijklmno50003' }
            @{ Branch = 'feature/tagged-rc (tag 2.0.0-rc.3)';             Label = 'rc';                                     Number = 3;   Expected = 'rc0003' }
        )
    }

    Context 'GitVersion v6 output (no NuGetPreReleaseTag)' {

        It 'returns the same value as GitVersion v5 for <Branch>' -ForEach $gitVersion5Outputs {
            $gitVersion = @{
                PreReleaseLabel = $Label
                PreReleaseNumber = [long]$Number
                PreReleaseTag = "$Label.$Number"
            }

            _Get-NuGetPreReleaseTag -GitVersion $gitVersion | Should -BeExactly $Expected
        }

        It 'returns the same value as GitVersion v5 from only PreReleaseTag, for <Branch>' -ForEach $gitVersion5Outputs {
            _Get-NuGetPreReleaseTag -GitVersion @{ PreReleaseTag = "$Label.$Number" } | Should -BeExactly $Expected
        }

        It 'returns an empty string for a release build' {
            $gitVersion = @{
                SemVer = '3.0.0'
                PreReleaseLabel = ''
                PreReleaseNumber = $null
                PreReleaseTag = ''
            }

            _Get-NuGetPreReleaseTag -GitVersion $gitVersion | Should -BeExactly ''
        }

        It 'reads the values that ConvertFrom-Json gives for GitVersion''s JSON output' {
            $gitVersion = '{ "SemVer": "1.2.4-preview.2", "PreReleaseLabel": "preview", "PreReleaseNumber": 2, "PreReleaseTag": "preview.2" }' |
                ConvertFrom-Json -AsHashtable

            _Get-NuGetPreReleaseTag -GitVersion $gitVersion | Should -BeExactly 'preview0002'
        }

        It 'reads a release build from GitVersion''s JSON output' {
            $gitVersion = '{ "SemVer": "1.2.3", "PreReleaseLabel": "", "PreReleaseNumber": null, "PreReleaseTag": "" }' |
                ConvertFrom-Json -AsHashtable

            _Get-NuGetPreReleaseTag -GitVersion $gitVersion | Should -BeExactly ''
        }

        It 'does not pad a number that already has 4 or more digits' {
            _Get-NuGetPreReleaseTag -GitVersion @{ PreReleaseLabel = 'beta'; PreReleaseNumber = 12345 } | Should -BeExactly 'beta12345'
        }

        It 'returns only the label when there is no pre-release number' {
            _Get-NuGetPreReleaseTag -GitVersion @{ PreReleaseLabel = 'Preview'; PreReleaseNumber = $null } | Should -BeExactly 'preview'
        }

        It 'shortens a label without a pre-release number to 20 characters' {
            _Get-NuGetPreReleaseTag -GitVersion @{ PreReleaseLabel = 'a-really-long-feature-branch-name-here' } | Should -BeExactly 'a-really-long-featur'
        }

        It 'returns only the label from a PreReleaseTag without a number' {
            _Get-NuGetPreReleaseTag -GitVersion @{ PreReleaseTag = 'rc' } | Should -BeExactly 'rc'
        }

        It 'uses only the last part of PreReleaseTag as the number' {
            _Get-NuGetPreReleaseTag -GitVersion @{ PreReleaseTag = 'alpha.beta.3' } | Should -BeExactly 'alpha.beta0003'
        }

        It 'uses PreReleaseLabel and PreReleaseNumber instead of PreReleaseTag' {
            $gitVersion = @{ PreReleaseLabel = 'preview'; PreReleaseNumber = 7; PreReleaseTag = 'other.1' }

            _Get-NuGetPreReleaseTag -GitVersion $gitVersion | Should -BeExactly 'preview0007'
        }

        It 'accepts a pre-release number that is a string' {
            _Get-NuGetPreReleaseTag -GitVersion @{ PreReleaseLabel = 'preview'; PreReleaseNumber = '9' } | Should -BeExactly 'preview0009'
        }

        It 'fails when the pre-release number is not a whole number' {
            { _Get-NuGetPreReleaseTag -GitVersion @{ PreReleaseLabel = 'preview'; PreReleaseNumber = '1.5' } } |
                Should -Throw "*'1.5' is not a whole number*"
        }
    }

    Context 'GitVersion v5 output, or an override that sets NuGetPreReleaseTag' {

        It 'returns NuGetPreReleaseTag unchanged' {
            $gitVersion = @{
                NuGetPreReleaseTag = 'my-feature-2-0004'
                PreReleaseLabel = 'my-feature-2'
                PreReleaseNumber = 4
            }

            _Get-NuGetPreReleaseTag -GitVersion $gitVersion | Should -BeExactly 'my-feature-2-0004'
        }

        It 'returns NuGetPreReleaseTag when it is the only pre-release property' {
            _Get-NuGetPreReleaseTag -GitVersion @{ NuGetPreReleaseTag = 'custom0001' } | Should -BeExactly 'custom0001'
        }

        It 'uses the other properties when NuGetPreReleaseTag is empty' {
            $gitVersion = @{ NuGetPreReleaseTag = ''; PreReleaseLabel = 'preview'; PreReleaseNumber = 3 }

            _Get-NuGetPreReleaseTag -GitVersion $gitVersion | Should -BeExactly 'preview0003'
        }

        It 'returns an empty string for a GitVersion v5 release build' {
            $gitVersion = @{
                SemVer = '3.0.0'
                NuGetPreReleaseTag = ''
                PreReleaseLabel = ''
                PreReleaseNumber = $null
                PreReleaseTag = ''
            }

            _Get-NuGetPreReleaseTag -GitVersion $gitVersion | Should -BeExactly ''
        }
    }

    Context 'Missing GitVersion output' {

        It 'returns an empty string when the output is empty' {
            _Get-NuGetPreReleaseTag -GitVersion @{} | Should -BeExactly ''
        }

        It 'returns an empty string when the output is null' {
            _Get-NuGetPreReleaseTag -GitVersion $null | Should -BeExactly ''
        }

        It 'returns an empty string when the label is only whitespace' {
            _Get-NuGetPreReleaseTag -GitVersion @{ PreReleaseLabel = ' '; PreReleaseNumber = 1 } | Should -BeExactly ''
        }
    }
}
