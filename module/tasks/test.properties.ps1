# <copyright file="test.properties.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

# Synopsis: When true, all Pester tests will be skipped.
$SkipPesterTests = $false

# Synopsis: The version of Pester to use for testing.
$PesterVersion = "5.7.1"

# Synopsis: The directory containing the Pester tests. Defaults to the current directory.
$PesterTestsDir = $null

# Synopsis: The Pester output format.
$PesterOutputFormat = "NUnitXml"

# Synopsis: The file path for the Pester test results.
$PesterOutputFilePath = "PesterTestResults.xml"

# Synopsis: The Pester show options.
$PesterShowOptions = @("Summary","Fails")