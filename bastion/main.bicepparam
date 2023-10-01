using 'main.bicep'

// Parameters specific to resource names
param bastionName = 'bpdev-bas-01'
param resourceGroupName = 'bpdev-rg-01'
param virtualNetworkName = 'bpdev-vnet-01'

// Location of the deployed resources
param location = 'westeurope'

// Parameters specific for Azure Virtual Network
param addressPrefixes = [
  '192.168.2.0/24'
]
param publicIPName = 'bpdev-pip-01'
param subnets = [
  {
    name: 'AzureBastionSubnet'
    addressPrefix: '192.168.2.0/26'
  }
]
