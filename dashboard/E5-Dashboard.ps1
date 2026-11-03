<#
.SYNOPSIS
    Microsoft 365 E5 Renew - Modern Web Dashboard & API Server
.DESCRIPTION
    Phục vụ mẫu Dashboard UTF-8 với CSS cục bộ,
    giao diện sáng, theo dõi trạng thái thời gian thực và
    cho phép CHẠY TRỰC TIẾP mọi mã nguồn từ giao diện Web.
.PARAMETER Serve
    Chạy máy chủ web cục bộ (port 5500)
.PARAMETER Port
    Cổng web server (Mặc định: 5500)
.PARAMETER NoBrowser
    Không tự động mở trình duyệt
#>

[CmdletBinding()]
param(
    [switch]$NoServe,
    [int]$Port = 5500,
    [switch]$NoBrowser
)

$Serve = -not $NoServe

$ErrorActionPreference = "Continue"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RootDir = Split-Path -Parent $ScriptDir
$ConfigPath = Join-Path $RootDir "config\config.json"
$LogDir = Join-Path $RootDir "logs"
$HtmlPath = Join-Path $ScriptDir "Dashboard.html"

# 1. Thu thập dữ liệu trạng thái
function Get-E5Telemetry {
    $cfg = @{}
    if (Test-Path $ConfigPath) {
        try {
            $cfg = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
        } catch {}
    }

    $driveLetter = if ($cfg.rclone.driveLetter) { $cfg.rclone.driveLetter } else { "M:" }
    $isMounted = Test-Path "$driveLetter\" -ErrorAction SilentlyContinue
    $mountRemote = if ($cfg.rclone.oneDriveRemote) { $cfg.rclone.oneDriveRemote } else { "1Drive:" }

    # Trạng thái Task Scheduler
    $tasksInfo = @()
    $tasksError = $null
    $availableTasks = @()
    try {
        $availableTasks = @(Get-ScheduledTask -ErrorAction Stop)
    } catch {
        $tasksError = "Không đọc được lịch chạy. Kiểm tra quyền truy cập Task Scheduler rồi cập nhật lại."
    }
    $targetTasks = @("1. E5_Mount", "2. E5_Activity", "3. E5_PythonPing")
    foreach ($t in $targetTasks) {
        $taskObj = $availableTasks | Where-Object TaskName -eq $t | Select-Object -First 1
        if ($taskObj) {
            $info = Get-ScheduledTaskInfo -TaskName $t -ErrorAction SilentlyContinue
            $tasksInfo += [PSCustomObject]@{
                Name        = $t
                State       = $taskObj.State.ToString()
                LastRun     = if ($info.LastRunTime -and $info.LastRunTime.Year -gt 1999) { $info.LastRunTime.ToString("yyyy-MM-dd HH:mm:ss") } else { "Chưa chạy" }
                NextRun     = if ($info.NextRunTime -and $info.NextRunTime.Year -gt 1999) { $info.NextRunTime.ToString("yyyy-MM-dd HH:mm:ss") } else { "Chưa lên lịch" }
                LastResult  = if ($info) { $info.LastTaskResult } else { 0 }
            }
        }
    }

    # Đọc logs gần nhất
    $recentLogs = @()
    $logFiles = @(
        (Join-Path $LogDir "graph_activity.log"),
        (Join-Path $LogDir "master_run.log"),
        (Join-Path $LogDir "mount.log"),
        (Join-Path $LogDir "sharepoint_activity.log"),
        (Join-Path $LogDir "sync_log.txt")
    )

    foreach ($lf in $logFiles) {
        if (Test-Path $lf) {
            $lines = Get-Content $lf -Tail 25 -Encoding UTF8 -ErrorAction SilentlyContinue
            foreach ($line in $lines) {
                if (-not [string]::IsNullOrWhiteSpace($line)) {
                    $recentLogs += [PSCustomObject]@{
                        File = (Split-Path -Leaf $lf)
                        Text = $line
                    }
                }
            }
        }
    }

    # Thống kê hoạt động
    $graphLogFile = Join-Path $LogDir "graph_activity.log"
    $successCount = 0
    $warnCount = 0
    $errorCount = 0
    if (Test-Path $graphLogFile) {
        $allGraphLogs = Get-Content $graphLogFile -Encoding UTF8 -ErrorAction SilentlyContinue
        $successCount = ($allGraphLogs | Where-Object { $_ -like "*SUCCESS*" }).Count
        $warnCount    = ($allGraphLogs | Where-Object { $_ -like "*WARN*" }).Count
        $errorCount   = ($allGraphLogs | Where-Object { $_ -like "*ERROR*" }).Count
    }

    return [PSCustomObject]@{
        GeneratedAt   = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        TenantId      = if ($cfg.azure.tenantId) { $cfg.azure.tenantId } else { "YOUR_TENANT_ID" }
        UserUPN       = if ($cfg.azure.userPrincipalName) { $cfg.azure.userPrincipalName } else { "admin@yourdomain.onmicrosoft.com" }
        IsMounted     = $isMounted
        DriveLetter   = $driveLetter
        MountRemote   = $mountRemote
        Tasks         = $tasksInfo
        TasksError    = $tasksError
        SuccessCount  = $successCount
        WarnCount     = $warnCount
        ErrorCount    = $errorCount
        RecentLogs    = ($recentLogs | Select-Object -Last 35)
    }
}

# 2. Thực thi lệnh từ Dashboard Web API
function Invoke-DashboardAction {
    param([string]$Action)

    $result = [ordered]@{
        Action    = $Action
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Success   = $false
        Output    = ""
        ExitCode  = -1
    }

    $cmd = ""
    switch ($Action) {
        "reconnect_1drive" {
            Start-Process -FilePath (Join-Path $RootDir "launchers\Reconnect-1Drive.bat")
            $result.Success = $true
            $result.Output = "Đã mở cửa sổ đăng nhập lại OneDrive."
            $result.ExitCode = 0
            return $result
        }
        "run_all" {
            $cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$RootDir\launchers\Run-All.ps1`""
        }
        "mount" {
            $cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$RootDir\core\E5-RcloneMount.ps1`" -Action Mount"
        }
        "unmount" {
            $cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$RootDir\core\E5-RcloneMount.ps1`" -Action Unmount"
        }
        "check_mount" {
            $cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$RootDir\core\E5-RcloneMount.ps1`" -Action Check"
        }
        "graph_activity" {
            $cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$RootDir\core\E5-GraphActivity.ps1`" -BasePath `"M:\API_Output`" -EnableGraphActivities"
        }
        "sharepoint_sync" {
            $cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$RootDir\core\E5-SharePointSync.ps1`""
        }
        "python_app" {
            $cmd = "python `"$RootDir\python\PingE5_App.py`""
        }
        "onedrive_sync" {
            $cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$RootDir\core\E5-OneDriveSync.ps1`""
        }
        "setup_tasks" {
            $cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$RootDir\tasks\Setup-ScheduledTasks.ps1`" -IntervalHours 48"
        }
        "check_tasks" {
            $cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$RootDir\tasks\Check-TaskStatus.ps1`""
        }
        "quick_renew" {
            $cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$RootDir\core\E5-RenewHelper.ps1`" -Action QuickRenew"
        }
        "create_draft" {
            $cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$RootDir\core\E5-RenewHelper.ps1`" -Action CreateDraft"
        }
        default {
            $result.Output = "Action không hợp lệ: $Action"
            return $result
        }
    }

    try {
        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $pinfo.FileName = "cmd.exe"
        $pinfo.Arguments = "/c chcp 65001 >nul & $cmd"
        $pinfo.EnvironmentVariables["PYTHONIOENCODING"] = "utf-8"
        $pinfo.RedirectStandardOutput = $true
        $pinfo.RedirectStandardError = $true
        $pinfo.UseShellExecute = $false
        $pinfo.CreateNoWindow = $true
        $pinfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $pinfo.StandardErrorEncoding = [System.Text.Encoding]::UTF8

        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $pinfo
        $proc.Start() | Out-Null

        $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
        $stderrTask = $proc.StandardError.ReadToEndAsync()
        if (-not $proc.WaitForExit(300000)) {
            $proc.Kill()
            $result.Output = "Lệnh đã bị dừng vì vượt quá thời gian chờ 300 giây."
            return $result
        }
        $stdout = $stdoutTask.Result
        $stderr = $stderrTask.Result

        $result.ExitCode = $proc.ExitCode
        $result.Success = ($proc.ExitCode -eq 0)
        $outText = ($stdout + "`n" + $stderr).Trim()
        $result.Output = if ($outText) { $outText } else { "Lệnh thực thi thành công (Không có output)." }
    } catch {
        $result.Success = $false
        $result.Output = "Lỗi thực thi tiến trình: $($_.Exception.Message)"
    }

    return $result
}

# 3. Read the source template explicitly as UTF-8 on Windows PowerShell 5.1.
function Build-DashboardHtml {
    $templatePath = Join-Path $ScriptDir "dashboard.template.html"
    $html = [System.IO.File]::ReadAllText($templatePath, [System.Text.Encoding]::UTF8)
    [System.IO.File]::WriteAllText($HtmlPath, $html, (New-Object System.Text.UTF8Encoding($false)))
    return $HtmlPath
}


# 4. Khởi chạy & Server Listener
$generatedHtml = Build-DashboardHtml

if (-not $NoBrowser) {
    if ($Serve) {
        Start-Process "http://localhost:$Port"
    } else {
        Start-Process $generatedHtml
    }
}

if ($Serve) {
    Write-Host ""
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host "  🚀 E5 RENEW WEB DASHBOARD SERVER ĐANG CHẠY TRÊN CỔNG $Port      " -ForegroundColor Yellow
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host "  Địa chỉ Dashboard : http://localhost:$Port" -ForegroundColor Green
    Write-Host "  Tính năng Web     : Hỗ trợ CHẠY TRỰC TIẾP mọi mã nguồn từ trình duyệt" -ForegroundColor White
    Write-Host "  Nhấn Ctrl+C để dừng server." -ForegroundColor Gray
    Write-Host ""

    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://localhost:$Port/")

    try {
        $listener.Start()
    } catch {
        Write-Warning "Không thể bind port $Port : $($_.Exception.Message)"
        exit 1
    }

    while ($listener.IsListening) {
        $res = $null
        try {
            $context = $listener.GetContext()
            $req = $context.Request
            $res = $context.Response

            $origin = $req.Headers["Origin"]
            $allowedOrigins = @(
                "http://localhost:$Port",
                "http://127.0.0.1:$Port"
            )
            $trustedOrigin = (-not $origin) -or ($origin -in $allowedOrigins)
            if (-not $trustedOrigin) {
                $res.StatusCode = 403
                $res.Close()
                continue
            }

            # Chỉ phản hồi CORS cho chính Dashboard local.
            if ($origin) {
                $res.AddHeader("Access-Control-Allow-Origin", $origin)
                $res.AddHeader("Vary", "Origin")
            }
            $res.AddHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
            $res.AddHeader("Access-Control-Allow-Headers", "Content-Type")
            $res.AddHeader("X-Content-Type-Options", "nosniff")
            $res.AddHeader("Referrer-Policy", "no-referrer")
            $res.AddHeader("X-Frame-Options", "DENY")
            $res.AddHeader("Content-Security-Policy", "default-src 'self'; script-src 'self' 'unsafe-inline' https://cdn.tailwindcss.com; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src https://fonts.gstatic.com; connect-src 'self'; img-src 'self' data:; object-src 'none'; base-uri 'none'; frame-ancestors 'none'; form-action 'none'")

            if ($req.HttpMethod -eq "OPTIONS") {
                $res.StatusCode = 204
                $res.Close()
                continue
            }

            # REST API: Status
            if ($req.Url.AbsolutePath -eq "/api/status") {
                $tele = Get-E5Telemetry
                $json = $tele | ConvertTo-Json -Depth 6
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
                $res.ContentType = "application/json; charset=utf-8"
                $res.OutputStream.Write($bytes, 0, $bytes.Length)
                $res.Close()
                continue
            }

            # REST API: Direct Execution
            if ($req.HttpMethod -eq "POST" -and $req.Url.AbsolutePath -eq "/api/run") {
                if ($req.ContentType -notlike "application/json*") {
                    $res.StatusCode = 415
                    $res.Close()
                    continue
                }
                if ($req.ContentLength64 -lt 1 -or $req.ContentLength64 -gt 4096) {
                    $res.StatusCode = 413
                    $res.Close()
                    continue
                }
                $reader = New-Object System.IO.StreamReader($req.InputStream, [System.Text.Encoding]::UTF8)
                $bodyStr = $reader.ReadToEnd()
                $jsonBody = $bodyStr | ConvertFrom-Json
                $actionName = $jsonBody.action

                Write-Host "[API RUN] Yêu cầu thực thi: $actionName" -ForegroundColor Cyan
                $execResult = Invoke-DashboardAction -Action $actionName

                $resJson = $execResult | ConvertTo-Json -Depth 4
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($resJson)
                $res.ContentType = "application/json; charset=utf-8"
                $res.OutputStream.Write($bytes, 0, $bytes.Length)
                $res.Close()
                continue
            }

            # Serve Dashboard HTML
            Build-DashboardHtml | Out-Null
            $htmlBytes = [System.IO.File]::ReadAllBytes($HtmlPath)
            $res.ContentType = "text/html; charset=utf-8"
            $res.OutputStream.Write($htmlBytes, 0, $htmlBytes.Length)
            $res.Close()
        } catch {
            if ($res) {
                try {
                    $res.StatusCode = 500
                    $res.Close()
                } catch {}
            }
            Start-Sleep -Milliseconds 100
        }
    }
}
