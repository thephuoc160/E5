<#
.SYNOPSIS
    Wrapper điều hướng đến core\E5-RenewHelper.ps1 -Action CreateDraft (Backward Compatibility)
#>
param(
    [string]$UserPrincipalName = "",
    [switch]$OpenDraftInBrowser
)
$targetScript = Join-Path $PSScriptRoot "core\E5-RenewHelper.ps1"
& $targetScript -Action CreateDraft -UserPrincipalName $UserPrincipalName
