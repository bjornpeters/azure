begin {
    $requiredModules = @(
        "Microsoft.Graph.Authentication",
        "Microsoft.Graph.Identity.Governance",
        "Microsoft.Graph.Identity.DirectoryManagement",
        "Microsoft.Graph.DirectoryObjects"
    )
    foreach ($module in $requiredModules) {
        # TODO: Fix error handling.
        if (-not (Get-Module -ListAvailable -Name $module)) {
            Write-Host "Module $module is not installed. Please install it before running this script."
            exit
        }
    }

    # Import and parse the configuration file.
    $inputFilePath = '/workspaces/azure/pim/entraId/inputs/tenant1.jsonc'
    Write-Host "Importing configuration from $inputFilePath..."
    if (Test-Path $inputFilePath) {
        try {
            # Read file content and remove comments (both // and /* */ style)
            $jsonContent = Get-Content -Path $inputFilePath -Raw
            # $jsonContent = $jsonContent -replace '//.*', '' # Remove single-line comments
            # $jsonContent = $jsonContent -replace '(?s)/\*.*?\*/', '' # Remove multi-line comments
            
            # Convert JSON to PowerShell object
            $configData = $jsonContent | ConvertFrom-Json
            
            # Set variables from config
            $tenantId = $configData.tenantId
            $roles = $configData.roles
            
            Write-Host "Configuration loaded successfully. Tenant ID: $tenantId"
            Write-Host "Roles to process: $($roles.Count)"
        }
        catch {
            Write-Error "Failed to parse configuration file: $_"
            exit
        }
    }
    else {
        Write-Error "Configuration file not found at path: $InputFilePath"
        exit
    }

    # Connect to Microsoft Graph with the required scopes.
    Write-Host "Connecting to Microsoft Graph..."
    Connect-MgGraph -Scopes @(
        "Directory.Read.All",
        "Group.Read.All", 
        "RoleManagement.ReadWrite.Directory",
        "RoleManagementPolicy.ReadWrite.Directory",
        "User.Read.All"
    )

}
process {

    foreach ($role in $roles) {
        Get-MgDirectoryRole -Filter "displayName eq '$role'"
    }






    # Main script execution
    try {
    
        # Connect to Microsoft Graph with the required permissions

    
        # Get the role definition
        Write-Host "Getting role definition for '$RoleDefinitionName'..."
        $roleDefinition = Get-EntraRole -RoleName $RoleDefinitionName
        Write-Host "Role '$RoleDefinitionName' found with ID: $($roleDefinition.Id)"
    
        # Get the group to assign the role to
        Write-Host "Getting group ID for '$GroupDisplayName'..."
        $group = Get-EntraGroup -GroupName $GroupDisplayName
        Write-Host "Group '$GroupDisplayName' found with ID: $($group.Id)"
    
        # If approver group is specified, get its ID
        $approverGroupId = $null
        if ($RequireApproval -and $ApproverGroupDisplayName) {
            Write-Host "Getting approver group ID for '$ApproverGroupDisplayName'..."
            $approverGroup = Get-EntraGroup -GroupName $ApproverGroupDisplayName
            $approverGroupId = $approverGroup.Id
            Write-Host "Approver group '$ApproverGroupDisplayName' found with ID: $approverGroupId"
        }
    
        # Configure Role Management Policy
        Write-Host "Configuring Role Management Policy for role '$RoleDefinitionName'..."
        Update-RoleManagementPolicy -RoleDefinitionId $roleDefinition.Id `
            -RequireJustification $RequireJustification `
            -RequireTicketInformation $RequireTicketInformation `
            -RequireMfa $RequireMfa `
            -RequireApproval $RequireApproval `
            -ApproverGroupObjectId $approverGroupId `
            -ActivationMaxDurationInHours $ActivationMaxDurationInHours
    
        # Create the PIM role assignment
        Write-Host "Creating role assignment for group '$GroupDisplayName' to role '$RoleDefinitionName'..."
        New-PimRoleAssignment -PrincipalId $group.Id `
            -RoleDefinitionId $roleDefinition.Id `
            -AssignmentType $AssignmentType `
            -DurationInDays $AssignmentScheduleDurationInDays
    
        Write-Host "PIM configuration completed successfully for role '$RoleDefinitionName' and group '$GroupDisplayName'"
    }
    catch {
        Write-Error "An error occurred: $_"
        Write-Error $_.ScriptStackTrace
    }
    finally {
        # Disconnect from Microsoft Graph
        Disconnect-MgGraph -ErrorAction SilentlyContinue
        Write-Host "Disconnected from Microsoft Graph."
    }
}
end {

}
