# 🌐 HƯỚNG DẪN THIẾT LẬP GITHUB ACTIONS CHO E5 RENEW (CLOUD RUNNER)

> **Mục tiêu:** Tự động chạy chu trình gọi Microsoft Graph API (JSON Batching, Delta Sync, Mail, Teams, Planner) trực tiếp từ đám mây **GitHub Actions**, giúp tăng tối đa điểm tín nhiệm (**Developer Activity Score**) từ Microsoft để tự động gia hạn E5 liên tục.

---

## 🚀 1. Các Hoạt Động Được Thực Thi Trên GitHub Actions

Workflow [`.github/workflows/e5-renew.yml`](file:///c:/Scripts/.github/workflows/e5-renew.yml) sẽ tự động chạy định kỳ (**mỗi 48 giờ** tại các khung giờ `03:25 UTC` và `15:25 UTC`):

1. 🔑 **Xác thực OAuth 2.0 Client Credentials:** Đăng nhập an toàn qua Microsoft Entra ID.
2. 📦 **Microsoft Graph JSON Batching (`$batch`):** Gom nhiều sub-requests truy vấn User, Messages, Drive, Organization trong 1 lần gọi HTTP.
3. 🔄 **Delta Queries (`/delta`):** Theo dõi các thay đổi gia tăng trên Inbox và OneDrive.
4. ✉️ **Gửi Email hoạt động CI/CD:** Gửi thông báo định kỳ đến hộp thư Developer.
5. 💬 **Teams & Planner Activity:** Gửi tin nhắn và kiểm tra tiến độ dự án.
6. 📊 **Báo cáo trực quan:** Tạo bảng thống kê Job Summary chi tiết ngay trên giao diện web của GitHub.

---

## 🛠️ 2. Các Bước Cài Đặt Chi Tiết (3 Phút)

### Bước 1: Đẩy (Push) Mã Nguồn Lên GitHub
Nếu bạn chưa có Repository trên GitHub:
1. Đăng nhập vào [GitHub](https://github.com) và tạo một Repository mới (ví dụ: `E5-Renew-Automation` - có thể chọn chế độ **Private** hoặc **Public**).
2. Mở PowerShell tại thư mục `C:\Scripts` và chạy các lệnh:
```bash
git init
git add .
git commit -m "feat: Add Microsoft 365 E5 Renew Engine with GitHub Actions"
git branch -M main
git remote add origin https://github.com/<USERNAME>/<REPO_NAME>.git
git push -u origin main
```

---

### Bước 2: Cấu Hình GitHub Secrets (Bảo Mật Tuyệt Đối)
Để bảo mật thông tin tài khoản và không để lộ Secret trên mã nguồn công khai:

1. Trên trang Repository GitHub của bạn, vào:
   👉 **Settings** $\rightarrow$ **Secrets and variables** $\rightarrow$ **Actions**.
2. Nhấp vào nút **New repository secret** và thêm lần lượt 4 biến sau:

| Tên Secret (Name) | Giá Trị (Value) | Nguồn Lấy |
| :--- | :--- | :--- |
| `AZURE_TENANT_ID` | `Directory (Tenant) ID của bạn` | Lấy từ Azure Portal / `config.json` |
| `AZURE_CLIENT_ID` | `Application (Client) ID của bạn` | Lấy từ Azure Portal / `config.json` |
| `AZURE_CLIENT_SECRET` | `Client Secret Value của bạn` | Lấy từ Azure Portal / `config.json` |
| `USER_PRINCIPAL_NAME` | `Email tài khoản Admin E5 của bạn` | Ví dụ: `admin@yourdomain.onmicrosoft.com` |

*(Tùy chọn thêm nếu muốn gửi tin nhắn Teams: `TEAMS_TEAM_ID`, `TEAMS_CHANNEL_ID`, `PLANNER_PLAN_ID`)*

---

### Bước 3: Kiểm Tra & Chạy Thử Trên GitHub
1. Trên giao diện GitHub, nhấp vào tab **Actions**.
2. Chọn workflow **`Microsoft 365 E5 Auto Renew Activity`** ở danh sách bên trái.
3. Nhấp vào nút **Run workflow** $\rightarrow$ Chọn nhánh `main` $\rightarrow$ Nhấn **Run workflow**.
4. Chờ khoảng 5-10 giây, bạn sẽ thấy job hoàn thành với biểu tượng **Tích xanh (Success)** kèm bảng báo cáo trực quan đầy đủ!

---

## 🔒 3. Tính An Toàn & Bảo Mật

- **Không lưu Secret trong code:** Mọi thông tin nhạy cảm đều được bảo vệ trong GitHub Encrypted Secrets.
- **Không phụ thuộc thư viện ngoài:** Script Python chạy hoàn toàn bằng thư viện gốc (`urllib`, `json`), đảm bảo không có rủi ro supply chain attack.
- **Cơ chế Retry thông minh:** Tự động bắt lỗi rate limit (HTTP 429) và tự động thử lại sau vài giây.
