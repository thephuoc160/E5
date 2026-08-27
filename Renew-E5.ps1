<#
.SYNOPSIS
    Wrapper điều hướng đến core\E5-RenewHelper.ps1 -Action QuickRenew (Backward Compatibility)
#>
$targetScript = Join-Path $PSScriptRoot "core\E5-RenewHelper.ps1"
& $targetScript -Action QuickRenew
