param(
    [string]$SettingsFilePath
)

$InvokePipelineModule = [InvokePipelineModule]::new($SettingsFilePath)

function Get-Pipeline {
    param (
        [string]$PipelineName
    )

    $Settings = $InvokePipelineModule.GetSettings()

    if ($PipelineName -eq "") {
        $Settings.Pipelines.Values | Select-Object Name, Description | Format-Table -AutoSize
    }
    else {
        $Pipeline = $Settings.GetPipeline($PipelineName)

        if ($null -eq $Pipeline) {
            Write-Error "Could not found pipeline with name '$PipelineName'! Possible options are:"
            $Settings.Pipelines.Values | Select-Object Name, Description | Format-Table -AutoSize
        }
        else {
            $Pipeline | Select-Object Name, Description, WorkingDirectory | Format-List | Write-Output
            $Pipeline.Steps | Select-Object | Format-Table  -AutoSize | Write-Output
        }
    }
}

function Invoke-Pipeline {
    param (
        $PipelineName
    )

    $Settings = $InvokePipelineModule.GetSettings()
    $Pipeline = $Settings.GetPipeline($PipelineName)

    if ($null -eq $Pipeline) {
        Write-Error "Could not found pipeline with name '$PipelineName'! Possible options are:"
        $Settings.Pipelines.Values | Select-Object Name, Description | Format-Table -AutoSize
    }
    else {
        $Pipeline.Invoke()
    }
}

Set-Alias -Name ipi -Value Invoke-Pipeline -Scope Global
Set-Alias -Name gpi -Value Get-Pipeline -Scope Global
Export-ModuleMember -Function Invoke-Pipeline, Get-Pipeline -Alias ipi, gpi

class InvokePipelineModule {
    [string]$SettingsFilePath

    InvokePipelineModule([string]$SettingsFilePath) {
        $this.SettingsFilePath = $SettingsFilePath
    }

    [Settings]GetSettings() {
        $SettingsContent = Get-Content -Path $this.SettingsFilePath    
        $SettingsYaml = $SettingsContent | ConvertFrom-Yaml
        $Settings = [Settings]::new($SettingsYaml)
        return $Settings
    }
}

class PipelineStep {
    [string]$Command
    [string]$WorkingDirectory

    PipelineStep($Raw) {
        $this.WorkingDirectory = $Raw.WorkingDirectory
        $this.Command = $Raw.Command
    }

    Invoke() {
        $CurrentLocation = Get-Location
        $Location = $this.WorkingDirectory -eq "" ? $CurrentLocation : $this.WorkingDirectory
        $PathInfo = Push-Location -Path $Location -StackName "Invoke-Pipeline" -PassThru
        try {
            if ($null -eq $PathInfo.Path) {
                throw
            }

            Invoke-Expression $this.Command
            $ExpressionExitCode = $LASTEXITCODE
            if ($null -ne $ExpressionExitCode -and $ExpressionExitCode -ne 0) {
                throw "Pipeline step failed with exit code '$ExpressionExitCode'!"
            }
        } finally {
            Pop-Location -StackName "Invoke-Pipeline" -PassThru
        }
    }
}

class Pipeline {
    [string]$Name
    [string]$Description
    [string]$WorkingDirectory
    [System.Collections.Generic.List[PipelineStep]]$Steps

    Pipeline($Name, $Raw) {
        $this.Name = $Name
        $this.Description = $Raw.Description
        $this.WorkingDirectory = $Raw.WorkingDirectory
        $this.Steps = [System.Collections.Generic.List[PipelineStep]]::new()
        foreach ($StepRaw in $Raw.Steps) {
            $Step = [PipelineStep]::new($StepRaw)
            $this.Steps.Add($Step)
        }
    }

    Invoke() {
        $CurrentLocation = Get-Location
        $Location = $this.WorkingDirectory -eq "" ? $CurrentLocation : $this.WorkingDirectory
        $PathInfo = Push-Location -Path $Location -StackName "Invoke-Pipeline" -PassThru
        try {
            if ($null -eq $PathInfo.Path) {
                throw
            }

            foreach ($Step in $this.Steps) {
                $Step.Invoke()
            }
        } finally {
            Pop-Location -StackName "Invoke-Pipeline" -PassThru
        }
    }
}

class Settings {
    [System.Collections.Generic.SortedDictionary[[string], Pipeline]]$Pipelines

    Settings($Raw) {
        $this.Pipelines = [System.Collections.Generic.SortedDictionary[[string], Pipeline]]::new()
        Write-Host $this.Pipelines
        foreach ($PipelineKey in $Raw.Pipelines.Keys) {
            $Pipeline = [Pipeline]::new($PipelineKey, $Raw.Pipelines.$PipelineKey)
            $this.Pipelines.Add($PipelineKey, $Pipeline)
        }
    }

    [Pipeline]GetPipeline([string]$PipelineName) {
        return $this.Pipelines.$PipelineName
    }
}
