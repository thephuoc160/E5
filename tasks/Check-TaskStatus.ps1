<#
.SYNOPSIS
    Kiểm tra trạng thái các tác vụ Task Scheduler của E5 Renew
#>

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "     TRẠNG THÁI TASK SCHEDULER E5 RENEW" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

$tasks = Get-ScheduledTask | Where-Object { $_.TaskName -like "*E5*" -or $_.TaskName -like "*Renew*" }

if (-not $tasks -or $tasks.Count -eq 0) {
    Write-Host "Không tìm thấy tác vụ E5 nào đang đăng ký trong Task Scheduler." -ForegroundColor Yellow
} else {
    foreach ($task in $tasks) {
        $info = Get-ScheduledTaskInfo -TaskName $task.TaskName -ErrorAction SilentlyContinue
        Write-Host "📌 Tên tác vụ : " -NoNewline; Write-Host $task.TaskName -ForegroundColor Green
        Write-Host "   Trạng thái : " -NoNewline; Write-Host $task.State -ForegroundColor Yellow
        if ($info) {
            Write-Host "   Chạy gần nhất : $($info.LastRunTime) (Mã kết quả: $($info.LastTaskResult))"
            Write-Host "   Chạy kế tiếp  : $($info.NextRunTime)"
        }
        Write-Host ""
    }
}

Write-Host "==================================================" -ForegroundColor Cyan
