<div align="center">
    <img src="https://upload.wikimedia.org/wikipedia/commons/a/af/PowerShell_Core_6.0_icon.png?20180119125925" alt="Logo" width="128" height="130"/>
    <h1 align="center">Invoke-Pipeline
</h1>
</div>

## Requirements

-   PowerShell 7.x

```powershell
winget install Microsoft.PowerShell
```

-   [powershell-yaml](https://github.com/cloudbase/powershell-yaml)

```powershell
Install-Module -Name powershell-yaml -AllowClobber -Scope CurrentUser -Force
```

## Install

```powershell
git clone git@github.com:felipegodias/Invoke-Profile.git
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Unrestricted
```

### Powershell Profile

```powershell
Import-Module <REPOSITORY_PATH>/Invoke-Pipeline.psm1 -Force -ArgumentList <SETTINGS_FILE_PATH>
```

## Usage

### Settings.yaml

```yaml
---
Pipelines:
    pipeline_foo:
        Description: "Prints Hello World"
        Steps:
            - Command: "Write-Host Hello World"
    pipeline_bar:
        Description: "Prints Steps Locations"
        WorkingDirectory: "C:/"
        Steps:
            - Command: "Get-Location | Write-Host"
            - Command: "Get-Location | Write-Host"
              WorkingDirectory: "C:/Users"
            - Command: "Get-Location | Write-Host"
```

### Get-Pipeline (gpi)

Get the details of the given pipeline. If the pipeline does not exists or ain't passed to the function this will show all possible pipelines that can be invoked.

```powershell
Get-Pipeline <PIPELINE_NAME>
gpi <PIPELINE_NAME>

#EXAMPLE 1
Get-Pipeline

#OUTPUT 1
#Name         Description
#----         -----------
#pipeline_bar Prints Steps Locations
#pipeline_foo Prints Hello World

#EXAMPLE 2
Get-Pipeline pipeline_foo

#OUTPUT 2
#Name             : pipeline_foo
#Description      : Prints Hello World
#WorkingDirectory : 

#Command                WorkingDirectory
#-------                ----------------
#Write-Host Hello World

#EXAMPLE 3
gpi pipeline_bar

#OUTPUT 3
#Name             : pipeline_bar
#Description      : Prints Steps Locations
#WorkingDirectory : C:/

#Command                   WorkingDirectory
#-------                   ----------------
#Get-Location | Write-Host
#Get-Location | Write-Host C:/Users
#Get-Location | Write-Host
```

### Invoke-Pipeline (ipi)

Invokes all the steps from the given pipeline.

```powershell
Invoke-Pipeline <PIPELINE_NAME>
ipi <PIPELINE_NAME>

#EXAMPLE 1
Invoke-Pipeline pipeline_foo

#OUTPUT 1
#Hello World

#EXAMPLE 2
ipi pipeline_bar

#OUTPUT 2
#C:\
#C:\Users
#C:\
```
