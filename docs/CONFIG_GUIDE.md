# 📖 HƯỚNG DẪN CẤU HÌNH CHI TIẾT (CONFIG GUIDE)

Tài liệu này hướng dẫn chi tiết cách thiết lập App Registration trên Azure Portal, cấu hình Microsoft Graph API và thiết lập rclone.

---

## 1. Cấu Hình Azure AD App Registration

1. Truy cập [Azure Portal](https://portal.azure.com) -> **Microsoft Entra ID** -> **App registrations** -> **New registration**.
2. Đặt tên App (ví dụ: `E5_Renew_Bot`), chọn **Accounts in this organizational directory only**.
3. **API Permissions** -> **Add a permission** -> **Microsoft Graph**:
   - **Application permissions** (cho `PingE5_App.py` và backend daemon):
     - `Mail.Send`
     - `Files.ReadWrite.All`
     - `Sites.ReadWrite.All`
     - `User.Read.All`
     - `Group.ReadWrite.All`
     - `Calendars.ReadWrite`
   - **Delegated permissions** (cho `PingE5_User.py` và PowerShell Interactive):
     - `User.Read`
     - `Mail.Send`
     - `Mail.ReadWrite`
     - `Files.ReadWrite`
     - `Tasks.ReadWrite`
     - `Group.ReadWrite.All`
     - `ChannelMessage.Send`
   - Nhấn **Grant admin consent for <Tenant>**.
4. **Certificates & secrets** -> **New client secret** -> Copy Value và dán vào `config/config.json` (`clientSecret`).
5. **Authentication** -> Thêm Redirect URI kiểu Web: `http://localhost:8000/callback`.

---

## 2. Cấu Hình Rclone (OneDrive & SharePoint)

Để rclone kết nối được với OneDrive và SharePoint:

1. Chạy lệnh:
   ```cmd
   tools\rclone.exe config
   ```
2. **Cấu hình Remote `1Drive` (OneDrive Business):**
   - Chọn `n` (New remote) -> Tên: `1Drive`
   - Loại lưu trữ: chọn `Microsoft OneDrive` (số tương ứng)
   - Để trống Client ID & Secret nếu dùng mặc định
   - Đăng nhập tài khoản E5 qua trình duyệt
   - Chọn loại drive: `OneDrive Personal or Business`
3. **Cấu hình Remote `sharepoint` (SharePoint Site):**
   - Chọn `n` (New remote) -> Tên: `sharepoint`
   - Loại lưu trữ: chọn `Microsoft OneDrive`
   - Chọn drive type: `Sharepoint site's document library`
   - Nhập URL Site (ví dụ: `https://yourdomain.sharepoint.com/sites/yourdevsite`)
   - Chọn Document Library (`Documents`)

---

## 3. Kiểm Tra Kết Nối

- Kiểm tra OneDrive: `tools\rclone.exe lsd 1Drive:`
- Kiểm tra SharePoint: `tools\rclone.exe lsd sharepoint:`
- Kiểm tra Mount: `powershell .\core\E5-RcloneMount.ps1 -Action Mount`
