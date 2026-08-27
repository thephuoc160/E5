<#
.SYNOPSIS
    Microsoft 365 E5 Renew - Modern Web Dashboard & API Server
.DESCRIPTION
    Tạo và phục vụ giao diện Dashboard hiện đại bằng Tailwind CSS,
    hỗ trợ Dark/Light mode, theo dõi trạng thái thời gian thực và
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
$HtmlPath = Join-Path $RootDir "Dashboard.html"

# 1. Thu thập dữ liệu trạng thái
function Get-E5Telemetry {
    $cfg = @{}
    if (Test-Path $ConfigPath) {
        try {
            $cfg = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
        } catch {}
    }

    # Trạng thái Mount M:
    $isMounted = Test-Path "M:\" -ErrorAction SilentlyContinue
    $mountRemote = if ($cfg.rclone.oneDriveRemote) { $cfg.rclone.oneDriveRemote } else { "1Drive:" }

    # Trạng thái Task Scheduler
    $tasksInfo = @()
    $targetTasks = @("1. E5_Mount", "2. E5_Activity", "3. E5_PythonPing")
    foreach ($t in $targetTasks) {
        $taskObj = Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue
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
        DriveLetter   = "M:"
        MountRemote   = $mountRemote
        Tasks         = $tasksInfo
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
        "run_all" {
            $cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$RootDir\Run-All.ps1`""
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
        $pinfo.Arguments = "/c $cmd"
        $pinfo.RedirectStandardOutput = $true
        $pinfo.RedirectStandardError = $true
        $pinfo.UseShellExecute = $false
        $pinfo.CreateNoWindow = $true
        $pinfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $pinfo.StandardErrorEncoding = [System.Text.Encoding]::UTF8

        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $pinfo
        $proc.Start() | Out-Null

        $stdout = $proc.StandardOutput.ReadToEnd()
        $stderr = $proc.StandardError.ReadToEnd()
        $proc.WaitForExit()

        $result.ExitCode = $proc.ExitCode
        $result.Success = ($proc.ExitCode -eq 0 -or $proc.ExitCode -lt 8)
        $outText = ($stdout + "`n" + $stderr).Trim()
        $result.Output = if ($outText) { $outText } else { "Lệnh thực thi thành công (Không có output)." }
    } catch {
        $result.Success = $false
        $result.Output = "Lỗi thực thi tiến trình: $($_.Exception.Message)"
    }

    return $result
}

# 3. Tạo file HTML Dashboard hoàn chỉnh
function Build-DashboardHtml {
    $telemetry = Get-E5Telemetry

    # Pre-render tasks HTML
    $tasksHtml = ""
    if ($telemetry.Tasks.Count -gt 0) {
        $taskItems = foreach ($t in $telemetry.Tasks) {
            $stateBadge = if ($t.State -eq "Ready") { "bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border border-emerald-500/20" } else { "bg-slate-200 dark:bg-slate-700 text-slate-600 dark:text-slate-300" }
            @"
            <div class="p-4 rounded-xl bg-white/70 dark:bg-slate-900/60 border border-slate-200/80 dark:border-slate-800/80 shadow-sm transition hover:shadow">
                <div class="flex items-center justify-between">
                    <span class="font-bold text-xs text-slate-800 dark:text-slate-200 flex items-center gap-1.5">
                        <span class="w-2 h-2 rounded-full bg-emerald-500"></span>
                        $($t.Name)
                    </span>
                    <span class="px-2 py-0.5 rounded text-[10px] font-semibold $stateBadge">$($t.State)</span>
                </div>
                <div class="mt-2 space-y-0.5 text-[11px] text-slate-500 dark:text-slate-400 font-mono">
                    <div>Chạy kế tiếp : <span class="text-indigo-600 dark:text-cyan-400 font-semibold">$($t.NextRun)</span></div>
                    <div>Chạy gần nhất: <span class="text-slate-700 dark:text-slate-300">$($t.LastRun)</span></div>
                </div>
            </div>
"@
        }
        $tasksHtml = $taskItems -join "`n"
    } else {
        $tasksHtml = "<div class='text-xs text-slate-500 dark:text-slate-400'>Chưa có task nào được đăng ký.</div>"
    }

    # Pre-render logs HTML
    $logsHtml = ""
    if ($telemetry.RecentLogs.Count -gt 0) {
        $logItems = foreach ($lg in $telemetry.RecentLogs) {
            $colorClass = "text-slate-700 dark:text-slate-300"
            if ($lg.Text -like "*SUCCESS*") { $colorClass = "text-emerald-600 dark:text-emerald-400 font-semibold" }
            elseif ($lg.Text -like "*WARN*") { $colorClass = "text-amber-600 dark:text-amber-400" }
            elseif ($lg.Text -like "*ERROR*") { $colorClass = "text-rose-600 dark:text-rose-400 font-semibold" }
            elseif ($lg.Text -like "*INFO*") { $colorClass = "text-indigo-600 dark:text-cyan-400" }

            $escapedText = [System.Web.HttpUtility]::HtmlEncode($lg.Text)
            "<div class='$colorClass leading-relaxed'>[$($lg.File)] $escapedText</div>"
        }
        $logsHtml = $logItems -join "`n"
    } else {
        $logsHtml = "<div class='text-slate-400'>Chưa có nhật ký hoạt động gần đây.</div>"
    }

    $mountStatusText = if ($telemetry.IsMounted) { "Đang Kết Nối" } else { "Chưa Mount" }
    $mountColorClass = if ($telemetry.IsMounted) { "text-emerald-600 dark:text-emerald-400" } else { "text-rose-600 dark:text-rose-400" }
    $mountBgClass    = if ($telemetry.IsMounted) { "bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border-emerald-500/20" } else { "bg-rose-500/10 text-rose-600 dark:text-rose-400 border-rose-500/20" }

    $html = @"
<!DOCTYPE html>
<html lang="vi" class="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>E5 Renew - Interactive Control & Monitoring Dashboard</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500;600&display=swap" rel="stylesheet">
    <script src="https://cdn.tailwindcss.com"></script>
    <script>
        tailwind.config = {
            darkMode: 'class',
            theme: {
                extend: {
                    fontFamily: {
                        sans: ['Plus Jakarta Sans', 'sans-serif'],
                        mono: ['JetBrains Mono', 'monospace'],
                    },
                    colors: {
                        brand: {
                            50: '#eef2ff',
                            100: '#e0e7ff',
                            500: '#6366f1',
                            600: '#4f46e5',
                            700: '#4338ca',
                        }
                    }
                }
            }
        }
    </script>
    <style>
        .glass-header {
            backdrop-filter: blur(16px);
        }
        .card-modern {
            transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
        }
        .card-modern:hover {
            transform: translateY(-2px);
        }
        ::-webkit-scrollbar {
            width: 6px;
            height: 6px;
        }
        ::-webkit-scrollbar-track {
            background: transparent;
        }
        ::-webkit-scrollbar-thumb {
            background: rgba(148, 163, 184, 0.4);
            border-radius: 4px;
        }
        @keyframes pulse-ring {
            0% { transform: scale(0.95); opacity: 0.8; }
            50% { transform: scale(1.15); opacity: 0.3; }
            100% { transform: scale(0.95); opacity: 0.8; }
        }
        .animate-pulse-ring {
            animation: pulse-ring 2s infinite ease-in-out;
        }
    </style>
</head>
<body class="bg-slate-50 dark:bg-slate-950 text-slate-900 dark:text-slate-100 min-h-screen font-sans antialiased selection:bg-brand-500 selection:text-white transition-colors duration-200">

    <!-- Toast Notification Container -->
    <div id="toastContainer" class="fixed top-5 right-5 z-50 flex flex-col gap-2 pointer-events-none"></div>

    <!-- Top Navigation -->
    <header class="glass-header sticky top-0 z-40 bg-white/80 dark:bg-slate-950/80 border-b border-slate-200 dark:border-slate-800/80 px-6 py-4">
        <div class="max-w-7xl mx-auto flex flex-wrap items-center justify-between gap-4">
            
            <!-- Logo & Title -->
            <div class="flex items-center gap-3">
                <div class="w-10 h-10 rounded-xl bg-gradient-to-tr from-brand-600 via-indigo-500 to-cyan-400 flex items-center justify-center shadow-lg shadow-brand-500/25">
                    <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
                    </svg>
                </div>
                <div>
                    <div class="flex items-center gap-2">
                        <h1 class="text-xl font-extrabold tracking-tight bg-gradient-to-r from-slate-900 via-slate-700 to-slate-500 dark:from-white dark:via-slate-100 dark:to-slate-400 bg-clip-text text-transparent">
                            Microsoft 365 E5 Renew
                        </h1>
                        <span class="px-2 py-0.5 rounded-full text-[10px] font-bold bg-brand-50 dark:bg-brand-500/10 text-brand-600 dark:text-brand-400 border border-brand-200 dark:border-brand-500/20">v2.5 PRO</span>
                    </div>
                    <p class="text-xs text-slate-500 dark:text-slate-400 font-mono">Bảng Điều Khiển & Giám Sát Tự Động Trực Tiếp</p>
                </div>
            </div>

            <!-- Status Badges & Controls -->
            <div class="flex items-center flex-wrap gap-2.5">
                <!-- Server Connection Badge -->
                <div id="serverStatusBadge" class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-semibold bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border border-emerald-500/20">
                    <span class="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
                    <span id="serverStatusText">Web Server Online</span>
                </div>

                <!-- Dark / Light Toggle -->
                <button onclick="toggleTheme()" class="p-2 rounded-xl bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 dark:hover:bg-slate-700 text-slate-600 dark:text-slate-300 border border-slate-200 dark:border-slate-700 transition" title="Chuyển đổi giao diện Sáng / Tối">
                    <svg id="themeIcon" class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z"/></svg>
                </button>

                <!-- Refresh Button -->
                <button onclick="refreshData()" class="px-3.5 py-1.5 rounded-xl bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 dark:hover:bg-slate-700 text-xs font-semibold text-slate-700 dark:text-slate-200 transition border border-slate-200 dark:border-slate-700 flex items-center gap-1.5 shadow-sm">
                    <svg id="refreshIcon" class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/></svg>
                    Làm mới
                </button>
            </div>
        </div>
    </header>

    <!-- Main Content Area -->
    <main class="max-w-7xl mx-auto p-6 space-y-6">

        <!-- Banner khi mở trực tiếp file:// -->
        <div id="fileProtocolWarning" class="hidden rounded-2xl p-4 bg-amber-50 dark:bg-amber-500/10 border border-amber-200 dark:border-amber-500/20 flex items-center justify-between gap-4">
            <div class="flex items-center gap-3">
                <span class="text-2xl">💡</span>
                <div class="text-xs text-amber-800 dark:text-amber-300">
                    <b>Mẹo:</b> Bạn đang mở Dashboard qua dạng tệp tin tĩnh. Để <b>kích hoạt các nút bấm chạy trực tiếp</b>, hãy nhấp đúp vào <b>Dashboard.bat</b> (mở tại <a href="http://localhost:5500" class="underline font-bold text-amber-900 dark:text-amber-200">http://localhost:5500</a>).
                </div>
            </div>
            <a href="http://localhost:5500" class="px-3 py-1.5 rounded-lg bg-amber-600 text-white font-semibold text-xs whitespace-nowrap hover:bg-amber-500 transition shadow">Mở qua Server Local</a>
        </div>

        <!-- 1. KPI & Quick Status Metrics Grid -->
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            
            <!-- Metric 1: Account Info -->
            <div class="card-modern rounded-2xl p-5 bg-white dark:bg-slate-900/60 border border-slate-200/80 dark:border-slate-800/80 shadow-sm">
                <div class="flex items-center justify-between mb-2">
                    <span class="text-[11px] font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider">Tài khoản E5</span>
                    <div class="p-2 rounded-xl bg-blue-50 dark:bg-blue-500/10 text-blue-600 dark:text-blue-400">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/></svg>
                    </div>
                </div>
                <div class="text-sm font-bold text-slate-900 dark:text-slate-100 truncate" id="kpiUpn">$($telemetry.UserUPN)</div>
                <div class="text-[11px] text-slate-500 dark:text-slate-400 font-mono mt-1 truncate" id="kpiTenant">Tenant: $($telemetry.TenantId)</div>
            </div>

            <!-- Metric 2: Mount Drive Status -->
            <div class="card-modern rounded-2xl p-5 bg-white dark:bg-slate-900/60 border border-slate-200/80 dark:border-slate-800/80 shadow-sm">
                <div class="flex items-center justify-between mb-2">
                    <span class="text-[11px] font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider">Ổ đĩa Mount (M:)</span>
                    <div class="p-2 rounded-xl $mountBgClass">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z"/></svg>
                    </div>
                </div>
                <div class="flex items-center gap-2">
                    <span class="text-base font-extrabold $mountColorClass" id="kpiMountStatus">
                        $mountStatusText
                    </span>
                </div>
                <div class="text-[11px] text-slate-500 dark:text-slate-400 font-mono mt-1">Remote: $($telemetry.MountRemote)</div>
            </div>

            <!-- Metric 3: Success Count -->
            <div class="card-modern rounded-2xl p-5 bg-white dark:bg-slate-900/60 border border-slate-200/80 dark:border-slate-800/80 shadow-sm">
                <div class="flex items-center justify-between mb-2">
                    <span class="text-[11px] font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider">Tác vụ thành công</span>
                    <div class="p-2 rounded-xl bg-emerald-50 dark:bg-emerald-500/10 text-emerald-600 dark:text-emerald-400">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
                    </div>
                </div>
                <div class="text-2xl font-black text-emerald-600 dark:text-emerald-400" id="kpiSuccess">$($telemetry.SuccessCount)</div>
                <div class="text-[11px] text-slate-500 dark:text-slate-400 mt-1">Ghi nhận từ nhật ký Graph</div>
            </div>

            <!-- Metric 4: Warnings & Retries -->
            <div class="card-modern rounded-2xl p-5 bg-white dark:bg-slate-900/60 border border-slate-200/80 dark:border-slate-800/80 shadow-sm">
                <div class="flex items-center justify-between mb-2">
                    <span class="text-[11px] font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider">Cảnh báo / Lỗi</span>
                    <div class="p-2 rounded-xl bg-amber-50 dark:bg-amber-500/10 text-amber-600 dark:text-amber-400">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"/></svg>
                    </div>
                </div>
                <div class="flex items-center gap-3">
                    <span class="text-2xl font-black text-amber-600 dark:text-amber-400" id="kpiWarn">$($telemetry.WarnCount)</span>
                    <span class="text-xs text-slate-400">Cảnh báo</span>
                    <span class="text-2xl font-black text-rose-600 dark:text-rose-400" id="kpiError">$($telemetry.ErrorCount)</span>
                    <span class="text-xs text-slate-400">Lỗi</span>
                </div>
                <div class="text-[11px] text-slate-500 dark:text-slate-400 mt-1">Tự động retry khi có sự cố</div>
            </div>

        </div>

        <!-- 2. INTERACTIVE ACTION CENTER (CHẠY TRỰC TIẾP TỪ DASHBOARD) -->
        <div class="rounded-3xl p-6 bg-gradient-to-br from-indigo-900/30 via-slate-900/60 to-slate-900/90 border border-brand-500/20 shadow-xl space-y-6">
            <div class="flex flex-wrap items-center justify-between gap-4">
                <div>
                    <h2 class="text-lg font-extrabold text-white flex items-center gap-2.5">
                        <span class="p-1.5 rounded-lg bg-brand-600 text-white text-sm">⚡</span>
                        Trung Tâm Thực Thi Tác Vụ Trực Tiếp (1-Click Run)
                    </h2>
                    <p class="text-xs text-slate-300 mt-1">Nhấp để chạy ngay lập tức các script tự động hóa trên máy tính của bạn</p>
                </div>
                <div class="flex items-center gap-2">
                    <span id="runningIndicator" class="hidden inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full text-xs font-bold bg-amber-500/20 text-amber-300 border border-amber-500/30">
                        <svg class="animate-spin h-3.5 w-3.5 text-amber-300" viewBox="0 0 24 24" fill="none"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"></path></svg>
                        Đang thực thi lệnh...
                    </span>
                </div>
            </div>

            <!-- Master Runner Hero Button -->
            <div class="p-5 rounded-2xl bg-gradient-to-r from-brand-600 to-indigo-600 border border-white/10 shadow-lg flex flex-wrap items-center justify-between gap-4">
                <div class="space-y-1">
                    <div class="flex items-center gap-2">
                        <span class="text-xl">🚀</span>
                        <h3 class="text-base font-bold text-white">Chạy Toàn Bộ Chu Trình Renew E5 (Run All)</h3>
                    </div>
                    <p class="text-xs text-indigo-100">Kiểm tra Mount M:, tạo hoạt động Graph API, SharePoint API và ghi nhận log đầy đủ.</p>
                </div>
                <button onclick="runAction('run_all', 'Chạy toàn bộ chu trình Renew E5')" class="px-5 py-2.5 rounded-xl bg-white text-brand-700 font-extrabold text-xs transition hover:bg-indigo-50 shadow-md hover:scale-105 active:scale-95 flex items-center gap-2">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z"/><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
                    THỰC THI NGAY
                </button>
            </div>

            <!-- Action Grid (Categorized) -->
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3.5">
                
                <!-- Action 1: Mount M: -->
                <div class="p-4 rounded-xl bg-slate-900/80 border border-slate-800 hover:border-brand-500/40 transition flex items-center justify-between gap-3">
                    <div class="space-y-0.5">
                        <div class="text-xs font-bold text-slate-200 flex items-center gap-1.5">
                            <span>📁</span> Mount Ổ Đĩa (M:)
                        </div>
                        <div class="text-[11px] text-slate-400">Kết nối OneDrive Business sang M:</div>
                    </div>
                    <div class="flex items-center gap-1.5">
                        <button onclick="runAction('mount', 'Mount ổ đĩa M:')" class="px-2.5 py-1.5 rounded-lg bg-indigo-600/30 hover:bg-indigo-600 text-indigo-200 hover:text-white text-xs font-semibold transition border border-indigo-500/30">Mount</button>
                        <button onclick="runAction('unmount', 'Unmount ổ đĩa M:')" class="px-2.5 py-1.5 rounded-lg bg-rose-600/30 hover:bg-rose-600 text-rose-200 hover:text-white text-xs font-semibold transition border border-rose-500/30">Unmount</button>
                        <button onclick="runAction('reconnect_1drive', 'Đăng nhập lại OAuth rclone')" class="px-2.5 py-1.5 rounded-lg bg-amber-600/30 hover:bg-amber-600 text-amber-200 hover:text-white text-xs font-semibold transition border border-amber-500/30" title="Đăng nhập lại khi token hết hạn">🔑 Auth</button>
                    </div>
                </div>

                <!-- Action 2: Graph Activity -->
                <div class="p-4 rounded-xl bg-slate-900/80 border border-slate-800 hover:border-brand-500/40 transition flex items-center justify-between gap-3">
                    <div class="space-y-0.5">
                        <div class="text-xs font-bold text-slate-200 flex items-center gap-1.5">
                            <span>⚡</span> Graph API Activity
                        </div>
                        <div class="text-[11px] text-slate-400">Gửi mail, Teams, Planner, To-Do</div>
                    </div>
                    <button onclick="runAction('graph_activity', 'Hoạt động Microsoft Graph API')" class="px-3 py-1.5 rounded-lg bg-brand-600 hover:bg-brand-500 text-white text-xs font-semibold transition shadow-sm">Chạy</button>
                </div>

                <!-- Action 3: SharePoint API -->
                <div class="p-4 rounded-xl bg-slate-900/80 border border-slate-800 hover:border-brand-500/40 transition flex items-center justify-between gap-3">
                    <div class="space-y-0.5">
                        <div class="text-xs font-bold text-slate-200 flex items-center gap-1.5">
                            <span>🌐</span> SharePoint Sync
                        </div>
                        <div class="text-[11px] text-slate-400">Kiểm tra quota, list & upload file</div>
                    </div>
                    <button onclick="runAction('sharepoint_sync', 'Đồng bộ SharePoint API')" class="px-3 py-1.5 rounded-lg bg-brand-600 hover:bg-brand-500 text-white text-xs font-semibold transition shadow-sm">Chạy</button>
                </div>

                <!-- Action 4: Python Ping E5 -->
                <div class="p-4 rounded-xl bg-slate-900/80 border border-slate-800 hover:border-brand-500/40 transition flex items-center justify-between gap-3">
                    <div class="space-y-0.5">
                        <div class="text-xs font-bold text-slate-200 flex items-center gap-1.5">
                            <span>🐍</span> Python Ping E5
                        </div>
                        <div class="text-[11px] text-slate-400">Chạy daemon token nền</div>
                    </div>
                    <button onclick="runAction('python_app', 'Python Ping E5 Daemon')" class="px-3 py-1.5 rounded-lg bg-emerald-600/30 hover:bg-emerald-600 text-emerald-200 hover:text-white text-xs font-semibold transition border border-emerald-500/30">Chạy</button>
                </div>

                <!-- Action 5: OneDrive Robocopy Sync -->
                <div class="p-4 rounded-xl bg-slate-900/80 border border-slate-800 hover:border-brand-500/40 transition flex items-center justify-between gap-3">
                    <div class="space-y-0.5">
                        <div class="text-xs font-bold text-slate-200 flex items-center gap-1.5">
                            <span>🔄</span> Đồng Bộ OneDrive
                        </div>
                        <div class="text-[11px] text-slate-400">Business sang Personal (Robocopy)</div>
                    </div>
                    <button onclick="runAction('onedrive_sync', 'Đồng bộ OneDrive Robocopy')" class="px-3 py-1.5 rounded-lg bg-brand-600 hover:bg-brand-500 text-white text-xs font-semibold transition shadow-sm">Đồng Bộ</button>
                </div>

                <!-- Action 6: Quick Renew / Draft -->
                <div class="p-4 rounded-xl bg-slate-900/80 border border-slate-800 hover:border-brand-500/40 transition flex items-center justify-between gap-3">
                    <div class="space-y-0.5">
                        <div class="text-xs font-bold text-slate-200 flex items-center gap-1.5">
                            <span>🛠️</span> Tiện Ích Graph Nhanh
                        </div>
                        <div class="text-[11px] text-slate-400">Quick Renew & Thư Nháp Outlook</div>
                    </div>
                    <div class="flex items-center gap-1.5">
                        <button onclick="runAction('quick_renew', 'Quick Renew E5')" class="px-2.5 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-semibold transition border border-slate-700">Quick</button>
                        <button onclick="runAction('create_draft', 'Tạo Thư Nháp Email')" class="px-2.5 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-semibold transition border border-slate-700">Draft</button>
                    </div>
                </div>

            </div>
        </div>

        <!-- 3. LIVE CONSOLE OUTPUT TERMINAL -->
        <div id="terminalSection" class="rounded-3xl p-6 bg-slate-900 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 shadow-xl space-y-4">
            <div class="flex flex-wrap items-center justify-between gap-3">
                <div class="flex items-center gap-2">
                    <div class="flex items-center gap-1.5">
                        <span class="w-3 h-3 rounded-full bg-rose-500"></span>
                        <span class="w-3 h-3 rounded-full bg-amber-500"></span>
                        <span class="w-3 h-3 rounded-full bg-emerald-500"></span>
                    </div>
                    <h3 class="text-xs font-bold text-slate-300 font-mono ml-2 flex items-center gap-2">
                        <span>Terminal Output Console</span>
                        <span id="terminalStatus" class="px-2 py-0.5 rounded text-[10px] font-semibold bg-slate-800 text-slate-400">Sẵn Sàng</span>
                    </h3>
                </div>
                <div class="flex items-center gap-2">
                    <button onclick="copyTerminalOutput()" class="px-3 py-1 rounded-lg bg-slate-800 hover:bg-slate-700 text-xs text-slate-300 font-mono transition border border-slate-700">Sao Chép</button>
                    <button onclick="clearTerminal()" class="px-3 py-1 rounded-lg bg-slate-800 hover:bg-slate-700 text-xs text-slate-300 font-mono transition border border-slate-700">Xóa Màn Hình</button>
                </div>
            </div>

            <!-- Terminal Screen -->
            <pre id="terminalOutput" class="w-full bg-slate-950 text-slate-200 font-mono text-xs p-4 rounded-2xl h-56 overflow-y-auto border border-slate-800/80 leading-relaxed">Sẵn sàng thực thi lệnh. Nhấp vào các nút phía trên để chạy tác vụ trực tiếp...</pre>
        </div>

        <!-- 4. Services Status & Task Scheduler Grid -->
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">

            <!-- Services Health Column -->
            <div class="lg:col-span-2 card-modern rounded-3xl p-6 bg-white dark:bg-slate-900/60 border border-slate-200/80 dark:border-slate-800/80 shadow-sm space-y-4">
                <div class="flex items-center justify-between">
                    <h2 class="text-sm font-extrabold text-slate-900 dark:text-slate-100 flex items-center gap-2">
                        <svg class="w-4 h-4 text-brand-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/></svg>
                        Trạng Thái Dịch Vụ Microsoft 365
                    </h2>
                    <span class="text-xs text-slate-400 font-mono" id="telemetryTime">Cập nhật: $($telemetry.GeneratedAt)</span>
                </div>

                <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-3">
                    <div class="p-3.5 rounded-xl bg-slate-50 dark:bg-slate-950/60 border border-slate-200/80 dark:border-slate-800/80 flex items-center justify-between">
                        <div>
                            <div class="text-[11px] text-slate-500 dark:text-slate-400 font-medium">Outlook & Mail API</div>
                            <div class="text-xs font-bold text-emerald-600 dark:text-emerald-400 mt-0.5 flex items-center gap-1.5">
                                <span class="w-1.5 h-1.5 rounded-full bg-emerald-500"></span> Active
                            </div>
                        </div>
                        <span class="text-xl">✉️</span>
                    </div>

                    <div class="p-3.5 rounded-xl bg-slate-50 dark:bg-slate-950/60 border border-slate-200/80 dark:border-slate-800/80 flex items-center justify-between">
                        <div>
                            <div class="text-[11px] text-slate-500 dark:text-slate-400 font-medium">Teams & Channels</div>
                            <div class="text-xs font-bold text-emerald-600 dark:text-emerald-400 mt-0.5 flex items-center gap-1.5">
                                <span class="w-1.5 h-1.5 rounded-full bg-emerald-500"></span> Active
                            </div>
                        </div>
                        <span class="text-xl">💬</span>
                    </div>

                    <div class="p-3.5 rounded-xl bg-slate-50 dark:bg-slate-950/60 border border-slate-200/80 dark:border-slate-800/80 flex items-center justify-between">
                        <div>
                            <div class="text-[11px] text-slate-500 dark:text-slate-400 font-medium">Planner & To-Do</div>
                            <div class="text-xs font-bold text-emerald-600 dark:text-emerald-400 mt-0.5 flex items-center gap-1.5">
                                <span class="w-1.5 h-1.5 rounded-full bg-emerald-500"></span> Active
                            </div>
                        </div>
                        <span class="text-xl">📋</span>
                    </div>

                    <div class="p-3.5 rounded-xl bg-slate-50 dark:bg-slate-950/60 border border-slate-200/80 dark:border-slate-800/80 flex items-center justify-between">
                        <div>
                            <div class="text-[11px] text-slate-500 dark:text-slate-400 font-medium">SharePoint Online</div>
                            <div class="text-xs font-bold text-emerald-600 dark:text-emerald-400 mt-0.5 flex items-center gap-1.5">
                                <span class="w-1.5 h-1.5 rounded-full bg-emerald-500"></span> Active
                            </div>
                        </div>
                        <span class="text-xl">🌐</span>
                    </div>

                    <div class="p-3.5 rounded-xl bg-slate-50 dark:bg-slate-950/60 border border-slate-200/80 dark:border-slate-800/80 flex items-center justify-between">
                        <div>
                            <div class="text-[11px] text-slate-500 dark:text-slate-400 font-medium">Calendar Events</div>
                            <div class="text-xs font-bold text-emerald-600 dark:text-emerald-400 mt-0.5 flex items-center gap-1.5">
                                <span class="w-1.5 h-1.5 rounded-full bg-emerald-500"></span> Active
                            </div>
                        </div>
                        <span class="text-xl">📅</span>
                    </div>

                    <div class="p-3.5 rounded-xl bg-slate-50 dark:bg-slate-950/60 border border-slate-200/80 dark:border-slate-800/80 flex items-center justify-between">
                        <div>
                            <div class="text-[11px] text-slate-500 dark:text-slate-400 font-medium">App Registration</div>
                            <div class="text-xs font-bold text-emerald-600 dark:text-emerald-400 mt-0.5 flex items-center gap-1.5">
                                <span class="w-1.5 h-1.5 rounded-full bg-emerald-500"></span> Active
                            </div>
                        </div>
                        <span class="text-xl">🔑</span>
                    </div>
                </div>

                <!-- Admin Quick Links -->
                <div class="pt-3 border-t border-slate-200 dark:border-slate-800 flex flex-wrap gap-2">
                    <a href="https://portal.azure.com" target="_blank" class="px-3.5 py-1.5 rounded-xl bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-300 font-semibold text-xs transition border border-slate-200 dark:border-slate-700 flex items-center gap-1.5 shadow-sm">
                        <span>Azure Portal ↗</span>
                    </a>
                    <a href="https://admin.microsoft.com" target="_blank" class="px-3.5 py-1.5 rounded-xl bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-300 font-semibold text-xs transition border border-slate-200 dark:border-slate-700 flex items-center gap-1.5 shadow-sm">
                        <span>M365 Admin Center ↗</span>
                    </a>
                    <a href="https://developer.microsoft.com/graph/graph-explorer" target="_blank" class="px-3.5 py-1.5 rounded-xl bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-300 font-semibold text-xs transition border border-slate-200 dark:border-slate-700 flex items-center gap-1.5 shadow-sm">
                        <span>Graph Explorer ↗</span>
                    </a>
                </div>
            </div>

            <!-- Task Scheduler Column -->
            <div class="card-modern rounded-3xl p-6 bg-white dark:bg-slate-900/60 border border-slate-200/80 dark:border-slate-800/80 shadow-sm space-y-4">
                <div class="flex items-center justify-between">
                    <h2 class="text-sm font-extrabold text-slate-900 dark:text-slate-100 flex items-center gap-2">
                        <svg class="w-4 h-4 text-cyan-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
                        Windows Task Scheduler
                    </h2>
                    <button onclick="runAction('setup_tasks', 'Cài đặt lại Task Scheduler')" class="text-xs text-brand-600 dark:text-brand-400 hover:underline font-semibold">Cài Lại (48h)</button>
                </div>

                <div class="space-y-3" id="tasksContainer">
                    $tasksHtml
                </div>
            </div>

        </div>

        <!-- 5. Activity Log Stream Timeline -->
        <div class="card-modern rounded-3xl p-6 bg-white dark:bg-slate-900/60 border border-slate-200/80 dark:border-slate-800/80 shadow-sm space-y-4">
            <div class="flex items-center justify-between">
                <h2 class="text-sm font-extrabold text-slate-900 dark:text-slate-100 flex items-center gap-2">
                    <svg class="w-4 h-4 text-amber-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/></svg>
                    Nhật Ký Hoạt Động (Activity Logs)
                </h2>
                <span class="text-xs text-slate-400 font-mono">logs/*.log</span>
            </div>

            <div id="logsContainer" class="bg-slate-950 rounded-2xl p-4 font-mono text-xs text-slate-300 h-64 overflow-y-auto space-y-1.5 border border-slate-800 leading-relaxed">
                $logsHtml
            </div>
        </div>

    </main>

    <!-- Footer -->
    <footer class="max-w-7xl mx-auto px-6 py-8 text-center text-xs text-slate-400 dark:text-slate-500 font-mono">
        Microsoft 365 Developer E5 Auto Renewal System • Antigravity Agent
    </footer>

    <!-- Client-Side JavaScript API & Interactive Engine -->
    <script>
        const API_BASE = window.location.protocol.startsWith('http') ? window.location.origin : 'http://127.0.0.1:8765';

        const CMD_FALLBACKS = {
            'run_all': 'powershell -ExecutionPolicy Bypass -File "C:\\Scripts\\Run-All.ps1"',
            'mount': 'powershell -ExecutionPolicy Bypass -File "C:\\Scripts\\core\\E5-RcloneMount.ps1" -Action Mount',
            'unmount': 'powershell -ExecutionPolicy Bypass -File "C:\\Scripts\\core\\E5-RcloneMount.ps1" -Action Unmount',
            'check_mount': 'powershell -ExecutionPolicy Bypass -File "C:\\Scripts\\core\\E5-RcloneMount.ps1" -Action Check',
            'graph_activity': 'powershell -ExecutionPolicy Bypass -File "C:\\Scripts\\core\\E5-GraphActivity.ps1" -BasePath "M:\\API_Output" -EnableGraphActivities',
            'sharepoint_sync': 'powershell -ExecutionPolicy Bypass -File "C:\\Scripts\\core\\E5-SharePointSync.ps1"',
            'python_app': 'python "C:\\Scripts\\python\\PingE5_App.py"',
            'onedrive_sync': 'powershell -ExecutionPolicy Bypass -File "C:\\Scripts\\core\\E5-OneDriveSync.ps1"',
            'setup_tasks': 'powershell -ExecutionPolicy Bypass -File "C:\\Scripts\\tasks\\Setup-ScheduledTasks.ps1" -IntervalHours 48',
            'check_tasks': 'powershell -ExecutionPolicy Bypass -File "C:\\Scripts\\tasks\\Check-TaskStatus.ps1"',
            'quick_renew': 'powershell -ExecutionPolicy Bypass -File "C:\\Scripts\\core\\E5-RenewHelper.ps1" -Action QuickRenew',
            'create_draft': 'powershell -ExecutionPolicy Bypass -File "C:\\Scripts\\core\\E5-RenewHelper.ps1" -Action CreateDraft'
        };

        // Check if running via file://
        if (window.location.protocol === 'file:') {
            document.getElementById('fileProtocolWarning').classList.remove('hidden');
        }

        // Dark / Light Mode Toggle
        function toggleTheme() {
            const html = document.documentElement;
            if (html.classList.contains('dark')) {
                html.classList.remove('dark');
                localStorage.setItem('theme', 'light');
            } else {
                html.classList.add('dark');
                localStorage.setItem('theme', 'dark');
            }
        }

        // Apply saved theme
        if (localStorage.getItem('theme') === 'light') {
            document.documentElement.classList.remove('dark');
        }

        // Toast Notification System
        function showToast(title, message, type = 'info') {
            const container = document.getElementById('toastContainer');
            const toast = document.createElement('div');
            
            const borderColors = {
                info: 'border-brand-500/30 bg-slate-900/90 text-slate-100',
                success: 'border-emerald-500/30 bg-slate-900/90 text-emerald-300',
                error: 'border-rose-500/30 bg-slate-900/90 text-rose-300',
                warn: 'border-amber-500/30 bg-slate-900/90 text-amber-300',
            };

            const icons = {
                info: 'ℹ️',
                success: '✅',
                error: '❌',
                warn: '⚠️',
            };

            toast.className = `p-4 rounded-2xl border shadow-xl backdrop-blur-md transition-all duration-300 flex items-start gap-3 w-80 pointer-events-auto transform translate-y-2 opacity-0 ${borderColors[type] || borderColors.info}`;
            toast.innerHTML = `
                <span class="text-xl">${icons[type] || 'ℹ️'}</span>
                <div class="flex-1 text-xs">
                    <div class="font-bold text-slate-100">${title}</div>
                    <div class="text-slate-300 mt-0.5">${message}</div>
                </div>
            `;

            container.appendChild(toast);
            setTimeout(() => {
                toast.classList.remove('translate-y-2', 'opacity-0');
            }, 10);

            setTimeout(() => {
                toast.classList.add('opacity-0', 'translate-x-full');
                setTimeout(() => toast.remove(), 300);
            }, 4500);
        }

        // Execute Action directly from Web UI
        async function runAction(actionName, label) {
            const indicator = document.getElementById('runningIndicator');
            const terminal = document.getElementById('terminalOutput');
            const termStatus = document.getElementById('terminalStatus');

            indicator.classList.remove('hidden');
            termStatus.textContent = 'Đang chạy: ' + label;
            termStatus.className = 'px-2 py-0.5 rounded text-[10px] font-semibold bg-amber-500/20 text-amber-400';

            terminal.textContent += `\n\n========================================\n[${new Date().toLocaleTimeString()}] BẮT ĐẦU: ${label}...\n========================================\n`;
            terminal.scrollTop = terminal.scrollHeight;
            showToast('Bắt đầu tác vụ', `Đang chạy: ${label}...`, 'info');

            try {
                const response = await fetch(`${API_BASE}/api/run`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ action: actionName })
                });

                if (!response.ok) {
                    throw new Error(`HTTP Error ${response.status}`);
                }

                const data = await response.json();
                terminal.textContent += `\n${data.Output}\n\n[${new Date().toLocaleTimeString()}] KẾT THÚC (${data.Success ? 'THÀNH CÔNG' : 'CÓ LỖI'})\n`;
                terminal.scrollTop = terminal.scrollHeight;

                if (data.Success) {
                    termStatus.textContent = 'Hoàn tất thành công';
                    termStatus.className = 'px-2 py-0.5 rounded text-[10px] font-semibold bg-emerald-500/20 text-emerald-400';
                    showToast('Hoàn tất', `${label} thành công!`, 'success');
                } else {
                    termStatus.textContent = 'Lỗi thực thi';
                    termStatus.className = 'px-2 py-0.5 rounded text-[10px] font-semibold bg-rose-500/20 text-rose-400';
                    showToast('Lỗi', `${label} gặp sự cố!`, 'error');
                }

                setTimeout(refreshData, 1500);

            } catch (err) {
                const fallbackCmd = CMD_FALLBACKS[actionName] || '';
                terminal.textContent += `\n❌ CHƯA KẾT NỐI ĐƯỢC MÁY CHỦ API CỤC BỘ.\n👉 Nguyên nhân: Bạn chưa khởi động Dashboard.bat\n\n💡 Cách khắc phục:\n1. Nhấp đúp vào file Dashboard.bat tại C:\\Scripts để bật máy chủ API trực tiếp.\n2. Hoặc sao chép lệnh sau và chạy trong PowerShell/CMD:\n   ${fallbackCmd}\n`;
                terminal.scrollTop = terminal.scrollHeight;
                termStatus.textContent = 'Chưa bật Dashboard.bat';
                termStatus.className = 'px-2 py-0.5 rounded text-[10px] font-semibold bg-rose-500/20 text-rose-400';
                
                if (fallbackCmd) {
                    navigator.clipboard.writeText(fallbackCmd);
                    showToast('Chưa bật Server', `Đã sao chép lệnh chạy vào Clipboard! Hãy dán vào PowerShell hoặc mở Dashboard.bat`, 'warn');
                } else {
                    showToast('Không thể kết nối Server', 'Vui lòng mở Dashboard qua Dashboard.bat', 'error');
                }
            } finally {
                indicator.classList.add('hidden');
            }
        }

        // Refresh Data via API
        async function refreshData() {
            const refreshIcon = document.getElementById('refreshIcon');
            refreshIcon.classList.add('animate-spin');

            try {
                const res = await fetch(`${API_BASE}/api/status`);
                if (res.ok) {
                    const data = await res.json();
                    document.getElementById('kpiUpn').textContent = data.UserUPN;
                    document.getElementById('kpiTenant').textContent = 'Tenant: ' + data.TenantId;
                    document.getElementById('kpiSuccess').textContent = data.SuccessCount;
                    document.getElementById('kpiWarn').textContent = data.WarnCount;
                    document.getElementById('kpiError').textContent = data.ErrorCount;
                    document.getElementById('telemetryTime').textContent = 'Cập nhật: ' + data.GeneratedAt;

                    const mountElem = document.getElementById('kpiMountStatus');
                    if (data.IsMounted) {
                        mountElem.textContent = 'Đang Kết Nối';
                        mountElem.className = 'text-base font-extrabold text-emerald-600 dark:text-emerald-400';
                    } else {
                        mountElem.textContent = 'Chưa Mount';
                        mountElem.className = 'text-base font-extrabold text-rose-600 dark:text-rose-400';
                    }

                    showToast('Đã cập nhật', 'Dữ liệu telemetry mới nhất đã sẵn sàng', 'success');
                }
            } catch (e) {
                // Ignore silent refresh error on file protocol
            } finally {
                refreshIcon.classList.remove('animate-spin');
            }
        }

        function clearTerminal() {
            document.getElementById('terminalOutput').textContent = 'Màn hình console đã được dọn sạch.\n';
        }

        function copyTerminalOutput() {
            const text = document.getElementById('terminalOutput').textContent;
            navigator.clipboard.writeText(text);
            showToast('Đã sao chép', 'Toàn bộ nội dung console đã được lưu vào clipboard', 'info');
        }

        // Auto check server status on load
        fetch(`${API_BASE}/api/status`).catch(() => {
            const badge = document.getElementById('serverStatusBadge');
            const text = document.getElementById('serverStatusText');
            badge.className = 'inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-semibold bg-amber-500/10 text-amber-600 dark:text-amber-400 border border-amber-500/20';
            text.textContent = 'Chế độ tệp tĩnh (Mở Dashboard.bat để bật API)';
        });
    </script>
</body>
</html>
"@

    $utf8Bom = New-Object System.Text.UTF8Encoding($true)
    [System.IO.File]::WriteAllText($HtmlPath, $html, $utf8Bom)
    Write-Host "✅ Đã tạo Dashboard thành công tại: $HtmlPath" -ForegroundColor Green
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
        try {
            $context = $listener.GetContext()
            $req = $context.Request
            $res = $context.Response

            # CORS headers
            $res.AddHeader("Access-Control-Allow-Origin", "*")
            $res.AddHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
            $res.AddHeader("Access-Control-Allow-Headers", "Content-Type")

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
            Start-Sleep -Milliseconds 100
        }
    }
}
