# first commit creates main on ad-devops shared (Clean init leaves no branches)
resource "azuredevops_git_repository_file" "adf_publish_template" {
  repository_id       = local.config.roots["ad-devops"].shared_repo.id
  file                = "pipelines/adf-publish.yml"
  branch              = "refs/heads/main"
  commit_message      = "Seed pipelines/adf-publish.yml"
  overwrite_on_create = true
  # yamlencode sorts map keys; ADO treats the first key of each step as the type (must be task:)
  content = <<-EOT
  stages:
    - stage: Publish
      jobs:
        - job: Publish
          variables:
            armOutput: ArmTemplate
          steps:
            - task: UseNode@1
              displayName: Install Node.js
              inputs:
                version: "20.x"
            - task: PowerShell@2
              displayName: Create package.json
              inputs:
                targetType: inline
                pwsh: true
                workingDirectory: $(Build.Repository.LocalPath)
                script: Set-Content -Path package.json -Encoding utf8 -Value '{"scripts":{"build":"node node_modules/@microsoft/azure-data-factory-utilities/lib/index"},"dependencies":{"@microsoft/azure-data-factory-utilities":"^1.0.3"}}'
            - task: Npm@1
              displayName: Install npm package
              inputs:
                command: install
                workingDir: $(Build.Repository.LocalPath)
                verbose: true
            - task: Npm@1
              displayName: Validate and generate ARM template
              inputs:
                command: custom
                workingDir: $(Build.Repository.LocalPath)
                customCommand: run build export "$(Build.Repository.LocalPath)" "$(factoryId)" "$(armOutput)"
            - task: PowerShell@2
              displayName: Resolve ARM paths
              inputs:
                targetType: inline
                pwsh: true
                script: |
                  $armDir = Join-Path "$(Build.Repository.LocalPath)" "$(armOutput)"
                  $armTemplate = Join-Path $armDir ARMTemplateForFactory.json
                  Write-Host "##vso[task.setvariable variable=armTemplate]$armTemplate"
                  $armParameters = Join-Path $armDir ARMTemplateParametersForFactory.json
                  Write-Host "##vso[task.setvariable variable=armParameters]$armParameters"
                  $armScript = Join-Path $armDir PrePostDeploymentScript.ps1
                  Write-Host "##vso[task.setvariable variable=armScript]$armScript"
            - task: AzurePowerShell@5
              displayName: Stop ADF triggers
              inputs:
                azureSubscription: $(azureRmServiceConnection)
                scriptType: FilePath
                scriptPath: $(armScript)
                ScriptArguments: -armTemplate "$(armTemplate)" -ResourceGroupName $(resourceGroupName) -DataFactoryName $(factoryName) -predeployment:1 -deleteDeployment:0
                errorActionPreference: stop
                FailOnStandardError: false
                azurePowerShellVersion: LatestVersion
                pwsh: true
            - task: AzureResourceManagerTemplateDeployment@3
              displayName: ARM deploy factory
              inputs:
                deploymentScope: Resource Group
                azureResourceManagerConnection: $(azureRmServiceConnection)
                action: Create Or Update Resource Group
                resourceGroupName: $(resourceGroupName)
                location: $(location)
                templateLocation: Linked artifact
                csmFile: $(armTemplate)
                csmParametersFile: $(armParameters)
                deploymentMode: Incremental
            - task: AzurePowerShell@5
              displayName: Start ADF triggers
              condition: always()
              inputs:
                azureSubscription: $(azureRmServiceConnection)
                scriptType: FilePath
                scriptPath: $(armScript)
                ScriptArguments: -armTemplate "$(armTemplate)" -ResourceGroupName $(resourceGroupName) -DataFactoryName $(factoryName) -predeployment:0 -deleteDeployment:1
                errorActionPreference: stop
                FailOnStandardError: false
                azurePowerShellVersion: LatestVersion
                pwsh: true
  EOT
  lifecycle {
    ignore_changes = [commit_message]
  }
}
