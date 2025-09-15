# <copyright file="ZeroFailed.Build.PowerShell.module.tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

$moduleName = Split-Path -Leaf $PSCommandPath.Replace('.module.tests.ps1', '')

Describe "'$moduleName' Module Tests" {

    BeforeDiscovery {
        Write-Host "PSScriptRoot: $PSScriptRoot" -f Magenta
        $functions = Get-ChildItem -Recurse $PSScriptRoot/functions -Include *.ps1 |
                        Where-Object { $_ -notmatch ".Tests.ps1" }
        $tasks = Get-ChildItem -Recurse $PSScriptRoot/tasks -Include *.tasks.ps1
    }
    
    BeforeAll {
        $moduleName = Split-Path -Leaf $PSCommandPath.Replace('.module.tests.ps1', '')
    }
    
    Context 'Module Setup' {
        It "has the root module $moduleName.psm1" {
            "$PSScriptRoot/$moduleName.psm1" | Should -Exist
        }

        It "has the a manifest file of $moduleName.psd1" {
            "$PSScriptRoot/$moduleName.psd1" | Should -Exist
            "$PSScriptRoot/$moduleName.psd1" | Should -FileContentMatch "$moduleName.psm1"
        }
    
        It "$moduleName folder has functions folder" {
            "$PSScriptRoot/functions" | Should -Exist
        }

        It "$moduleName is valid PowerShell code" {
            $psFile = Get-Content -Path "$PSScriptRoot/$moduleName.psm1" -ErrorAction Stop
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize($psFile, [ref]$errors)
            $errors.Count | Should -Be 0
        }
    }
    
    Context "Test Function <_>" -ForEach $functions {
        
        BeforeAll {
            $function = $_.Name
            $functionPath = $_.FullName
            $functionTestsPath = $_.FullName.Replace('.ps1', '.Tests.ps1')
            $functionDir = $_.Directory.FullName
            $isPrivateFunction = $_.Name.StartsWith('_')
            $markdownDocPath = Join-Path $here 'docs' 'functions' "$(Split-Path -LeafBase $_.Name).md"
        }
        
        It "<function> should exist" {
            $functionPath | Should -Exist
        }

        It "<function> should have a copyright block" {
            $functionPath | Should -FileContentMatch 'Copyright \(c\) Endjin Limited'
        }

        It "<function> should have a PlatyPS markdown documentation file with no placeholders" {
            if (!$isPrivateFunction) {
                $markdownDocPath | Should -Exist
                $doc = Import-MarkdownCommandHelp -Path $markdownDocPath
                $doc | Should -Not -Match '\"\{\{.*\}\}\"'
            }
        }

        It "<function> should be an advanced function" {
            $functionPath | Should -FileContentMatch 'function'
            $functionContent = Get-Content -raw $functionPath
            if ($functionContent -notmatch '#SUPPRESS-ParameterChecks') {
                $functionPath | Should -FileContentMatch 'cmdletbinding'
                $functionPath | Should -FileContentMatch 'param'
            }
        }
    
        It "<function> is valid PowerShell code" {
            $psFile = Get-Content -Path $functionPath -ErrorAction Stop
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize($psFile, [ref]$errors)
            $errors.Count | Should -Be 0
        }

        It "<function> should have tests" {
            if (!$isPrivateFunction) {
                $functionTestsPath | Should -Exist
            }
        }
    }

    Context "Test Tasks file <_>" -ForEach $tasks {
        
        BeforeAll {
            $task = $_.Name
            $taskPath = $_.FullName
            $taskDir = $_.Directory.FullName
            $propertiesPath = $taskPath.Replace(".tasks.ps1", ".properties.ps1")
        }
        
        It "<task> should exist" {
            $taskPath | Should -Exist
        }

        It "<task> is valid PowerShell code" {
            $psFile = Get-Content -Path $taskPath -ErrorAction Stop
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize($psFile, [ref]$errors)
            $errors.Count | Should -Be 0
        }

        It "<task> should have a copyright block" {
            $taskPath | Should -FileContentMatch 'Copyright \(c\) Endjin Limited'
        }

        It "<task> should have a properties file" {
            $propertiesPath | Should -Exist
        }

        It "<task> should have a valid properties file" {
            $psFile = Get-Content -Path $propertiesPath -ErrorAction Stop
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize($psFile, [ref]$errors)
            $errors.Count | Should -Be 0
        }

        It "<task> properties file should have a copyright block" {
            $propertiesPath | Should -FileContentMatch 'Copyright \(c\) Endjin Limited'
        }
    }
}