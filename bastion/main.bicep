targetScope = 'subscription'

// Parameters specific to the resource names
@description('Name of the Azure Bastion resource.')
param bastionName string

@description('Name of the resource group.')
param resourceGroupName string

@description('Name of the Azure Virtual Network resource.')
param virtualNetworkName string

// Location of the deployed resources
@description('Name of the Azure region.')
param location string

// Parameters specific to the Azure Virtual Network
@description('Address prefixes of the Azure Virtual Network.')
param addressPrefixes array

// Paramaters specific to the Azure Bastion
@description('Name of the Public IP address resource.')
param publicIPName string

@description('Subnets of the Azure Virtual Network.')
param subnets array

// Deployment of all required resources
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

module bastionHost './modules/bastion.bicep' = {
  name: guid(bastionName, resourceGroup.id) 
  scope: resourceGroup
  params: {
    name: bastionName
    location: location
    enableIpConnect: true
    publicIpId: publicIp.outputs.resourceId
    skuName: 'Standard'
    vNetId: virtualNetwork.outputs.resourceId
  }
}
