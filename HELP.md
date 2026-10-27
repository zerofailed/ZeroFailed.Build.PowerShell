# ZeroFailed.Build.PowerShell - Reference Sheet

<!-- START_GENERATED_HELP -->

## Documentation

This group contains functionality for maintaining PowerShell module documentation.

### Properties

| Name                              | Default Value | ENV Override                              | Description                                                                                                                                     |
| --------------------------------- | ------------- | ----------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `SkipGeneratePSMarkdownDocs`      | $false        |                                           | When true, all markdown documentation will tasks will be skipped.                                                                               |
| `PSMarkdownDocsOutputPath`        | './docs'      | `ZF_BUILD_PS_MD_DOCS_OUTPUT_PATH`         | The base output path for generated markdown files.                                                                                              |
| `PSMarkdownDocsFlattenOutputPath` | $false        | `ZF_BUILD_PS_MD_DOCS_FLATTEN_OUTPUT_PATH` | When true, works around default PlatyPS behaviour of placing markdown files in a sub-folder named after the module.                             |
| `PSMarkdownDocsIncludeModulePage` | $true         |                                           | When true, PlatyPS will generate a markdown index page for the module.                                                                          |
| `PSMarkdownDocsLocale`            | 'en-US'       | `ZF_BUILD_PS_MD_DOCS_LOCALE`              | The locale written to the generated markdown frontmatter. Pinned so that the output does not vary with the culture of the build agent.          |
| `PSMarkdownDocsRequireLinting`    | $true         |                                           | When true, failed markdown linting (e.g. to ensure no generated placeholder text) will break the build, otherwise they are treated as warnings. |

### Tasks

| Name                       | Description                                                                                                                                        |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `GeneratePSMarkdownDocs`   | Uses PlatyPS to generate the markdown help documentation from the module's comment-based help.                                                     |
| `RunPSMarkdownDocsLinting` | Runs linting against markdown documentation (e.g. to ensure no generated placeholder text).                                                        |


## Publish

This group contains functionality for publishing PowerShell modules to repositories.

### Properties

| Name                                 | Default Value | ENV Override                    | Description                                                                                                                                                            |
| ------------------------------------ | ------------- | ------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `EnablePowerShellModuleForcePublish` | $false        |                                 | When true, the PowerShell module will be published even if the version already exists in the repository.                                                               |
| `PowerShellModulesToPublish`         | @()           |                                 | Configures the PowerShell modules to be published to a PowerShell repository (e.g. PSGallery). See [note below](#powershellmodulestopublish) for configuration syntax. |
| `PowerShellRepositories`             | @()           |                                 | The PowerShell repositories to publish to (e.g. PSGallery and GitHub Packages). See [note below](#powershellrepositories) for configuration syntax.                     |
| `PowerShellRepository`               | "PSGallery"   |                                 | The name of the PowerShell repository to publish to. Only used when `PowerShellRepositories` is empty.                                                                 |
| `PSRepositoryApiKey`                 | ""            | `ZF_BUILD_PS_REPOSITORY_APIKEY` | The API key to use when publishing to the PowerShell repository. Only used when `PowerShellRepositories` is empty.                                                     |
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

#### PowerShellRepositories

Each module in `PowerShellModulesToPublish` is published to every repository in this list. When the list is empty, the module is published to the single repository named by `PowerShellRepository`, using `PSRepositoryApiKey`.

Each entry is a hashtable with these keys:

| Key               | Required | Description                                                                                                       |
| ----------------- | -------- | ----------------------------------------------------------------------------------------------------------------- |
| `Name`            | yes      | The name of the PowerShell repository.                                                                            |
| `ApiKey`          | no       | The API key to use when publishing.                                                                               |
| `SourceLocation`  | no       | The repository's source URI. When set, the repository is registered (as trusted) if it is not registered already. |
| `PublishLocation` | no       | The repository's publish URI. Defaults to `SourceLocation`.                                                       |
| `Credential`      | no       | A `PSCredential` used to register the repository and to publish to it.                                            |

Any value can be a scriptblock. Scriptblocks are evaluated when the publish task runs, so secrets are only read when they are needed.

The example below publishes to PSGallery and to GitHub Packages:

```powershell
$PowerShellRepositories = @(
    @{
        Name = 'PSGallery'
        ApiKey = { $PSRepositoryApiKey }
    }
    @{
        Name = 'GitHubPackages'
        SourceLocation = 'https://nuget.pkg.github.com/<owner>/index.json'
        ApiKey = { $env:ZF_BUILD_GITHUB_PACKAGES_TOKEN }
        Credential = {
            [pscredential]::new('github-actions', (ConvertTo-SecureString $env:ZF_BUILD_GITHUB_PACKAGES_TOKEN -AsPlainText -Force))
        }
    }
)
```

### Tasks

| Name                       | Description                                                                                             |
| -------------------------- | ------------------------------------------------------------------------------------------------------- |
| `PublishPowerShellModules` | Publishes PowerShell Modules to one or more PowerShell Repositories (e.g. PSGallery, GitHub Packages) |

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
