# <copyright file="publish.properties.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

# Synopsis: Configures the PowerShell modules to be published to a PowerShell repository (e.g. PSGallery)
$PowerShellModulesToPublish = @()

# Synopsis: When true, publishing any PowerShell modules will be skipped.
$SkipPowerShellPublish = $false

# Synopsis: When true, 'Publish-Module' is run with '-Force'. This skips confirmation prompts and some version-ordering checks (e.g. publishing a pre-release after the stable version of the same version number). It does NOT allow re-publishing a version that already exists in the repository - see 'PowerShellModulePublishSkipDuplicates'.
$EnablePowerShellModuleForcePublish = $false

# Synopsis: When true, a repository that already holds the module version being published is skipped with a warning instead of failing the build. This makes it safe to re-run a publish that only partly succeeded.
$PowerShellModulePublishSkipDuplicates = [Convert]::ToBoolean((property ZF_BUILD_PS_SKIP_PUBLISH_DUPLICATES $true))

# Synopsis: The PowerShell repositories to publish to (e.g. PSGallery and GitHub Packages). When empty, the single repository defined by 'PowerShellRepository' and 'PSRepositoryApiKey' is used.
$PowerShellRepositories = @()

# Synopsis: The name of the PowerShell repository to publish to. Only used when 'PowerShellRepositories' is empty.
$PowerShellRepository = "PSGallery"

# Synopsis: The API key to use when publishing to the PowerShell repository. Only used when 'PowerShellRepositories' is empty.
$PSRepositoryApiKey = property ZF_BUILD_PS_REPOSITORY_APIKEY ""