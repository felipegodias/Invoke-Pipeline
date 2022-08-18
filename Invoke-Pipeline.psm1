param(
    [string]$SettingsFilePath
)

# Initializes the Module with the given settings file.
$InvokePipelineModule = [InvokePipelineModule]::new($SettingsFilePath)

# Get the details of the given pipeline. If the pipeline does not exists or ain't passed to the function
# this will show all possible pipelines that can be invoked.
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

# Invokes all the steps from the given pipeline.
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

# Handler for the Module
class InvokePipelineModule {
    [string]$SettingsFilePath

    InvokePipelineModule([string]$SettingsFilePath) {
        $this.SettingsFilePath = $SettingsFilePath
    }

    [Settings]GetSettings() {
        # Gets the content from yaml file then convert it into a Settings class.
        # We're not caching this because this way users can change the settings file on the fly
        # without the need to reimport the module or call a reload cmdlet.
        $SettingsContent = Get-Content -Path $this.SettingsFilePath    
        $SettingsYaml = $SettingsContent | ConvertFrom-Yaml
        $Settings = [Settings]::new($SettingsYaml)
        return $Settings
    }
}

# Handler for the pipeline step. Each step can have a command to be executed and a working directory.
class PipelineStep {
    [string]$Command
    [string]$WorkingDirectory

    # Parses the step from the yaml file.
    PipelineStep($Raw) {
        $this.WorkingDirectory = $Raw.WorkingDirectory
        $this.Command = $Raw.Command
    }

    Invoke() {
        $CurrentLocation = Get-Location
        # If the current pipeline step does not sets as working directory we use the current location as working directory.
        # This way we can just use Push/Pop Location.
        $Location = $this.WorkingDirectory -eq "" ? $CurrentLocation : $this.WorkingDirectory
        $PathInfo = Push-Location -Path $Location -StackName "Invoke-Pipeline" -PassThru
        try {
            # If step wasn't able to set the working directory lets abort the process.
            # No error message is needed because Push-Location will already shows a error message to the user.
            if ($null -eq $PathInfo.Path) {
                throw
            }

            Invoke-Expression $this.Command
            $ExpressionExitCode = $LASTEXITCODE
            # Validates if the current step was succesfully executed. If not, we just abort the execution of the other steps.
            if ($null -ne $ExpressionExitCode -and $ExpressionExitCode -ne 0) {
                throw "Pipeline step failed with exit code '$ExpressionExitCode'!"
            }
        } finally {
            Pop-Location -StackName "Invoke-Pipeline" -PassThru
        }
    }
}

# Handler for the pipeline. Each pipeline can have multiple steps to be executed.
class Pipeline {
    [string]$Name
    [string]$Description
    [string]$WorkingDirectory
    [System.Collections.Generic.List[PipelineStep]]$Steps

    # Parsing the pipeline from the yaml file.
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

    # Invokes the current pipeline.
    Invoke() {
        $CurrentLocation = Get-Location

        # If the given pipeline does not sets as working directory we use the current location as working directory.
        # This way we can just use Push/Pop Location.
        $Location = $this.WorkingDirectory -eq "" ? $CurrentLocation : $this.WorkingDirectory
        $PathInfo = Push-Location -Path $Location -StackName "Invoke-Pipeline" -PassThru
        try {
            # If pipeline wasn't able to set the working directory lets abort the process.
            # No error message is needed because Push-Location will already shows a error message to the user.
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

# Handler for the Settings.yaml file.
class Settings {
    [System.Collections.Generic.SortedDictionary[[string], Pipeline]]$Pipelines

    # Parses the raw yaml file.
    Settings($Raw) {
        $this.Pipelines = [System.Collections.Generic.SortedDictionary[[string], Pipeline]]::new()
        Write-Host $this.Pipelines
        foreach ($PipelineKey in $Raw.Pipelines.Keys) {
            $Pipeline = [Pipeline]::new($PipelineKey, $Raw.Pipelines.$PipelineKey)
            $this.Pipelines.Add($PipelineKey, $Pipeline)
        }
    }

    # Search for the pipeline with the given name; otherwise, null.
    [Pipeline]GetPipeline([string]$PipelineName) {
        return $this.Pipelines.$PipelineName
    }
}
