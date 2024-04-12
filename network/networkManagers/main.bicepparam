using 'main.bicep'

param parNetworkManagerScopes = {
  managementGroups: [
    '/providers/Microsoft.Management/managementGroups/bpdev-production'
  ]
  subscriptions: []
}

param parNetworkManagerScopeAccesses = [
  'SecurityAdmin'
]

param parLock = {
  kind: 'CanNotDelete'
}

param parVirtualNetworks = [
  {
    name: 'bpdev-vnet-01'
    resourceGroup: 'bpdev-resources'
    subscriptionId: '28009298-a17a-45b1-8aa2-1c7061100112'
  }
]
