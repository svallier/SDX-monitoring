/*
------------------------
Parameters
------------------------
*/
param environment string
param resourceGroupName string
param logAnalyticsWorkspaceName string
param keyVaultName string
param storageAccountName string
param appServicePlanName string
param functionAppName string
param resourceGroupvNetName string
param vNetName string
param subnetName string
param natGatewayName string
param anomaliesDatasetId string
param complianceDatasetId string
param anomaliesReportId string
param complianceReportId string



/*
------------------------
Variables
------------------------
*/
var storageAccountId = resourceId('Microsoft.Storage/storageAccounts', storageAccountName)



/*
------------------------
Deployment
------------------------
*/

// Virtual Network
resource vNet 'Microsoft.Network/virtualNetworks@2020-11-01' existing = {
  scope: resourceGroup(resourceGroupvNetName)
  name: vNetName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' existing = {
  name: subnetName
  parent: vNet
}

// Log Analytics Workspace
module logAnalyticsWorkspace 'Modules/Microsoft.OperationalInsights/workspaces/deploy.bicep' = {
  name: '${uniqueString(deployment().name)}-LAW'
  params: {
    name: logAnalyticsWorkspaceName
    dataRetention: 30
  }
}



//KeyVault
module keyvault 'Modules/Microsoft.KeyVault/deploy.bicep' = {
  dependsOn: [
    storageAccount
  ]
  name: '${uniqueString(deployment().name)}-AKV'
  params: {
    publicAccess: false
    name: keyVaultName
    privateEndpointIntegration: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
      // virtualNetworkRules: [
      //   {
      //     id: subnetAppgw.id
      //   }
      // ]
    }
  }
}


module keyVaultAccessPolicies 'Modules/Microsoft.KeyVault/accessPolicies/deploy.bicep' = {
  name: '${uniqueString(deployment().name)}-AKV-AccessPolicies'
  scope: resourceGroup(resourceGroupName)
  dependsOn: [
    keyvault
    functionApp
  ]
  params: {
    keyVaultName: keyVaultName
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: functionApp.outputs.systemAssignedPrincipalId
        permissions: {
          keys: ['get', 'list']
          secrets: ['get', 'list']
        }
      }
    ]
  }
}



// Storage
module storageAccount 'Modules/Microsoft.Storage/storageAccounts/deploy.bicep' = {
  name:  '${uniqueString(deployment().name)}-SA'
  params: {
    name: storageAccountName
    privateEndpointIntegration: true
    services: ['blob']
    storageAccountSku : 'Standard_LRS'
    isRestrictedDataClassification : false
    publicNetworkAccess: true
  }
}

module storageAccountContainerCactusRaw 'Modules/Microsoft.Storage/storageAccounts/blobServices/containers/deploy.bicep' = {
  name: '${uniqueString(deployment().name)}-SA-RAW'
  dependsOn: [
    storageAccount
  ]
  params: {
    name: 'cactus-raw'
    storageAccountName: storageAccountName
    publicAccess: 'None'
  }
}

module storageAccountContainerCactusAnalysed 'Modules/Microsoft.Storage/storageAccounts/blobServices/containers/deploy.bicep' = {
  name: '${uniqueString(deployment().name)}-SA-analysed'
  dependsOn: [
    storageAccount
  ]
  params: {
    name: 'cactus-analysed'
    storageAccountName: storageAccountName
    publicAccess: 'None'
  }
}

module storageAccountContainerReports 'Modules/Microsoft.Storage/storageAccounts/blobServices/containers/deploy.bicep' = {
  name: '${uniqueString(deployment().name)}-SA-repors'
  dependsOn: [
    storageAccount
  ]
  params: {
    name: 'reports'
    storageAccountName: storageAccountName
    publicAccess: 'None'
  }
}



// App Service Plan
module appServicePlan 'Modules/Microsoft.Web/serverfarms/deploy.bicep' = {
  name: '${uniqueString(deployment().name)}-ASP'
  dependsOn: [
    storageAccount
  ]
  params: {
    name: appServicePlanName
    sku: {
      name: 'P2V2'
      tier: 'PremiumV2'
      size: 'P2V2'
      family: 'Pv2'
      capacity: 2
    }
  }
}



// NAT Gateway
module natGateway 'Modules/Microsoft.Network/natGateways/deploy.bicep' = {
  name: '${uniqueString(deployment().name)}-NATGW'
  params: {
    name: natGatewayName
    natGatewayPublicIpAddress: true
  }
}



// function app
module functionApp 'Modules/Microsoft.Web/sites/deploy.bicep' = {
  name: '${uniqueString(deployment().name)}-FA'
  dependsOn: [
    logAnalyticsWorkspace
    appServicePlan
    storageAccountContainerCactusRaw
    storageAccountContainerCactusAnalysed
    storageAccountContainerReports
    keyvault
  ]
  params: {
    privateEndpointIntegration: false
    kind: 'functionapp' 
    name: functionAppName
    serverFarmResourceId: appServicePlan.outputs.resourceId
    virtualNetworkSubnetId: subnet.id
    systemAssignedIdentity: true

    siteConfig: {
      alwaysOn: true
      cors: {
        allowedOrigins: [
          'https://portal.azure.com'
        ]
        supportCredentials: true
      }
      ftpsState: 'Disabled'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${listKeys(storageAccountId, '2019-06-01').keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'powershell'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME_VERSION'
          value: '7.2'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '0'
        }
        {
          name: 'WEBSITE_ENABLE_SYNC_UPDATE_SITE'
          value: true
        }
        {
          name: 'environment'
          value: environment
        }
        {
          name: 'storageAccountName'
          value: storageAccountName
        }
        {
          name: 'keyVaultName'
          value: keyVaultName
        }
        {
          name: 'anomaliesDatasetId'
          value: anomaliesDatasetId
        }
        {
          name: 'complianceDatasetId'
          value: complianceDatasetId
        }
        {
          name: 'anomaliesReportId'
          value: anomaliesReportId
        }
        {
          name: 'complianceReportId'
          value: complianceReportId
        }
      ]
    }
  }  
}
