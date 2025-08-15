# ZeroFailed.Build.PowerShell - Reference Sheet

<!-- START_GENERATED_HELP -->

## Publish

This group contains functionality for publishing PowerShell modules to repositories.

### Properties

| Name                                 | Default Value | ENV Override                    | Description                                                                                                                                                            |
| ------------------------------------ | ------------- | ------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `EnablePowerShellModuleForcePublish` | $false        |                                 | When true, the PowerShell module will be published even if the version already exists in the repository.                                                               |
| `PowerShellModulesToPublish`         | @()           |                                 | Configures the PowerShell modules to be published to a PowerShell repository (e.g. PSGallery). See [note below](#powershellmodulestopublish) for configuration syntax. |
| `PowerShellRepository`               | "PSGallery"   |                                 | The name of the PowerShell repository to publish to.                                                                                                                   |
| `PSRepositoryApiKey`                 | ""            | `ZF_BUILD_PS_REPOSITORY_APIKEY` | The API key to use when publishing to the PowerShell repository.                                                                                                       |
| `SkipPowerShellPublish`              | $false        |                                 | When true, publishing any PowerShell modules will be skipped.                                                                                                          |

#### PowerShellModulesToPublish

This property is configured using the following structure:

```powershell
$PowerShellModulesToPublish = @(
    @{
        ModulePath = "module/my-module.psd1"
        FunctionsToExport = @("*")
        CmdletsToExport = @()
        AliasesToExport = @()
    }
)
```

### Tasks

| Name                       | Description                                                                         |
| -------------------------- | ----------------------------------------------------------------------------------- |
| `PublishPowerShellModules` | Publishes PowerShell Modules to a registered PowerShell Repository (e.g. PSGallery) |

## Test

This group contains features for testing your PowerShell projects using [Pester](https://pester.dev).

### Properties

| Name                             | Default Value            | ENV Override | Description                                                                                                |
| -------------------------------- | ------------------------ | ------------ | ---------------------------------------------------------------------------------------------------------- |
| `PesterCodeCoverageEnabled`      | $true                    |              | When true, code coverage will be enabled for Pester tests.                                                 |
| `PesterCodeCoverageOutputFormat` | "Cobertura"              |              | The output format for code coverage reports. Ref: https://pester.dev/docs/usage/configuration#codecoverage |
| `PesterCodeCoverageOutputPath`   | "PesterCodeCoverage.xml" |              | The file path for the code coverage report.                                                                |
| `PesterCodeCoveragePaths`        | @()                      |              | The path(s) to analyze for code coverage.                                                                  |
| `PesterCodeCoverageThreshold`    | 75                       |              | The minimum code coverage percentage required to pass.                                                     |
| `PesterExcludeTagFilter`         | @()                      |              | Tags to exclude when running Pester tests.                                                                 |
| `PesterOutputFilePath`           | "PesterTestResults.xml"  |              | The file path for the Pester test results.                                                                 |
| `PesterOutputFormat`             | "NUnitXml"               |              | The Pester output format.  Ref: https://pester.dev/docs/usage/configuration#testresult                     |
| `PesterShowOptions`              | @()                      |              | *DEPRECATED* The Pester show options; use `PesterVerbosity` instead.                                       |
| `PesterTagFilter`                | @()                      |              | Tags to include when running Pester tests.                                                                 |
| `PesterTestsDir`                 | $null                    |              | The directory containing the Pester tests. Defaults to the current directory.                              |
| `PesterVerbosity`                | $null                    |              | The verbosity level for Pester output.  Ref: https://pester.dev/docs/usage/configuration#output            |
| `PesterVersion`                  | "5.7.1"                  |              | The version of Pester to use for testing.                                                                  |
| `SkipPesterTests`                | $false                   |              | When true, all Pester tests will be skipped.                                                               |

### Tasks

| Name             | Description                                                                                                                                       |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `InstallPester`  | Installs the required version of Pester                                                                                                           |
| `RunPesterTests` | Runs all the available Pester tests using modern v5 configuration approach with support for code coverage, filtering, and multiple output formats |


<!-- END_GENERATED_HELP -->
