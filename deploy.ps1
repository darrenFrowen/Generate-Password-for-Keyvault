# Deploys the Bicep template to Azure.

# Required. Set the location for the deployment
$location = "UK South"

# Variables
$templateFile = 'main.bicep'
$today = Get-Date -Format 'MM-dd-yyyy'
$deploymentName = "deploymentscript-$today"

# Deploy the Bicep template
New-AzDeployment -Name $deploymentName `
    -Location $location `
    -TemplateFile $templateFile `
    -Verbose #-WhatIf


$githubOrganizationName = 'darrenFrowen'
$githubRepositoryName = 'Generate-Password-for-Keyvault'

$applicationRegistration = New-AzADApplication -DisplayName 'frowens-github-workflow'

# Describe this workflow in Azure Portal
New-AzADAppFederatedCredential -Name 'frowens-github-workflow' `
-ApplicationObjectId $applicationRegistration.Id `
-Issuer 'https://token.actions.githubusercontent.com' `
-Audience 'api://AzureADTokenExchange' `
-Subject "repo:$($githubOrganizationName)/$($githubRepositoryName):ref:refs/heads/main"

# Describe this workflow in Azure Portal
New-AzADServicePrincipal -AppId $applicationRegistration.AppId


$azureContext = Get-AzContext
Write-Host "AZURE_CLIENT_ID: $($applicationRegistration.AppId)"
Write-Host "AZURE_TENANT_ID: $($azureContext.Tenant.Id)"
Write-Host "AZURE_SUBSCRIPTION_ID: $($azureContext.Subscription.Id)"