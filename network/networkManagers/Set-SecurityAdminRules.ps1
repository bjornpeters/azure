# Verify if the 'Az.Network' module is installed.
$azNetworkModule = 'Az.Network'
If (Get-InstalledModule -Name $azNetworkModule -MinimumVersion '5.3.0') {
    Import-Module -Name $azNetworkModule -Force
}
Else {
    Install-Module -Name $azNetworkModule -Force
}

# Connect with Azure.
Connect-AzAccount
Set-AzContext -SubscriptionName 'mySubscription'

######################################################
### Example of creating a Virtual Network Manager. ###
######################################################

# Variables
$location = 'westeurope'

# Create a new resource group.
$resourceGroupName = 'virtualNetworkManager'
$resourceGroup = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
If ($resourceGroup) {
    Write-Host 'Resource Group already exists.'
}
Else {
    $resourceGroup = New-AzResourceGroup -Name $resourceGroupName -Location $location
}

# Create a new Virtual Network Manager scope for an array of subscriptions.
$subscriptionId = (Get-AzSubscription).Id
$subscriptionScope = @(
    "/subscriptions/$subscriptionId"
)
$scope = New-AzNetworkManagerScope -Subscription $subscriptionScope

# Create Virtual Network Manager.
$avnmParameters = @{
    Name = "vnm-$location-01"
    ResourceGroupName = $resourceGroup.ResourceGroupName
    NetworkManagerScope = $scope
    NetworkManagerScopeAccess = @(
        'SecurityAdmin'
    )
    Location = $location
}
$networkManager = New-AzNetworkManager @avnmParameters

# Create a network group to define the membership (Virtual Network members) in.
$ngParameters = @{
    Name = "vnm-$location-01-ng-01"
    ResourceGroupName = $resourceGroup.ResourceGroupName
    NetworkManagerName = $networkManager.Name
}
$networkManagerGroup = New-AzNetworkManagerGroup @ngParameters

# Get a sample virtual network and add it to the network group.
$virtualNetwork = Get-AzVirtualNetwork -ResourceGroupName 'bpdev-resources' -Name 'bpdev-we-vnet-01'
$staticMemberParameters = @{
    Name = (New-Guid).Guid
    ResourceGroupName = $resourceGroup.ResourceGroupName
    NetworkGroupName = $networkManagerGroup.Name
    NetworkManagerName = $networkManager.Name
    ResourceId = $virtualNetwork.Id
}
New-AzNetworkManagerStaticMember @staticMemberParameters

###############################################################################
### Example of creating a Security Admin configuration and rule collection. ###
###############################################################################

# Create a Security Admin configuration.
$securityConfigParameters = @{
    Name = 'SecurityConfig'
    ResourceGroupName = $resourceGroup.ResourceGroupName
    NetworkManagerName = $networkManager.Name
}
$securityConfig = New-AzNetworkManagerSecurityAdminConfiguration @securityConfigParameters

# Add the network group to the Security Admin configuration and store the group item in a variable.
$groupItem = New-AzNetworkManagerSecurityGroupItem -NetworkGroupId $networkManagerGroup.Id

# Create a new rule collection for the Security Admin configuration.
$collectionParameters = @{
    Name = 'myRuleCollection'
    ResourceGroupName = $resourceGroup.ResourceGroupName
    NetworkManager = $networkManager.Name
    ConfigName = $securityConfig.Name
    AppliesToGroup = @(
        $groupItem
    )
}
$ruleCollection = New-AzNetworkManagerSecurityAdminRuleCollection @collectionParameters

##################################################
### Example of creating a Security Admin Rule. ###
##################################################

# Set the source to any IP address.
$sourceIp = @{
    AddressPrefix = '*'
    AddressPrefixType = 'IPPrefix'
}
$sourcePrefix = New-AzNetworkManagerAddressPrefixItem @sourceIp

# Set the destination to the Internet.
$destinationIp = @{
    AddressPrefix = 'Internet'
    AddressPrefixType = 'ServiceTag'
}
$destinationPrefix = New-AzNetworkManagerAddressPrefixItem @destinationIp

$rule = @{
    Name = 'Allow-HTTPS-Outbound-Internet'
    ResourceGroupName = $resourceGroup.ResourceGroupName
    NetworkManagerName = $networkManager.Name
    SecurityAdminConfigurationName = $securityConfig.Name
    RuleCollectionName = $ruleCollection.Name
    Protocol = 'TCP'
    Access = 'Allow'
    Priority = '100'
    Direction = 'Outbound'
    SourceAddressPrefix = $sourcePrefix
    SourcePortRange = @(
        '0-65535'
    )
    DestinationAddressPrefix = $destinationPrefix
    DestinationPortRange = @(
        '443'
    )
}
$securityRule = New-AzNetworkManagerSecurityAdminRule @rule
