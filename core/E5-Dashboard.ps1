# Compatibility entry point. The dashboard lives in dashboard/.
[CmdletBinding()]
param(
    [switch]$NoServe,
    [int]$Port = 5500,
    [switch]$NoBrowser
)
& (Join-Path (Split-Path -Parent $PSScriptRoot) "dashboard\E5-Dashboard.ps1") @PSBoundParameters
