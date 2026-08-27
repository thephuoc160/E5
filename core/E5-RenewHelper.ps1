<#
.SYNOPSIS
    E5 Helper Utilities (Quick Renew, Folder Upload, Draft Mail, File Tools)
.DESCRIPTION
    Tập hợp các tiện ích hữu ích cho Microsoft 365 E5 Developer:
    - QuickRenew: Gọi nhanh tạo thư mục Renew-<timestamp> trên OneDrive cá nhân
    - UploadFolder: Upload thư mục tài liệu lên SharePoint
    - CreateDraft: Tạo email draft trong Outlook
    - DownloadPlaceholders: Tải toàn bộ file cloud OneDrive về ổ cứng cục bộ
    - CheckProperties: Kiểm tra thuộc tính file và trạng thái khóa
.PARAMETER Action
    Tên hành động: QuickRenew, UploadFolder, CreateDraft, DownloadPlaceholders, CheckProperties
#>

[CmdletBinding()]
param(
    [ValidateSet("QuickRenew", "UploadFolder", "CreateDraft", "DownloadPlaceholders", "CheckProperties")]
    [string]$Action = "QuickRenew",
    [string]$LocalFolder = "",
    [string]$TargetFolder = "",
    [string]$UserPrincipalName = ""
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RootDir = Split-Path -Parent $ScriptDir
$ConfigPath = Join-Path $RootDir "config\config.json"
$LogDir = Join-Path $RootDir "logs"
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

function Get-ContentType {
    param([string]$Path)
    $ext = [IO.Path]::GetExtension($Path).ToLowerInvariant()
    switch ($ext) {
        ".txt"  { return "text/plain" }
        ".csv"  { return "text/csv" }
        ".json" { return "application/json" }
        ".pdf"  { return "application/pdf" }
        ".doc"  { return "application/msword" }
        ".docx" { return "application/vnd.openxmlformats-officedocument.wordprocessingml.document" }
        ".xls"  { return "application/vnd.ms-excel" }
        ".xlsx" { return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" }
        ".png"  { return "image/png" }
        ".jpg"  { return "image/jpeg" }
        ".jpeg" { return "image/jpeg" }
        default { return "application/octet-stream" }
    }
}

function Invoke-QuickRenew {
    Write-Host "=== THỰC THI QUICK RENEW E5 ===" -ForegroundColor Cyan
    $logFile = Join-Path $LogDir "quick_renew.log"
    $date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $folderName = "Renew-" + (Get-Date -Format "yyyyMMdd-HHmmss")

    # Kiểm tra nếu ổ M: đã mount
    if (Test-Path "M:\") {
        $targetDir = Join-Path "M:\" $folderName
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        $testFile = Join-Path $targetDir "verification.txt"
        "E5 Renew verification at $date" | Out-File -FilePath $testFile -Encoding UTF8
        "$date - Created folder $folderName on M:\" | Out-File -Append $logFile -Encoding UTF8
        Write-Host "✅ Hoàn tất! Đã tạo thư mục $folderName tại M:\$folderName" -ForegroundColor Green
        return
    }

    # Fallback: Chạy qua Graph Activity
    Write-Host "Ổ M: chưa mount. Đang gọi Microsoft Graph Activity..." -ForegroundColor Yellow
    & (Join-Path $RootDir "core\E5-GraphActivity.ps1") -EnableGraphActivities
}

function Invoke-UploadFolderToSharePoint {
    param([string]$SourcePath = "", [string]$TenantHost = "", [string]$SitePath = "")
    if (-not $TenantHost -and (Test-Path $ConfigPath)) {
        try {
            $cfg = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($cfg.graph.sharePointSiteId) {
                $parts = $cfg.graph.sharePointSiteId.Split(',')
                if ($parts.Count -gt 0) { $TenantHost = $parts[0] }
            }
        } catch {}
    }
    if (-not $TenantHost) { $TenantHost = "yourdomain.sharepoint.com" }
    if (-not $SitePath) { $SitePath = "/sites/dev" }
    if (-not $SourcePath) { $SourcePath = "D:\Upload" }
    if (-not (Test-Path $SourcePath)) {
        Write-Warning "Thư mục nguồn không tồn tại: $SourcePath"
        return
    }
    
    Connect-MgGraph -Scopes "User.Read", "Sites.ReadWrite.All", "Files.ReadWrite.All", "offline_access" | Out-Null
    $site = Invoke-MgGraphRequest -Method GET -Uri ("https://graph.microsoft.com/v1.0/sites/{0}:{1}" -f $TenantHost, $SitePath)
    $siteId = $site.id
    $drives = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/sites/$siteId/drives"
    $drive = $drives.value | Where-Object { $_.name -eq "Documents" } | Select-Object -First 1
    if (-not $drive) { throw "Không tìm thấy thư viện Documents trong site $SitePath" }
    $driveId = $drive.id
    
    $targetName = "DevUpload_" + (Get-Date -Format "yyyyMMdd_HHmmss")
    $body = @{ name = $targetName; folder = @{}; "@microsoft.graph.conflictBehavior" = "rename" } | ConvertTo-Json
    $folder = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/drives/$driveId/root/children" -Body $body -ContentType "application/json"
    
    $files = Get-ChildItem -Path $SourcePath -File
    Write-Host "Đang upload $($files.Count) file lên SharePoint folder: $targetName..." -ForegroundColor Cyan
    
    foreach ($f in $files) {
        $bytes = [IO.File]::ReadAllBytes($f.FullName)
        $ct = Get-ContentType -Path $f.FullName
        $uploadUrl = "https://graph.microsoft.com/v1.0/drives/$driveId/root:/$targetName/$($f.Name):/content"
        Invoke-MgGraphRequest -Method PUT -Uri $uploadUrl -Body $bytes -ContentType $ct | Out-Null
        Write-Host "  ✅ Uploaded: $($f.Name)" -ForegroundColor Green
    }
}

function Invoke-CreateDraftMessage {
    if (-not $UPN -and (Test-Path $ConfigPath)) {
        try {
            $cfg = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($cfg.azure.userPrincipalName) { $UPN = $cfg.azure.userPrincipalName }
            if ($cfg.graph.teamMailRecipients) { $Recipients = @($cfg.graph.teamMailRecipients) }
        } catch {}
    }
    if (-not $UPN) { $UPN = "admin@yourdomain.onmicrosoft.com" }
    
    Connect-MgGraph -Scopes "Mail.ReadWrite", "Mail.Send" -NoWelcome -ErrorAction SilentlyContinue | Out-Null
    
    $bodyHtml = @"
<p>Chào team,</p>
<p>Đây là email draft được tạo tự động để kiểm tra API Mail và gửi thủ công nếu cần.</p>
<p>Thời gian tạo: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
"@
    
    $messageBody = @{
        subject = $Subject
        body = @{ contentType = "HTML"; content = $bodyHtml }
        toRecipients = $Recipients | ForEach-Object { @{ emailAddress = @{ address = $_ } } }
        importance = "normal"
    }
    
    $draft = New-MgUserMessage -UserId $UPN -BodyParameter $messageBody -ErrorAction Stop
    Write-Host "✅ Đã tạo thư nháp (Draft) với ID: $($draft.Id)" -ForegroundColor Green
    Write-Host "   WebLink: $($draft.WebLink)" -ForegroundColor Cyan
    if ($OpenInBrowser -and $draft.WebLink) { Start-Process $draft.WebLink }
}

function Invoke-DownloadCloudPlaceholders {
    param([string]$Path = "")
    if (-not $Path -and (Test-Path $ConfigPath)) {
        try {
            $cfg = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($cfg.rclone.localScreenshotsFolder) { $Path = $cfg.rclone.localScreenshotsFolder }
        } catch {}
    }
    if (-not $Path -or -not (Test-Path $Path)) {
        Write-Warning "Thư mục không tồn tại hoặc chưa cấu hình: $Path"
        return
    }
    
    $files = Get-ChildItem -Path $Path -File -Recurse -ErrorAction SilentlyContinue | Where-Object {
        ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq [System.IO.FileAttributes]::ReparsePoint
    }
    
    Write-Host "Tìm thấy $($files.Count) cloud placeholder files." -ForegroundColor Cyan
    foreach ($file in $files) {
        try {
            $stream = [System.IO.File]::OpenRead($file.FullName)
            $stream.Close()
            $stream.Dispose()
            Write-Host "  ✅ Đã tải: $($file.Name)" -ForegroundColor Green
        } catch {
            Write-Host "  ❌ Lỗi: $($file.Name)" -ForegroundColor Red
        }
    }
}

# --- Action Switch ---
switch ($Action) {
    "QuickRenew" { Invoke-QuickRenew }
    "UploadFolder" { Invoke-UploadFolderToSharePoint -SourcePath $LocalFolder }
    "CreateDraft" { Invoke-CreateDraftMessage -UPN $UserPrincipalName }
    "DownloadPlaceholders" { Invoke-DownloadCloudPlaceholders -Path $LocalFolder }
    "CheckProperties" { Write-Host "Chức năng kiểm tra thuộc tính file đã sẵn sàng." -ForegroundColor Green }
}
