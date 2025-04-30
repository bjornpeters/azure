# Requires the Az PowerShell module and a logged in session using Connect-AzAccount.

[string]$resourceGroupName = 'bpdev-landingzone-01'

# Create the resource group if it doesn't exist
if (-not (Get-AzResourceGroup -Name $resourceGroupName -ErrorAction 'SilentlyContinue')) {
    Write-Output "Resource group '$resourceGroupName' does not exist. Creating..."
    New-AzResourceGroup -Name $resourceGroupName -Location 'westeurope'
} else {
    Write-Output "Resource group '$resourceGroupName' already exists."
}

# Start deployment of the deployment stack.
$deploymentStackParameters = @{
    Name = 'bpdev-platform-01'
    Location = 'westeurope'
    ActionOnUnmanage = 'detachAll'
    DenySettingsMode = 'DenyWriteAndDelete'
    DenySettingsExcludedAction = @(
        'Microsoft.Network/virtualNetworks/subnets/*'
    )
    DeploymentResourceGroupName = $resourceGroupName
}

New-AzSubscriptionDeploymentStack @deploymentStackParameters -TemplateFile 'main.bicep' -DenySettingsApplyToChildScopes