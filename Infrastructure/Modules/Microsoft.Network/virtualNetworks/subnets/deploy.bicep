@description('Optional. The Name of the subnet resource.')
param name string

@description('Conditional. The name of the parent virtual network. Required if the template is used in a standalone deployment.')
param virtualNetworkName string

@description('Optional. The address prefix for the subnet.')
param addressPrefix string

@description('Optional. The resource ID of the network security group to assign to the subnet.')
param networkSecurityGroupId string = ''

@description('Optional. The resource ID of the route table to assign to the subnet.')
param routeTableId string = ''

@description('Optional. The service endpoints to enable on the subnet.')
param serviceEndpoints array = []

@description('Optional. The delegations to enable on the subnet.')
param delegations array = []

@description('Optional. The resource ID of the NAT Gateway to use for the subnet.')
param natGatewayId string = ''

@description('Optional. enable or disable apply network policies on private endpoint in the subnet.')
@allowed([
  'Disabled'
  'Enabled'
  ''
])
param privateEndpointNetworkPolicies string = ''

@description('Optional. enable or disable apply network policies on private link service in the subnet.')
@allowed([
  'Disabled'
  'Enabled'
  ''
])
param privateLinkServiceNetworkPolicies string = ''

@description('Optional. List of address prefixes for the subnet.')
param addressPrefixes array = []

@description('Optional. Application gateway IP configurations of virtual network resource.')
param applicationGatewayIpConfigurations array = []

@description('Optional. Array of IpAllocation which reference this subnet.')
param ipAllocations array = []

@description('Optional. An array of service endpoint policies.')
param serviceEndpointPolicies array = []

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2021-08-01' existing = {
  name: virtualNetworkName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2021-08-01' = {
  name: name
  parent: virtualNetwork
  properties: {
    addressPrefix: addressPrefix
    networkSecurityGroup: !empty(networkSecurityGroupId) ? {
      id: networkSecurityGroupId
    } : null
    routeTable: !empty(routeTableId) ? {
      id: routeTableId
    } : null
    natGateway: !empty(natGatewayId) ? {
      id: natGatewayId
    } : null
    serviceEndpoints: serviceEndpoints
    delegations: delegations
    privateEndpointNetworkPolicies: !empty(privateEndpointNetworkPolicies) ? any(privateEndpointNetworkPolicies) : null
    privateLinkServiceNetworkPolicies: !empty(privateLinkServiceNetworkPolicies) ? any(privateLinkServiceNetworkPolicies) : null
    addressPrefixes: addressPrefixes
    applicationGatewayIpConfigurations: applicationGatewayIpConfigurations
    ipAllocations: ipAllocations
    serviceEndpointPolicies: serviceEndpointPolicies
  }
}


@description('The resource group the virtual network peering was deployed into.')
output resourceGroupName string = resourceGroup().name

@description('The name of the virtual network peering.')
output name string = subnet.name

@description('The resource ID of the virtual network peering.')
output resourceId string = subnet.id

@description('The address prefix for the subnet.')
output subnetAddressPrefix string = subnet.properties.addressPrefix

@description('List of address prefixes for the subnet.')
output subnetAddressPrefixes array = !empty(addressPrefixes) ? subnet.properties.addressPrefixes : []
