# <copyright file="_Get-RequiredModuleSpecification.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    . (Join-Path $PSScriptRoot '_Get-RequiredModuleSpecification.ps1')
}

Describe '_Get-RequiredModuleSpecification' {

    It 'returns a module name with no version' {
        $result = _Get-RequiredModuleSpecification -RequiredModule 'Pester'

        $result.Name | Should -Be 'Pester'
        $result.Version | Should -BeNullOrEmpty
    }

    It 'returns no version for a hashtable with no version keys' {
        $result = _Get-RequiredModuleSpecification -RequiredModule @{ ModuleName = 'Pester' }

        $result.Name | Should -Be 'Pester'
        $result.Version | Should -BeNullOrEmpty
    }

    It 'converts <Description> to <Expected>' -ForEach @(
        @{ Description = 'RequiredVersion'; Entry = @{ RequiredVersion = '1.2.3' }; Expected = '[1.2.3]' }
        @{ Description = 'RequiredVersion with other keys'; Entry = @{ RequiredVersion = '1.2.3'; ModuleVersion = '1.0' }; Expected = '[1.2.3]' }
        @{ Description = 'ModuleVersion'; Entry = @{ ModuleVersion = '1.0' }; Expected = '[1.0, )' }
        @{ Description = 'MaximumVersion'; Entry = @{ MaximumVersion = '2.0' }; Expected = '(, 2.0]' }
        @{ Description = 'ModuleVersion and MaximumVersion'; Entry = @{ ModuleVersion = '1.0'; MaximumVersion = '2.0' }; Expected = '[1.0, 2.0]' }
        @{ Description = "MaximumVersion '5.*'"; Entry = @{ MaximumVersion = '5.*' }; Expected = '(, 6)' }
        @{ Description = "MaximumVersion '5.2.*'"; Entry = @{ MaximumVersion = '5.2.*' }; Expected = '(, 5.3)' }
        @{ Description = "ModuleVersion and MaximumVersion '5.*'"; Entry = @{ ModuleVersion = '5.0.0'; MaximumVersion = '5.*' }; Expected = '[5.0.0, 6)' }
        @{ Description = "ModuleVersion and MaximumVersion '*'"; Entry = @{ ModuleVersion = '5.0.0'; MaximumVersion = '*' }; Expected = '[5.0.0, )' }
    ) {
        $Entry.ModuleName = 'Pester'

        $result = _Get-RequiredModuleSpecification -RequiredModule $Entry

        $result.Name | Should -Be 'Pester'
        $result.Version | Should -Be $Expected
    }

    It "returns no version for MaximumVersion '*' alone" {
        (_Get-RequiredModuleSpecification -RequiredModule @{ ModuleName = 'Pester'; MaximumVersion = '*' }).Version |
            Should -BeNullOrEmpty
    }
}
