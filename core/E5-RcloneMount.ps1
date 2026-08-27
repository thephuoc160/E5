<#
.SYNOPSIS
    E5 Rclone Mount Manager (Mount / Unmount / Health Check / Reconnect Drive M:)
.DESCRIPTION
    Quản lý kết nối ổ đĩa M: từ OneDrive Business hoặc SharePoint qua rclone.
    Hỗ trợ kiểm tra sức khỏe tự động, auto-reconnect và phân tích lỗi token.
.PARAMETER Action
    Mount, Unmount, Restart, Check, Status, Reconnect
.PARAMETER Remote
    Tên remote trong rclone (Mặc định: 1Drive:)
.PARAMETER DriveLetter
    Ký tự ổ đĩa muốn gắn (Mặc định: M:)
#>

[CmdletBinding()]
param(
    [ValidateSet("Mount", "Unmount", "Restart", "Check", "Status", "Reconnect")]
    [string]$Action = "Mount",
    [string]$Remote = "",
    [string]$DriveLetter = "M:"
)

$ErrorActionPreference = "Continue"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RootDir = Split-Path -Parent $ScriptDir
$ConfigPath = Join-Path $RootDir "config\config.json"
$LogDir = Join-Path $RootDir "logs"
$LogFile = Join-Path $LogDir "mount.log"

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# Đọc cấu hình nếu không truyền tham số
if ([string]::IsNullOrWhiteSpace($Remote) -and (Test-Path $ConfigPath)) {
    try {
        $cfg = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($cfg.rclone.oneDriveRemote) { $Remote = $cfg.rclone.oneDriveRemote }
        if ($cfg.rclone.mountDrive) { $DriveLetter = $cfg.rclone.mountDrive }
    } catch {}
}
if ([string]::IsNullOrWhiteSpace($Remote)) { $Remote = "1Drive:" }

function Write-MountLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $logEntry = "[$timestamp] [$Level] $Message"
    $color = switch ($Level) {
        "ERROR"   { "Red" }
        "WARN"    { "Yellow" }
        "SUCCESS" { "Green" }
        default   { "Cyan" }
    }
    Write-Host $logEntry -ForegroundColor $color
    try {
        $logEntry | Out-File -FilePath $LogFile -Append -Encoding UTF8
    } catch {}
}

function Get-RcloneBinary {
    $candidates = @(
        (Join-Path $RootDir "tools\rclone.exe"),
        (Join-Path $RootDir "rclone.exe"),
        "C:\rclone\rclone.exe",
        "rclone.exe"
    )
    
    foreach ($path in $candidates) {
        if (Test-Path $path) {
            return (Resolve-Path $path).Path
        }
    }
    
    $inPath = Get-Command "rclone.exe" -ErrorAction SilentlyContinue
    if ($inPath) {
        return $inPath.Source
    }
    
    return $null
}

function Test-MountStatus {
    $driveRoot = if ($DriveLetter.EndsWith("\")) { $DriveLetter } else { "$DriveLetter\" }
    return (Test-Path $driveRoot -ErrorAction SilentlyContinue)
}

function Stop-RcloneMount {
    Write-MountLog "Đang ngắt kết nối ổ đĩa $DriveLetter..." "INFO"
    $rcloneBin = Get-RcloneBinary
    
    # 1. Thử qua remote control rclone rc
    if ($rcloneBin) {
        try {
            & $rcloneBin rc core/quit 2>$null | Out-Null
            Start-Sleep -Seconds 2
        } catch {}
    }
    
    # 2. Dừng process nếu còn tồn tại
    $procs = Get-Process -Name "rclone" -ErrorAction SilentlyContinue
    if ($procs) {
        $procs | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }
    
    if (-not (Test-MountStatus)) {
        Write-MountLog "Đã unmount thành công ổ đĩa $DriveLetter." "SUCCESS"
        return $true
    } else {
        Write-MountLog "Cảnh báo: Ổ đĩa $DriveLetter vẫn còn hiển thị trong hệ thống." "WARN"
        return $false
    }
}

function Start-RcloneMount {
    $rcloneBin = Get-RcloneBinary
    if (-not $rcloneBin) {
        Write-MountLog "Lỗi: Không tìm thấy rclone.exe! Vui lòng kiểm tra thư mục tools." "ERROR"
        return $false
    }
    
    if (Test-MountStatus) {
        Write-MountLog "Ổ đĩa $DriveLetter đã được mount từ trước và đang sẵn sàng." "SUCCESS"
        return $true
    }
    
    # 1. Kiểm tra xác thực token rclone trước khi mount
    Write-MountLog "Kiểm tra quyền truy cập và Token OAuth của $Remote..." "INFO"
    $testOutput = & $rcloneBin lsd $Remote --max-depth 1 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        if ($testOutput -like "*token expired*" -or $testOutput -like "*invalid_grant*") {
            Write-MountLog "❌ LỖI XÁC THỰC: Token OAuth của remote '$Remote' đã hết hạn!" "ERROR"
            Write-MountLog "👉 HƯỚNG DẪN: Hãy nhấp đúp vào file 'Reconnect-1Drive.bat' tại thư mục C:\Scripts để đăng nhập lại qua trình duyệt web." "WARN"
            return $false
        } else {
            Write-MountLog "Cảnh báo kiểm tra remote: $testOutput" "WARN"
        }
    }
    
    Write-MountLog "Khởi động rclone mount: $Remote -> $DriveLetter (Binary: $rcloneBin)" "INFO"
    
    # Dọn dẹp tiến trình cũ nếu có
    Get-Process -Name "rclone" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    
    $argList = "mount $Remote $DriveLetter --vfs-cache-mode writes --rc"
    
    Start-Process -FilePath $rcloneBin -ArgumentList $argList -WindowStyle Hidden
    
    # Chờ mount hoàn tất (tối đa 15 giây)
    $maxWait = 15
    for ($i = 0; $i -lt $maxWait; $i++) {
        Start-Sleep -Seconds 1
        if (Test-MountStatus) {
            Write-MountLog "Mount thành công ổ đĩa $DriveLetter!" "SUCCESS"
            return $true
        }
    }
    
    Write-MountLog "Mount thất bại sau $maxWait giây chờ đợi." "ERROR"
    return $false
}

function Check-MountHealth {
    Write-MountLog "Kiểm tra tình trạng ổ đĩa $DriveLetter..." "INFO"
    if (Test-MountStatus) {
        Write-MountLog "Ổ đĩa $DriveLetter đang hoạt động bình thường." "SUCCESS"
        return $true
    } else {
        Write-MountLog "Ổ đĩa $DriveLetter KHÔNG hoạt động. Đang thử phục hồi tự động..." "WARN"
        return (Start-RcloneMount)
    }
}

function Reconnect-RcloneRemote {
    $rcloneBin = Get-RcloneBinary
    if (-not $rcloneBin) {
        Write-MountLog "Lỗi: Không tìm thấy rclone.exe!" "ERROR"
        return
    }
    Write-Host "`n==================================================================" -ForegroundColor Cyan
    Write-Host "  🔑 BẮT ĐẦU ĐĂNG NHẬP / LÀM MỚI TOKEN OAUTH CHO $Remote          " -ForegroundColor Yellow
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host "Trình duyệt web sẽ mở ra để bạn đăng nhập tài khoản Microsoft 365." -ForegroundColor White
    Write-Host "Hãy cấp quyền (Accept) khi được hỏi.`n" -ForegroundColor White
    
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$rcloneBin`" config reconnect $Remote & pause"
}

# --- Thực thi theo Action ---
switch ($Action) {
    "Mount" {
        $res = Start-RcloneMount
        if (-not $res) { exit 1 }
    }
    "Unmount" {
        $res = Stop-RcloneMount
    }
    "Restart" {
        Stop-RcloneMount | Out-Null
        $res = Start-RcloneMount
        if (-not $res) { exit 1 }
    }
    "Check" {
        $res = Check-MountHealth
        if (-not $res) { exit 1 }
    }
    "Reconnect" {
        Reconnect-RcloneRemote
    }
    "Status" {
        $isMounted = Test-MountStatus
        if ($isMounted) {
            Write-Host "STATUS: MOUNTED ($DriveLetter -> $Remote)" -ForegroundColor Green
            exit 0
        } else {
            Write-Host "STATUS: NOT MOUNTED ($DriveLetter)" -ForegroundColor Red
            exit 1
        }
    }
}
