# <copyright file="publish.properties.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

# PowerShellModulesToPublish must be an array of the following structure:
# @(
#     @{
#         ModulePath = "<path-to-psd1-file>"
#         FunctionsToExport = @("*")
#         CmdletsToExport = @()
#         AliasesToExport = @()
#     }
# )

# Synopsis: Configures the PowerShell modules to be published to a PowerShell repository (e.g. PSGallery)
$PowerShellModulesToPublish = @()

# Synopsis: When true, publishing any PowerShell modules will be skipped. Defaults to false.
$SkipPowerShellPublish = $false

# Synopsis: When true, the PowerShell module will be published even if the version already exists in the repository. Defaults to false.
$EnablePowerShellModuleForcePublish = $false

# Synopsis: The name of the PowerShell repository to publish to. Defaults to PSGallery.
$PowerShellRepository = "PSGallery"

# Synopsis: The API key to use when publishing to the PowerShell repository.
$PSRepositoryApiKey = property ZF_BUILD_PS_REPOSITORY_APIKEY ""