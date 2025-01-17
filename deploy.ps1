# Deploys the Bicep template to Azure.

# Required. Set the location for the deployment
$location = "<location>"

# Variables
$templateFile = 'main.bicep'
$today = Get-Date -Format 'MM-dd-yyyy'
$deploymentName = "deploymentscript-$today"

# Deploy the Bicep template
New-AzDeployment -Name $deploymentName `
    -Location $location `
    -TemplateFile $templateFile `
    -Verbose #-WhatIf