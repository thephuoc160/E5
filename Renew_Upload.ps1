<#
.SYNOPSIS
    Wrapper điều hướng đến core\E5-RenewHelper.ps1 -Action UploadFolder (Backward Compatibility)
#>
param([string]$LocalFolder = "D:\Upload")
$targetScript = Join-Path $PSScriptRoot "core\E5-RenewHelper.ps1"
& $targetScript -Action UploadFolder -LocalFolder $LocalFolder
