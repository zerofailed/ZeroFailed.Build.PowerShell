# <copyright file="test.tasks.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

. $PSScriptRoot/test.properties.ps1

# synopsis: Installs the required version of Pester
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

# Synopsis: Runs all the available Pester tests
task RunPesterTests `
    -If {!$SkipPesterTests -and $PesterTestsDir} `
    -After TestCore `
    InstallPester,{

    $results = Invoke-Pester -Path $PesterTestsDir `
                             -OutputFormat $PesterOutputFormat `
                             -OutputFile $PesterOutputFilePath `
                             -PassThru `
                             -Show $PesterShowOptions

    if ($results.FailedCount -gt 0) {
        throw ("{0} out of {1} tests failed - check previous logging for more details" -f $results.FailedCount, $results.TotalCount)
    }
}
