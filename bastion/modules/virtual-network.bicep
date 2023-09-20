@description('Required. The Virtual Network (vNet) Name.')
param name string

@description('Optional. Location for all resources.')
param location string = resourceGroup().location

@description('Required. An Array of 1 or more IP Address Prefixes for the Virtual Network.')
param addressPrefixes array

@description('Optional. An Array of subnets to deploy to the Virtual Network.')
param subnets array = []

@description('Optional. DNS Servers associated to the Virtual Network.')
param dnsServers array = []

@description('Optional. Resource ID of the DDoS protection plan to assign the VNET to. If it\'s left blank, DDoS protection will not be configured. If it\'s provided, the VNET created by this template will be attached to the referenced DDoS protection plan. The DDoS protection plan can exist in the same or in a different subscription.')
param ddosProtectionPlanId string = ''

@description('Optional. Indicates if encryption is enabled on virtual network and if VM without encryption is allowed in encrypted VNet. Requires the EnableVNetEncryption feature to be registered for the subscription and a supported region to use this property.')
param vnetEncryption bool = false

@allowed([
  'AllowUnencrypted'
  'DropUnencrypted'
])
@description('Optional. If the encrypted VNet allows VM that does not support encryption. Can only be used when vnetEncryption is enabled.')
param vnetEncryptionEnforcement string = 'AllowUnencrypted'

@maxValue(30)
@description('Optional. The flow timeout in minutes for the Virtual Network, which is used to enable connection tracking for intra-VM flows. Possible values are between 4 and 30 minutes. Default value 0 will set the property to null.')
param flowTimeoutInMinutes int = 0

@description('Optional. Tags of the resource.')
param tags object = {}

var dnsServersVar = {
  dnsServers: array(dnsServers)
}

var ddosProtectionPlan = {
  id: ddosProtectionPlanId
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: addressPrefixes
    }
    ddosProtectionPlan: !empty(ddosProtectionPlanId) ? ddosProtectionPlan : null
    dhcpOptions: !empty(dnsServers) ? dnsServersVar : null
    enableDdosProtection: !empty(ddosProtectionPlanId)
    encryption: vnetEncryption == true ? {
      enabled: vnetEncryption
      enforcement: vnetEncryptionEnforcement
    } : null
    flowTimeoutInMinutes: flowTimeoutInMinutes != 0 ? flowTimeoutInMinutes : null
    subnets: [for subnet in subnets: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.addressPrefix
        addressPrefixes: contains(subnet, 'addressPrefixes') ? subnet.addressPrefixes : []
        applicationGatewayIPConfigurations: contains(subnet, 'applicationGatewayIPConfigurations') ? subnet.applicationGatewayIPConfigurations : []
        delegations: contains(subnet, 'delegations') ? subnet.delegations : []
        ipAllocations: contains(subnet, 'ipAllocations') ? subnet.ipAllocations : []
        natGateway: contains(subnet, 'natGatewayId') ? {
          id: subnet.natGatewayId
        } : null
        networkSecurityGroup: contains(subnet, 'networkSecurityGroupId') ? {
          id: subnet.networkSecurityGroupId
        } : null
        privateEndpointNetworkPolicies: contains(subnet, 'privateEndpointNetworkPolicies') ? subnet.privateEndpointNetworkPolicies : null
        privateLinkServiceNetworkPolicies: contains(subnet, 'privateLinkServiceNetworkPolicies') ? subnet.privateLinkServiceNetworkPolicies : null
        routeTable: contains(subnet, 'routeTableId') ? {
          id: subnet.routeTableId
        } : null
        serviceEndpoints: contains(subnet, 'serviceEndpoints') ? subnet.serviceEndpoints : []
        serviceEndpointPolicies: contains(subnet, 'serviceEndpointPolicies') ? subnet.serviceEndpointPolicies : []
      }
    }]
  }
}

@description('The resource group the virtual network was deployed into.')
output resourceGroupName string = resourceGroup().name

@description('The resource ID of the virtual network.')
output resourceId string = virtualNetwork.id

@description('The name of the virtual network.')
output name string = virtualNetwork.name

@description('The names of the deployed subnets.')
output subnetNames array = [for subnet in subnets: subnet.name]

@description('The resource IDs of the deployed subnets.')
output subnetResourceIds array = [for subnet in subnets: az.resourceId('Microsoft.Network/virtualNetworks/subnets', name, subnet.name)]

@description('The location the resource was deployed into.')
output location string = virtualNetwork.location
