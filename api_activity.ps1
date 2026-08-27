<#
.SYNOPSIS
    Wrapper điều hướng đến core\E5-GraphActivity.ps1 (Backward Compatibility)
#>
[CmdletBinding()]
param(
    [string]$BasePath = "M:\API_Output",
    [int]$MinActivities = 10,
    [int]$MaxActivities = 20,
    [switch]$EnableGraphActivities = $true,
    [string]$UserPrincipalName = "",
    [string[]]$TeamMailRecipients = @()
)

$targetScript = Join-Path $PSScriptRoot "core\E5-GraphActivity.ps1"
& $targetScript @PSBoundParameters
