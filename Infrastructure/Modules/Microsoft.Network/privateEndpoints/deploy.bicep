// ============ //
//  Parameters  //
// ============ //
@description('Required. Name of the private endpoint resource to create.')
param name string

@description('Required. Resource ID of the resource that needs to be connected to the network.')
param serviceResourceId string

@description('Required. Subtype(s) of the connection to be created. The allowed values depend on the type serviceResourceId refers to.')
param groupIds array

@description('Required. Location for the Resource.')
param location string = resourceGroup().location



// ============ //
//  Variables   //
// ============ //
var currentSub = subscription().displayName

var subscriptionName = {
 'SDX DEV/TEST': '/subscriptions/c0978b9d-b809-45f4-aa76-391ceb2cfdba/resourceGroups/IST-GLB-IENO-COMMON-DEV-RG01/providers/Microsoft.Network/virtualNetworks/IST-GLB-IENO-PVTPNT-DEV-VN01/subnets/IST-GLB-IENO-PVTPNT-DEV-SN01'
 'SDX INT/UAT': '/subscriptions/daf86ec1-725c-493f-bf09-a1f129b8588a/resourceGroups/IST-GLB-IENO-COMMON-UAT-RG01/providers/Microsoft.Network/virtualNetworks/IST-GLB-IENO-PVTPNT-UAT-VN01/subnets/IST-GLB-IENO-PVTPNT-UAT-SN01'
 'SDX STA/PRD': '/subscriptions/cf25f2a1-4d40-45af-bb81-87ec46112b3e/resourceGroups/IST-GLB-IENO-COMMON-PRD-RG01/providers/Microsoft.Network/virtualNetworks/IST-GLB-IENO-PVTPNT-PRD-VN01/subnets/IST-GLB-IENO-PVTPNT-PRD-SN01'
}



// =========== //
// Deployments //
// =========== //
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2022-05-01' = {
  name: name
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: name
        properties: {
          privateLinkServiceId: serviceResourceId
          groupIds: groupIds
        }
      }
    ]
    subnet: {
      id: '${subscriptionName[currentSub]}'
    }
  }
}



// =========== //
//   Outputs   //
// =========== //
@description('The resource group the private endpoint was deployed into.')
output resourceGroupName string = resourceGroup().name

@description('The resource ID of the private endpoint.')
output resourceId string = privateEndpoint.id

@description('The name of the private endpoint.')
output name string = privateEndpoint.name

@description('The location the resource was deployed into.')
output location string = privateEndpoint.location
