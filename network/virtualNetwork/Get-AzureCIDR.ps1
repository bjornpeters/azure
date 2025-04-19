<#
.SYNOPSIS
    Searches for virtual networks in Azure that have the specified CIDR address space.

.DESCRIPTION
    This function checks if a specific CIDR address range is already in use by any virtual network
    across multiple Azure subscriptions within a specified management group hierarchy. It uses Azure Resource Graph
    to perform the search efficiently across the entire management group scope.

.PARAMETER CIDR
    The CIDR notation (e.g., '10.0.0.0/16') to check for usage in existing virtual networks.
    The format must be valid IPv4 CIDR notation.

.PARAMETER ParentScopeId
    The ID of the parent management group to scope the search to. The function will search all
    subscriptions under this management group hierarchy.

.EXAMPLE
    Get-VirtualNetworkAddressSpace -CIDR '10.0.0.0/16'
    
    Checks if the CIDR 10.0.0.0/16 is being used by any virtual network in the default management group scope.

.EXAMPLE
    Get-VirtualNetworkAddressSpace -CIDR '192.168.0.0/24' -ParentScopeId 'abc12345-1234-1234-1234-123456789012'
    
    Checks if the CIDR 192.168.0.0/24 is being used by any virtual network under the specified management group.

.OUTPUTS
    Returns a single virtual network object that match the specified CIDR.
    If no matches are found, returns nothing (indicating the CIDR is available).

.NOTES
    Requires the Az.ResourceGraph module to be installed.
    The function uses the ipv4_is_match KQL function to check for CIDR overlaps.
#>
function Get-VirtualNetworkAddressSpace {
    param (
        [Parameter(Mandatory = $true,
            HelpMessage = "Specifies the CIDR notation to check for free IP ranges.")]
        [ValidatePattern('^(\d{1,3}\.){3}\d{1,3}/\d{1,2}$', 
            ErrorMessage = "Value must be in CIDR notation (e.g., '192.168.1.0/24').")]
        [string]$CIDR,
        
        [Parameter(Mandatory = $false,
            HelpMessage = "Specifies the parent management group scope to search in.")]
        [string]$ParentScopeId = "357cc3a1-fb43-40f9-a4ab-2706991b77c6"
    )
    begin {
        # Prepare the KQL query to search virtual networks under a management group scope and combine subscription info.
        $kql = "resources
        | where type == 'microsoft.network/virtualnetworks'
        | join kind=inner ( resourcecontainers
        | where type == 'microsoft.resources/subscriptions'
        | where properties['managementGroupAncestorsChain'] has '$ParentScopeId'
        | project subscriptionName = name, subscriptionId) on subscriptionId
        | mv-expand addressPrefix = properties.addressSpace.addressPrefixes
        | extend addressSpace = tostring(addressPrefix)
        | extend result = ipv4_is_match(addressSpace, '$CIDR')
        | where result == 1
        | project subscriptionName, vnetName = name, addressSpace"
    }
    process {
        # Use the search cmdlet in combination with the query to look for a vnet with the given CIDR.
        try {
            [object]$virtualNetwork = Search-AzGraph -Query $kql
        }
        catch {
            throw $_
        }
    }
    end {
        # Returns a virtual network when CIDR is in the address space, returns nothing when CIDR is available.
        return $virtualNetwork
    }
}
