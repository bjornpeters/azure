#Requires -Modules Az.Accounts, Az.Resources

<#
.SYNOPSIS
    Functions for Azure Privileged Identity Management (PIM) operations.
.DESCRIPTION
    This module provides functions to interact with Azure Privileged Identity Management,
    including authentication and approval of PIM requests.
.NOTES
    Version:        1.0.0
    Author:         GitHub Copilot
    Creation Date:  2025-04-30
#>

# Authentication Functions
function Connect-AzPim {
    <#
    .SYNOPSIS
        Authenticates to Azure and verifies access to PIM.
    .DESCRIPTION
        Authenticates the user to Azure using Az PowerShell module and verifies
        that the user has access to Privileged Identity Management.
    .EXAMPLE
        Connect-AzPim
    .OUTPUTS
        PSObject with authentication status and context
    #>
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

# PIM Request Functions
function Get-AzPimRequests {
    [CmdletBinding()]
    param()
    try {
        Write-Host "Retrieving pending PIM requests..." -ForegroundColor Cyan
        
        $pendingRequestsUri = 'https://management.azure.com/providers/Microsoft.Authorization/roleAssignmentScheduleRequests?api-version=2022-04-01-preview&$filter=asApprover()'
        $pendingRequests = (Invoke-RestMethod -Method 'GET' -Uri $pendingRequestsUri -Authentication 'Bearer' -Token (Get-AzAccessToken -AsSecureString).Token).value
    
        if ($pendingRequests -and $pendingRequests.Count -gt 0) {
            Write-Host "Found $($pendingRequests.Count) pending PIM request(s)." -ForegroundColor Green
            return $pendingRequests
        }
        else {
            Write-Host "No pending PIM requests found." -ForegroundColor Yellow
            return @()
        }
    }
    catch {
        Write-Error "Failed to retrieve PIM requests: $_"
        return @()
    }
}

function New-AzPimDecisionRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true,
            HelpMessage = 'Unique identifier for the approval.')]
        [System.String]$ApprovalId,
        
        [Parameter(Mandatory = $true,
            HelpMessage = 'Justification for the approval.')]
        [System.String]$Reason,

        [Parameter(Mandatory = $true,
            HelpMessage = 'Justification for the approval.')]
        [ValidateSet('Approve', 'Deny', 'NotReviewed')]
        [System.String]$ReviewResult
    )
    begin {
        # Set the basic url for the Privileged Identity Management API and the API version.
        [System.String]$baseUri = 'https://management.azure.com'
        [System.String]$apiVersion = '2021-01-01-preview'

        # Retrieve the Azure access token to support te requests.
        [securestring]$token = (Get-AzAccessToken -AsSecureString).Token
    }
    process {
        try {    
            # Get the approval steps first of a single PIM request.
            [System.String]$approvalStepsUri = $baseUri + "$($ApprovalId)/stages?api-version=$apiVersion"
            [System.Object]$approvalSteps = Invoke-RestMethod -Method 'GET' -Uri $approvalStepsUri -Authentication 'Bearer' -Token $token
    
            Write-Host "Sending decision '$ReviewResult' for PIM request $($approvalSteps.value[0].id)..." -ForegroundColor Cyan

            # Construct the necessary API call for approving a PIM request
            [System.String]$approvalDecisionUri = $baseUri + ($approvalSteps.value[0].id) + "?api-version=$apiVersion"
    
            # Prepare the request body for the decision request.
            [System.Object]$body = @{
                properties = @{
                    justification = $Reason
                    reviewResult  = $ReviewResult
                }
            } | ConvertTo-Json
            Write-Host $body
            
            # Send the decision for the approval request to the PIM API.
            [hashtable] $approvalDecisionParams = @{
                Method = 'PUT'
                Uri = $approvalDecisionUri
                Body = $body
                Authentication = 'Bearer'
                Token = $token
                ContentType = 'application/json'
            }
            [System.Object]$approvalDecision = Invoke-RestMethod @approvalDecisionParams
            Write-Host $approvalDecision
            
            Write-Host "Successfully approved PIM request." -ForegroundColor Green
            return $true
        }
        catch {
            Write-Error "Failed to approve PIM request: $_"
            throw $_
            return $false
        }
    }
    end {

    }
}

function Reject-AzPimRequest {
    <#
    .SYNOPSIS
        Rejects a PIM request.
    .DESCRIPTION
        Rejects a specific PIM request in Azure Privileged Identity Management.
    .PARAMETER RequestId
        The ID of the request to reject.
    .PARAMETER Reason
        The reason for rejecting the request.
    .EXAMPLE
        Reject-AzPimRequest -RequestId "12345" -Reason "Request does not meet security requirements"
    .OUTPUTS
        Boolean indicating success or failure
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RequestId,
        
        [Parameter(Mandatory = $true)]
        [string]$Reason
    )
    
    try {
        Write-Host "Rejecting PIM request $RequestId..." -ForegroundColor Cyan
        
        # Construct the necessary API call for rejecting a PIM request
        $apiVersion = "2020-10-01"
        $uri = "https://management.azure.com$RequestId/deny?api-version=$apiVersion"
        
        $body = @{
            justification = $Reason
            decision = "Deny"
        } | ConvertTo-Json
        
        # Get the access token from the current context
        $tokenCache = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.TokenCache
        $token = $tokenCache.ReadItems() | Where-Object { $_.Resource -eq "https://management.azure.com/" } | Sort-Object -Property ExpiresOn -Descending | Select-Object -First 1
        
        $headers = @{
            'Authorization' = "Bearer $($token.AccessToken)"
            'Content-Type' = 'application/json'
        }
        
        Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body $body | Out-Null
        
        Write-Host "Successfully rejected PIM request." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to reject PIM request: $_"
        return $false
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
            HelpMessage = 'Justification provided for the request.')]
        [string]$Justification,
        
        [Parameter(Mandatory = $true,
            HelpMessage = 'User principal ID of the requestor.')]
        [string]$PrincipalName,
        
        [Parameter(Mandatory = $true,
            HelpMessage = 'Display name of the resource.')]
        [string]$ResourceName,
        
        [Parameter(Mandatory = $true,
            HelpMessage = 'Type of the resource.')]
        [string]$ResourceType,
        
        [Parameter(Mandatory = $true,
            HelpMessage = 'Role definition ID being requested.')]
        [string]$RoleDefinitionName,
        
        [Parameter(Mandatory = $true,
            HelpMessage = 'Current status of the request.')]
        [string]$Status
    )
    
    Write-Host "================= PIM Request Details =================" -ForegroundColor Cyan
    Write-Host "Role:          $RoleDefinitionName" -ForegroundColor White
    Write-Host "Resource:      $ResourceName" -ForegroundColor White
    Write-Host "Resource type: $ResourceType" -ForegroundColor White
    Write-Host "Requestor:     $PrincipalName" -ForegroundColor White
    Write-Host "Request time:  $CreatedOn" -ForegroundColor White
    Write-Host "Reason:        $Justification" -ForegroundColor White
    Write-Host "Status:        $Status" -ForegroundColor White
    Write-Host "=======================================================" -ForegroundColor Cyan
}

Export-ModuleMember -Function Connect-AzPim, Disconnect-AzPim, Get-AzPimRequests, Approve-AzPimRequest, Reject-AzPimRequest, Show-AzPimRequestDetails