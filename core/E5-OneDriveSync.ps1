<#
.SYNOPSIS
    E5 OneDrive Sync Manager (OneDrive Business <-> OneDrive Personal)
.DESCRIPTION
    Đồng bộ dữ liệu an toàn giữa OneDrive Business và OneDrive Personal bằng Robocopy tối ưu:
    - Mirroring (/MIR) với retry thông minh (/R:3 /W:5)
    - Tự động lấy danh sách thư mục từ config/config.json
    - Ghi log chi tiết vào logs/sync_log.txt
    - Phân tích và hiển thị mã lỗi Robocopy rõ ràng
#>

[CmdletBinding()]
param(
    [switch]$WhatIf
)

$ErrorActionPreference = "Continue"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RootDir = Split-Path -Parent $ScriptDir
$ConfigPath = Join-Path $RootDir "config\config.json"
$LogDir = Join-Path $RootDir "logs"

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
$LogFile = Join-Path $LogDir "sync_log.txt"

# Đọc cấu hình
$syncPairs = @()
if (Test-Path $ConfigPath) {
    try {
        $cfg = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($cfg.syncFolders) {
            $syncPairs = @($cfg.syncFolders)
        }
    } catch {
        Write-Warning "Không đọc được file cấu hình sync: $_"
    }
}

# Fallback nếu config chưa cấu hình
if ($syncPairs.Count -eq 0) {
    Write-Warning "Chưa có danh sách thư mục đồng bộ trong config/config.json."
    Write-Host "Vui lòng cấu hình mục 'syncFolders' trong config/config.json để thực hiện đồng bộ Robocopy." -ForegroundColor Yellow
    return
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "    ĐỒNG BỘ ONEDRIVE BUSINESS -> ONEDRIVE PERSONAL" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

$overallSuccess = $true

foreach ($pair in $syncPairs) {
    $name = $pair.name
    $src = $pair.source
    $dst = $pair.destination

    Write-Host "--------------------------------------------------" -ForegroundColor Yellow
    Write-Host "Đang đồng bộ thư mục: $name" -ForegroundColor Yellow
    Write-Host "  Nguồn: $src" -ForegroundColor Gray
    Write-Host "  Đích : $dst" -ForegroundColor Gray
    Write-Host ""

    if (-not (Test-Path $src)) {
        Write-Host "  [CẢNH BÁO] Thư mục nguồn không tồn tại: $src" -ForegroundColor Red
        continue
    }

    if (-not (Test-Path $dst)) {
        New-Item -ItemType Directory -Path $dst -Force | Out-Null
        Write-Host "  [TẠO MỚI] Đã tạo thư mục đích: $dst" -ForegroundColor Green
    }

    $roboArgs = @(
        "`"$src`"",
        "`"$dst`"",
        "/MIR",
        "/COPY:DAT",
        "/R:3",
        "/W:5",
        "/LOG+:`"$LogFile`"",
        "/NP",
        "/TEE",
        "/NDL"
    )

    if ($WhatIf) {
        $roboArgs += "/L"
        Write-Host "  [Chế độ kiểm tra WhatIf / Preview]" -ForegroundColor Cyan
    }

    $cmd = "robocopy " + ($roboArgs -join " ")
    Invoke-Expression $cmd
    $exitCode = $LASTEXITCODE

    # Robocopy exit code interpretation:
    # 0 = No files copied, in sync
    # 1 = Files copied successfully
    # 2 = Extra files detected
    # 3 = Files copied + extra files
    # 4 = Mismatched files
    # >= 8 = Serious Error
    if ($exitCode -lt 8) {
        Write-Host "  ✅ Hoàn tất đồng bộ: $name (Robocopy Code: $exitCode)" -ForegroundColor Green
    } else {
        Write-Host "  ❌ LỖI trong quá trình đồng bộ: $name (Mã lỗi: $exitCode)" -ForegroundColor Red
        $overallSuccess = $false
    }
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
if ($overallSuccess) {
    Write-Host "  TẤT CẢ THƯ MỤC ĐÃ ĐỒNG BỘ THÀNH CÔNG!" -ForegroundColor Green
} else {
    Write-Host "  CÓ LỖI XẢY RA TRONG QUÁ TRÌNH ĐỒNG BỘ." -ForegroundColor Red
}
Write-Host "  Xem chi tiết log tại: $LogFile" -ForegroundColor Gray
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""
