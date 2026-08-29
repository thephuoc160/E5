# 🚀 HỆ THỐNG (TK E5 RENEW)

> **Mục tiêu:** Tự động hóa toàn diện các hoạt động nhằm duy trì trạng thái **Active** liên tục cho gói đăng ký.

---

## 📂 1. Cấu Trúc Thư Mục Dự Án

```
C:\Scripts\
├── 📁 .github/                # CI/CD Tự động hóa trên Cloud (GitHub Actions)
│   ├── workflows/e5-renew.yml # Workflow chạy tự động mỗi 48h trên GitHub Actions
│   └── scripts/e5_cloud_runner.py # Script chạy Cloud đa luồng ($batch, /delta, Mail, Teams)
│
├── 📁 config/                 # Cấu hình tập trung (.env, config.json)
│   ├── config.json            # Cấu hình JSON dùng chung cho PowerShell & Python
│   └── .env.example           # Mẫu biến môi trường cho Secret/Credentials
│
├── 📁 core/                   # Các Module Logic cốt lõi & Web Server
│   ├── server.py              # Web API Server đa luồng phục vụ Dashboard & chạy lệnh 1-Click
│   ├── E5-Dashboard.ps1       # Trình tạo giao diện Dashboard tĩnh/động
│   ├── E5-GraphActivity.ps1   # Gọi Microsoft Graph (Mail, Teams, Planner, To-Do, SharePoint, App Reg...)
│   ├── E5-RcloneMount.ps1     # Quản lý Mount/Unmount/Health Check ổ đĩa M: qua rclone
│   ├── E5-SharePointSync.ps1  # Tác vụ kiểm tra & đồng bộ SharePoint qua rclone
│   ├── E5-OneDriveSync.ps1    # Đồng bộ OneDrive Business <-> Personal bằng Robocopy tối ưu
│   └── E5-RenewHelper.ps1     # Tiện ích phụ (Quick Renew, Draft Mail, Tải Cloud File, Scan Properties)
│
├── 📁 python/                 # Mã nguồn Python
│   ├── PingE5_App.py          # Chạy nền tự động bằng Client Credentials (App Token)
│   ├── PingE5_User.py         # Chạy tương tác qua OAuth2 Web Flow (User Delegated Token)
│   └── requirements.txt       # Danh sách thư viện Python phụ thuộc
│
├── 📁 tasks/                  # Quản lý Windows Task Scheduler
│   ├── Setup-ScheduledTasks.ps1  # Đăng ký lịch tự động (mỗi 24h hoặc 48h)
│   ├── Check-TaskStatus.ps1      # Kiểm tra trạng thái chạy của các Task
│   └── Remove-ScheduledTasks.ps1 # Gỡ bỏ các Task E5 khi cần
│
├── 📁 tools/                  # Công cụ & Môi trường
│   ├── rclone.exe             # Binary rclone chính thức
│   └── Install-Prerequisites.ps1 # Script tự động cài đặt PowerShell Graph Modules & Python deps
│
├── 📁 logs/                   # Nhật ký hoạt động tập trung
│   ├── graph_activity.log
│   ├── mount.log
│   ├── sharepoint_activity.log
│   └── sync_log.txt
│
├── 📁 docs/                   # Tài liệu hướng dẫn & tài liệu cấu hình
│   ├── README.md
│   ├── CONFIG_GUIDE.md
│   └── GITHUB_ACTIONS_GUIDE.md # Hướng dẫn thiết lập GitHub Actions Cloud Runner
│
├── 📊 Dashboard.bat / Dashboard.html # DASHBOARD QUẢN LÝ THEO DÕI & CHẠY LỆNH TRỰC TIẾP
├── 🔑 Reconnect-1Drive.bat           # 1-Click Đăng nhập lại OAuth rclone khi token hết hạn
├── 🖥️ Menu.bat / Menu.ps1           # BẢNG ĐIỀU KHIỂN TRUNG TÂM (Interactive Control Center)
├── ⚡ Run-All.bat / Run-All.ps1       # Chạy 1-Click toàn bộ chu trình Renew
│
└── 🔗 Wrappers Tương Thích Ngược (Đảm bảo Task Scheduler & Phím tắt cũ hoạt động 100%)
    ├── #1.M_Drive.bat         --> Gọi core\E5-RcloneMount.ps1 (Mount)
    ├── #2.run_activity.bat    --> Gọi Run-All.ps1
    ├── #3.odBiz_To_odPer.bat  --> Gọi core\E5-OneDriveSync.ps1
    ├── #unmount.bat           --> Gọi core\E5-RcloneMount.ps1 (Unmount)
    ├── api_activity.ps1       --> Chuyển tiếp tới core\E5-GraphActivity.ps1
    ├── check_mount.ps1        --> Chuyển tiếp tới core\E5-RcloneMount.ps1 (Check)
    └── Renew-E5.ps1           --> Chuyển tiếp tới core\E5-RenewHelper.ps1
```

---

## ⚡ 2. Hướng Dẫn Sử Dụng Nhanh

### 📊 1. Mở Dashboard Quản Lý & Chạy Tác Vụ Trực Tiếp
Nhấp đúp chuột vào file:
👉 **`Dashboard.bat`** (Trình duyệt sẽ mở **`http://127.0.0.1:8765`**)

---

### 🌐 2. Tự Động Hóa Từ Đám Mây (GitHub Actions)
Xem hướng dẫn chi tiết tại: [**`docs/GITHUB_ACTIONS_GUIDE.md`**](file:///c:/Scripts/docs/GITHUB_ACTIONS_GUIDE.md) để kích hoạt pipeline gọi API tự động mỗi 48h từ cloud runner của GitHub!

---

### 🖥️ 3. Mở Bảng Điều Khiển Trung Tâm (Menu)
Nhấp đúp chuột vào file:
👉 **`Menu.bat`**
```
  [D]  📊 Mở Dashboard Quản Lý Theo Dõi (Web Dashboard)
  [1]  🚀 Chạy toàn bộ chu trình Renew (Run All)
  [2]  📁 Mount ổ đĩa M: (OneDrive / SharePoint)
  [3]  🔌 Unmount ổ đĩa M:
  [4]  ⚡ Chạy hoạt động Microsoft Graph (Teams, Mail, Planner, To-Do)
  [5]  🌐 Chạy hoạt động SharePoint API (rclone)
  [6]  🐍 Chạy Python Ping E5 (App Credentials Daemon)
  [7]  🌐 Chạy Python Ping E5 Interactive (User Auth - Web Browser)
  [8]  🔄 Đồng bộ OneDrive Business sang Personal (Robocopy)
  [9]  🛠️ Tiện ích phụ (Quick Renew, Tạo Draft Email, Tải Cloud Files)
  [10] ⏰ Quản lý Task Scheduler (Cài đặt / Kiểm tra / Gỡ bỏ)
  [11] 📦 Cài đặt môi trường & Modules phụ thuộc
  [12] 🔑 Đăng nhập / Làm mới OAuth Token cho rclone (1Drive)
  [0]  🚪 Thoát
```
