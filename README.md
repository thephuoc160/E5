# Microsoft 365 E5 — bộ script quản lý

Mã nguồn trong `C:\Scripts`, liên kết với repository `thephuoc160/E5`.

## Bắt đầu sử dụng

| File tại thư mục gốc | Chức năng |
| --- | --- |
| [Menu.bat](Menu.bat) | Mở menu chọn chức năng |
| [Dashboard.bat](Dashboard.bat) | Mở Dashboard tại `http://127.0.0.1:8765` |
| [Run-All.bat](Run-All.bat) | Chạy chu trình hoạt động đã cấu hình |
| [Reconnect-1Drive.bat](Reconnect-1Drive.bat) | Đăng nhập lại kết nối rclone `1Drive:` |

## Nội dung từng thư mục

| Thư mục | Nội dung | File chính |
| --- | --- | --- |
| `launchers/` | Các lệnh khởi chạy và điều phối | `Menu.ps1`, `Run-All.ps1`, các file `.bat` có tên mô tả |
| `dashboard/` | Máy chủ web, trình tạo giao diện, HTML được sinh tại máy | `server.py`, `E5-Dashboard.ps1` |
| `core/` | Xử lý Graph, mount, đồng bộ và các tiện ích | `E5-GraphActivity.ps1`, `E5-RcloneMount.ps1`, `E5-OneDriveSync.ps1`, `E5-SharePointSync.ps1`, `E5-RenewHelper.ps1` |
| `python/` | Chương trình Python chạy bằng tài khoản ứng dụng hoặc người dùng | `PingE5_App.py`, `PingE5_User.py`, `requirements.txt` |
| `tasks/` | Quản lý Windows Task Scheduler | `Setup-ScheduledTasks.ps1`, `Check-TaskStatus.ps1`, `Remove-ScheduledTasks.ps1` |
| `config/` | Cấu hình máy và các file mẫu | `config.json`, `config.example.json`, `.env.example` |
| `tools/` | Công cụ và cài đặt phụ thuộc | `rclone.exe`, `Install-Prerequisites.ps1` |
| `docs/` | Hướng dẫn cấu hình, GitHub Actions và bảng đường dẫn | [Mục lục](docs/README.md) |
| `logs/` | Nhật ký chạy tại máy | `graph_activity.log`, `mount.log`, các log khác |
| `scratch/` | Dữ liệu thử nghiệm hoặc tạm thời | `drive_sim/`, `sharepoint/` |
| `shortcuts/` | Phím tắt riêng tại máy | `AppQuiz_Azure.lnk` |

Các file khởi chạy cũ tại thư mục gốc và hai file `core/server.py`, `core/E5-Dashboard.ps1` là file chuyển tiếp. Khi chỉnh sửa chức năng, sửa mã nguồn ở thư mục tương ứng trong bảng trên. Bảng ánh xạ đầy đủ nằm trong [docs/STRUCTURE.md](docs/STRUCTURE.md).

## Lệnh thường dùng

Chạy trong PowerShell tại thư mục dự án:

```powershell
# Mở menu
.\Menu.bat

# Mở Dashboard
.\Dashboard.bat

# Chạy chu trình; có thể bỏ qua mount hoặc SharePoint
.\launchers\Run-All.ps1 -SkipMount -SkipSharePoint

# Chỉ tạo HTML, không mở máy chủ hoặc trình duyệt
.\dashboard\E5-Dashboard.ps1 -NoServe -NoBrowser

# Xem trạng thái lịch chạy
.\tasks\Check-TaskStatus.ps1
```

Máy chủ Python dùng cổng `8765`. Phương án PowerShell dự phòng dùng cổng `5500`. Nếu HTML chưa có sau khi tải mã nguồn, máy chủ Python sẽ gọi trình tạo HTML trước khi phục vụ giao diện.

## Cấu hình và dữ liệu tại máy

- Thiết lập theo [hướng dẫn cấu hình](docs/CONFIG_GUIDE.md). File mẫu nằm ở `config/config.example.json`.
- Cài phụ thuộc bằng `tools/Install-Prerequisites.ps1`; danh sách Python nằm ở `python/requirements.txt`.
- Yêu cầu Python 3.10 trở lên. `python/requirements.lock` khóa toàn bộ phiên bản để cài đặt có thể tái lập; chỉ cập nhật lockfile sau khi chạy kiểm tra dependency.
- `config/config.json`, HTML sinh tự động, log, dữ liệu tạm, phím tắt và công cụ `.exe` được loại khỏi Git bằng `.gitignore`.
- Vì an toàn dữ liệu, `PingE5_App.py` không xóa nội dung OneDrive mặc định. Chỉ bật `settings.allowRemoteCleanup` sau khi đã xác nhận đúng remote và thư mục đích.
- Quy trình trên GitHub dùng file riêng và các Secrets của repository; xem [hướng dẫn GitHub Actions](docs/GITHUB_ACTIONS_GUIDE.md).

## Kiểm tra chất lượng

Các kiểm tra không gọi Microsoft Graph, không gửi mail và không thay đổi dữ liệu cloud:

```powershell
python -m pip install -r python\requirements-dev.txt
python -m unittest discover -s tests -v
ruff check .
ruff format --check .
pip-audit -r python\requirements.lock
bandit -q -ll -r .github\scripts dashboard python -x tests
```

GitHub Actions chạy lại lint, test, audit dependency và parse toàn bộ PowerShell trong workflow `Code quality`.
