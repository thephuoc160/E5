<#
.SYNOPSIS
    E5 SharePoint Activity & Rclone Sync Manager
.DESCRIPTION
    Thực thi các lệnh API và hoạt động kiểm tra dữ liệu với SharePoint Remote qua rclone:
    - Kiểm tra kết nối SharePoint (about)
    - Liệt kê thư mục & files (lsd, ls)
    - Upload file ngẫu nhiên / log trạng thái
    - Tính toán dung lượng (size)
#>

[CmdletBinding()]
param(
    [string]$RemoteName = "sharepoint:",
    [string]$BasePath = "M:\API\SharePoint",
    [int]$MinActivities = 3,
    [int]$MaxActivities = 5
)

$ErrorActionPreference = "Continue"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RootDir = Split-Path -Parent $ScriptDir
$ConfigPath = Join-Path $RootDir "config\config.json"
$LogDir = Join-Path $RootDir "logs"

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
$LogFile = Join-Path $LogDir "sharepoint_activity.log"

if (Test-Path $ConfigPath) {
    try {
        $cfg = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($cfg.rclone.sharePointRemote) { $RemoteName = $cfg.rclone.sharePointRemote }
    } catch {}
}

function Write-SPLog {
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
        $logLine | Out-File -FilePath $LogFile -Append -Encoding UTF8
    } catch {}
}

function Get-RclonePath {
    $candidatePaths = @(
        (Join-Path $RootDir "tools\rclone.exe"),
        (Join-Path $RootDir "rclone.exe"),
        "C:\Scripts\tools\rclone.exe",
        "C:\Scripts\rclone.exe",
        "E:\10. E5 API\#rclone\rclone.exe"
    )
    
    foreach ($p in $candidatePaths) {
        if (Test-Path $p) { return $p }
    }
    
    $inPath = Get-Command "rclone" -ErrorAction SilentlyContinue
    if ($inPath) { return $inPath.Source }
    return $null
}

$rcloneBin = Get-RclonePath
if (-not $rcloneBin) {
    Write-SPLog "Không tìm thấy rclone.exe!" "ERROR"
    exit 1
}

Write-SPLog "=== BẮT ĐẦU HOẠT ĐỘNG SHAREPOINT API ===" "INFO"
Write-SPLog "Rclone binary: $rcloneBin" "INFO"

# Test SharePoint Connection
try {
    Write-SPLog "Đang kiểm tra kết nối tới remote: $RemoteName..." "INFO"
    $aboutOut = & $rcloneBin about $RemoteName 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-SPLog "Kết nối SharePoint thành công!" "SUCCESS"
    } else {
        Write-SPLog "Cảnh báo: Không thể kết nối SharePoint ($aboutOut)" "WARN"
    }
} catch {
    Write-SPLog "Lỗi kết nối: $($_.Exception.Message)" "WARN"
}

# Các hoạt động rclone SharePoint
$activityPool = @(
    @{
        Name = "Liệt kê danh sách thư mục (lsd)"
        Action = {
            & $rcloneBin lsd $RemoteName 2>&1 | Out-Null
        }
    },
    @{
        Name = "Kiểm tra dung lượng và hạn ngạch (about)"
        Action = {
            & $rcloneBin about $RemoteName 2>&1 | Out-Null
        }
    },
    @{
        Name = "Tạo & Upload file test"
        Action = {
            $tempDir = Join-Path $RootDir "scratch_sp_test"
            if (-not (Test-Path $tempDir)) { New-Item -ItemType Directory -Path $tempDir -Force | Out-Null }
            $testFileName = "sp_ping_{0}.txt" -f (Get-Date -Format "yyyyMMdd_HHmmss")
            $testFile = Join-Path $tempDir $testFileName
            "SharePoint Test Ping $(Get-Date)" | Out-File -FilePath $testFile -Encoding UTF8
            
            & $rcloneBin copy $testFile "$RemoteName/API_Tests/" 2>&1 | Out-Null
            Remove-Item $testFile -Force -ErrorAction SilentlyContinue
        }
    },
    @{
        Name = "Tính toán tổng dung lượng SharePoint (size)"
        Action = {
            & $rcloneBin size "$RemoteName/API_Tests/" 2>&1 | Out-Null
        }
    },
    @{
        Name = "Liệt kê các file mới nhất (lsl)"
        Action = {
            & $rcloneBin lsl --max-depth 2 $RemoteName 2>&1 | Out-Null
        }
    }
)

$numActivities = Get-Random -Minimum $MinActivities -Maximum ($MaxActivities + 1)
$selected = $activityPool | Get-Random -Count $numActivities

Write-SPLog "Thực hiện $numActivities hoạt động ngẫu nhiên trên SharePoint..." "INFO"

for ($i = 0; $i -lt $selected.Count; $i++) {
    $act = $selected[$i]
    Write-SPLog "[$($i+1)/$numActivities] Đang chạy: $($act.Name)..." "INFO"
    try {
        & $act.Action
        Write-SPLog "[$($i+1)/$numActivities] Hoàn thành: $($act.Name)" "SUCCESS"
        Start-Sleep -Seconds (Get-Random -Minimum 2 -Maximum 5)
    } catch {
        Write-SPLog "[$($i+1)/$numActivities] Lỗi: $($_.Exception.Message)" "WARN"
    }
}

Write-SPLog "=== HOÀN TẤT HOẠT ĐỘNG SHAREPOINT ===" "SUCCESS"
