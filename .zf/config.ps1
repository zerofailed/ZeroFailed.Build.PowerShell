# Extensions setup
$zerofailedExtensions = @(
    @{
        Name = "ZeroFailed.Build.PowerShell"
        # It uses itself as a dependency, so we test the local repository version
        Path = "$here\module"
    }
)

# Load the tasks and process
. ZeroFailed.tasks -ZfPath $here/.zf

# Set the required build options
$PesterTestsDir = "$here/module"
$PesterCodeCoveragePaths = @("$here/module/functions")
$PowerShellModulesToPublish = @(
    @{
        ModulePath = "$here/module/ZeroFailed.Build.PowerShell.psd1"
        FunctionsToExport = @("*")
        CmdletsToExport = @()
        AliasesToExport = @()
    }
)
$PowerShellRepositories = @(
    @{
        Name = 'PSGallery'
        ApiKey = { $PSRepositoryApiKey }
    }
    @{
        Name = 'GitHubPackages'
        SourceLocation = 'https://nuget.pkg.github.com/zerofailed/index.json'
        ApiKey = { $env:ZF_BUILD_GITHUB_PACKAGES_TOKEN }
        Credential = {
            if ($env:ZF_BUILD_GITHUB_PACKAGES_TOKEN) {
                [pscredential]::new('github-actions', (ConvertTo-SecureString $env:ZF_BUILD_GITHUB_PACKAGES_TOKEN -AsPlainText -Force))
            }
        }
    }
)
$PSMarkdownDocsFlattenOutputPath = $true
$PSMarkdownDocsOutputPath = './docs/functions'
$PSMarkdownDocsIncludeModulePage = $false

# Customise the build process
task . FullBuild

#
# Build Process Extensibility Points - uncomment and implement as required
#

# task RunFirst {}
# task PreInit {}
# task PostInit {}
# task PreVersion {}
# task PostVersion {}
# task PreBuild {}
# task PostBuild {}
# task PreTest {}
# task PostTest {}
# task PreTestReport {}
# task PostTestReport {}
# task PreAnalysis {}
# task PostAnalysis {}
# task PrePackage {}
# task PostPackage {}
# task PrePublish {}
# task PostPublish {}
# task RunLast {}
