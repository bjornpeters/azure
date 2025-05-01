#!/usr/bin/env pwsh
#Requires -Version 5.1
#Requires -Modules Az.Accounts, Az.Resources

<#
.SYNOPSIS
    Command-line interface for Azure Privileged Identity Management.
.DESCRIPTION
    This script provides a command-line interface for managing Azure Privileged Identity Management
    operations, including approving requests.
.NOTES
    Version:        1.0.0
    Author:         GitHub Copilot
    Creation Date:  2025-04-30
.EXAMPLE
    ./PimCli.ps1
#>

[CmdletBinding()]
param()

# Import the PimFunctions module
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$modulePath = Join-Path -Path $scriptPath -ChildPath "PimFunctions.ps1"

if (Test-Path -Path $modulePath) {
    . $modulePath
}
else {
    Write-Error "Required module not found: $modulePath"
    exit 1
}

# Function to display the banner
function Show-Banner {
    Write-Host "=====================================================" -ForegroundColor Cyan
    Write-Host "        Azure Privileged Identity Management CLI     " -ForegroundColor Cyan
    Write-Host "=====================================================" -ForegroundColor Cyan
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
    
    Write-Host "Fetching pending PIM requests..." -ForegroundColor Cyan
    $requests = Get-AzPimRequests
    
    if (-not $requests -or $requests.Count -eq 0) {
        Write-Host "No pending PIM requests found." -ForegroundColor Yellow
        Read-Host "Press Enter to continue"
        return
    }
    
    Write-Host "Found $($requests.Count) pending PIM request(s)." -ForegroundColor Green
    Write-Host ""
    
    # Display all pending requests
    for ($i = 0; $i -lt $requests.Count; $i++) {
        Write-Host "[$($i + 1)] Request ID: $($requests[$i].properties.approvalId)" -ForegroundColor White
        Write-Host "    Principal: $($requests[$i].properties.expandedProperties.principal.displayName)" -ForegroundColor White
        Write-Host "    Role: $($requests[$i].properties.expandedProperties.roleDefinition.displayName)" -ForegroundColor White
        Write-Host "    Requested on: $($requests[$i].properties.createdOn)" -ForegroundColor White
        Write-Host "    Justification: $($requests[$i].properties.justification)" -ForegroundColor White
        Write-Host ""
    }
    
    Write-Host "Enter request number to view details and approve (or C to return to menu):" -ForegroundColor Yellow
    $selection = Read-Host
    
    if ($selection -eq "C") {
        return
    }
    
    if (-not [int]::TryParse($selection, [ref]$null) -or [int]$selection -lt 1 -or [int]$selection -gt $requests.Count) {
        Write-Host "Invalid selection." -ForegroundColor Red
        Read-Host "Press Enter to continue"
        return
    }
    
    $selectedRequest = $requests[[int]$selection - 1]
    $pimRequestDetailsParams = @{
        CreatedOn = $selectedRequest.properties.createdOn
        Justification = $selectedRequest.properties.justification
        PrincipalName = $selectedRequest.properties.expandedProperties.principal.displayName
        ResourceName = $selectedRequest.properties.expandedProperties.scope.displayName
        ResourceType = $selectedRequest.properties.expandedProperties.scope.type
        RoleDefinitionName = $selectedRequest.properties.expandedProperties.roleDefinition.displayName
        Status = $selectedRequest.properties.status
    }
    
    # Show detailed information about the selected request
    Clear-Host
    Show-AzPimRequestDetails @pimRequestDetailsParams
    
    Write-Host "Action options:" -ForegroundColor Yellow
    Write-Host "Y - Approve the request" -ForegroundColor Green
    Write-Host "N - Reject the request" -ForegroundColor Red
    Write-Host "C - Cancel and return to request list" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "What would you like to do? (Y/N/C)" -ForegroundColor Yellow
    $action = Read-Host
    
    switch ($action.ToUpper()) {
        "Y" {
            Write-Host "Please provide a justification for this approval:" -ForegroundColor Yellow
            $reason = Read-Host
            
            if ([string]::IsNullOrWhiteSpace($reason)) {
                $reason = "Approved by PIM CLI tool"
            }
            
            $result = New-AzPimDecisionRequest -ApprovalId $selectedRequest.properties.approvalId -Reason $reason -ReviewResult 'Approve'
            
            if ($result) {
                Write-Host "Request approved successfully." -ForegroundColor Green
            }
            else {
                Write-Host "Failed to approve request." -ForegroundColor Red
            }
        }
        "N" {
            Write-Host "Please provide a reason for rejecting this request:" -ForegroundColor Yellow
            $reason = Read-Host
            
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
        Write-Host "Welcome to the Azure PIM CLI tool!" -ForegroundColor Green
        Write-Host "Authenticating to Azure..." -ForegroundColor Cyan
        
        $authResult = Connect-AzPim
        
        if (-not $authResult.Success) {
            Write-Error "Authentication failed: $($authResult.ErrorMessage)"
            return
        }
        
        if (-not $authResult.PimAccess) {
            Write-Warning "You may not have sufficient permissions for PIM operations."
            Write-Host "Do you want to continue anyway? (Y/N)" -ForegroundColor Yellow
            $continue = Read-Host
            
            if ($continue -ne "Y" -and $continue -ne "y") {
                return
            }
        }
        
        # Main menu loop
        $exit = $false
        while (-not $exit) {
            Show-MainMenu -Account $authResult.Account
            $choice = Read-Host "Enter your choice"
            
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
                Write-Host "Disconnecting from Azure..." -ForegroundColor Cyan
                Disconnect-AzAccount -ErrorAction SilentlyContinue | Out-Null
            }
        }
        catch {
            # Ignore errors during cleanup
        }
    }
}

# Start the CLI
Start-PimCli