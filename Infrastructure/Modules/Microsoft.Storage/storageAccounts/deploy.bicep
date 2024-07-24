// ============ //
// Parameters   //
// ============ //
@maxLength(24)
@description('Required. Name of the Storage Account.')
param name string

@allowed([
  'blob'
  'table'
  'queue'
  'file'
  'web'
  'dfs'
])
@description('Required. Services to activate.')
param services array

@description('Conditional. If true, set publicNetworkAccess to false')
param isRestrictedDataClassification bool = true // AST-MD003

@description('Optional. Is this storage exposed ?. false if isRestrictedDataClassification is true')
param publicNetworkAccess bool = false // AST-MD003

@description('Optional. Enables system assigned managed identity on the resource.')
param systemAssignedIdentity bool = false

@description('Optional. The ID(s) to assign to the resource.')
param userAssignedIdentities object = {}

@allowed([
  'Storage'
  'StorageV2'
  'BlobStorage'
  'FileStorage'
  'BlockBlobStorage'
])
@description('Optional. Type of Storage Account to create.')
param storageAccountKind string = 'StorageV2'

@allowed([
  'Standard_LRS'
  'Standard_ZRS'
  'Premium_ZRS'
  'Standard_GZRS'
  'Standard_RAGZRS'
])
@description('Optional. Storage Account Sku Name.') // AST-MD001
param storageAccountSku string

@allowed([
  'Hot'
  'Cool'
])
@description('Optional. Storage Account Access Tier.')
param storageAccountAccessTier string = 'Hot'

@description('Optional. Provides the identity based authentication settings for Azure Files.')
param azureFilesIdentityBasedAuthentication object = {}

@description('Optional. Configuration details for private endpoints. For security reasons, it is recommended to use private endpoints whenever possible.')
param privateEndpointIntegration bool

@description('Optional. Networks ACLs, this value contains IPs to whitelist and/or Subnet information. For security reasons, it is recommended to set the DefaultAction Deny.')
param networkAcls object = {}

@description('Optional. Blob service and containers to deploy.')
param blobServices object = {}

@description('Conditional. If true, enables Hierarchical Namespace for the storage account. Required if enableSftp or enableNfsV3 is set to true.')
param enableHierarchicalNamespace bool = false

@description('Optional. Local users to deploy for SFTP authentication.')
param localUsers array = []

@description('Conditional. The resource ID of a key vault to reference a customer managed key for encryption from. Required if \'cMKKeyName\' is not empty.')
param cMKKeyVaultResourceId string = ''

@description('Optional. The name of the customer managed key to use for encryption. Cannot be deployed together with the parameter \'systemAssignedIdentity\' enabled.')
param cMKKeyName string = ''

@description('Conditional. User assigned identity to use when fetching the customer managed key. Required if \'cMKKeyName\' is not empty.')
param cMKUserAssignedIdentityResourceId string = ''

@description('Optional. The version of the customer managed key to reference for encryption. If not provided, latest is used.')
param cMKKeyVersion string = ''


var supportsBlobService = storageAccountKind == 'BlockBlobStorage' || storageAccountKind == 'BlobStorage' || storageAccountKind == 'StorageV2' || storageAccountKind == 'Storage'
var supportsFileService = storageAccountKind == 'FileStorage' || storageAccountKind == 'StorageV2' || storageAccountKind == 'Storage'

var identityType = systemAssignedIdentity ? (!empty(userAssignedIdentities) ? 'SystemAssigned,UserAssigned' : 'SystemAssigned') : (!empty(userAssignedIdentities) ? 'UserAssigned' : 'None')
var identity = identityType != 'None' ? {
  type: identityType
  userAssignedIdentities: !empty(userAssignedIdentities) ? userAssignedIdentities : null
} : null



// =========== //
//  Variables  //
// =========== //
var location = resourceGroup().location



// =========== //
// Deployments //
// =========== //
resource keyVault 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = if (!empty(cMKKeyVaultResourceId)) {
  name: last(split(cMKKeyVaultResourceId, '/'))
  scope: resourceGroup(split(cMKKeyVaultResourceId, '/')[2], split(cMKKeyVaultResourceId, '/')[4])
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: name
  location: location
  kind: storageAccountKind
  sku: {
    name: storageAccountSku
  }
  identity: identity
  properties: {
    encryption: {
      keySource: !empty(cMKKeyName) ? 'Microsoft.Keyvault' : 'Microsoft.Storage'
      services: {
        blob: supportsBlobService ? {
          enabled: true
        } : null
        file: supportsFileService ? {
          enabled: true
        } : null
        table: {
          enabled: true
        }
        queue: {
          enabled: true
        }
      }
      keyvaultproperties: !empty(cMKKeyName) ? {
        keyname: cMKKeyName
        keyvaulturi: keyVault.properties.vaultUri
        keyversion: !empty(cMKKeyVersion) ? cMKKeyVersion : null
      } : null
      identity: !empty(cMKKeyName) ? {
        userAssignedIdentity: cMKUserAssignedIdentityResourceId
      } : null
    }
    accessTier: storageAccountKind != 'Storage' ? storageAccountAccessTier : null
    supportsHttpsTrafficOnly: true // AST-FE001 / AST-ME001
    isHnsEnabled: enableHierarchicalNamespace ? enableHierarchicalNamespace : null
    minimumTlsVersion: 'TLS1_2' // [X-GR] TLS 1.2
    networkAcls: !empty(networkAcls) ? {
      bypass: contains(networkAcls, 'bypass') ? networkAcls.bypass : null
      defaultAction: contains(networkAcls, 'defaultAction') ? networkAcls.defaultAction : null
      virtualNetworkRules: contains(networkAcls, 'virtualNetworkRules') ? networkAcls.virtualNetworkRules : []
      ipRules: contains(networkAcls, 'ipRules') ? networkAcls.ipRules : []
    } : null
    allowBlobPublicAccess: false
    publicNetworkAccess: ((isRestrictedDataClassification == false) && (publicNetworkAccess == true))? 'Enabled' : 'Disabled'
    azureFilesIdentityBasedAuthentication: !empty(azureFilesIdentityBasedAuthentication) ? azureFilesIdentityBasedAuthentication : null
  }
}

// SFTP user settings
module storageAccount_localUsers 'localUsers/deploy.bicep' = [for (localUser, index) in localUsers: {
  name: '${uniqueString(deployment().name, location)}-Storage-LocalUsers-${index}'
  params: {
    storageAccountName: storageAccount.name
    name: localUser.name
    hasSharedKey: contains(localUser, 'hasSharedKey') ? localUser.hasSharedKey : false
    hasSshKey: contains(localUser, 'hasSshPassword') ? localUser.hasSshPassword : true
    hasSshPassword: contains(localUser, 'hasSshPassword') ? localUser.hasSshPassword : false
    homeDirectory: contains(localUser, 'homeDirectory') ? localUser.homeDirectory : ''
    permissionScopes: contains(localUser, 'permissionScopes') ? localUser.permissionScopes : []
    sshAuthorizedKeys: contains(localUser, 'sshAuthorizedKeys') ? localUser.sshAuthorizedKeys : []
  }
}]

// Containers
module storageAccount_blobServices 'blobServices/deploy.bicep' = if (!empty(blobServices)) {
  name: '${uniqueString(deployment().name, location)}-Storage-BlobServices'
  params: {
    storageAccountName: storageAccount.name
    containers: contains(blobServices, 'containers') ? blobServices.containers : []
    automaticSnapshotPolicyEnabled: contains(blobServices, 'automaticSnapshotPolicyEnabled') ? blobServices.automaticSnapshotPolicyEnabled : false
    deleteRetentionPolicy: true
    deleteRetentionPolicyDays: 365
    diagnosticLogsRetentionInDays: contains(blobServices, 'diagnosticLogsRetentionInDays') ? blobServices.diagnosticLogsRetentionInDays : 365
    diagnosticStorageAccountId: contains(blobServices, 'diagnosticStorageAccountId') ? blobServices.diagnosticStorageAccountId : ''
    diagnosticEventHubAuthorizationRuleId: contains(blobServices, 'diagnosticEventHubAuthorizationRuleId') ? blobServices.diagnosticEventHubAuthorizationRuleId : ''
    diagnosticEventHubName: contains(blobServices, 'diagnosticEventHubName') ? blobServices.diagnosticEventHubName : ''
    diagnosticLogCategoriesToEnable: contains(blobServices, 'diagnosticLogCategoriesToEnable') ? blobServices.diagnosticLogCategoriesToEnable : []
    diagnosticMetricsToEnable: contains(blobServices, 'diagnosticMetricsToEnable') ? blobServices.diagnosticMetricsToEnable : []
    diagnosticWorkspaceId: contains(blobServices, 'diagnosticWorkspaceId') ? blobServices.diagnosticWorkspaceId : ''
  }
}

module privateEndpoint '../../Microsoft.Network/privateEndpoints/deploy.bicep' = [for service in services: if (privateEndpointIntegration == true) {
  name:  '${uniqueString(deployment().name)}-${service}-PE'
  params: {
    location: location
    groupIds: [service]
    name: '${name}-${service}-pe'
    serviceResourceId: storageAccount.id 
  }
}]



// =========== //
//   Outputs   //
// =========== //
@description('The resource ID of the deployed storage account.')
output storageAccountId string = storageAccount.id

@description('The name of the deployed storage account.')
output name string = storageAccount.name

@description('The resource group of the deployed storage account.')
output resourceGroupName string = resourceGroup().name

@description('The primary blob endpoint reference if blob services are deployed.')
output primaryBlobEndpoint string = !empty(blobServices) && contains(blobServices, 'containers') ? reference('Microsoft.Storage/storageAccounts/${storageAccount.name}', '2019-04-01').primaryEndpoints.blob : ''

@description('The principal ID of the system assigned identity.')
output systemAssignedPrincipalId string = systemAssignedIdentity && contains(storageAccount.identity, 'principalId') ? storageAccount.identity.principalId : ''

@description('The location the resource was deployed into.')
output location string = storageAccount.location

@description('The primary blob endpoint reference if blob services are deployed.')
output primaryStaticWebsiteEndpoint string = reference('Microsoft.Storage/storageAccounts/${storageAccount.name}', '2019-04-01').primaryEndpoints.web
