# <copyright file="publish.properties.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

# Synopsis: Configures the PowerShell modules to be published to a PowerShell repository (e.g. PSGallery)
$PowerShellModulesToPublish = @()

# Synopsis: When true, publishing any PowerShell modules will be skipped.
$SkipPowerShellPublish = $false

# Synopsis: When true, the PowerShell module will be published even if the version already exists in the repository.
$EnablePowerShellModuleForcePublish = $false

# Synopsis: The name of the PowerShell repository to publish to.
$PowerShellRepository = "PSGallery"

# Synopsis: The API key to use when publishing to the PowerShell repository.
$PSRepositoryApiKey = property ZF_BUILD_PS_REPOSITORY_APIKEY ""