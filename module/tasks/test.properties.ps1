# <copyright file="test.properties.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

# Synopsis: When true, all Pester tests will be skipped. Defaults to false.
$SkipPesterTests = $false

# Synopsis: The version of Pester to use for testing. Defaults to 5.5.0.
$PesterVersion = "5.5.0"

# Synopsis: The directory containing the Pester tests. Defaults to the current directory.
$PesterTestsDir = $null

# Synopsis: The Pester output format. Defaults to NUnitXml.
$PesterOutputFormat = "NUnitXml"

# Synopsis: The file path for the Pester test results. Defaults to PesterTestResults.xml.
$PesterOutputFilePath = "PesterTestResults.xml"

# Synopsis: The Pester show options. Defaults to 'Summary' and 'Fails'.
$PesterShowOptions = @("Summary","Fails")