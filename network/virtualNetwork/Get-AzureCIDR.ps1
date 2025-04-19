function Get-VirtualNetworkAddressSpace {
    param (
        [Parameter(Mandatory = $true,
            HelpMessage = "Specifies the CIDR notation to check for free IP ranges.")]
        [ValidatePattern('^(\d{1,3}\.){3}\d{1,3}/\d{1,2}$', 
            ErrorMessage = "Value must be in CIDR notation (e.g., '192.168.1.0/24').")]
        [string]$CIDR,
        
        [Parameter(Mandatory = $false,
            HelpMessage = "Specifies the parent management group scope to search in.")]
        [string]$ParentScopeId = "6c84a54c-4dfb-40c6-bb8b-ebb0dc3bbbd0"
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