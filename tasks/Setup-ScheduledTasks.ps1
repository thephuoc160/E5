<#
.SYNOPSIS
    Thiết lập lịch chạy tự động Task Scheduler cho E5 Renew
.DESCRIPTION
    Tạo các tác vụ tự động trong Windows Task Scheduler với cơ chế chạy ẩn,
    hỗ trợ pin laptop (AllowStartIfOnBatteries) và chu kỳ lặp lại tùy chọn (24h/48h).
.PARAMETER IntervalHours
    Khoảng thời gian lặp lại giữa các lần chạy (Mặc định: 48 giờ)
#>

[CmdletBinding()]
param(
    [int]$IntervalHours = 48,
    [switch]$IncludePythonPing
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RootDir = Split-Path -Parent $ScriptDir

$MountBat = Join-Path $RootDir "#1.M_Drive.bat"
$ActivityBat = Join-Path $RootDir "#2.run_activity.bat"
$RunAllBat = Join-Path $RootDir "Run-All.bat"
$PythonScript = Join-Path $RootDir "python\PingE5_App.py"

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "    CÀI ĐẶT LỊCH TỰ ĐỘNG E5 RENEW (TASK SCHEDULER)" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Chu kỳ lặp: Mỗi $IntervalHours giờ" -ForegroundColor Yellow
Write-Host ""

# Xóa toàn bộ task cũ/trùng lặp
$legacyTasks = @(
    "E5_Check_Mount",
    "E5_API_Activity",
    "E5_SharePoint_API",
    "1. E5_Mount",
    "2. E5_Activity",
    "E5_Mount",
    "E5_Activity",
    "E5_PythonPing"
)

foreach ($t in $legacyTasks) {
    Unregister-ScheduledTask -TaskName $t -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 2)

# --- Task 1: 1. E5_Mount ---
$actionMount = New-ScheduledTaskAction -Execute $MountBat
$triggerMount = New-ScheduledTaskTrigger -Daily -At "10:00AM"
$triggerMount.Repetition = (New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours $IntervalHours)).Repetition

Register-ScheduledTask -TaskName "1. E5_Mount" `
    -Action $actionMount `
    -Trigger $triggerMount `
    -Settings $settings `
    -Description "E5 Auto Mount M: Drive (OneDrive/SharePoint) - Runs every $IntervalHours hours" `
    -Force | Out-Null

Write-Host "  ✅ Đã tạo tác vụ: 1. E5_Mount" -ForegroundColor Green

# --- Task 2: 2. E5_Activity ---
$actionActivity = New-ScheduledTaskAction -Execute $ActivityBat
$triggerActivity = New-ScheduledTaskTrigger -Daily -At "10:05AM"
$triggerActivity.Repetition = (New-ScheduledTaskTrigger -Once -At ((Get-Date).AddMinutes(5)) -RepetitionInterval (New-TimeSpan -Hours $IntervalHours)).Repetition

Register-ScheduledTask -TaskName "2. E5_Activity" `
    -Action $actionActivity `
    -Trigger $triggerActivity `
    -Settings $settings `
    -Description "E5 API Activities & Graph Renew - Runs every $IntervalHours hours" `
    -Force | Out-Null

Write-Host "  ✅ Đã tạo tác vụ: 2. E5_Activity" -ForegroundColor Green

# --- Task 3 (Tùy chọn): Python Ping ---
if ($IncludePythonPing) {
    $pythonExe = (Get-Command "python" -ErrorAction SilentlyContinue).Source
    if ($pythonExe) {
        $actionPy = New-ScheduledTaskAction -Execute $pythonExe -Argument "`"$PythonScript`""
        $triggerPy = New-ScheduledTaskTrigger -Daily -At "10:15AM"
        $triggerPy.Repetition = (New-ScheduledTaskTrigger -Once -At ((Get-Date).AddMinutes(15)) -RepetitionInterval (New-TimeSpan -Hours $IntervalHours)).Repetition

        Register-ScheduledTask -TaskName "3. E5_PythonPing" `
            -Action $actionPy `
            -Trigger $triggerPy `
            -Settings $settings `
            -Description "E5 Python Graph Ping Daemon" `
            -Force | Out-Null

        Write-Host "  ✅ Đã tạo tác vụ: 3. E5_PythonPing" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  HOÀN TẤT THIẾT LẬP LỊCH TỰ ĐỘNG!" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""
