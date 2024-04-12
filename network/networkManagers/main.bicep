param parLocation string = resourceGroup().location
param parLock lockType
param parVirtualNetworks array
param parNetworkManagerScopeAccesses networkManagerScopeAccessesType
param parNetworkManagerScopes networkManagerScopesType

@description('Create unique suffix for module deployments.')
var varUniqueSuffix = uniqueString(deployment().name)

var varVirtualNetworks = [for virtualNetwork in parVirtualNetworks: {
  name: virtualNetwork.name
  resourceId: resourceId(virtualNetwork.subscriptionId, virtualNetwork.resourceGroup, 'Microsoft.Network/virtualNetworks', virtualNetwork.name)
}]

module resNetworkManager 'br/public:avm/res/network/network-manager:0.1.0' = {
  name: 'vnm-${varUniqueSuffix}'
  params: {
    name: 'we-vnm-01'
    enableTelemetry: false
    location: parLocation
    lock: parLock
    networkGroups: [
      {
        description: 'Network group for all spoke networks'
        name: 'allSpokes'
        staticMembers: varVirtualNetworks
      }
    ]
    networkManagerScopeAccesses: parNetworkManagerScopeAccesses
    networkManagerScopes: parNetworkManagerScopes
  }
}

// =============== //
//   Definitions   //
// =============== //

type lockType = {
  @description('Optional. Specify the name of lock.')
  name: string?

  @description('Optional. Specify the type of lock.')
  kind: ('CanNotDelete' | 'ReadOnly' | 'None')?
}

@description('Defines the access scopes that Virtual Network Manager can manage.')
type networkManagerScopeAccessesType = ('Connectivity' | 'SecurityAdmin')[]

@description('Defines the scopes that Virtual Network Manager can manage.')
type networkManagerScopesType = {
  managementGroups: string[]
  subscriptions: string[]
}
