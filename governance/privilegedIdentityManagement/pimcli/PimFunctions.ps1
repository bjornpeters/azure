<#
.SYNOPSIS
    Functions for Azure Privileged Identity Management (PIM) operations.
.DESCRIPTION
    This module provides functions to interact with Azure Privileged Identity Management,
    including authentication and approval of PIM requests.
.NOTES
    Version:        0.0.1
    Author:         Bjorn Peters
    Creation Date:  2025-04-30
#>

# Authentication Functions
function Connect-AzPim {
    [CmdletBinding()]
    param()
    
    try {
        Write-Host "Checking Azure connection status..." -ForegroundColor Cyan
        $context = Get-AzContext
        
        if (-not $context) {
            Write-Host "Not authenticated to Azure. Initiating login..." -ForegroundColor Yellow
            Connect-AzAccount -ErrorAction Stop | Out-Null
            $context = Get-AzContext
            Write-Host "Successfully logged in to Azure." -ForegroundColor Green

            # Set access token for Azure.
            $token = (Get-AzAccessToken -AsSecureString).Token
        }
        else {
            Write-Host "Already authenticated as $($context.Account)" -ForegroundColor Green
        }
        
        # Make sure we have a valid account name
        $accountName = if ($context.Account.Id) { 
            $context.Account.Id 
        } elseif ($context.Account) {
            $context.Account.ToString()
        } else {
            "Unknown Account"
        }
        
        # Verify the user has permissions to use PIM
        Write-Host "Verifying PIM access..." -ForegroundColor Cyan
        
        # Get role assignments to verify PIM access
        try {
            # Use the current user's context instead of relying on SignInName
            $roles = Get-AzRoleAssignment -ErrorAction Stop
            $hasPimAccess = $roles | Where-Object { 
                $_.RoleDefinitionName -like "*Administrator*" -or
                $_.RoleDefinitionName -like "*Owner*" -or
                $_.RoleDefinitionName -like "*Contributor*" -or
                $_.RoleDefinitionName -like "*Privileged*" 
            }
            
            if ($hasPimAccess) {
                Write-Host "PIM access verified." -ForegroundColor Green
                return @{
                    Success = $true
                    Context = $context
                    Account = $accountName
                    PimAccess = $true
                }
            }
            else {
                Write-Warning "You may not have sufficient permissions to manage PIM requests."
                return @{
                    Success = $true
                    Context = $context
                    Account = $accountName
                    PimAccess = $false
                }
            }
        }
        catch {
            Write-Warning "Could not verify PIM access: $_"
            return @{
                Success = $true
                Context = $context
                Account = $accountName
                PimAccess = $false
            }
        }
    }
    catch {
        Write-Error "Authentication failed: $_"
        return @{
            Success = $false
            ErrorMessage = $_.Exception.Message
            Account = "Not Authenticated"
        }
    }
}

function Disconnect-AzPim {
    <#
    .SYNOPSIS
        Disconnects from Azure.
    .DESCRIPTION
        Disconnects the current Azure session.
    .EXAMPLE
        Disconnect-AzPim
    #>
    [CmdletBinding()]
    param()
    
    try {
        Disconnect-AzAccount -ErrorAction Stop
        Write-Host "Successfully disconnected from Azure." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to disconnect: $_"
        return $false
    }
}

# TODO: Add some verbose logging within this cmdlet. Change cmdlet to singular.
function Get-AzPimRequests {
    [CmdletBinding()]
    param()
    try {        
        [string]$pendingRequestsUri = 'https://management.azure.com/providers/Microsoft.Authorization/roleAssignmentScheduleRequests?api-version=2022-04-01-preview&$filter=asApprover()'

        # Set parameters for the PIM API request.
        [hashtable]$pendingRequestParams = @{
            Method = 'GET'
            Uri =  $pendingRequestsUri
            Authentication = 'Bearer'
            Token = (Get-AzAccessToken -AsSecureString).Token
        }
        [object]$pendingRequests = (Invoke-RestMethod @pendingRequestParams).value
        
        if ($pendingRequests -and $pendingRequests.Count -gt 0) {
            return [array]$pendingRequests
        }
        else {
            return [array]@()
        }
    }
    catch {
        Write-Error "Failed to retrieve PIM requests: $_"
        return [array]@()
    }
}

function New-AzPimDecisionRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true,
            HelpMessage = 'Unique identifier for the approval.')]
        [string]$ApprovalId,
        
        [Parameter(Mandatory = $true,
            HelpMessage = 'Justification for the approval.')]
        [string]$Reason,

        [Parameter(Mandatory = $true,
            HelpMessage = 'Justification for the approval.')]
        [ValidateSet('Approve', 'Deny', 'NotReviewed')]
        [string]$ReviewResult
    )
    begin {
        # Set the basic url for the Privileged Identity Management API and the API version.
        [string]$baseUri = 'https://management.azure.com'
        [string]$apiVersion = '2021-01-01-preview'

        # Retrieve the Azure access token to support te requests.
        [securestring]$token = (Get-AzAccessToken -AsSecureString).Token
    }
    process {
        try {    
            # Get the approval steps first of a single PIM request.
            [string]$approvalStepsUri = $baseUri + "$($ApprovalId)/stages?api-version=$apiVersion"
            [object]$approvalSteps = Invoke-RestMethod -Method 'GET' -Uri $approvalStepsUri -Authentication 'Bearer' -Token $token
    
            Write-Host "Sending decision '$ReviewResult' for PIM request $($approvalSteps.value[0].id)..." -ForegroundColor Cyan

            # Construct the necessary API call for approving a PIM request
            [string]$approvalDecisionUri = $baseUri + ($approvalSteps.value[0].id) + "?api-version=$apiVersion"
    
            # Prepare the request body for the decision request.
            [object]$body = @{
                properties = @{
                    justification = $Reason
                    reviewResult  = $ReviewResult
                }
            } | ConvertTo-Json
            
            # Send the decision for the approval request to the PIM API.
            [hashtable]$approvalDecisionParams = @{
                Method = 'PUT'
                Uri = $approvalDecisionUri
                Body = $body
                Authentication = 'Bearer'
                Token = $token
                ContentType = 'application/json'
            }
            [object]$approvalDecision = Invoke-RestMethod @approvalDecisionParams

            # TODO: Remove return object after debugging.
            Write-Host $approvalDecision
        }
        catch {
            Write-Error "Failed to approve PIM request: $_"
            throw $_
            return $false
        }
    }
    end {
        Write-Host "Successfully approved PIM request with status '$($approvalDecision.properties.status)'." -ForegroundColor 'Green'
        return $true
    }
}

# Helper Functions
function Show-AzPimRequestDetails {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true,
            HelpMessage = 'Creation date and time of the request.')]
        [string]$CreatedOn,
        
        [Parameter(Mandatory = $true,
            HelpMessage = 'Duration of the requested access.')]
        [string]$Duration,
        
        [Parameter(Mandatory = $true,
            HelpMessage = 'Justification provided for the request.')]
        [string]$Justification,
        
        [Parameter(Mandatory = $true,
            HelpMessage = 'Display name of the user requesting access.')]
        [string]$PrincipalName,
        
        [Parameter(Mandatory = $true,
            HelpMessage = 'Display name of the resource.')]
        [string]$ResourceName,
        
        [Parameter(Mandatory = $true,
            HelpMessage = 'Type of the resource being accessed.')]
        [string]$ResourceType,
        
        [Parameter(Mandatory = $true,
            HelpMessage = 'Name of the role being requested.')]
        [string]$RoleDefinitionName,
        
        [Parameter(Mandatory = $true,
            HelpMessage = 'Start date and time for the requested access.')]
        [string]$StartDateTime,
        
        [Parameter(Mandatory = $true,
            HelpMessage = 'Current status of the request.')]
        [string]$Status,

        [Parameter(Mandatory = $true,
            HelpMessage = 'Reference ticket number for the request.')]
        [string]$TicketNumber,

        [Parameter(Mandatory = $true,
            HelpMessage = 'Source system for the reference ticket.')]
        [string]$TicketSystem
    )

    Write-Host "================= PIM Request Details =================" -ForegroundColor 'Cyan'
    Write-Host ""
    Write-Host "Request details" -ForegroundColor 'Cyan'
    Write-Host "Role:          $RoleDefinitionName" -ForegroundColor 'White'
    Write-Host "Requestor:     $PrincipalName" -ForegroundColor 'White'
    Write-Host "Resource:      $ResourceName" -ForegroundColor 'White'
    Write-Host "Resource type: $ResourceType" -ForegroundColor 'White'
    Write-Host "Request time:  $CreatedOn" -ForegroundColor 'White'
    Write-Host "Reason:        $Justification" -ForegroundColor 'White'
    Write-Host "Status:        $Status" -ForegroundColor 'White'
    Write-Host ""
    Write-Host "Ticket information" -ForegroundColor 'Cyan'
    Write-Host "Ticket number: $TicketNumber" -ForegroundColor 'White'
    Write-Host "Ticket system: $TicketSystem" -ForegroundColor 'White'
    Write-Host ""
    Write-Host "Schedule information" -ForegroundColor 'Cyan'
    Write-Host "Start time:    $StartDateTime" -ForegroundColor 'White'
    Write-Host "Duration:      $Duration" -ForegroundColor 'White'
    Write-Host ""
    Write-Host "=======================================================" -ForegroundColor 'Cyan'
}

# Function to display the banner
function Show-Banner {
    Write-Host "=====================================================" -ForegroundColor 'Cyan'
    Write-Host "        Azure Privileged Identity Management CLI     " -ForegroundColor 'Cyan'
    Write-Host "=====================================================" -ForegroundColor 'Cyan'
    Write-Host ""
}

# Function to display the main menu
function Show-MainMenu {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Account
    )
    
    Clear-Host
    Show-Banner
    Write-Host "Connected as: $Account" -ForegroundColor Green
    Write-Host ""
    Write-Host "Please select an option:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. View and approve pending PIM requests" -ForegroundColor White
    Write-Host "2. Request a role activation" -ForegroundColor White
    Write-Host "3. View your active roles" -ForegroundColor White
    Write-Host "4. Disconnect from Azure" -ForegroundColor White
    Write-Host "5. Exit" -ForegroundColor White
    Write-Host ""
}

# Function to handle approval of PIM requests
function Invoke-PimRequestApproval {
    Clear-Host
    Show-Banner
    
    # Send request to the Azure Management API to get active approval requests in Priviliged Identity Management.
    Write-Host "Retrieving pending PIM requests..." -ForegroundColor 'Cyan'
    [array]$requests = Get-AzPimRequests
    
    # When there are no requests returned, simply report that back in the console and return back to the previous screen.
    # TODO: Walk through the flow when no active approval requests are found.
    if (-not $requests -or $requests.Count -eq 0) {
        Write-Host "No pending PIM requests found." -ForegroundColor 'Yellow'
        Read-Host "Press Enter to continue"
        return
    }
    
    Write-Host "Found $($requests.Count) pending PIM request(s)." -ForegroundColor 'Green'
    Write-Host ""
    
    # Redeclare the variable but sort the array based on the request date. If there is no date found in the request, specify the max date value.
    $requests = $requests | Sort-Object { 
        if ($_.properties.scheduleInfo.startDateTime) {
            [DateTime]$_.properties.scheduleInfo.startDateTime 
        } 
        else { 
            [DateTime]::MaxValue 
        }
    }

    # Display all pending requests
    for ($i = 0; $i -lt $requests.Count; $i++) {
        # Set up human-readable variables to prepare for displaying pending requests.
        [string]$approvalId = $($requests[$i].properties.approvalId).Trim('providers/Microsoft.Authorization/roleAssignmentApprovals/')

        Write-Host "[$($i + 1)] Approval ID: $approvalId" -ForegroundColor 'White'
        Write-Host "    Principal: $($requests[$i].properties.expandedProperties.principal.displayName)" -ForegroundColor 'White'
        Write-Host "    Role: $($requests[$i].properties.expandedProperties.roleDefinition.displayName)" -ForegroundColor 'White'
        Write-Host "    Requested on: $($requests[$i].properties.createdOn)" -ForegroundColor 'White'
        Write-Host "    Justification: $($requests[$i].properties.justification)" -ForegroundColor 'White'
        Write-Host ""
    }
    
    $selection = Read-Host -Prompt 'Enter request number to view details and approve (or C to return to menu)'
    
    if ($selection -eq "C") {
        return
    }
    
    if (-not [int]::TryParse($selection, [ref]$null) -or [int]$selection -lt 1 -or [int]$selection -gt $requests.Count) {
        Write-Host "Invalid selection, returning..." -ForegroundColor 'Red'
        Start-Sleep 2
        return
    }
    
    $selectedRequest = $requests[[int]$selection - 1]
    $pimRequestDetailsParams = @{
        CreatedOn = $selectedRequest.properties.createdOn
        Duration = if ([string]::IsNullOrEmpty($selectedRequest.properties.scheduleInfo.expiration.duration)) { 'N/A' } else { $selectedRequest.properties.scheduleInfo.expiration.duration }
        Justification = $selectedRequest.properties.justification
        PrincipalName = $selectedRequest.properties.expandedProperties.principal.displayName
        ResourceName = $selectedRequest.properties.expandedProperties.scope.displayName
        ResourceType = $selectedRequest.properties.expandedProperties.scope.type
        RoleDefinitionName = $selectedRequest.properties.expandedProperties.roleDefinition.displayName
        StartDateTime = if ($selectedRequest.properties.scheduleInfo.startDateTime) { $selectedRequest.properties.scheduleInfo.startDateTime } else { 'Immediate' }
        Status = $selectedRequest.properties.status
        TicketNumber = if ([string]::IsNullOrEmpty($selectedRequest.properties.ticketInfo.ticketNumber)) { 'N/A' } else { $selectedRequest.properties.ticketInfo.ticketNumber }
        TicketSystem = if ([string]::IsNullOrEmpty($selectedRequest.properties.ticketInfo.ticketSystem)) { 'N/A' } else { $selectedRequest.properties.ticketInfo.ticketSystem }
    }
    
    # Show detailed information about the selected request
    Clear-Host
    Show-AzPimRequestDetails @pimRequestDetailsParams
    
    Write-Host "Action options:" -ForegroundColor 'Yellow'
    Write-Host "Y - Approve the request" -ForegroundColor 'Green'
    Write-Host "N - Reject the request" -ForegroundColor 'Red'
    Write-Host "C - Cancel and return to main menu" -ForegroundColor 'Cyan'
    Write-Host ""
    $action = Read-Host -Prompt 'What would you like to do? (Y/N/C)'
    
    switch ($action.ToUpper()) {
        "Y" {
            $reason = Read-Host -Prompt 'Please provide a justification for this approval'

            # TODO: Think about what to do when a reason is not provided.
            if ([string]::IsNullOrWhiteSpace($reason)) {
                $reason = "Approved by PIM CLI tool"
            }
            
            $result = New-AzPimDecisionRequest -ApprovalId $selectedRequest.properties.approvalId -Reason $reason -ReviewResult 'Approve'
            
            if ($result) {
                Write-Host "Request approved successfully." -ForegroundColor 'Green'
            }
            else {
                Write-Host "Failed to approve request." -ForegroundColor 'Red'
            }
        }
        "N" {
            $reason = Read-Host -Prompt 'Please provide a reason for rejecting this request'
            
            # TODO: Think about what to do when a reason is not provided.
            if ([string]::IsNullOrWhiteSpace($reason)) {
                $reason = "Rejected by PIM CLI tool"
            }
            
            $result = New-AzPimDecisionRequest -ApprovalId $selectedRequest.properties.approvalId -Reason $reason -ReviewResult 'Deny'
            
            if ($result) {
                Write-Host "Request rejected successfully." -ForegroundColor Green
            }
            else {
                Write-Host "Failed to reject request." -ForegroundColor Red
            }
        }
        "C" {
            Write-Host "Returning to request list..." -ForegroundColor Cyan
            # No action needed, will fall through to continue
            return
        }
        default {
            Write-Host "Invalid option. Returning to request list..." -ForegroundColor Yellow
        }
    }
    
    Read-Host "Press Enter to continue"
}

# Main script
function Start-PimCli {
    try {
        # Check if Az module is installed
        if (-not (Get-Module -ListAvailable -Name Az.Accounts)) {
            Write-Error "This script requires the Az PowerShell module. Please install it with: Install-Module -Name Az -AllowClobber -Force"
            return
        }
        
        # Authenticate to Azure
        Clear-Host
        Show-Banner
        Write-Host "Welcome to the Azure PIM CLI tool!" -ForegroundColor 'Green'
        Write-Host "Authenticating to Azure..." -ForegroundColor 'Cyan'
        
        $authResult = Connect-AzPim
        
        if (-not $authResult.Success) {
            Write-Error "Authentication failed: $($authResult.ErrorMessage)"
            return
        }
        
        if (-not $authResult.PimAccess) {
            Write-Warning "You may not have sufficient permissions for PIM operations."
            Write-Host "Do you want to continue anyway? (Y/N)" -ForegroundColor 'Yellow'
            $continue = Read-Host
            
            if ($continue -ne "Y" -and $continue -ne "y") {
                return
            }
        }
        
        Start-Sleep 5

        # Main menu loop
        $exit = $false
        while (-not $exit) {
            Show-MainMenu -Account $authResult.Account
            $choice = Read-Host -Prompt 'Enter your choice'
            
            switch ($choice) {
                "1" { Invoke-PimRequestApproval }
                "2" { 
                    Clear-Host
                    Write-Host "Feature coming soon: Request role activation" -ForegroundColor Yellow
                    Read-Host "Press Enter to continue"
                }
                "3" { 
                    Clear-Host
                    Write-Host "Feature coming soon: View active roles" -ForegroundColor Yellow
                    Read-Host "Press Enter to continue"
                }
                "4" { 
                    Disconnect-AzPim 
                    $exit = $true
                }
                "5" { $exit = $true }
                default {
                    Write-Host "Invalid choice. Please try again." -ForegroundColor Red
                    Start-Sleep -Seconds 2
                }
            }
        }
    }
    catch {
        Write-Error "An error occurred: $_"
    }
    finally {
        # Ensure we disconnect from Azure if something fails
        try {
            $context = Get-AzContext -ErrorAction SilentlyContinue
            if ($context) {
                # Write-Host "Disconnecting from Azure..." -ForegroundColor Cyan
                # Disconnect-AzAccount -ErrorAction SilentlyContinue | Out-Null
            }
        }
        catch {
            # Ignore errors during cleanup
        }
    }
}

# Export-ModuleMember -Function Connect-AzPim, Disconnect-AzPim, Get-AzPimRequests, Approve-AzPimRequest, Show-AzPimRequestDetails, Show-Banner, Show-MainMenu, Invoke-PimRequestApproval, Start-PimCli