<#
.SYNOPSIS
    Wrapper điều hướng đến core\E5-RcloneMount.ps1 (Backward Compatibility)
#>
$targetScript = Join-Path $PSScriptRoot "core\E5-RcloneMount.ps1"
& $targetScript -Action Check
