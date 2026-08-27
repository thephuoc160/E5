<#
.SYNOPSIS
    Gỡ bỏ tất cả các tác vụ Task Scheduler của E5 Renew
#>

$allTasks = @(
    "1. E5_Mount",
    "2. E5_Activity",
    "3. E5_PythonPing",
    "E5_Check_Mount",
    "E5_API_Activity",
    "E5_SharePoint_API",
    "E5_Mount",
    "E5_Activity"
)

Write-Host "Đang gỡ bỏ các tác vụ E5 trong Task Scheduler..." -ForegroundColor Yellow

foreach ($t in $allTasks) {
    $exists = Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue
    if ($exists) {
        Unregister-ScheduledTask -TaskName $t -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "  ✅ Đã xóa: $t" -ForegroundColor Green
    }
}

Write-Host "Hoàn tất gỡ bỏ!" -ForegroundColor Cyan
