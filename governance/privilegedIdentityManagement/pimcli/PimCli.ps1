<#
.SYNOPSIS
    Command-line interface for Azure Privileged Identity Management.
.DESCRIPTION
    This script provides a command-line interface for managing Azure Privileged Identity Management
    operations, including approving requests.
.NOTES
    Version:        0.1
    Author:         Bjorn Peters
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

# Start the CLI
Start-PimCli