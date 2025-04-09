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

function Get-EntraGroup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$GroupName
    )
    
    $group = Get-MgGroup -Filter "displayName eq '$GroupName'"
    
    if (-not $group) {
        throw "Group '$GroupName' not found in Entra ID."
    }
    
    return $group
}

#region Functions
function Ensure-ModuleInstalled {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ModuleName
    )
    
    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
        Write-Host "Installing module $ModuleName..."
        Install-Module -Name $ModuleName -Scope CurrentUser -Force
    }
    
    Import-Module -Name $ModuleName -Force
}





function Update-RoleManagementPolicy {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$RoleDefinitionId,
        
        [Parameter(Mandatory = $true)]
        [bool]$RequireJustification,
        
        [Parameter(Mandatory = $true)]
        [bool]$RequireTicketInformation,
        
        [Parameter(Mandatory = $true)]
        [bool]$RequireMfa,
        
        [Parameter(Mandatory = $true)]
        [bool]$RequireApproval,
        
        [Parameter(Mandatory = $false)]
        [string]$ApproverGroupObjectId,
        
        [Parameter(Mandatory = $true)]
        [int]$ActivationMaxDurationInHours
    )
    
    $policyId = "DirectoryRole_$RoleDefinitionId"
    $policies = Get-MgPolicyRoleManagementPolicy -UnifiedRoleManagementPolicyId $policyId
    
    if (-not $policies) {
        throw "Policy for role ID $RoleDefinitionId not found."
    }
    
    Write-Host "Updating role management policy rules..."
    $activationRules = Get-MgPolicyRoleManagementPolicyRule -UnifiedRoleManagementPolicyId $policyId | Where-Object { $_.Id -like "Activation_*" }
    
    foreach ($rule in $activationRules) {
        $params = @{}
        
        switch -Wildcard ($rule.Id) {
            "*_EnabledRule" {
                $params = @{ "@odata.type" = "#microsoft.graph.unifiedRoleManagementPolicyEnablementRule"; "enabledRules" = @() }
            }
            "*_JustificationRule" {
                $params = @{ "@odata.type" = "#microsoft.graph.unifiedRoleManagementPolicyJustificationRule"; "isJustificationRequired" = $RequireJustification }
            }
            "*_MfaRule" {
                $params = @{ "@odata.type" = "#microsoft.graph.unifiedRoleManagementPolicyMfaRule"; "isMfaRequired" = $RequireMfa }
            }
            "*_TicketingRule" {
                $params = @{ "@odata.type" = "#microsoft.graph.unifiedRoleManagementPolicyTicketingRule"; "isTicketingRequired" = $RequireTicketInformation }
            }
            "*_ApprovalRule" {
                if ($RequireApproval -and $ApproverGroupObjectId) {
                    $params = @{
                        "@odata.type" = "#microsoft.graph.unifiedRoleManagementPolicyApprovalRule"
                        "setting" = @{
                            "isApprovalRequired" = $true
                            "isApprovalRequiredForExtension" = $false
                            "isRequestorJustificationRequired" = $true
                            "approvalMode" = "SingleStage"
                            "approvalStages" = @(
                                @{
                                    "approvalStageTimeOutInDays" = 1
                                    "isApproverJustificationRequired" = $true
                                    "escalationTimeInMinutes" = 0
                                    "primaryApprovers" = @(
                                        @{
                                            "@odata.type" = "#microsoft.graph.groupMembers"
                                            "groupId" = $ApproverGroupObjectId
                                        }
                                    )
                                    "isEscalationEnabled" = $false
                                }
                            )
                        }
                    }
                }
                else {
                    $params = @{
                        "@odata.type" = "#microsoft.graph.unifiedRoleManagementPolicyApprovalRule"
                        "setting" = @{
                            "isApprovalRequired" = $false
                            "isApprovalRequiredForExtension" = $false
                            "isRequestorJustificationRequired" = $true
                        }
                    }
                }
            }
            "*_AuthenticationContextRule" {
                $params = @{ "@odata.type" = "#microsoft.graph.unifiedRoleManagementPolicyAuthenticationContextRule"; "isEnabled" = $false }
            }
            "*_ExpirationRule" {
                $params = @{
                    "@odata.type" = "#microsoft.graph.unifiedRoleManagementPolicyExpirationRule"
                    "isExpirationRequired" = $true
                    "maximumDuration" = "PT$($ActivationMaxDurationInHours)H"
                    "expiration" = @{ "type" = "AfterDateTime"; "endDateTime" = $null; "duration" = "PT$($ActivationMaxDurationInHours)H" }
                }
            }
        }
        
        if ($params.Count -gt 0) {
            Write-Host "Updating rule: $($rule.Id)"
            Update-MgPolicyRoleManagementPolicyRule -UnifiedRoleManagementPolicyId $policyId -UnifiedRoleManagementPolicyRuleId $rule.Id -BodyParameter $params
        }
    }
    
    Write-Host "Role management policy updated successfully."
}

function New-PimRoleAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$PrincipalId,
        
        [Parameter(Mandatory = $true)]
        [string]$RoleDefinitionId,
        
        [Parameter(Mandatory = $true)]
        [string]$AssignmentType,
        
        [Parameter(Mandatory = $true)]
        [int]$DurationInDays
    )
    
    $scheduleInfo = @{
        expiration = @{
            type = "afterDuration"
            duration = "P${DurationInDays}D"
        }
    }
    
    $params = @{
        principalId = $PrincipalId
        roleDefinitionId = $RoleDefinitionId
        directoryScopeId = "/"
        justification = "Assigned via PIM automation script"
        scheduleInfo = $scheduleInfo
    }
    
    if ($AssignmentType -eq "Eligible") {
        Write-Host "Creating eligible role assignment..."
        New-MgRoleManagementDirectoryRoleEligibilityScheduleRequest -BodyParameter $params
    }
    else {
        Write-Host "Creating active role assignment..."
        New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -BodyParameter $params
    }
}
#endregion