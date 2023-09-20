@description('Required. Name of the Azure Bastion resource.')
param name string

@description('Optional. Location for all resources.')
param location string = resourceGroup().location

@description('Required. Public IP address resource identifier.')
param publicIpId string

@description('Required. Shared services Virtual Network resource identifier.')
param vNetId string

@allowed([
  'Basic'
  'Standard'
])
@description('Optional. The SKU of this Bastion Host.')
param skuName string = 'Basic'

@description('Optional. Choose to disable or enable Copy Paste.')
param disableCopyPaste bool = false

@description('Optional. Choose to disable or enable File Copy.')
param enableFileCopy bool = true

@description('Optional. Choose to disable or enable IP Connect.')
param enableIpConnect bool = false

@description('Optional. Choose to disable or enable Kerberos authentication.')
param enableKerberos bool = false

@description('Optional. Choose to disable or enable Shareable Link.')
param enableShareableLink bool = false

@description('Optional. The scale units for the Bastion Host resource.')
param scaleUnits int = 2

@description('Optional. Tags of the resource.')
param tags object = {}

var enableTunneling = skuName == 'Standard' ? true : null

var scaleUnitsVar = skuName == 'Basic' ? 2 : scaleUnits

var ipConfigurations = [
  {
    name: 'IpConfAzureBastionSubnet'
    properties: {
      subnet: {
        id: '${vNetId}/subnets/AzureBastionSubnet' // The subnet name must be AzureBastionSubnet
      }
      publicIPAddress: {
        id: publicIpId
      }
    }
  }
]

var bastionProperties = skuName == 'Standard' ? {
  scaleUnits: scaleUnitsVar
  ipConfigurations: ipConfigurations
  enableTunneling: enableTunneling
  disableCopyPaste: disableCopyPaste
  enableFileCopy: enableFileCopy
  enableIpConnect: enableIpConnect
  enableKerberos: enableKerberos
  enableShareableLink: enableShareableLink
} : {
  scaleUnits: scaleUnitsVar
  ipConfigurations: ipConfigurations
  enableKerberos: enableKerberos
}

resource azureBastion 'Microsoft.Network/bastionHosts@2022-11-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  properties: bastionProperties
}

@description('The resource group the Azure Bastion was deployed into.')
output resourceGroupName string = resourceGroup().name

@description('The name the Azure Bastion.')
output name string = azureBastion.name

@description('The resource ID the Azure Bastion.')
output resourceId string = azureBastion.id

@description('The location the resource was deployed into.')
output location string = azureBastion.location

@description('The Public IPconfiguration object for the AzureBastionSubnet.')
output ipConfAzureBastionSubnet object = azureBastion.properties.ipConfigurations[0]
