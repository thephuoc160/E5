<#
.SYNOPSIS
    E5 Master Runner - Thực thi toàn diện chu trình Renew E5
.DESCRIPTION
    Tự động hóa toàn bộ quy trình:
    1. Kiểm tra & Mount ổ đĩa M: (OneDrive/SharePoint)
    2. Chạy hoạt động Microsoft Graph API & File System
    3. Chạy hoạt động SharePoint API (rclone)
    4. Ghi log tổng kết chi tiết
#>

[CmdletBinding()]
param(
    [switch]$SkipMount,
    [switch]$SkipSharePoint
)

$ErrorActionPreference = "Continue"
$RootDir = $PSScriptRoot
$LogDir = Join-Path $RootDir "logs"
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
$MasterLog = Join-Path $LogDir "master_run.log"

function Write-MasterLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$Level] $Message"
    
    switch ($Level) {
        "SUCCESS" { Write-Host $logLine -ForegroundColor Green }
        "WARN"    { Write-Host $logLine -ForegroundColor Yellow }
        "ERROR"   { Write-Host $logLine -ForegroundColor Red }
        default   { Write-Host $logLine -ForegroundColor Cyan }
    }
    
    try {
        $logLine | Out-File -FilePath $MasterLog -Append -Encoding UTF8
    } catch {}
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "       MICROSOFT 365 E5 RENEW MASTER RUNNER       " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

$startTime = Get-Date
Write-MasterLog "Bắt đầu chu trình Master E5 Renew..." "INFO"

# --- Bước 1: Mount Drive M: ---
if (-not $SkipMount) {
    Write-Host "`n--- [1/3] KIỂM TRA & MOUNT Ổ ĐĨA M: ---" -ForegroundColor Yellow
    $mountScript = Join-Path $RootDir "core\E5-RcloneMount.ps1"
    if (Test-Path $mountScript) {
        & $mountScript -Action Check
    }
}

# --- Bước 2: Chạy Microsoft Graph Activity ---
Write-Host "`n--- [2/3] CHẠY HOẠT ĐỘNG MICROSOFT GRAPH & FILE OPS ---" -ForegroundColor Yellow
$graphScript = Join-Path $RootDir "core\E5-GraphActivity.ps1"
if (Test-Path $graphScript) {
    & $graphScript -BasePath "M:\API_Output" -EnableGraphActivities
} else {
    Write-MasterLog "Không tìm thấy core\E5-GraphActivity.ps1!" "ERROR"
}

# --- Bước 3: Chạy SharePoint Activity ---
if (-not $SkipSharePoint) {
    Write-Host "`n--- [3/3] CHẠY HOẠT ĐỘNG SHAREPOINT API ---" -ForegroundColor Yellow
    $spScript = Join-Path $RootDir "core\E5-SharePointSync.ps1"
    if (Test-Path $spScript) {
        & $spScript
    }
}

$duration = (Get-Date) - $startTime
Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-MasterLog ("HOÀN TẤT TOÀN BỘ QUY TRÌNH E5 RENEW TRONG {0:N1} GIÂY!" -f $duration.TotalSeconds) "SUCCESS"
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""
