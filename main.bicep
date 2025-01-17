metadata title = 'Keyvault with a autogenerated password'
metadata dateCreated = '16-01-2025'
metadata version = '0.0.1'
metadata description = 'This script deploys a keyvault with a autogenerated password and then deletes the deployment script'

targetScope = 'subscription'

@description('Required. Location for the deployment')
param location string = 'uksouth'

@description('Optional. Deploying user principle id for RBAC access to the keyvault')
param deployUserPrincipleId string = '0f32888d-7ae1-4643-a938-97d42a723c7c'
@description('Optional. Resource group name.')
param resourceGroupName string = 'rg-deployment-script'
@description('Optional. User assigned identity name')
param userAssignedIdentityName string = 'uami-shared'
@description('Optional. Keyvault name')
param keyVaultName string = 'kv-shared-01'
@description('Optional. Secret name')
param secretName string = 'adminPasswordKvSecret'
@description('Optional. Deployment Script name that generates the secret')
param scriptName string = 'generatePasswordKvSecret'
@description('Optional. Deployment Script name to delete the generatePasswordKvSecret script')
param deleteScriptName string = 'deletedGeneratePasswordKvSecret'
@description('Optional. UTC time value used to generate the secret')
param utcValue string = utcNow()


@description('This is the deployment script and shared keyvault resource group')
resource sharedResourceGroup 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: resourceGroupName
  location: location
}

@description('Deployment Script User assigned identity')
module userAssignedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.0' = {
  scope: sharedResourceGroup
  name: 'userAssignedIdentity-deploy'
  params: {
    name: userAssignedIdentityName
  }
}

@description('Deployment Script to generate a unique 16 character secret to paas to keyvault')
module deploymentScript 'br/public:avm/res/resources/deployment-script:0.5.1' = {
  name: 'deploymentScript-deploy'
  scope: sharedResourceGroup
  params: {
    name: scriptName
    managedIdentities: {
      userAssignedResourceIds: [
        userAssignedIdentity.outputs.resourceId
      ]
    }
    kind: 'AzurePowerShell'
    baseTime: utcValue
    azPowerShellVersion: '12.3'
    environmentVariables: [
      {
        name: 'varKeyVaultName'
        value: keyVaultName
      }
      {
        name: 'varSecretName'
        value: secretName
      }
    ]
    scriptContent: '''
    # Check for an existing secret value to be recorded as an output 'existingSecret'
    $existingSecret = Get-AzKeyVaultSecret -VaultName $env:varKeyVaultName -Name $env:varSecretName -AsPlainText -ErrorAction SilentlyContinue

    # Generate a new secret value to be recorded as an output 'newSecret'
    $charlist = [char]94..[char]126 + [char]65..[char]90 + [char]47..[char]57
    $newSecret = ($charlist | Get-Random -count 16) -join ''

    # Define the deployment script outputs
    $DeploymentScriptOutputs = @{
      "newSecret" = $newSecret
      "existingSecret" = $existingSecret
    }
    '''
    timeout: 'PT1H'
    retentionInterval: 'PT1H'
    roleAssignments: [
      {
        description: 'Allow the user assigned identity to delete this script see deletedGeneratePasswordKvSecret script'
        principalId: userAssignedIdentity.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: 'Contributor'
      }
    ]
  }
}

@description('Keyvault to store the secret that was generated by the deployment script')
module keyvault 'br/public:avm/res/key-vault/vault:0.11.1' = {
  name: 'keyVault-deploy'
  scope: sharedResourceGroup
  params: {
    enablePurgeProtection: false
    name: keyVaultName
    sku: 'standard'
    accessPolicies: []
    secrets: concat(
      empty(deploymentScript.outputs.outputs.existingSecret ?? '') ? [
        {
          name: secretName
          value: deploymentScript.outputs.outputs.newSecret
        }
      ] : [],
      [
        {
          name: 'testOtherSecret'
          value: 'notARealSecret'
        }
      ]
    )
    roleAssignments: [
      {
        description: 'Allow the deploying user assigned identity to manage the key vault'
        principalId: deployUserPrincipleId
        principalType: 'User'
        roleDefinitionIdOrName: 'Key Vault Administrator'
      }
      {
        description: 'Allow the deployment script user assigned identity to manage the key vault'
        principalId: userAssignedIdentity.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: 'Key Vault Administrator'
      }
    ]
  }
}

@description('Deployment Script to delete generatePasswordKvSecret and its outputs. This scripts deletes after 1h of creation')
module deleteDeploymentScript 'br/public:avm/res/resources/deployment-script:0.5.1' = {
  name: 'deleteDeploymentScript-deploy'
  scope: sharedResourceGroup
  dependsOn: [
    deploymentScript
    keyvault
  ]
  params: {
    name: deleteScriptName
    managedIdentities: {
      userAssignedResourceIds: [
        userAssignedIdentity.outputs.resourceId
      ]
    }
    kind: 'AzurePowerShell'
    baseTime: utcValue
    azPowerShellVersion: '12.3'
    environmentVariables: [
      {
        name: 'varResourceGroupName'
        value: resourceGroupName
      }
      {
        name: 'varScriptName'
        value: scriptName
      }
    ]
    scriptContent: '''
    Remove-AzDeploymentScript -ResourceGroupName $env:varResourceGroupName -Name $env:varScriptName
    '''
    timeout: 'PT1H'
    retentionInterval: 'PT1H'
  }
}
