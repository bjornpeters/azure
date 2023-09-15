@description('Required. Name of the Azure Bastion resource.')
param name string

@description('Optional. Location for all resources.')
param location string = resourceGroup().location

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

@description('Optional. Choose to disable or enable tunneling.')
param enableTunneling bool = false

@description('Optional. The scale units for the Bastion Host resource.')
param scaleUnits int = 2

resource bastionHost 'Microsoft.Network/bastionHosts@2023-04-01' = {
  name: name
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    disableCopyPaste: disableCopyPaste
    dnsName: 'string'
    enableFileCopy: enableFileCopy
    enableIpConnect: enableIpConnect
    enableKerberos: enableKerberos
    enableShareableLink: enableShareableLink
    enableTunneling: enableTunneling
    ipConfigurations: [
      {
        id: 'string'
        name: 'string'
        properties: {
          privateIPAllocationMethod: 'string'
          publicIPAddress: {
            id: 'string'
          }
          subnet: {
            id: 'string'
          }
        }
      }
    ]
    scaleUnits: scaleUnits
  }
}
