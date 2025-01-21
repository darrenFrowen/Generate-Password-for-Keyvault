# Deploys the Bicep template to Azure.

Param(
    [Switch]$whatif = $false
)

# Required. Set the location for the deployment
$location = "UK South"

# Variables
$templateFile = 'main.bicep'
$today = Get-Date -Format 'MM-dd-yyyy'
$deploymentName = "deploymentscript-$today"

if ($whatif) { Write-Host "##[section] Running What-If" } else { Write-Host "##[section] Running Deployment" }

# Deploy the Bicep template
New-AzDeployment -Name $deploymentName `
    -Location $location `
    -TemplateFile $templateFile `
    -Verbose -WhatIf:$whatif