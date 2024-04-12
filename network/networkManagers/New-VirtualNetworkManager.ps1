


# Verify if the 'Az.Network' module is installed.
$azNetworkModule = 'Az.Network'
If (Get-InstalledModule -Name $azNetworkModule -MinimumVersion '5.3.0') {
    Import-Module -Name $azNetworkModule -Force
}
Else {
    Install-Module -Name $azNetworkModule -Force
}

# Create a new resource group.
$resourceGroupName = 'networkManager'