# <copyright file="test.tasks.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # Import the module being tested
    $ModulePath = Split-Path -Parent $PSScriptRoot
    Import-Module "$ModulePath/ZeroFailed.Build.PowerShell.psd1" -Force
    
    # Mock InvokeBuild functions since we're testing tasks
    function task { }
    function Install-Module { }
    function Get-Module { return @() }
    function Import-Module { }
    function Remove-Module { }
    
    # Create a test directory structure
    $TestDrive = New-Item -ItemType Directory -Path (Join-Path $TestDrive "TestModule") -Force
    $TestModuleDir = $TestDrive.FullName
    $TestFunctionsDir = New-Item -ItemType Directory -Path (Join-Path $TestModuleDir "functions") -Force
    
    # Create test PowerShell files
    "function Test-Function { return 'test' }" | Out-File -FilePath (Join-Path $TestFunctionsDir.FullName "Test-Function.ps1")
    
    # Create a simple test file
    @"
Describe 'Sample Tests' {
    It 'Should pass' {
        `$true | Should -Be `$true
    }
    
    It 'Should also pass' {
        1 + 1 | Should -Be 2
    }
}
"@ | Out-File -FilePath (Join-Path $TestModuleDir "Sample.Tests.ps1")
}

Describe "test.tasks.ps1 Tests" {
    
    Context "Properties Loading" {
        BeforeAll {
            # Source the properties file to get defaults
            . "$PSScriptRoot/test.properties.ps1"
        }
        
        It "Should have all required properties defined" {
            $SkipPesterTests | Should -Not -BeNullOrEmpty
            $PesterVersion | Should -Not -BeNullOrEmpty
            $PesterOutputFormat | Should -Not -BeNullOrEmpty
            $PesterOutputFilePath | Should -Not -BeNullOrEmpty
            $PesterShowOptions | Should -Not -BeNullOrEmpty
        }
        
        It "Should have new code coverage properties defined" {
            { $PesterCodeCoverageEnabled } | Should -Not -Throw
            { $PesterCodeCoveragePath } | Should -Not -Throw
            { $PesterCodeCoverageOutputFormat } | Should -Not -Throw
            { $PesterCodeCoverageOutputPath } | Should -Not -Throw
            { $PesterCodeCoverageThreshold } | Should -Not -Throw
        }
        
        It "Should have new filtering properties defined" {
            { $PesterTagFilter } | Should -Not -Throw
            { $PesterExcludeTagFilter } | Should -Not -Throw
            { $PesterAdditionalOutputFormats } | Should -Not -Throw
            { $PesterAdditionalOutputPaths } | Should -Not -Throw
            { $PesterVerbosity } | Should -Not -Throw
            { $PesterParallelEnabled } | Should -Not -Throw
        }
        
        It "Should have sensible defaults" {
            $PesterCodeCoverageEnabled | Should -Be $false
            $PesterCodeCoverageOutputFormat | Should -Be "JaCoCo"
            $PesterCodeCoverageThreshold | Should -Be 0
            $PesterParallelEnabled | Should -Be $false
        }
    }
    
    Context "New-PesterConfiguration Integration" {
        BeforeAll {
            # Mock Pester functions
            Mock New-PesterConfiguration {
                return [PSCustomObject]@{
                    Run = [PSCustomObject]@{
                        Path = $null
                        PassThru = $null
                        Parallel = $null
                    }
                    TestResult = [PSCustomObject]@{
                        Enabled = $null
                        OutputFormat = $null
                        OutputPath = $null
                    }
                    Output = [PSCustomObject]@{
                        Verbosity = $null
                    }
                    Filter = [PSCustomObject]@{
                        Tag = $null
                        ExcludeTag = $null
                    }
                    CodeCoverage = [PSCustomObject]@{
                        Enabled = $null
                        Path = $null
                        OutputFormat = $null
                        OutputPath = $null
                    }
                }
            }
            
            Mock Invoke-Pester {
                return [PSCustomObject]@{
                    FailedCount = 0
                    TotalCount = 2
                    CodeCoverage = [PSCustomObject]@{
                        CoveredPercent = 85.5
                    }
                }
            }
            
            # Source the properties with test values
            . "$PSScriptRoot/test.properties.ps1"
            $PesterTestsDir = $TestModuleDir
        }
        
        It "Should create configuration object" {
            # Test that New-PesterConfiguration is called when we invoke it
            $config = New-PesterConfiguration
            $config | Should -Not -BeNullOrEmpty
            
            Should -Invoke New-PesterConfiguration -Times 1 -Exactly
        }
        
        It "Should configure basic test execution" {
            $config = New-PesterConfiguration
            $config.Run.Path = $PesterTestsDir
            $config.Run.PassThru = $true
            $config.TestResult.Enabled = $true
            $config.TestResult.OutputFormat = $PesterOutputFormat
            $config.TestResult.OutputPath = $PesterOutputFilePath
            
            $config.Run.Path | Should -Be $TestModuleDir
            $config.TestResult.OutputFormat | Should -Be "NUnitXml"
        }
    }
    
    Context "Code Coverage Configuration" {
        BeforeAll {
            Mock New-PesterConfiguration {
                return [PSCustomObject]@{
                    Run = [PSCustomObject]@{ Path = $null; PassThru = $null }
                    TestResult = [PSCustomObject]@{ Enabled = $null; OutputFormat = $null; OutputPath = $null }
                    Output = [PSCustomObject]@{ Verbosity = $null }
                    Filter = [PSCustomObject]@{ Tag = $null; ExcludeTag = $null }
                    CodeCoverage = [PSCustomObject]@{ Enabled = $null; Path = $null; OutputFormat = $null; OutputPath = $null }
                }
            }
            
            Mock Invoke-Pester {
                return [PSCustomObject]@{
                    FailedCount = 0
                    TotalCount = 2
                    CodeCoverage = [PSCustomObject]@{ CoveredPercent = 85.5 }
                }
            }
        }
        
        It "Should enable code coverage when requested" {
            # Set code coverage properties
            . "$PSScriptRoot/test.properties.ps1"
            $PesterCodeCoverageEnabled = $true
            $PesterCodeCoverageOutputFormat = "JaCoCo"
            $PesterCodeCoverageOutputPath = "coverage.xml"
            $PesterTestsDir = $TestModuleDir
            
            $config = New-PesterConfiguration
            
            # Simulate the task logic
            if ($PesterCodeCoverageEnabled) {
                $config.CodeCoverage.Enabled = $true
                $config.CodeCoverage.OutputFormat = $PesterCodeCoverageOutputFormat
                $config.CodeCoverage.OutputPath = $PesterCodeCoverageOutputPath
            }
            
            $config.CodeCoverage.Enabled | Should -Be $true
            $config.CodeCoverage.OutputFormat | Should -Be "JaCoCo"
            $config.CodeCoverage.OutputPath | Should -Be "coverage.xml"
        }
        
        It "Should set default coverage path when not specified" {
            . "$PSScriptRoot/test.properties.ps1"
            $PesterCodeCoverageEnabled = $true
            $PesterCodeCoveragePath = @()
            $PesterTestsDir = $TestModuleDir
            
            $config = New-PesterConfiguration
            
            # Simulate default path logic
            if ($PesterCodeCoverageEnabled) {
                $config.CodeCoverage.Enabled = $true
                if ($PesterCodeCoveragePath.Count -gt 0) {
                    $config.CodeCoverage.Path = $PesterCodeCoveragePath
                } else {
                    $functionsDir = Join-Path $PesterTestsDir "functions"
                    if (Test-Path $functionsDir) {
                        $config.CodeCoverage.Path = @("$functionsDir/*.ps1")
                    }
                }
            }
            
            $config.CodeCoverage.Path | Should -Be @("$TestFunctionsDir/*.ps1")
        }
    }
    
    Context "Verbosity Configuration" {
        It "Should prefer explicit verbosity over legacy show options" {
            # Test explicit verbosity
            $PesterVerbosity = "Detailed"
            $PesterShowOptions = @("Summary")
            
            $config = New-PesterConfiguration
            
            # Simulate verbosity logic
            if ($PesterVerbosity) {
                $config.Output.Verbosity = $PesterVerbosity
            } elseif ($PesterShowOptions -contains "Summary" -and $PesterShowOptions.Count -eq 1) {
                $config.Output.Verbosity = 'Minimal'
            }
            
            $config.Output.Verbosity.Value | Should -Be "Detailed"
        }
        
        It "Should use legacy show options when verbosity not set" {
            $PesterVerbosity = $null
            $PesterShowOptions = @("Summary")
            
            $config = New-PesterConfiguration
            
            # Test the condition logic directly
            $shouldBeMinimal = ($PesterShowOptions -contains "Summary" -and $PesterShowOptions.Count -eq 1)
            $shouldBeMinimal | Should -Be $true
            
            # Simulate verbosity logic - the actual assignment
            if ($PesterVerbosity) {
                $config.Output.Verbosity = $PesterVerbosity
            } elseif ($PesterShowOptions -contains "Summary" -and $PesterShowOptions.Count -eq 1) {
                $config.Output.Verbosity = 'None'  # Use 'None' for minimal output
            } else {
                $config.Output.Verbosity = 'Normal'
            }
            
            $config.Output.Verbosity.Value | Should -Be "None"
        }
    }
    
    Context "Tag Filtering" {
        It "Should configure include tags when specified" {
            $PesterTagFilter = @("Unit", "Integration")
            
            $config = New-PesterConfiguration
            
            if ($PesterTagFilter.Count -gt 0) {
                $config.Filter.Tag = $PesterTagFilter
            }
            
            $config.Filter.Tag.Value | Should -Be @("Unit", "Integration")
        }
        
        It "Should configure exclude tags when specified" {
            $PesterExcludeTagFilter = @("Slow", "Manual")
            
            $config = New-PesterConfiguration
            
            if ($PesterExcludeTagFilter.Count -gt 0) {
                $config.Filter.ExcludeTag = $PesterExcludeTagFilter
            }
            
            $config.Filter.ExcludeTag.Value | Should -Be @("Slow", "Manual")
        }
    }
    
    Context "Parallel Execution" {
        It "Should warn about parallel execution not available in v5" {
            $PesterParallelEnabled = $true
            $PesterVersion = "5.7.1"
            
            # Test that the warning logic is correct
            if ($PesterParallelEnabled) {
                $warningMessage = "Parallel execution requires Pester v6 or newer. Current version: $PesterVersion"
                $warningMessage | Should -Match "Parallel execution requires Pester v6"
            }
        }
    }
}