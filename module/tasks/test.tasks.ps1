# <copyright file="test.tasks.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

. $PSScriptRoot/test.properties.ps1

# Synopsis: Installs the required version of Pester
task InstallPester {

    [array]$existingModule = Get-Module -ListAvailable Pester
    $existingPesterVersions = $existingModule |
                                Select-Object -ExpandProperty Version |
                                ForEach-Object { $_.ToString() }
    if (!$existingModule -or $existingPesterVersions -notcontains $PesterVersion) {
        Install-Module Pester -RequiredVersion $PesterVersion -Force -Scope CurrentUser -SkipPublisherCheck
    }
    Get-Module Pester | Remove-Module
    Import-Module Pester -RequiredVersion $PesterVersion
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
        $config.Output.Verbosity = 'Detailed'
    } elseif ($PesterShowOptions -contains "Summary" -and $PesterShowOptions.Count -eq 1) {
        $config.Output.Verbosity = 'None'  # Use 'None' for minimal output instead of 'Minimal'
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

    # Configure parallel execution if enabled (only available in Pester v6+)
    if ($PesterParallelEnabled) {
        Write-Warning "Parallel execution requires Pester v6 or newer. Current version: $PesterVersion"
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

    # Generate additional output formats if specified
    if ($PesterAdditionalOutputFormats.Count -gt 0) {
        $additionalFormats = $PesterAdditionalOutputFormats
        $additionalPaths = $PesterAdditionalOutputPaths
        
        # If paths not specified or count mismatch, generate default paths
        if ($additionalPaths.Count -ne $additionalFormats.Count) {
            Write-Warning "Additional output paths count doesn't match formats count. Generating default paths."
            $additionalPaths = @()
            for ($i = 0; $i -lt $additionalFormats.Count; $i++) {
                $format = $additionalFormats[$i]
                $extension = switch ($format) {
                    "JUnitXml" { "xml" }
                    "NUnitXml" { "xml" }
                    "NUnit2.5" { "xml" }
                    "JaCoCo" { "xml" }
                    default { "txt" }
                }
                $additionalPaths += "PesterResults.$format.$extension"
            }
        }
        
        # Generate each additional format
        for ($i = 0; $i -lt $additionalFormats.Count; $i++) {
            $format = $additionalFormats[$i]
            $path = $additionalPaths[$i]
            
            Write-Host "Generating additional test results in $format format: $path" -ForegroundColor Cyan
            
            # Create a new configuration for this format
            $additionalConfig = New-PesterConfiguration
            $additionalConfig.Run.Path = $PesterTestsDir
            $additionalConfig.Run.PassThru = $false
            $additionalConfig.TestResult.Enabled = $true
            $additionalConfig.TestResult.OutputFormat = $format
            $additionalConfig.TestResult.OutputPath = $path
            $additionalConfig.Output.Verbosity = 'None'
            
            # Apply same filters
            if ($PesterTagFilter.Count -gt 0) {
                $additionalConfig.Filter.Tag = $PesterTagFilter
            }
            if ($PesterExcludeTagFilter.Count -gt 0) {
                $additionalConfig.Filter.ExcludeTag = $PesterExcludeTagFilter
            }
            
            # Run tests again just for output format (this is efficient as discovery is cached)
            Invoke-Pester -Configuration $additionalConfig | Out-Null
        }
    }

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
