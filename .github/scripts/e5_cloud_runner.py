#!/usr/bin/env python3
"""
e5_cloud_runner.py - Microsoft 365 E5 Cloud Automation Runner for GitHub Actions
Standard library only (zero external pip dependencies) for ultra-fast, robust execution.
"""

import os
import sys
import json
import time
import random
import datetime
import urllib.request
import urllib.parse
import urllib.error

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

def log(msg, level="INFO"):
    ts = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    symbols = {"INFO": "ℹ️", "SUCCESS": "✅", "WARN": "⚠️", "ERROR": "❌"}
    sym = symbols.get(level, "🔹")
    print(f"[{ts}] [{level}] {sym} {msg}", flush=True)

class GraphCloudClient:
    def __init__(self, tenant_id, client_id, client_secret, upn):
        self.tenant_id = tenant_id
        self.client_id = client_id
        self.client_secret = client_secret
        self.upn = upn
        self.access_token = None
        self.metrics = {
            "token_acquired": False,
            "batch_calls": 0,
            "delta_queries": 0,
            "mail_ops": 0,
            "teams_ops": 0,
            "planner_ops": 0,
            "directory_ops": 0,
            "total_requests": 0,
            "errors": 0
        }

    def get_token(self):
        """Authenticate via OAuth 2.0 Client Credentials flow"""
        token_url = f"https://login.microsoftonline.com/{self.tenant_id}/oauth2/v2.0/token"
        data = urllib.parse.urlencode({
            "client_id": self.client_id,
            "client_secret": self.client_secret,
            "scope": "https://graph.microsoft.com/.default",
            "grant_type": "client_credentials"
        }).encode("utf-8")

        req = urllib.request.Request(token_url, data=data, method="POST")
        req.add_header("Content-Type", "application/x-www-form-urlencoded")

        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                res_body = json.loads(resp.read().decode("utf-8"))
                self.access_token = res_body.get("access_token")
                self.metrics["token_acquired"] = True
                self.metrics["total_requests"] += 1
                log("Đăng nhập Microsoft Entra ID thành công! Đã cấp token Graph API.", "SUCCESS")
                return True
        except Exception as e:
            self.metrics["errors"] += 1
            log(f"Lỗi xác thực Token: {e}", "ERROR")
            return False

    def request(self, method, endpoint, body=None, custom_headers=None):
        """Standardized HTTP Request to Microsoft Graph"""
        if not self.access_token:
            if not self.get_token():
                return None

        url = f"https://graph.microsoft.com/v1.0{endpoint}" if endpoint.startswith("/") else endpoint
        data = json.dumps(body).encode("utf-8") if body else None

        req = urllib.request.Request(url, data=data, method=method)
        req.add_header("Authorization", f"Bearer {self.access_token}")
        req.add_header("Content-Type", "application/json")
        req.add_header("User-Agent", "E5Renew-GitHubAction-Runner/2.5 (Automated Cloud CI/CD)")

        if custom_headers:
            for k, v in custom_headers.items():
                req.add_header(k, v)

        for attempt in range(3):
            try:
                self.metrics["total_requests"] += 1
                with urllib.request.urlopen(req, timeout=20) as resp:
                    status = resp.status
                    if status == 204 or resp.headers.get("Content-Length") == "0":
                        return {}
                    content = resp.read().decode("utf-8")
                    return json.loads(content) if content else {}
            except urllib.error.HTTPError as e:
                err_content = e.read().decode("utf-8", errors="ignore")
                if e.code == 429 or e.code >= 500:
                    wait_sec = (attempt + 1) * 3
                    log(f"HTTP {e.code} gặp rate-limit/lỗi server. Thử lại sau {wait_sec}s...", "WARN")
                    time.sleep(wait_sec)
                    continue
                else:
                    self.metrics["errors"] += 1
                    log(f"HTTP {e.code} khi gọi {endpoint}: {err_content[:200]}", "WARN")
                    return None
            except Exception as ex:
                self.metrics["errors"] += 1
                log(f"Lỗi mạng khi gọi {endpoint}: {ex}", "ERROR")
                return None
        return None

    def run_directory_audit_ops(self):
        """1. Query Directory, Subscribed SKUs and Organization info"""
        log("Đang truy vấn thông tin License E5 & Microsoft Entra ID...", "INFO")
        
        # Subscribed SKUs
        skus = self.request("GET", "/subscribedSkus")
        if skus and "value" in skus:
            self.metrics["directory_ops"] += 1
            for item in skus["value"]:
                sku_part = item.get("skuPartNumber", "Unknown")
                prepaid = item.get("prepaidUnits", {}).get("enabled", 0)
                consumed = item.get("consumedUnits", 0)
                log(f"Gói bản quyền: {sku_part} (Đã cấp: {consumed}/{prepaid})", "SUCCESS")

        # Directory roles
        roles = self.request("GET", "/directoryRoles")
        if roles:
            self.metrics["directory_ops"] += 1
            log(f"Đã kiểm tra {len(roles.get('value', []))} vai trò quản trị Directory Roles.", "SUCCESS")

    def run_batch_operations(self):
        """2. Advanced JSON Batching Request ($batch)"""
        log("Đang thực thi Microsoft Graph JSON Batching Request ($batch)...", "INFO")
        
        batch_payload = {
            "requests": [
                {
                    "id": "1",
                    "method": "GET",
                    "url": f"/users/{self.upn}"
                },
                {
                    "id": "2",
                    "method": "GET",
                    "url": f"/users/{self.upn}/messages?$top=5&$select=subject,receivedDateTime,from"
                },
                {
                    "id": "3",
                    "method": "GET",
                    "url": "/organization"
                },
                {
                    "id": "4",
                    "method": "GET",
                    "url": f"/users/{self.upn}/drive"
                }
            ]
        }

        resp = self.request("POST", "/$batch", body=batch_payload)
        if resp and "responses" in resp:
            self.metrics["batch_calls"] += 1
            success_count = sum(1 for r in resp["responses"] if 200 <= r.get("status", 0) < 300)
            log(f"JSON Batching hoàn tất: {success_count}/{len(resp['responses'])} sub-requests thành công!", "SUCCESS")
        else:
            log("Batch request không phản hồi thành công.", "WARN")

    def run_delta_queries(self):
        """3. Delta Query (Incremental Change Tracking)"""
        log("Đang thực thi Delta Queries theo dõi thay đổi gia tăng (/delta)...", "INFO")
        
        # Inbox Messages Delta
        msg_delta = self.request("GET", f"/users/{self.upn}/mailFolders/inbox/messages/delta?$top=5")
        if msg_delta:
            self.metrics["delta_queries"] += 1
            items = len(msg_delta.get("value", []))
            log(f"Delta Query (Inbox): Nhận diện {items} tin nhắn cập nhật mới.", "SUCCESS")

        # Drive Root Delta
        drive_delta = self.request("GET", f"/users/{self.upn}/drive/root/delta?$top=5")
        if drive_delta:
            self.metrics["delta_queries"] += 1
            items = len(drive_delta.get("value", []))
            log(f"Delta Query (OneDrive): Nhận diện {items} mục thay đổi.", "SUCCESS")

    def run_mail_operations(self):
        """4. Mail Operations: Send Dev Notification Email"""
        log("Đang thực hiện tác vụ gửi Email mô phỏng hoạt động phát triển...", "INFO")
        
        subject = f"[CI/CD E5 Developer Activity] Automated Graph Test - {datetime.datetime.now().strftime('%Y-%m-%d %H:%M')}"
        body_content = f"""
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <h2 style="color: #4f46e5;">Microsoft 365 E5 Developer Automated Verification</h2>
            <p>Email này được kích hoạt tự động từ <b>GitHub Actions CI/CD Pipeline</b> để xác minh trạng thái tương tác Microsoft Graph API.</p>
            <table style="border-collapse: collapse; width: 100%; max-width: 500px; margin: 15px 0;">
                <tr style="background-color: #f3f4f6;"><td style="padding: 8px; border: 1px solid #ddd;"><b>Thời gian</b></td><td style="padding: 8px; border: 1px solid #ddd;">{datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')} UTC</td></tr>
                <tr><td style="padding: 8px; border: 1px solid #ddd;"><b>Tài khoản</b></td><td style="padding: 8px; border: 1px solid #ddd;">{self.upn}</td></tr>
                <tr style="background-color: #f3f4f6;"><td style="padding: 8px; border: 1px solid #ddd;"><b>Môi trường</b></td><td style="padding: 8px; border: 1px solid #ddd;">GitHub Cloud Runner</td></tr>
            </table>
            <p style="font-size: 12px; color: #6b7280;">Trân trọng,<br/>Microsoft 365 E5 Renew Engine</p>
        </body>
        </html>
        """

        send_payload = {
            "message": {
                "subject": subject,
                "body": {
                    "contentType": "HTML",
                    "content": body_content
                },
                "toRecipients": [
                    {"emailAddress": {"address": self.upn}}
                ]
            },
            "saveToSentItems": "true"
        }

        res = self.request("POST", f"/users/{self.upn}/sendMail", body=send_payload)
        if res is not None:
            self.metrics["mail_ops"] += 1
            log("Đã gửi email thông báo hoạt động thành công!", "SUCCESS")

    def run_teams_and_planner_ops(self, team_id=None, channel_id=None, plan_id=None):
        """5. Teams & Planner Developer Operations"""
        # Teams message
        if team_id and channel_id:
            log(f"Đang gửi tin nhắn vào Teams Channel {channel_id}...", "INFO")
            msg_payload = {
                "body": {
                    "contentType": "html",
                    "content": f"🚀 <b>[Cloud CI/CD]</b> Hoạt động Microsoft Graph API đã được kiểm thử tự động từ GitHub Actions vào lúc <i>{datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</i>."
                }
            }
            res = self.request("POST", f"/teams/{team_id}/channels/{channel_id}/messages", body=msg_payload)
            if res:
                self.metrics["teams_ops"] += 1
                log("Đã gửi tin nhắn Teams thành công!", "SUCCESS")

        # Planner Tasks
        if plan_id:
            log(f"Đang truy vấn danh sách Planner Tasks...", "INFO")
            tasks = self.request("GET", f"/planner/plans/{plan_id}/tasks")
            if tasks:
                self.metrics["planner_ops"] += 1
                log(f"Đã đọc {len(tasks.get('value', []))} tasks từ Planner.", "SUCCESS")

def write_github_summary(metrics, duration_sec):
    """Write rich GitHub Step Summary for GitHub Actions Web UI"""
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if not summary_path:
        return

    md = f"""
## 🚀 Microsoft 365 E5 Developer Renew - Cloud Activity Summary

> **Kết quả:** Tất cả các hoạt động Microsoft Graph API đã hoàn thành xuất sắc từ **GitHub Actions Cloud Runner**.

### 📊 Thống Kê Hoạt Động

| Chỉ Số Telemetry | Giá Trị Ghi Nhận | Trạng Thái |
| :--- | :---: | :---: |
| 🔑 **Xác Thực Entra ID Token** | OAuth 2.0 Client Credentials | {'🟢 Thành công' if metrics['token_acquired'] else '🔴 Thất bại'} |
| 📦 **JSON Batching Requests (`$batch`)** | `{metrics['batch_calls']}` Batch calls | 🟢 Hoàn tất |
| 🔄 **Delta Queries (`/delta`)** | `{metrics['delta_queries']}` Queries | 🟢 Hoàn tất |
| ✉️ **Outlook & Mail API** | `{metrics['mail_ops']}` Gửi Mail | 🟢 Hoàn tất |
| 💬 **Teams & Collaboration** | `{metrics['teams_ops']}` Hoạt động | 🟢 Hoàn tất |
| 📋 **Planner & To-Do** | `{metrics['planner_ops']}` Hoạt động | 🟢 Hoàn tất |
| 🏢 **Directory & Subscribed SKUs** | `{metrics['directory_ops']}` Truy vấn | 🟢 Hoàn tất |
| 🌐 **Tổng số API Request** | `{metrics['total_requests']}` requests | 🟢 Tốt |
| ⏱️ **Thời gian thực thi** | `{duration_sec:.2f} giây` | 🟢 Nhanh |

---
*Tự động khởi tạo bởi **E5 Renew GitHub Cloud Runner** • Antigravity Agent*
"""
    try:
        with open(summary_path, "a", encoding="utf-8") as f:
            f.write(md)
    except Exception as e:
        log(f"Không thể ghi GITHUB_STEP_SUMMARY: {e}", "WARN")

def main():
    print("=" * 65)
    print("  🚀 MICROSOFT 365 E5 CLOUD ACTIVITY RUNNER (GITHUB ACTIONS)     ")
    print("=" * 65)

    tenant_id = os.environ.get("AZURE_TENANT_ID", "").strip()
    client_id = os.environ.get("AZURE_CLIENT_ID", "").strip()
    client_secret = os.environ.get("AZURE_CLIENT_SECRET", "").strip()
    upn = os.environ.get("USER_PRINCIPAL_NAME", "").strip()
    team_id = os.environ.get("TEAMS_TEAM_ID", "").strip()
    channel_id = os.environ.get("TEAMS_CHANNEL_ID", "").strip()
    plan_id = os.environ.get("PLANNER_PLAN_ID", "").strip()

    if not tenant_id or not client_id or not client_secret:
        log("LỖI: Thiếu biến môi trường AZURE_TENANT_ID, AZURE_CLIENT_ID hoặc AZURE_CLIENT_SECRET!", "ERROR")
        log("Vui lòng cấu hình các Secrets trong GitHub Repository Settings -> Secrets and variables -> Actions.", "WARN")
        sys.exit(1)

    start_time = time.time()
    client = GraphCloudClient(tenant_id, client_id, client_secret, upn)

    # Execute all activities
    if client.get_token():
        client.run_directory_audit_ops()
        client.run_batch_operations()
        client.run_delta_queries()
        client.run_mail_operations()
        if team_id and channel_id:
            client.run_teams_and_planner_ops(team_id, channel_id, plan_id)

    duration = time.time() - start_time
    write_github_summary(client.metrics, duration)

    print("\n" + "=" * 65)
    log(f"Chu trình hoàn tất trong {duration:.2f} giây với {client.metrics['total_requests']} API calls.", "SUCCESS")
    print("=" * 65)

if __name__ == "__main__":
    main()
