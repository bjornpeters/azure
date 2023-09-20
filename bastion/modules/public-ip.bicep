@description('Required. The name of the Public IP Address.')
param name string

@description('Optional. Resource ID of the Public IP Prefix object. This is only needed if you want your Public IPs created in a PIP Prefix.')
param publicIPPrefixResourceId string = ''

@description('Optional. The public IP address allocation method.')
@allowed([
  'Dynamic'
  'Static'
])
param publicIPAllocationMethod string = 'Dynamic'

@description('Optional. Name of a public IP address SKU.')
@allowed([
  'Basic'
  'Standard'
])
param skuName string = 'Basic'

@description('Optional. Tier of a public IP address SKU.')
@allowed([
  'Global'
  'Regional'
])
param skuTier string = 'Regional'

@description('Optional. A list of availability zones denoting the IP allocated for the resource needs to come from.')
param zones array = []

@description('Optional. IP address version.')
@allowed([
  'IPv4'
  'IPv6'
])
param publicIPAddressVersion string = 'IPv4'

@description('Optional. The domain name label. The concatenation of the domain name label and the regionalized DNS zone make up the fully qualified domain name associated with the public IP address. If a domain name label is specified, an A DNS record is created for the public IP in the Microsoft Azure DNS system.')
param domainNameLabel string = ''

@allowed([
  ''
  'NoReuse'
  'ResourceGroupReuse'
  'SubscriptionReuse'
  'TenantReuse'
])
@description('Optional. The domain name label scope. If a domain name label and a domain name label scope are specified, an A DNS record is created for the public IP in the Microsoft Azure DNS system with a hashed value includes in FQDN.')
param domainNameLabelScope string = ''

@description('Optional. The Fully Qualified Domain Name of the A DNS record associated with the public IP. This is the concatenation of the domainNameLabel and the regionalized DNS zone.')
param fqdn string = ''

@description('Optional. The reverse FQDN. A user-visible, fully qualified domain name that resolves to this public IP address. If the reverseFqdn is specified, then a PTR DNS record is created pointing from the IP address in the in-addr.arpa domain to the reverse FQDN.')
param reverseFqdn string = ''

@description('Optional. Location for all resources.')
param location string = resourceGroup().location

@description('Optional. Tags of the resource.')
param tags object = {}

resource publicIpAddress 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuTier
  }
  zones: zones
  properties: {
    dnsSettings: !empty(domainNameLabel) ? {
      domainNameLabel: domainNameLabel
      domainNameLabelScope: domainNameLabelScope
      fqdn: fqdn
      reverseFqdn: reverseFqdn
    } : null
    publicIPAddressVersion: publicIPAddressVersion
    publicIPAllocationMethod: publicIPAllocationMethod
    publicIPPrefix: !empty(publicIPPrefixResourceId) ? {
      id: publicIPPrefixResourceId
    } : null
    idleTimeoutInMinutes: 4
    ipTags: []
  }
}

@description('The resource group the public IP address was deployed into.')
output resourceGroupName string = resourceGroup().name

@description('The name of the public IP address.')
output name string = publicIpAddress.name

@description('The resource ID of the public IP address.')
output resourceId string = publicIpAddress.id

@description('The public IP address of the public IP address resource.')
output ipAddress string = contains(publicIpAddress.properties, 'ipAddress') ? publicIpAddress.properties.ipAddress : ''

@description('The location the resource was deployed into.')
output location string = publicIpAddress.location
