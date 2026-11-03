# Compatibility entry point for existing shortcuts and scheduled tasks.
[CmdletBinding()]
param(
    [switch]$SkipMount,
    [switch]$SkipSharePoint
)
& (Join-Path $PSScriptRoot "launchers\Run-All.ps1") @PSBoundParameters
