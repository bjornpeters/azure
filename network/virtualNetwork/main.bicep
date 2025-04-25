@description('The Azure region to deploy to')
param parLocation string = resourceGroup().location

@description('The name of the Virtual Network')
param parVirtualNetworkName string

@description('The name of the Network Security Group')
param parNetworkSecurityGroupName string = ''

@description('The address prefixes of the Virtual Network')
param parVirtualNetworkAddressPrefixes array

@description('Optional tags for resources')
param parTags object = {}

@description('Subnets configuration for the Virtual Network')
param parSubnets array = []

@description('Network Security Group rules to apply')
param parNetworkSecurityGroupRules array = []

var varNsgName = empty(parNetworkSecurityGroupName) ? '${parVirtualNetworkName}-nsg' : parNetworkSecurityGroupName

// Deploy Network Security Group if subnets are defined
module modNetworkSecurityGroup 'br/public:avm/res/network/network-security-group:0.5.1' = if (!empty(parSubnets)) {
  name: 'deploy-${varNsgName}'
  params: {
    name: varNsgName
    location: parLocation
    tags: parTags
    securityRules: parNetworkSecurityGroupRules
  }
}

// Deploy Virtual Network
module modVirtualNetwork 'br/public:avm/res/network/virtual-network:0.6.1' = {
  name: 'deploy-${parVirtualNetworkName}'
  params: {
    name: parVirtualNetworkName
    location: parLocation
    tags: parTags
    addressPrefixes: parVirtualNetworkAddressPrefixes
    subnets: []
  }
}

// Output the Virtual Network and NSG IDs
output virtualNetworkId string = modVirtualNetwork.outputs.resourceId
output virtualNetworkName string = modVirtualNetwork.outputs.name
output networkSecurityGroupId string = !empty(parSubnets) ? modNetworkSecurityGroup.outputs.resourceId : ''
output networkSecurityGroupName string = !empty(parSubnets) ? modNetworkSecurityGroup.outputs.name : ''
