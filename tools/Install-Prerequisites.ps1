<#
.SYNOPSIS
    Cài đặt các gói phụ thuộc (Microsoft.Graph PowerShell SDK & Python requirements)
#>

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "    CÀI ĐẶT MÔI TRƯỜNG & PHỤ THUỘC E5 RENEW" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# 1. PowerShell Modules
Write-Host "[1/3] Kiểm tra và cài đặt Microsoft Graph PowerShell Modules..." -ForegroundColor Yellow
$graphModules = @(
    "Microsoft.Graph.Authentication",
    "Microsoft.Graph.Users",
    "Microsoft.Graph.Mail",
    "Microsoft.Graph.Calendar",
    "Microsoft.Graph.Teams",
    "Microsoft.Graph.Planner",
    "Microsoft.Graph.Sites",
    "Microsoft.Graph.Applications",
    "Microsoft.Graph.Identity.DirectoryManagement"
)

foreach ($mod in $graphModules) {
    if (Get-Module -ListAvailable -Name $mod) {
        Write-Host "  ✅ Đã cài đặt: $mod" -ForegroundColor Green
    } else {
        Write-Host "  ⏳ Đang cài đặt: $mod..." -ForegroundColor Cyan
        try {
            Install-Module -Name $mod -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
            Write-Host "  ✅ Đã cài đặt thành công: $mod" -ForegroundColor Green
        } catch {
            Write-Host "  ❌ Lỗi khi cài đặt $mod : $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# 2. Python Packages
Write-Host ""
Write-Host "[2/3] Kiểm tra Python & thư viện Python..." -ForegroundColor Yellow
$pythonExe = Get-Command "python" -ErrorAction SilentlyContinue
if ($pythonExe) {
    Write-Host "  ✅ Tìm thấy Python: $($pythonExe.Source)" -ForegroundColor Green
    $reqFile = Join-Path (Split-Path -Parent $PSScriptRoot) "python\requirements.txt"
    if (Test-Path $reqFile) {
        Write-Host "  ⏳ Đang cài đặt requirements qua pip..." -ForegroundColor Cyan
        pip install -r $reqFile
    }
} else {
    Write-Host "  ⚠️ Không tìm thấy Python trong PATH. Nếu muốn dùng các script Python, vui lòng cài đặt Python." -ForegroundColor Yellow
}

# 3. Rclone & WinFsp
Write-Host ""
Write-Host "[3/3] Kiểm tra Rclone..." -ForegroundColor Yellow
$rcloneExe = Join-Path $PSScriptRoot "rclone.exe"
if (Test-Path $rcloneExe) {
    $version = & $rcloneExe version | Select-Object -First 1
    Write-Host "  ✅ Rclone sẵn sàng: $version" -ForegroundColor Green
} else {
    Write-Host "  ⚠️ Không tìm thấy rclone.exe trong tools." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  HOÀN TẤT CÀI ĐẶT MÔI TRƯỜNG!" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Cyan
