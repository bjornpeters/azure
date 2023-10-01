targetScope = 'subscription'

param resourceGroupName string
param virtualNetworkName string
param location string

// Parameters specific for Azure Virtual Network
param addressPrefixes array = [
  '192.168.2.0/24'
]

param subnets array = [
  {
    name: 'AzureBastionSubnet'
    addressPrefix: '192.168.2.0/26'
  }
]

// Paramaters specific for Azure Bastion
param publicIPName string = 'bpdev-pip-01'

// Deployment section
resource resourceGroup 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: resourceGroupName
  location: location
}

module virtualNetwork './modules/virtual-network.bicep' = {
  name: guid(virtualNetworkName, resourceGroup.id) 
  scope: resourceGroup
  params: {
    name: virtualNetworkName
    location: location
    addressPrefixes: addressPrefixes
    subnets: subnets
  }
}

module publicIp './modules/public-ip.bicep' = {
  name: guid(publicIPName, resourceGroup.id) 
  scope: resourceGroup
  params: {
    name: publicIPName
    location: location
  }
}
// module bastionHost './modules/bastion.bicep' = {
//   name: 'bastion'
//   scope: resourceGroup
//   params: {
//     name: 'bpdev-bast-01'
//     location: location
//     publicIpId: publicIp.outputs.resourceId
//     vNetId: 'string'
//   }
// }
