@description('Required. Name of the Azure Bastion resource.')
param name string

@description('Optional. Use to have a new Public IP Address created for the NAT Gateway.')
param natGatewayPublicIpAddress bool = false

@description('Optional. Specifies the name of the Public IP used by the NAT Gateway. If it\'s not provided, a \'-pip\' suffix will be appended to the Bastion\'s name.')
param natGatewayPipName string = ''

@description('Optional. Location for all resources.')
param location string = resourceGroup().location

var natGatewayPipNameVar = (empty(natGatewayPipName) ? '${name}-pip' : natGatewayPipName)



// PUBLIC IP
// =========
resource publicIP 'Microsoft.Network/publicIPAddresses@2021-08-01' = if (natGatewayPublicIpAddress) {
  name: natGatewayPipNameVar
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPPrefix: null
    dnsSettings: null
  }
}

// NAT GATEWAY
// ===========
resource natGateway 'Microsoft.Network/natGateways@2021-08-01' = {
  name: name
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    idleTimeoutInMinutes: 5
    publicIpAddresses: [
      {
        id: publicIP.id
      }
    ]
  }
}


@description('The name of the NAT Gateway.')
output name string = natGateway.name

@description('The resource ID of the NAT Gateway.')
output resourceId string = natGateway.id

@description('The resource group the NAT Gateway was deployed into.')
output resourceGroupName string = resourceGroup().name

@description('The location the resource was deployed into.')
output location string = natGateway.location
