# Cấu trúc và đường dẫn tương thích

Sắp xếp lại ngày 02/11/2026 trong `C:\Scripts`.

## Quy tắc lưu file

| Loại nội dung | Vị trí |
| --- | --- |
| Lệnh khởi chạy, menu và điều phối | `launchers/` |
| Giao diện web và máy chủ Dashboard | `dashboard/` |
| Chức năng PowerShell dùng chung | `core/` |
| Chức năng Python | `python/` |
| Cài đặt, kiểm tra và gỡ lịch chạy | `tasks/` |
| Cấu hình | `config/` |
| Công cụ và cài đặt phụ thuộc | `tools/` |
| Hướng dẫn | `docs/` |
| Kết quả chạy và nhật ký | `logs/` |
| Dữ liệu tạm hoặc mô phỏng | `scratch/` |
| Phím tắt riêng tại máy | `shortcuts/` |

Mã Python và PowerShell xác định đường dẫn dự án từ vị trí file. Các file `.bat` trong `launchers/` chuyển thư mục làm việc về gốc dự án trước khi gọi mã nguồn.

## Các file khởi chạy tại thư mục gốc

Các đường dẫn sau vẫn có file chuyển tiếp để các lệnh, phím tắt và Task Scheduler đã dùng chúng tiếp tục tìm được mã nguồn. Tham số của file `.bat`, menu và `Run-All.ps1` được chuyển tiếp.

| Đường dẫn cũ | Mã nguồn hiện tại |
| --- | --- |
| `Menu.bat` | `launchers/Menu.bat` |
| `Menu.ps1` | `launchers/Menu.ps1` |
| `Dashboard.bat` | `launchers/Dashboard.bat` |
| `Run-All.bat` | `launchers/Run-All.bat` |
| `Run-All.ps1` | `launchers/Run-All.ps1` |
| `Reconnect-1Drive.bat` | `launchers/Reconnect-1Drive.bat` |
| `Push-To-GitHub.bat` | `launchers/Push-To-GitHub.bat` |
| `#1.M_Drive.bat` | `launchers/Mount-Drive.bat` |
| `#2.run_activity.bat` | `launchers/Run-Activity.bat` |
| `#3.odBiz_To_odPer.bat` | `launchers/Sync-OneDrive.bat` |
| `#unmount.bat` | `launchers/Unmount-Drive.bat` |
| `run_api.bat` | `launchers/Run-Api.bat` |
| `run_sharepoint.bat` | `launchers/Run-SharePoint.bat` |
| `core/server.py` | `dashboard/server.py` |
| `core/E5-Dashboard.ps1` | `dashboard/E5-Dashboard.ps1` |

Các file chuyển tiếp có từ trước như `api_activity.ps1`, `check_mount.ps1`, `Renew-E5.ps1`, `Renew_Upload.ps1`, `create_draft.ps1`, `4. auto.ps1`, `4. check.ps1`, `4. manual.ps1`, `PingE5_App.py` và `PingE5_User.py` tiếp tục được giữ ở gốc.

## File và dữ liệu tại máy đã chuyển

| Trước | Sau |
| --- | --- |
| `Dashboard.html` | `dashboard/Dashboard.html`; vị trí cũ chứa trang chuyển tiếp |
| `scratch_drive_sim/` | `scratch/drive_sim/` |
| `scratch_sp_test/` | `scratch/sharepoint/` |
| `AppQuiz_Azure.lnk` | `shortcuts/AppQuiz_Azure.lnk` |

Script Graph dùng `scratch/drive_sim/` khi cần dữ liệu mô phỏng tại máy. Script SharePoint dùng `scratch/sharepoint/` cho dữ liệu tạm.

`dashboard/Dashboard.html` do trình tạo PowerShell sinh từ cấu hình và trạng thái tại máy. Khi file này chưa có, máy chủ Python tạo file trước khi mở giao diện. Các URL `/`, `/index.html` và `/Dashboard.html` vẫn phục vụ Dashboard.

Việc sắp xếp không thay đổi nội dung `config/config.json`, nhật ký hiện có, công cụ rclone hoặc hai file chạy trên GitHub.
