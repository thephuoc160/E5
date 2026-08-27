<#
.SYNOPSIS
    E5 Microsoft Graph & OneDrive Activity Generator
.DESCRIPTION
    Tạo các hoạt động phong phú (Mail, Teams, Calendar, Planner, To-Do, SharePoint,
    App Registration, Mailbox Rules, File Operations) qua Microsoft Graph SDK và
    ổ đĩa M: nhằm duy trì hoạt động tài khoản Microsoft 365 Developer E5.
.PARAMETER BasePath
    Đường dẫn thư mục làm việc trên ổ đĩa M: hoặc local (Mặc định: M:\API_Output)
.PARAMETER EnableGraphActivities
    Bật/Tắt các hoạt động gọi Microsoft Graph API (Mặc định: $true)
#>

[CmdletBinding()]
param(
    [string]$BasePath = "M:\API_Output",
    [int]$MinActivities = 10,
    [int]$MaxActivities = 20,
    [switch]$EnableGraphActivities = $true,
    [string]$UserPrincipalName = "",
    [string[]]$TeamMailRecipients = @(),
    [string]$ConfigFilePath = ""
)

$ErrorActionPreference = "Continue"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RootDir = Split-Path -Parent $ScriptDir
$DefaultConfigPath = Join-Path $RootDir "config\config.json"
$LogDir = Join-Path $RootDir "logs"

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
$LogFile = Join-Path $LogDir "graph_activity.log"

# --- Load configuration ---
$config = $null
$effectiveConfigPath = if ($ConfigFilePath -and (Test-Path $ConfigFilePath)) { $ConfigFilePath } else { $DefaultConfigPath }
if (Test-Path $effectiveConfigPath) {
    try {
        $config = Get-Content $effectiveConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        Write-Warning "Không thể đọc file config: $_"
    }
}

# Resolve settings with config fallback
if (-not $UserPrincipalName) {
    if ($config -and $config.azure.userPrincipalName) { $UserPrincipalName = $config.azure.userPrincipalName }
    else { $UserPrincipalName = "admin@yourdomain.onmicrosoft.com" }
}

if (-not $TeamMailRecipients -or $TeamMailRecipients.Count -eq 0) {
    if ($config -and $config.graph.teamMailRecipients) { $TeamMailRecipients = @($config.graph.teamMailRecipients) }
    else { $TeamMailRecipients = @("user1@yourdomain.onmicrosoft.com", "user2@yourdomain.onmicrosoft.com") }
}

$TeamsTeamId = if ($config.graph.teamsTeamId) { $config.graph.teamsTeamId } else { "" }
$TeamsChannelId = if ($config.graph.teamsChannelId) { $config.graph.teamsChannelId } else { "" }
$TeamsChatId = if ($config.graph.teamsChatId) { $config.graph.teamsChatId } else { "" }
$PlannerPlanId = if ($config.graph.plannerPlanId) { $config.graph.plannerPlanId } else { "" }
$PlannerBucketId = if ($config.graph.plannerBucketId) { $config.graph.plannerBucketId } else { "" }
$SharePointSiteId = if ($config.graph.sharePointSiteId) { $config.graph.sharePointSiteId } else { "" }
$SharePointLibraryFolder = if ($config.graph.sharePointLibraryFolder) { $config.graph.sharePointLibraryFolder } else { "CopilotAutomation" }
$MailboxRuleName = if ($config.graph.mailboxRuleName) { $config.graph.mailboxRuleName } else { "Auto Archive Rule" }
$MailboxRuleSubjectContains = if ($config.graph.mailboxRuleSubjectContains) { $config.graph.mailboxRuleSubjectContains } else { "Review" }
$MailboxRuleTargetFolderPath = if ($config.graph.mailboxRuleTargetFolderPath) { $config.graph.mailboxRuleTargetFolderPath } else { "Inbox/Archive" }
$UserSnapshotReportPath = if ($config.graph.userSnapshotReportPath) { $config.graph.userSnapshotReportPath } else { "M:\API\user_snapshot.json" }

$CopilotTaskSubjects = if ($config.graph.copilotTaskSubjects) { @($config.graph.copilotTaskSubjects) } else { @("Review Dev prompts", "Document feedback", "Plan rollout") }
$PlannerTaskTitles = if ($config.graph.plannerTaskTitles) { @($config.graph.plannerTaskTitles) } else { @("Review backlog", "Track AI issues", "Prepare highlights", "Export plan to Excel") }
$AppRegistrationNames = if ($config.graph.appRegistrationNames) { @($config.graph.appRegistrationNames) } else { @("My_Dev_App") }
$AppRegistrationExistingAppIds = if ($config.graph.appRegistrationExistingAppIds) { @($config.graph.appRegistrationExistingAppIds) } else { @() }
$AppRegistrationExistingSecretIds = if ($config.graph.appRegistrationExistingSecretIds) { @($config.graph.appRegistrationExistingSecretIds) } else { @() }

# Fallback BasePath nếu M:\ chưa mount
if (-not (Test-Path "M:\") -and $BasePath.StartsWith("M:", [System.StringComparison]::OrdinalIgnoreCase)) {
    $localFallback = Join-Path $RootDir "scratch_drive_sim"
    if (-not (Test-Path $localFallback)) { New-Item -ItemType Directory -Path $localFallback -Force | Out-Null }
    Write-Warning "Ổ đĩa M: chưa sẵn sàng. Sử dụng thư mục tạm $localFallback cho hoạt động file."
    $BasePath = $localFallback
}

# --- Helper Logging ---
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$stamp] [$Level] $Message"
    
    switch ($Level) {
        "SUCCESS" { Write-Host $line -ForegroundColor Green }
        "WARN"    { Write-Host $line -ForegroundColor Yellow }
        "ERROR"   { Write-Host $line -ForegroundColor Red }
        default   { Write-Host $line -ForegroundColor Cyan }
    }
    
    try {
        $line | Out-File -FilePath $LogFile -Append -Encoding utf8
        if (Test-Path $BasePath) {
            $line | Out-File -FilePath (Join-Path $BasePath "activity.log") -Append -Encoding utf8 -ErrorAction SilentlyContinue
        }
    } catch {}
}

function Safe-ReleaseComObject {
    param($ComObject)
    if ($ComObject) {
        try {
            [System.Runtime.InteropServices.Marshal]::ReleaseComObject($ComObject) | Out-Null
        } catch {}
    }
}

# --- File Simulation Ops ---
function New-TestFile {
    param([string]$Path)
    $content = @"
Test file created: $(Get-Date)
Random ID: $((New-Guid).ToString())
Activity Type: API Call Test
Content Size: $(Get-Random -Minimum 100 -Maximum 1000) bytes
$(1..10 | ForEach-Object { "Line $_ - $(Get-Random)" })
"@
    $content | Out-File -FilePath $Path -Encoding UTF8
}

function Invoke-FileSystemActivity {
    if (-not (Test-Path $BasePath)) {
        New-Item -ItemType Directory -Path $BasePath -Force | Out-Null
    }
    
    $activityCount = Get-Random -Minimum $MinActivities -Maximum $MaxActivities
    Write-Log "Bắt đầu $activityCount hoạt động file system trên $BasePath" "INFO"

    for ($i = 1; $i -le $activityCount; $i++) {
        switch (Get-Random -Minimum 1 -Maximum 13) {
            1 {
                $fileName = "test_{0}_{1}.txt" -f (Get-Date -Format "yyyyMMdd_HHmmss"), $i
                New-TestFile -Path (Join-Path $BasePath $fileName)
                Write-Log "Tạo file: $fileName" "INFO"
            }
            2 {
                $folder = "folder_{0}" -f (Get-Date -Format "yyyyMMdd_HHmm")
                $folderPath = Join-Path $BasePath $folder
                if (!(Test-Path $folderPath)) {
                    New-Item -ItemType Directory -Path $folderPath -Force | Out-Null
                    Write-Log "Tạo thư mục: $folder" "INFO"
                }
            }
            3 {
                $items = Get-ChildItem -Path $BasePath -ErrorAction SilentlyContinue
                Write-Log ("Liệt kê {0} items trong API folder" -f $items.Count) "INFO"
            }
            4 {
                $files = Get-ChildItem -Path $BasePath -Filter "*.txt" -ErrorAction SilentlyContinue
                if ($files.Count -gt 0) {
                    $randomFile = $files | Get-Random
                    Get-Content -Path $randomFile.FullName -ErrorAction SilentlyContinue | Out-Null
                    Write-Log ("Đọc file: {0}" -f $randomFile.Name) "INFO"
                }
            }
            5 {
                $files = Get-ChildItem -Path $BasePath -Filter "*.txt" -ErrorAction SilentlyContinue
                if ($files.Count -gt 0) {
                    $source = $files | Get-Random
                    $copyName = "copy_{0}_{1}.txt" -f (Get-Date -Format "HHmmss"), $source.BaseName
                    Copy-Item -Path $source.FullName -Destination (Join-Path $BasePath $copyName) -ErrorAction SilentlyContinue
                    Write-Log ("Copy file: {0} -> {1}" -f $source.Name, $copyName) "INFO"
                }
            }
            6 {
                $files = Get-ChildItem -Path $BasePath -Filter "test_*.txt" -ErrorAction SilentlyContinue
                if ($files.Count -gt 0) {
                    $file = $files | Get-Random
                    $newName = "renamed_{0}_{1}.txt" -f (Get-Date -Format "HHmmss"), $file.BaseName
                    Rename-Item -Path $file.FullName -NewName $newName -ErrorAction SilentlyContinue
                    Write-Log ("Rename: {0} -> {1}" -f $file.Name, $newName) "INFO"
                }
            }
            7 {
                $files = Get-ChildItem -Path $BasePath -Filter "*.txt" -ErrorAction SilentlyContinue
                if ($files.Count -gt 0) {
                    $file = $files | Get-Random
                    Add-Content -Path $file.FullName -Value ("`nUpdated: {0} - Random: {1}" -f (Get-Date), (Get-Random)) -ErrorAction SilentlyContinue
                    Write-Log ("Cập nhật file: {0}" -f $file.Name) "INFO"
                }
            }
            8 {
                $jsonName = "data_{0}.json" -f (Get-Date -Format "yyyyMMdd_HHmmss")
                $jsonPath = Join-Path $BasePath $jsonName
                $jsonData = @{
                    timestamp = Get-Date
                    id        = (New-Guid).ToString()
                    type      = "api_test"
                    data      = @{
                        value1 = Get-Random
                        value2 = Get-Random -Minimum 1000 -Maximum 9999
                        text   = "API activity test"
                    }
                } | ConvertTo-Json -Depth 3
                $jsonData | Out-File -FilePath $jsonPath -Encoding UTF8
                Write-Log ("Tạo JSON file: {0}" -f $jsonName) "INFO"
            }
            9 {
                $files = Get-ChildItem -Path $BasePath -File -ErrorAction SilentlyContinue
                $totalSize = ($files | Measure-Object -Property Length -Sum).Sum
                Write-Log ("Tổng kích thước: {0} KB ({1} files)" -f ([math]::Round($totalSize / 1KB, 2)), $files.Count) "INFO"
            }
            10 {
                $files = Get-ChildItem -Path $BasePath -Filter "*.txt" -ErrorAction SilentlyContinue
                $folders = Get-ChildItem -Path $BasePath -Directory -ErrorAction SilentlyContinue
                if ($files.Count -gt 0 -and $folders.Count -gt 0) {
                    $file = $files | Get-Random
                    $folder = $folders | Get-Random
                    Move-Item -Path $file.FullName -Destination (Join-Path $folder.FullName $file.Name) -ErrorAction SilentlyContinue
                    Write-Log ("Move file: {0} -> {1}" -f $file.Name, $folder.Name) "INFO"
                }
            }
            11 {
                $oldFiles = Get-ChildItem -Path $BasePath -File | Where-Object {
                    $_.CreationTime -lt (Get-Date).AddHours(-1) -and $_.Name -like "test_*"
                }
                if ($oldFiles.Count -gt 0) {
                    $fileToDelete = $oldFiles | Get-Random
                    Remove-Item -Path $fileToDelete.FullName -Force -ErrorAction SilentlyContinue
                    Write-Log ("Xóa file cũ: {0}" -f $fileToDelete.Name) "INFO"
                }
            }
            12 {
                $folders = Get-ChildItem -Path $BasePath -Directory -ErrorAction SilentlyContinue
                if ($folders.Count -gt 0) {
                    $folder = $folders | Get-Random
                    $archiveName = "{0}_archive" -f $folder.Name
                    Copy-Item -Path $folder.FullName -Destination (Join-Path $BasePath $archiveName) -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Log ("Nhân bản thư mục: {0} -> {1}" -f $folder.Name, $archiveName) "INFO"
                }
            }
        }
        Start-Sleep -Seconds (Get-Random -Minimum 1 -Maximum 3)
    }

    Write-Log ("Hoàn thành {0} hoạt động file system" -f $activityCount) "SUCCESS"
}

function Invoke-CleanupOldFiles {
    Write-Log "Dọn dẹp các file giả lập cũ..." "INFO"
    $oldFiles = Get-ChildItem -Path $BasePath -Filter "test_*" -ErrorAction SilentlyContinue | Where-Object {
        $_.CreationTime -lt (Get-Date).AddHours(-24)
    }

    foreach ($file in $oldFiles) {
        Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
        Write-Log ("Cleanup: Xóa {0}" -f $file.Name) "INFO"
    }

    $allFiles = Get-ChildItem -Path $BasePath -File -ErrorAction SilentlyContinue | Sort-Object CreationTime -Descending
    if ($allFiles.Count -gt 50) {
        $filesToDelete = $allFiles | Select-Object -Skip 50
        foreach ($file in $filesToDelete) {
            Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
            Write-Log ("Cleanup: Xóa excess file {0}" -f $file.Name) "INFO"
        }
    }
}

# --- Microsoft Graph Automation ---
function Ensure-GraphConnection {
    param([string[]]$Scopes, [string]$Username)

    $requiredModules = @(
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

    foreach ($mod in $requiredModules) {
        if (-not (Get-Module -Name $mod)) {
            Import-Module $mod -ErrorAction SilentlyContinue
        }
    }

    try {
        $context = Get-MgContext -ErrorAction SilentlyContinue
    } catch {
        $context = $null
    }

    $needsConnect = $true
    if ($context) {
        $missingScopes = @()
        foreach ($scope in $Scopes) {
            if ($context.Scopes -notcontains $scope) {
                $missingScopes += $scope
            }
        }
        if ($missingScopes.Count -eq 0) {
            $needsConnect = $false
        }
    }

    if ($needsConnect) {
        Write-Log "Kết nối tới Microsoft Graph..." "INFO"
        Connect-MgGraph -Scopes $Scopes -ContextScope Process -ErrorAction Stop | Out-Null
        Write-Log "Đã kết nối thành công tới Microsoft Graph!" "SUCCESS"
    } else {
        Write-Log "Tái sử dụng phiên Microsoft Graph hiện có: $($context.Account)" "INFO"
    }
}

function Invoke-TeamMailBroadcast {
    param([string]$UserId, [string[]]$Recipients)
    if (-not $UserId -or -not $Recipients -or $Recipients.Count -eq 0) { return }

    $now = Get-Date
    $mailBody = @{
        Message = @{
            Subject = "[E5 Renew] Tự động cập nhật trạng thái " + $now.ToString("yyyy-MM-dd HH:mm")
            Body    = @{
                ContentType = "HTML"
                Content     = "<p>Xin chào team,</p><p>Email gửi tự động nhằm duy trì hoạt động Microsoft 365 E5 Developer.</p><p>Thời gian thực thi: <b>" + $now.ToString("yyyy-MM-dd HH:mm:ss") + "</b></p>"
            }
            ToRecipients = $Recipients | ForEach-Object {
                @{ EmailAddress = @{ Address = $_ } }
            }
        }
        SaveToSentItems = $true
    }

    try {
        Send-MgUserMail -UserId $UserId -BodyParameter $mailBody -ErrorAction Stop
        Write-Log ("Đã gửi email kiểm tra tới {0} người nhận" -f $Recipients.Count) "SUCCESS"
    } catch {
        Write-Log ("Gửi mail thất bại: {0}" -f $_.Exception.Message) "WARN"
    }
}

function Invoke-TeamsMeeting {
    param([string]$UserId, [string[]]$Attendees, [int]$DurationMinutes = 30)
    if (-not $UserId) { return }

    $start = (Get-Date).AddMinutes(10)
    $end = $start.AddMinutes([Math]::Max($DurationMinutes, 15))
    
    $eventParams = @{
        Subject = "Auto Dev Sync Meeting " + $start.ToString("yyyy-MM-dd")
        Body    = @{
            ContentType = "HTML"
            Content     = "<p>Cuộc họp tự động duy trì hoạt động Microsoft Teams & Calendar.</p>"
        }
        Start = @{
            DateTime = $start.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss")
            TimeZone = "UTC"
        }
        End = @{
            DateTime = $end.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss")
            TimeZone = "UTC"
        }
        Location = @{ DisplayName = "Microsoft Teams" }
        IsOnlineMeeting = $true
        OnlineMeetingProvider = "teamsForBusiness"
        AllowNewTimeProposals = $false
    }

    if ($Attendees -and $Attendees.Count -gt 0) {
        $eventParams.Attendees = $Attendees | ForEach-Object {
            @{ EmailAddress = @{ Address = $_ }; Type = "required" }
        }
    }

    try {
        $event = New-MgUserEvent -UserId $UserId -BodyParameter $eventParams -ErrorAction Stop
        Write-Log ("Đã tạo Teams Meeting: {0}" -f $event.Subject) "SUCCESS"
    } catch {
        Write-Log ("Tạo cuộc họp thất bại: {0}" -f $_.Exception.Message) "WARN"
    }
}

function Invoke-CopilotTodoTasks {
    param([string]$UserId, [string[]]$Subjects, [int]$DueInDays = 3)
    if (-not $UserId -or -not $Subjects -or $Subjects.Count -eq 0) { return }

    try {
        $lists = Get-MgUserTodoList -UserId $UserId -ErrorAction Stop
        $targetList = $lists | Where-Object { $_.WellknownListName -eq "defaultList" } | Select-Object -First 1
        if (-not $targetList) { $targetList = $lists | Select-Object -First 1 }
        if (-not $targetList) { return }

        foreach ($subject in $Subjects) {
            $taskBody = @{
                title = $subject.Trim()
                body  = @{
                    contentType = "text"
                    content     = "E5 Auto Task created " + (Get-Date).ToString("yyyy-MM-dd HH:mm")
                }
                dueDateTime = @{
                    dateTime = (Get-Date).AddDays($DueInDays).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss")
                    timeZone = "UTC"
                }
            }
            New-MgUserTodoListTask -UserId $UserId -TodoTaskListId $targetList.Id -BodyParameter $taskBody -ErrorAction SilentlyContinue | Out-Null
            Write-Log ("Đã tạo To-Do task: {0}" -f $subject.Trim()) "SUCCESS"
        }
    } catch {
        Write-Log ("Tạo To-Do task thất bại: {0}" -f $_.Exception.Message) "WARN"
    }
}

function Invoke-PlannerTasks {
    param([string]$PlanId, [string]$BucketId, [string[]]$Titles, [int]$DueInDays = 3)
    if ([string]::IsNullOrWhiteSpace($PlanId) -or -not $Titles) { return }

    foreach ($title in $Titles) {
        $params = @{
            Title       = $title.Trim()
            PlanId      = $PlanId
            DueDateTime = (Get-Date).AddDays($DueInDays).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            Assignments = @{}
        }
        if ($BucketId) { $params.BucketId = $BucketId }

        try {
            New-MgPlannerTask @params -ErrorAction Stop | Out-Null
            Write-Log ("Đã tạo Planner task: {0}" -f $title) "SUCCESS"
        } catch {
            Write-Log ("Tạo Planner task thất bại: {0}" -f $_.Exception.Message) "WARN"
        }
    }
}

function Export-PlannerPlanToExcel {
    param([string]$PlanId, [string]$OutputDirectory)
    if ([string]::IsNullOrWhiteSpace($PlanId) -or [string]::IsNullOrWhiteSpace($OutputDirectory)) { return $null }

    try {
        if (-not (Test-Path $OutputDirectory)) {
            New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
        }

        $tasks = @()
        $tasksUri = "https://graph.microsoft.com/v1.0/planner/plans/$PlanId/tasks?`$select=id,title,percentComplete,startDateTime,dueDateTime,createdDateTime"
        $resp = Invoke-MgGraphRequest -Method GET -Uri $tasksUri -ErrorAction SilentlyContinue
        if ($resp -and $resp.value) { $tasks = $resp.value }

        if ($tasks.Count -eq 0) { return $null }

        $fileName = "planner_export_{0}.csv" -f (Get-Date).ToString("yyyyMMdd_HHmmss")
        $outputPath = Join-Path $OutputDirectory $fileName

        $tasks | Select-Object id, title, percentComplete, startDateTime, dueDateTime, createdDateTime |
            Export-Csv -Path $outputPath -NoTypeInformation -Encoding UTF8

        Write-Log ("Đã xuất Planner plan ra CSV: {0}" -f $fileName) "SUCCESS"
        return $outputPath
    } catch {
        Write-Log ("Xuất Planner plan thất bại: {0}" -f $_.Exception.Message) "WARN"
        return $null
    }
}

function Invoke-TeamsChatMessage {
    param([string]$ChatId, [string]$TeamId, [string]$ChannelId)
    $msgText = "E5 Dev API Health Check ping at " + (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $body = @{
        Body = @{
            Content     = $msgText
            ContentType = "text"
        }
    }

    try {
        if ($ChatId) {
            New-MgChatMessage -ChatId $ChatId -BodyParameter $body -ErrorAction Stop | Out-Null
            Write-Log "Đã gửi tin nhắn Teams Chat" "SUCCESS"
        } elseif ($TeamId -and $ChannelId) {
            New-MgTeamChannelMessage -TeamId $TeamId -ChannelId $ChannelId -BodyParameter $body -ErrorAction Stop | Out-Null
            Write-Log "Đã gửi tin nhắn Teams Channel" "SUCCESS"
        }
    } catch {
        Write-Log ("Gửi tin nhắn Teams thất bại: {0}" -f $_.Exception.Message) "WARN"
    }
}

function Invoke-SharePointGraphOps {
    param([string]$SiteId, [string]$FolderName)
    if ([string]::IsNullOrWhiteSpace($SiteId)) { return }

    try {
        $drive = Get-MgSiteDrive -SiteId $SiteId -ErrorAction Stop | Select-Object -First 1
        if (-not $drive) { return }
        $driveId = $drive.Id

        $folderBody = @{
            name = $FolderName
            folder = @{}
            '@microsoft.graph.conflictBehavior' = "rename"
        } | ConvertTo-Json -Depth 4

        Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/drives/$driveId/root/children" -Body $folderBody -ContentType "application/json" -ErrorAction SilentlyContinue | Out-Null

        $fileName = "e5_status_{0}.txt" -f (Get-Date).ToString("yyyyMMdd_HHmmss")
        $fileContent = "SharePoint E5 automated ping check at " + (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        $payload = [System.Text.Encoding]::UTF8.GetBytes($fileContent)
        $uploadUri = "https://graph.microsoft.com/v1.0/drives/$driveId/root:/$FolderName/$fileName`:/content"
        Invoke-MgGraphRequest -Method PUT -Uri $uploadUri -Body $payload -ContentType "text/plain" -ErrorAction Stop | Out-Null
        Write-Log ("Đã upload file lên SharePoint Library: {0}/{1}" -f $FolderName, $fileName) "SUCCESS"
    } catch {
        Write-Log ("SharePoint Graph Ops thất bại: {0}" -f $_.Exception.Message) "WARN"
    }
}

# --- Main Execution Flow ---
try {
    Write-Log "==========================================" "INFO"
    Write-Log "  BẮT ĐẦU PHIÊN HOẠT ĐỘNG E5 RENEW SESSION " "INFO"
    Write-Log "==========================================" "INFO"

    # 1. Hoạt động File System
    Invoke-FileSystemActivity

    # 2. Hoạt động Microsoft Graph
    if ($EnableGraphActivities) {
        $scopes = @(
            "Mail.Send", "Calendars.ReadWrite", "Tasks.ReadWrite",
            "Group.ReadWrite.All", "Chat.ReadWrite", "Sites.ReadWrite.All",
            "Application.ReadWrite.All", "Mail.ReadWrite", "MailboxSettings.ReadWrite",
            "User.Read.All"
        )
        
        Ensure-GraphConnection -Scopes $scopes -Username $UserPrincipalName
        
        Invoke-TeamMailBroadcast -UserId $UserPrincipalName -Recipients $TeamMailRecipients
        Invoke-TeamsMeeting -UserId $UserPrincipalName -Attendees $TeamMailRecipients -DurationMinutes 30
        Invoke-CopilotTodoTasks -UserId $UserPrincipalName -Subjects $CopilotTaskSubjects -DueInDays 3
        Invoke-PlannerTasks -PlanId $PlannerPlanId -BucketId $PlannerBucketId -Titles $PlannerTaskTitles -DueInDays 3
        Export-PlannerPlanToExcel -PlanId $PlannerPlanId -OutputDirectory $BasePath | Out-Null
        Invoke-SharePointGraphOps -SiteId $SharePointSiteId -FolderName $SharePointLibraryFolder
        Invoke-TeamsChatMessage -ChatId $TeamsChatId -TeamId $TeamsTeamId -ChannelId $TeamsChannelId
    }

    # 3. Cleanup ngẫu nhiên
    if ((Get-Random -Minimum 1 -Maximum 4) -eq 1) {
        Invoke-CleanupOldFiles
    }

    Write-Log "Hoàn thành toàn bộ hoạt động E5 thành công!" "SUCCESS"
} catch {
    Write-Log ("Lỗi nghiêm trọng trong phiên E5: {0}" -f $_.Exception.Message) "ERROR"
    exit 1
}
