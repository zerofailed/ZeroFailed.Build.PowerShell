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

This group contains functionality for publishing PowerShell modules to repositories. It uses PSResourceGet (`Microsoft.PowerShell.PSResourceGet`), not PowerShellGet.

### Properties

| Name                                    | Default Value | ENV Override                          | Description                                                                                                                                                                                                              |
| --------------------------------------- | ------------- | ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `EnablePowerShellModuleForcePublish`    | $false        |                                       | **Deprecated**, and has no effect. Modules are published with PSResourceGet's `Publish-PSResource`, which does not have a `-Force` parameter. When `$true`, a warning is written. See `PowerShellModulePublishSkipDuplicates` to re-run a publish that only partly succeeded. |
| `PowerShellModulePublishSkipDuplicates` | $true         | `ZF_BUILD_PS_SKIP_PUBLISH_DUPLICATES` | When true, a repository that already holds the module version is skipped with a warning instead of failing the build. See [note below](#retrying-a-failed-publish).                                                     |
| `PowerShellModulesToPublish`            | @()           |                                       | Configures the PowerShell modules to be published to a PowerShell repository (e.g. PSGallery). See [note below](#powershellmodulestopublish) for configuration syntax.                                                   |
| `PowerShellRepositories`                | @()           |                                       | The PowerShell repositories to publish to (e.g. PSGallery and GitHub Packages). See [note below](#powershellrepositories) for configuration syntax.                                                                       |
| `PowerShellRepository`                  | "PSGallery"   |                                       | The name of the PowerShell repository to publish to. Only used when `PowerShellRepositories` is empty.                                                                                                                   |
| `PSRepositoryApiKey`                    | ""            | `ZF_BUILD_PS_REPOSITORY_APIKEY`       | The API key to use when publishing to the PowerShell repository. Only used when `PowerShellRepositories` is empty.                                                                                                       |
| `SkipPowerShellPublish`                 | $false        |                                       | When true, publishing any PowerShell modules will be skipped.                                                                                                                                                            |

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

| Key                       | Required | Description                                                                                                                  |
| ------------------------- | -------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `Name`                    | yes      | The name of the PowerShell repository, as registered with PSResourceGet (see `Get-PSResourceRepository`).                    |
| `ApiKey`                  | no       | The API key to use when publishing.                                                                                          |
| `SourceLocation`          | no       | The repository's URI. When set, the repository is registered with PSResourceGet (as trusted) if it is not registered already. |
| `PublishLocation`         | no       | Not supported. PSResourceGet publishes to the repository's URI. A warning is written when this differs from `SourceLocation`. |
| `Credential`              | no       | A `PSCredential` used to look for existing versions in the repository and to publish to it.                                  |
| `BlockPreReleaseVersions` | no       | When `$true`, pre-release versions are not published to this repository (it is not registered either). Defaults to `$false`. |

PSResourceGet keeps its own list of repositories. A repository that is registered only with PowerShellGet's `Register-PSRepository` is not found, so either set `SourceLocation` or register it with `Register-PSResourceRepository`.

Any value can be a scriptblock. Scriptblocks are evaluated when the publish task runs, so secrets are only read when they are needed.

The example below publishes every version to GitHub Packages, and only stable versions to PSGallery:

```powershell
$PowerShellRepositories = @(
    @{
        Name = 'PSGallery'
        ApiKey = { $PSRepositoryApiKey }
        BlockPreReleaseVersions = $true
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

#### Required modules

Before a module is published to a repository, each module in its manifest's `RequiredModules` must exist in that repository, so that the published module can be installed from it. When a required module is missing, publishing to that repository fails. Modules listed in the manifest's `PrivateData.PSData.ExternalModuleDependencies` are not checked, because they are installed from somewhere else. When a pre-release version is published, a pre-release version of a required module also counts.

PSResourceGet cannot publish a module whose `RequiredModules` has a wildcard `MaximumVersion` (e.g. `'5.*'`). When a manifest has one, publishing fails before any repository is published to. Use an explicit maximum version instead (e.g. `'5.99999999'` instead of `'5.*'`), or remove `MaximumVersion`.

#### Retrying a failed publish

Each module is published to every repository, even when publishing to an earlier repository fails. When any repository fails, the build fails after all repositories have been attempted, and the error lists each failed repository.

When `PowerShellModulePublishSkipDuplicates` is `$true` (the default), a repository that already holds the module version is skipped with a warning. So if publishing succeeds for PSGallery but fails for GitHub Packages, you can re-run the same build: PSGallery is skipped and only GitHub Packages is published to.

A version counts as already published when either:

- `Find-PSResource` finds that exact version in the repository, or
- `Publish-PSResource` fails with a NuGet `409 (Conflict)` response.

Set `PowerShellModulePublishSkipDuplicates` to `$false` if you want an existing version to fail the build.

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
