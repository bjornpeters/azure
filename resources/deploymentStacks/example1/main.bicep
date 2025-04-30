module modVirtualNetwork 'br/public:avm/res/network/virtual-network:0.6.1' = {
  name: 'deploy-vnet-01'
  params: {
    name: 'bpdev-landingzone-vnet-01'
    location: 'westeurope'
    addressPrefixes: [
      '192.168.1.0/24'
    ]
    subnets: []
  }
}
