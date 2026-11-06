# <copyright file="test.tasks.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

. $PSScriptRoot/test.properties.ps1

# Synopsis: Installs the required version of Pester
task InstallPester {

    # A module's 'Version' does not include its pre-release label (e.g. '6.0.0-alpha1'), which is in its manifest's
    # 'PrivateData.PSData.Prerelease'. So both parts must be compared to find the installed module.
    $numericVersion, $prereleaseLabel = $PesterVersion -split '-', 2
    function Get-InstalledPester {
        Get-Module -ListAvailable Pester |
            Where-Object { $_.Version -eq [version]$numericVersion -and "$($_.PrivateData.PSData.Prerelease)" -eq "$prereleaseLabel" } |
            Select-Object -First 1
    }

    $pester = Get-InstalledPester
    if (!$pester) {
        Install-PSResource Pester -Version "[$PesterVersion]" -Prerelease:([bool]$prereleaseLabel) -Scope CurrentUser -TrustRepository -Repository PSGallery
        $pester = Get-InstalledPester
        if (!$pester) {
            throw "Pester $PesterVersion was installed, but could not be found in the available modules"
        }
    }
    Get-Module Pester | Remove-Module
    # Import-Module's 'RequiredVersion' does not accept a pre-release label, so import the module from its path
    Import-Module $pester.Path
}

# Synopsis: Runs all the available Pester tests using modern v5 configuration approach with support for code coverage, filtering, and multiple output formats
task RunPesterTests `
    -If {!$SkipPesterTests -and $PesterTestsDir} `
    -After TestCore `
    InstallPester,{

    # Create Pester configuration object using modern v5 approach
    $config = New-PesterConfiguration
    
    # Configure test discovery and execution
    $config.Run.Path = $PesterTestsDir
    $config.Run.PassThru = $true
    
    # Configure test result output
    $config.TestResult.Enabled = $true
    $config.TestResult.OutputFormat = $PesterOutputFormat
    $config.TestResult.OutputPath = $PesterOutputFilePath
    
    # Configure output verbosity - prefer explicit $PesterVerbosity over legacy $PesterShowOptions
    if ($PesterVerbosity) {
        $config.Output.Verbosity = $PesterVerbosity
    } elseif ($PesterShowOptions -contains "All" -or $PesterShowOptions -contains "Describe" -or $PesterShowOptions -contains "Context") {
        Write-Build Yellow "Mapping deprecated PesterShowOptions to 'Detailed' verbosity - considering replacing `$PesterShowOptions with the `$PesterVerbosity property"
        $config.Output.Verbosity = 'Detailed'
    } elseif ($PesterShowOptions -contains "Summary" -and $PesterShowOptions.Count -eq 1) {
        Write-Build Yellow "Mapping deprecated PesterShowOptions to 'Minimal' verbosity - considering replacing `$PesterShowOptions with the `$PesterVerbosity property"
        $config.Output.Verbosity = 'Minimal'
    } elseif ($PesterShowOptions -contains "None") {
        Write-Build Yellow "Mapping deprecated PesterShowOptions to 'None' verbosity - considering replacing `$PesterShowOptions with the `$PesterVerbosity property"
        $config.Output.Verbosity = 'None'
    } else {
        $config.Output.Verbosity = 'Normal'
    }

    # Configure test filtering by tags
    if ($PesterTagFilter.Count -gt 0) {
        $config.Filter.Tag = $PesterTagFilter
    }
    if ($PesterExcludeTagFilter.Count -gt 0) {
        $config.Filter.ExcludeTag = $PesterExcludeTagFilter
    }

    # Configure code coverage if enabled
    if ($PesterCodeCoverageEnabled) {
        $config.CodeCoverage.Enabled = $true
        $config.CodeCoverage.OutputFormat = $PesterCodeCoverageOutputFormat
        $config.CodeCoverage.OutputPath = $PesterCodeCoverageOutputPath
        
        # Set coverage path - default to build directory if not specified
        if ($PesterCodeCoveragePaths.Count -gt 0) {
            $config.CodeCoverage.Path = $PesterCodeCoveragePaths
        }
        else {
            $config.CodeCoverage.Path = $PWD
        }
    }

    $results = Invoke-Pester -Configuration $config

    # Check code coverage threshold if enabled
    if ($PesterCodeCoverageEnabled -and $PesterCodeCoverageThreshold -gt 0 -and $results.CodeCoverage) {
        $coveragePercent = [math]::Round(($results.CodeCoverage.CoveragePercent), 2)
        if ($results.CodeCoverage.CommandsAnalyzedCount -eq 0) {
            Write-Host ("No commands were found for coverage analysis - skipping threshold rule") -ForegroundColor Yellow
        }
        elseif ($coveragePercent -lt $PesterCodeCoverageThreshold) {
            throw ("Code coverage of {0}% is below the required threshold of {1}%" -f $coveragePercent, $PesterCodeCoverageThreshold)
        }
        else {
            Write-Host ("Code coverage: {0}% (meets threshold of {1}%)" -f $coveragePercent, $PesterCodeCoverageThreshold) -ForegroundColor Green
        }
    }

    if ($results.FailedCount -gt 0) {
        throw ("{0} out of {1} tests failed - check previous logging for more details" -f $results.FailedCount, $results.TotalCount)
    }
}
