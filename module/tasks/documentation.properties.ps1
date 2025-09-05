# <copyright file="documentation.properties.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

# Synopsis: When true, all markdown documentation will tasks will be skipped.
$SkipGeneratePSMarkdownDocs = $false

# Synopsis: The base output path for generated markdown files.
$PSMarkdownDocsOutputPath = property ZF_BUILD_PS_MD_DOCS_OUTPUT_PATH './docs'

# Synopsis: When true, overrides PlatyPS behaviour of placing markdown files in a sub-folder named after the module.
$PSMarkdownDocsFlattenOutputPath = [Convert]::ToBoolean((property ZF_BUILD_PS_MD_DOCS_FLATTEN_OUTPUT_PATH $false))

# Synopsis: When true, PlatyPS will generate a markdown index page for the module.
$PSMarkdownDocsIncludeModulePage = $true
