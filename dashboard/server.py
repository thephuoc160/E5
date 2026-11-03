"""server.py - High-Performance Multi-Threaded Local Server for E5 Renew Dashboard.

Serves the modern Dashboard and executes PowerShell / Python automation scripts
directly from Web API endpoints with real-time output capturing.
"""

import json
import logging
import os
import subprocess
import sys
from collections import deque
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

PORT = 8765
ROOT_DIR = Path(__file__).resolve().parent.parent
LOG_DIR = ROOT_DIR / "logs"
CONFIG_FILE = ROOT_DIR / "config" / "config.json"
HTML_FILE = Path(__file__).resolve().parent / "Dashboard.html"
MAX_REQUEST_BODY_BYTES = 4 * 1024

LOG_DIR.mkdir(parents=True, exist_ok=True)
SERVER_LOG = LOG_DIR / "dashboard_server.log"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(SERVER_LOG, encoding="utf-8"),
        logging.StreamHandler(),
    ],
)
LOGGER = logging.getLogger(__name__)


def get_telemetry():
    """Collects live system and E5 metrics."""
    cfg = {}
    if CONFIG_FILE.exists():
        try:
            with open(CONFIG_FILE, "r", encoding="utf-8") as f:
                cfg = json.load(f)
        except (OSError, json.JSONDecodeError) as exc:
            LOGGER.warning("Error reading config.json: %s", exc)

    drive_letter = cfg.get("rclone", {}).get("driveLetter", "M:")
    is_mounted = os.path.exists(f"{drive_letter}\\")
    mount_remote = cfg.get("rclone", {}).get("oneDriveRemote", "1Drive:")

    # Check tasks via PowerShell
    tasks_info = []
    try:
        ps_cmd = (
            'Get-ScheduledTask | Where-Object { $_.TaskName -like "*E5*" } |'
            " ForEach-Object { $info = Get-ScheduledTaskInfo -TaskName"
            " $_.TaskName -ErrorAction SilentlyContinue; [PSCustomObject]@{ Name ="
            " $_.TaskName; State = $_.State.ToString(); LastRun ="
            ' ($info.LastRunTime.ToString("yyyy-MM-dd HH:mm:ss")); NextRun ='
            ' ($info.NextRunTime.ToString("yyyy-MM-dd HH:mm:ss")); LastResult ='
            " $info.LastTaskResult } } | ConvertTo-Json -Depth 3"
        )
        proc = subprocess.run(
            ["powershell", "-NoProfile", "-Command", ps_cmd],
            capture_output=True,
            text=True,
            timeout=8,
            check=False,
        )
        if proc.stdout.strip():
            raw = json.loads(proc.stdout)
            if isinstance(raw, list):
                tasks_info = raw
            elif isinstance(raw, dict):
                tasks_info = [raw]
    except (OSError, subprocess.TimeoutExpired, json.JSONDecodeError) as exc:
        LOGGER.warning("Error querying task scheduler: %s", exc)

    # Count successes, warnings, errors from logs
    success_count = 0
    warn_count = 0
    error_count = 0
    graph_log = LOG_DIR / "graph_activity.log"
    if graph_log.exists():
        try:
            with open(graph_log, "r", encoding="utf-8", errors="ignore") as f:
                for line in f:
                    if "SUCCESS" in line:
                        success_count += 1
                    elif "WARN" in line:
                        warn_count += 1
                    elif "ERROR" in line:
                        error_count += 1
        except OSError as exc:
            LOGGER.debug("Could not read %s: %s", graph_log, exc)

    # Recent logs tail
    recent_logs = []
    for log_name in [
        "graph_activity.log",
        "master_run.log",
        "mount.log",
        "sharepoint_activity.log",
        "sync_log.txt",
    ]:
        lf = LOG_DIR / log_name
        if lf.exists():
            try:
                with open(lf, "r", encoding="utf-8", errors="ignore") as f:
                    for line in deque(f, maxlen=15):
                        if line.strip():
                            recent_logs.append({"file": log_name, "text": line.strip()})
            except OSError as exc:
                LOGGER.debug("Could not read %s: %s", lf, exc)

    return {
        "GeneratedAt": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "TenantId": cfg.get("azure", {}).get("tenantId", "YOUR_TENANT_ID"),
        "UserUPN": cfg.get("azure", {}).get(
            "userPrincipalName", "admin@yourdomain.onmicrosoft.com"
        ),
        "IsMounted": is_mounted,
        "DriveLetter": drive_letter,
        "MountRemote": mount_remote,
        "Tasks": tasks_info,
        "SuccessCount": success_count,
        "WarnCount": warn_count,
        "ErrorCount": error_count,
        "RecentLogs": recent_logs[-30:],
    }


def get_action_command(action_name: str) -> list[str] | None:
    """Return a fixed argv list for an allowed dashboard action."""
    powershell = ["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass"]
    cmd_map = {
        "run_all": powershell + ["-File", str(ROOT_DIR / "launchers" / "Run-All.ps1")],
        "mount": powershell
        + [
            "-File",
            str(ROOT_DIR / "core" / "E5-RcloneMount.ps1"),
            "-Action",
            "Mount",
        ],
        "unmount": powershell
        + [
            "-File",
            str(ROOT_DIR / "core" / "E5-RcloneMount.ps1"),
            "-Action",
            "Unmount",
        ],
        "check_mount": powershell
        + [
            "-File",
            str(ROOT_DIR / "core" / "E5-RcloneMount.ps1"),
            "-Action",
            "Check",
        ],
        "graph_activity": powershell
        + [
            "-File",
            str(ROOT_DIR / "core" / "E5-GraphActivity.ps1"),
            "-BasePath",
            r"M:\API_Output",
            "-EnableGraphActivities",
        ],
        "sharepoint_sync": powershell
        + ["-File", str(ROOT_DIR / "core" / "E5-SharePointSync.ps1")],
        "python_app": [sys.executable, str(ROOT_DIR / "python" / "PingE5_App.py")],
        "onedrive_sync": powershell
        + ["-File", str(ROOT_DIR / "core" / "E5-OneDriveSync.ps1")],
        "setup_tasks": powershell
        + [
            "-File",
            str(ROOT_DIR / "tasks" / "Setup-ScheduledTasks.ps1"),
            "-IntervalHours",
            "48",
        ],
        "check_tasks": powershell
        + ["-File", str(ROOT_DIR / "tasks" / "Check-TaskStatus.ps1")],
        "quick_renew": powershell
        + [
            "-File",
            str(ROOT_DIR / "core" / "E5-RenewHelper.ps1"),
            "-Action",
            "QuickRenew",
        ],
        "create_draft": powershell
        + [
            "-File",
            str(ROOT_DIR / "core" / "E5-RenewHelper.ps1"),
            "-Action",
            "CreateDraft",
        ],
    }
    return cmd_map.get(action_name)


def is_trusted_request(host: str | None, origin: str | None, port: int) -> bool:
    """Allow only requests addressed to this loopback server.

    Browser requests without an Origin are allowed for direct navigation and
    command-line clients. When Origin is present, it must match this server.
    """
    allowed_hosts = {
        f"127.0.0.1:{port}",
        f"localhost:{port}",
        f"[::1]:{port}",
    }
    if not host or host.lower() not in allowed_hosts:
        return False
    if not origin:
        return True

    parsed = urlparse(origin)
    try:
        origin_port = parsed.port
    except ValueError:
        return False
    return (
        parsed.scheme == "http"
        and parsed.hostname in {"127.0.0.1", "localhost", "::1"}
        and origin_port == port
        and not parsed.username
        and not parsed.password
        and parsed.path in {"", "/"}
        and not parsed.query
        and not parsed.fragment
    )


def execute_action_command(action_name: str) -> dict:
    """Executes the mapped PowerShell or Python command."""
    if action_name == "reconnect_1drive":
        try:
            subprocess.Popen(
                [
                    "cmd.exe",
                    "/d",
                    "/c",
                    str(ROOT_DIR / "launchers" / "Reconnect-1Drive.bat"),
                ],
                cwd=ROOT_DIR,
                creationflags=getattr(subprocess, "CREATE_NEW_CONSOLE", 0),
            )
            return {
                "Success": True,
                "Output": "Đã mở cửa sổ kết nối lại OneDrive.",
                "ExitCode": 0,
            }
        except OSError as exc:
            LOGGER.exception("Failed to start OneDrive reconnect action")
            return {
                "Success": False,
                "Output": f"Không thể mở tác vụ kết nối lại: {exc}",
                "ExitCode": -1,
            }

    cmd = get_action_command(action_name)
    if not cmd:
        return {
            "Success": False,
            "Output": f"Hành động không hợp lệ: {action_name}",
            "ExitCode": 1,
        }

    LOGGER.info("Executing dashboard action [%s]", action_name)
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=300,
            check=False,
            cwd=ROOT_DIR,
        )
        output = (proc.stdout + "\n" + proc.stderr).strip()
        return {
            "Success": proc.returncode == 0,
            "Output": output
            if output
            else "Lệnh đã thực thi thành công (không có output).",
            "ExitCode": proc.returncode,
        }
    except subprocess.TimeoutExpired:
        return {
            "Success": False,
            "Output": "Lỗi: Quá thời gian chờ (Timeout 300s).",
            "ExitCode": -1,
        }
    except OSError as e:
        return {
            "Success": False,
            "Output": f"Lỗi thực thi: {str(e)}",
            "ExitCode": -1,
        }


class DashboardHandler(BaseHTTPRequestHandler):
    def _request_is_trusted(self):
        return is_trusted_request(
            self.headers.get("Host"),
            self.headers.get("Origin"),
            self.server.server_address[1],
        )

    def _reject_untrusted_request(self):
        self.send_response(403)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(
            json.dumps({"Success": False, "Output": "Yêu cầu bị từ chối."}).encode(
                "utf-8"
            )
        )

    def _set_cors_headers(self, content_type="application/json"):
        origin = self.headers.get("Origin")
        if origin:
            self.send_header("Access-Control-Allow-Origin", origin)
            self.send_header("Vary", "Origin")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Content-Type", f"{content_type}; charset=utf-8")
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header("X-Frame-Options", "DENY")
        self.send_header(
            "Content-Security-Policy",
            "default-src 'self'; "
            "script-src 'self' 'unsafe-inline' https://cdn.tailwindcss.com; "
            "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; "
            "font-src https://fonts.gstatic.com; connect-src 'self'; "
            "img-src 'self' data:; object-src 'none'; base-uri 'none'; "
            "frame-ancestors 'none'; form-action 'none'",
        )

    def do_OPTIONS(self):
        if not self._request_is_trusted():
            self._reject_untrusted_request()
            return
        self.send_response(204)
        self._set_cors_headers()
        self.end_headers()

    def do_GET(self):
        if not self._request_is_trusted():
            self._reject_untrusted_request()
            return
        parsed = urlparse(self.path)
        path = parsed.path

        if path == "/api/status":
            self.send_response(200)
            self._set_cors_headers("application/json")
            self.end_headers()
            data = get_telemetry()
            self.wfile.write(json.dumps(data, ensure_ascii=False).encode("utf-8"))

        elif path == "/api/ping":
            self.send_response(200)
            self._set_cors_headers("application/json")
            self.end_headers()
            self.wfile.write(
                json.dumps({"status": "ok", "server": "E5 Dashboard Server"}).encode(
                    "utf-8"
                )
            )

        elif path in ["/", "/index.html", "/Dashboard.html"]:
            # Regenerate or read HTML
            if HTML_FILE.exists():
                with open(HTML_FILE, "r", encoding="utf-8", errors="ignore") as f:
                    content = f.read()
                self.send_response(200)
                self._set_cors_headers("text/html")
                self.end_headers()
                self.wfile.write(content.encode("utf-8"))
            else:
                self.send_response(404)
                self.end_headers()
                self.wfile.write(b"Dashboard.html not found.")
        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b"Not Found")

    def do_POST(self):
        if not self._request_is_trusted():
            self._reject_untrusted_request()
            return
        parsed = urlparse(self.path)
        path = parsed.path

        if path == "/api/run":
            if self.headers.get_content_type() != "application/json":
                self.send_response(415)
                self._set_cors_headers("application/json")
                self.end_headers()
                self.wfile.write(
                    json.dumps(
                        {"Success": False, "Output": "Yêu cầu phải là JSON."}
                    ).encode("utf-8")
                )
                return

            try:
                content_len = int(self.headers.get("Content-Length", 0))
            except ValueError:
                content_len = -1
            if content_len < 1 or content_len > MAX_REQUEST_BODY_BYTES:
                self.send_response(413)
                self._set_cors_headers("application/json")
                self.end_headers()
                self.wfile.write(
                    json.dumps(
                        {"Success": False, "Output": "Kích thước yêu cầu không hợp lệ."}
                    ).encode("utf-8")
                )
                return

            body = self.rfile.read(content_len).decode("utf-8", errors="ignore")
            try:
                req_json = json.loads(body)
                action_value = (
                    req_json.get("action", "") if isinstance(req_json, dict) else ""
                )
                action_name = action_value if isinstance(action_value, str) else ""
            except json.JSONDecodeError:
                action_name = ""

            if not action_name:
                self.send_response(400)
                self._set_cors_headers("application/json")
                self.end_headers()
                self.wfile.write(
                    json.dumps(
                        {"Success": False, "Output": "Thiếu action parameter."}
                    ).encode("utf-8")
                )
                return

            # Execute action
            res = execute_action_command(action_name)

            self.send_response(200)
            self._set_cors_headers("application/json")
            self.end_headers()
            self.wfile.write(json.dumps(res, ensure_ascii=False).encode("utf-8"))
        else:
            self.send_response(404)
            self.end_headers()


def ensure_dashboard_html():
    """Build the local HTML after checkout, where generated files are ignored."""
    if HTML_FILE.exists():
        return

    subprocess.run(
        [
            "powershell.exe",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(ROOT_DIR / "dashboard" / "E5-Dashboard.ps1"),
            "-NoServe",
            "-NoBrowser",
        ],
        cwd=ROOT_DIR,
        check=True,
        timeout=60,
    )
    if not HTML_FILE.is_file():
        raise FileNotFoundError(f"Dashboard generation did not create {HTML_FILE}")


def start_server(port=PORT, open_browser=True):
    ensure_dashboard_html()
    server_address = ("127.0.0.1", port)
    try:
        httpd = ThreadingHTTPServer(server_address, DashboardHandler)
        LOGGER.info(
            f"E5 Dashboard Server started successfully at http://127.0.0.1:{port}"
        )
    except OSError as e:
        LOGGER.error("Failed to bind port %s: %s", port, e)
        return

    if open_browser:
        import webbrowser

        webbrowser.open(f"http://localhost:{port}")

    print("=" * 65)
    print("  [+] MICROSOFT 365 E5 RENEW DASHBOARD SERVER RUNNING")
    print(f"  URL : http://127.0.0.1:{port}")
    print("  Press Ctrl+C to stop server")
    print("=" * 65)

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        LOGGER.info("Stopping Dashboard Server...")
        httpd.server_close()


if __name__ == "__main__":
    start_server(port=PORT, open_browser=True)
