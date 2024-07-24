// ============ //
// Parameters   //
// ============ //
@description('Required. Name of the Key Vault. Must be globally unique.')
@maxLength(24)
param name string

@description('Optional. Array of access policies object.')
param accessPolicies array = []

@description('Optional. Specifies if the vault is enabled for deployment by script or compute.')
@allowed([
  true
  false
])
param enableVaultForDeployment bool = true

@description('Optional. Specifies if the vault is enabled for a template deployment.')
@allowed([
  true
  false
])
param enableVaultForTemplateDeployment bool = true

@description('Optional. Specifies if the azure platform has access to the vault for enabling disk encryption scenarios.')
@allowed([
  true
  false
])
param enableVaultForDiskEncryption bool = true

@description('Optional. softDelete data retention days. It accepts >=7 and <=90.')
@allowed([
  90
])
param softDeleteRetentionInDays int = 90

@description('Optional. Property that controls how data actions are authorized. When true, the key vault will use Role Based Access Control (RBAC) for authorization of data actions, and the access policies specified in vault properties will be ignored (warning: this is a preview feature). When false, the key vault will use the access policies specified in vault properties, and any policy stored on Azure Resource Manager will be ignored. If null or not specified, the vault is created with the default value of false. Note that management actions are always authorized with RBAC.')
@allowed([
  false
])
param enableRbacAuthorization bool = false

@description('Optional. The vault\'s create mode to indicate whether the vault need to be recovered or not. - recover or default.')
@allowed([
  'default'
  'recover'
])
param createMode string = 'default'

@description('Optional. Specifies the SKU for the vault.')
@allowed([
  'premium'
])
param vaultSku string = 'premium'

@description('Optional. Service endpoint object information. For security reasons, it is recommended to set the DefaultAction Deny.')
param networkAcls object = {}

@description('Optional. Configuration details for private endpoints. For security reasons, it is recommended to use private endpoints whenever possible.')
param privateEndpointIntegration bool

@description('Optional. public access to the vault. For security reasons, it is recommended to set the publicNetworkAccess to Disabled.')
param publicAccess bool = false



// ============ //
//  Variables   //
// ============ //
var location = resourceGroup().location



// =========== //
// Deployments //
// =========== //
resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: name
  location: location
  properties: {
    enabledForDeployment: enableVaultForDeployment
    enabledForTemplateDeployment: enableVaultForTemplateDeployment
    enabledForDiskEncryption: enableVaultForDiskEncryption
    enableSoftDelete: true // AKV-MD004
    softDeleteRetentionInDays: softDeleteRetentionInDays
    enableRbacAuthorization: enableRbacAuthorization
    createMode: createMode
    enablePurgeProtection: true // AKV-MD005
    tenantId: subscription().tenantId
    accessPolicies : accessPolicies
    sku: {
      name: vaultSku
      family: 'A'
    }
    networkAcls: !empty(networkAcls) ? {
      bypass: contains(networkAcls, 'bypass') ? networkAcls.bypass : null
      defaultAction: contains(networkAcls, 'defaultAction') ? networkAcls.defaultAction : null
      virtualNetworkRules: contains(networkAcls, 'virtualNetworkRules') ? networkAcls.virtualNetworkRules : []
      ipRules: contains(networkAcls, 'ipRules') ? networkAcls.ipRules : []
    } : null
    publicNetworkAccess: publicAccess ? 'Enabled' : 'Disabled'
  }
}

module privateEndpoint '../Microsoft.Network/privateEndpoints/deploy.bicep' = if (privateEndpointIntegration  == true) {
  name:  '${uniqueString(deployment().name)}-PE'
  params: {
    location: location
    groupIds: [
      'vault'
    ]
    name: '${name}-pe'
    serviceResourceId: keyVault.id 
  }
}



// ============ //
//   Outputs    //
// ============ //
@description('The resourceId of the KeyVault')
output KeyVaultId string = keyVault.id
