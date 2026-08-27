<#
.SYNOPSIS
    Microsoft 365 E5 Renew - Bảng điều khiển trung tâm (Interactive Control Menu)
#>

function Show-E5Menu {
    Clear-Host
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host "           MICROSOFT 365 E5 DEVELOPER RENEW CONTROL CENTER        " -ForegroundColor Yellow
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [D]  📊 MỞ DASHBOARD QUẢN LÝ THEO DÕI (Web Dashboard)" -ForegroundColor Magenta
    Write-Host "  [1]  🚀 Chạy toàn bộ chu trình Renew (Run All)" -ForegroundColor Green
    Write-Host "  [2]  📁 Mount ổ đĩa M: (OneDrive / SharePoint)" -ForegroundColor White
    Write-Host "  [3]  🔌 Unmount ổ đĩa M:" -ForegroundColor White
    Write-Host "  [4]  ⚡ Chạy hoạt động Microsoft Graph (Teams, Mail, Planner, To-Do)" -ForegroundColor White
    Write-Host "  [5]  🌐 Chạy hoạt động SharePoint API (rclone)" -ForegroundColor White
    Write-Host "  [6]  🐍 Chạy Python Ping E5 (App Credentials Daemon)" -ForegroundColor White
    Write-Host "  [7]  🌐 Chạy Python Ping E5 Interactive (User Auth - Web Browser)" -ForegroundColor White
    Write-Host "  [8]  🔄 Đồng bộ OneDrive Business sang Personal (Robocopy)" -ForegroundColor White
    Write-Host "  [9]  🛠️ Tiện ích phụ (Quick Renew, Tạo Draft Email, Tải Cloud Files)" -ForegroundColor White
    Write-Host "  [10] ⏰ Quản lý Task Scheduler (Cài đặt / Kiểm tra / Gỡ bỏ)" -ForegroundColor White
    Write-Host "  [11] 📦 Cài đặt môi trường & Modules phụ thuộc" -ForegroundColor White
    Write-Host "  [12] 🔑 Đăng nhập / Làm mới OAuth Token cho rclone (1Drive)" -ForegroundColor Yellow
    Write-Host "  [G]  🌐 Đẩy mã nguồn lên GitHub (thephuoc160/E5)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [0]  🚪 Thoát" -ForegroundColor Red
    Write-Host ""
    Write-Host "==================================================================" -ForegroundColor Cyan
}

$RootDir = $PSScriptRoot

do {
    Show-E5Menu
    $choice = Read-Host "Nhập lựa chọn của bạn [D, 0-11]"
    Write-Host ""

    switch ($choice.ToUpper()) {
        "D" {
            Start-Process -FilePath (Join-Path $RootDir "Dashboard.bat")
            Write-Host "Đã khởi động Dashboard Server tại http://127.0.0.1:8765" -ForegroundColor Green
            Write-Host "`nNhấn phím bất kỳ để quay lại menu..." -ForegroundColor Gray
            [Console]::ReadKey($true) | Out-Null
        }
        "1" {
            & (Join-Path $RootDir "Run-All.ps1")
            Write-Host "`nNhấn phím bất kỳ để quay lại menu..." -ForegroundColor Gray
            [Console]::ReadKey($true) | Out-Null
        }
        "2" {
            & (Join-Path $RootDir "core\E5-RcloneMount.ps1") -Action Mount
            Write-Host "`nNhấn phím bất kỳ để quay lại menu..." -ForegroundColor Gray
            [Console]::ReadKey($true) | Out-Null
        }
        "3" {
            & (Join-Path $RootDir "core\E5-RcloneMount.ps1") -Action Unmount
            Write-Host "`nNhấn phím bất kỳ để quay lại menu..." -ForegroundColor Gray
            [Console]::ReadKey($true) | Out-Null
        }
        "4" {
            & (Join-Path $RootDir "core\E5-GraphActivity.ps1") -EnableGraphActivities
            Write-Host "`nNhấn phím bất kỳ để quay lại menu..." -ForegroundColor Gray
            [Console]::ReadKey($true) | Out-Null
        }
        "5" {
            & (Join-Path $RootDir "core\E5-SharePointSync.ps1")
            Write-Host "`nNhấn phím bất kỳ để quay lại menu..." -ForegroundColor Gray
            [Console]::ReadKey($true) | Out-Null
        }
        "6" {
            $pyScript = Join-Path $RootDir "python\PingE5_App.py"
            python $pyScript
            Write-Host "`nNhấn phím bất kỳ để quay lại menu..." -ForegroundColor Gray
            [Console]::ReadKey($true) | Out-Null
        }
        "7" {
            $pyScript = Join-Path $RootDir "python\PingE5_User.py"
            Start-Process "http://localhost:8000"
            python $pyScript
            Write-Host "`nNhấn phím bất kỳ để quay lại menu..." -ForegroundColor Gray
            [Console]::ReadKey($true) | Out-Null
        }
        "8" {
            & (Join-Path $RootDir "core\E5-OneDriveSync.ps1")
            Write-Host "`nNhấn phím bất kỳ để quay lại menu..." -ForegroundColor Gray
            [Console]::ReadKey($true) | Out-Null
        }
        "9" {
            Write-Host "[1] Quick Renew (Tạo thư mục test Graph)"
            Write-Host "[2] Tạo Draft Email"
            Write-Host "[3] Tải toàn bộ file Cloud Placeholder"
            $sub = Read-Host "Chọn tính năng [1-3]"
            switch ($sub) {
                "1" { & (Join-Path $RootDir "core\E5-RenewHelper.ps1") -Action QuickRenew }
                "2" { & (Join-Path $RootDir "core\E5-RenewHelper.ps1") -Action CreateDraft }
                "3" { & (Join-Path $RootDir "core\E5-RenewHelper.ps1") -Action DownloadPlaceholders }
            }
            Write-Host "`nNhấn phím bất kỳ để quay lại menu..." -ForegroundColor Gray
            [Console]::ReadKey($true) | Out-Null
        }
        "10" {
            Write-Host "[1] Xem trạng thái các Task hiện tại"
            Write-Host "[2] Cài đặt / Đăng ký lại Task Scheduler (Mỗi 48 giờ)"
            Write-Host "[3] Gỡ bỏ tất cả Task Scheduler E5"
            $sub = Read-Host "Chọn thao tác [1-3]"
            switch ($sub) {
                "1" { & (Join-Path $RootDir "tasks\Check-TaskStatus.ps1") }
                "2" { & (Join-Path $RootDir "tasks\Setup-ScheduledTasks.ps1") -IntervalHours 48 }
                "3" { & (Join-Path $RootDir "tasks\Remove-ScheduledTasks.ps1") }
            }
            Write-Host "`nNhấn phím bất kỳ để quay lại menu..." -ForegroundColor Gray
            [Console]::ReadKey($true) | Out-Null
        }
        "11" {
            & (Join-Path $RootDir "tools\Install-Prerequisites.ps1")
            Write-Host "`nNhấn phím bất kỳ để quay lại menu..." -ForegroundColor Gray
            [Console]::ReadKey($true) | Out-Null
        }
        "12" {
            & (Join-Path $RootDir "core\E5-RcloneMount.ps1") -Action Reconnect -Remote "1Drive:"
            Write-Host "`nNhấn phím bất kỳ để quay lại menu..." -ForegroundColor Gray
            [Console]::ReadKey($true) | Out-Null
        }
        "G" {
            Start-Process -FilePath (Join-Path $RootDir "Push-To-GitHub.bat")
            Write-Host "Đang mở cửa sổ đồng bộ mã nguồn lên GitHub (thephuoc160/E5)..." -ForegroundColor Cyan
            Write-Host "`nNhấn phím bất kỳ để quay lại menu..." -ForegroundColor Gray
            [Console]::ReadKey($true) | Out-Null
        }
        "0" {
            Write-Host "Tạm biệt!" -ForegroundColor Yellow
            break
        }
        default {
            Write-Host "Lựa chọn không hợp lệ. Vui lòng thử lại." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
} while ($true)
