function Get-EntraDirectoryRole {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$RoleName
    )
    
    $role = Get-MgDirectoryRole -Filter "displayName eq '$RoleName'"
    
    # TODO: Decide if we want to throw an error or simply return $null.
    if (-not $role) {
        throw "Role '$RoleName' not found in Entra ID."
    }
    
    return $role
}