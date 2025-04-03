@description('The location where the DevCenter resource will be deployed.')
param parLocation string = resourceGroup().location

@description('The name of the DevCenter resource.')
@minLength(3)
@maxLength(26)
param parDevCenterName string

@description('The display name of the DevCenter.')
param parDevCenterDisplayName string = parDevCenterName

@description('Enable or disable Azure Monitor agent installation for DevBox provisioning.')
@allowed([
  'Enabled'
  'Disabled'
])
param parInstallAzureMonitorAgent string = 'Enabled'

@description('Enable or disable Microsoft Hosted Network.')
@allowed([
  'Enabled'
  'Disabled'
])
param parMicrosoftHostedNetworkEnabled string = 'Disabled'

@description('Enable or disable catalog item synchronization.')
@allowed([
  'Enabled'
  'Disabled'
])
param parCatalogItemSyncEnabled string = 'Enabled'

resource devCenter 'Microsoft.DevCenter/devcenters@2024-10-01-preview' = {
  location: parLocation
  name: parDevCenterName
  properties: {
    devBoxProvisioningSettings: {
      installAzureMonitorAgentEnableStatus: parInstallAzureMonitorAgent
    }
    displayName: parDevCenterDisplayName
    networkSettings: {
      microsoftHostedNetworkEnableStatus: parMicrosoftHostedNetworkEnabled
    }
    projectCatalogSettings: {
      catalogItemSyncEnableStatus: parCatalogItemSyncEnabled
    }
  }
}
