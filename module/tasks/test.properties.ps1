# <copyright file="test.properties.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

# Synopsis: When true, all Pester tests will be skipped.
$SkipPesterTests = $false

# Synopsis: The version of Pester to use for testing.
$PesterVersion = "5.7.1"

# Synopsis: The directory containing the Pester tests. Defaults to the current directory.
$PesterTestsDir = $null

# Synopsis: The Pester output format.  Ref: https://pester.dev/docs/usage/configuration#testresult
$PesterOutputFormat = "NUnitXml"

# Synopsis: The file path for the Pester test results.
$PesterOutputFilePath = "PesterTestResults.xml"

# Synopsis: *DEPRECATED* The Pester show options; use `PesterVerbosity` instead.
$PesterShowOptions = @()

# Synopsis: When true, code coverage will be enabled for Pester tests.
$PesterCodeCoverageEnabled = $true

# Synopsis: The path(s) to analyze for code coverage.
$PesterCodeCoveragePaths = @()

# Synopsis: The output format for code coverage reports. Ref: https://pester.dev/docs/usage/configuration#codecoverage
$PesterCodeCoverageOutputFormat = "Cobertura"

# Synopsis: The file path for the code coverage report.
$PesterCodeCoverageOutputPath = "PesterCodeCoverage.xml"

# Synopsis: The minimum code coverage percentage required to pass.
$PesterCodeCoverageThreshold = 75

# Synopsis: Tags to include when running Pester tests.
$PesterTagFilter = @()

# Synopsis: Tags to exclude when running Pester tests.
$PesterExcludeTagFilter = @()

# Synopsis: The verbosity level for Pester output.  Ref: https://pester.dev/docs/usage/configuration#output
$PesterVerbosity = $null
