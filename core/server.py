"""server.py - High-Performance Multi-Threaded Local Server for E5 Renew Dashboard.

Serves the modern Dashboard and executes PowerShell / Python automation scripts
directly from Web API endpoints with real-time output capturing.
"""

import json
import logging
import os
from pathlib import Path
import subprocess
import threading
from urllib.parse import urlparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import sys
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

PORT = 8765
ROOT_DIR = Path(__file__).resolve().parent.parent
LOG_DIR = ROOT_DIR / "logs"
CONFIG_FILE = ROOT_DIR / "config" / "config.json"
HTML_FILE = ROOT_DIR / "Dashboard.html"

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


def get_telemetry():
  """Collects live system and E5 metrics."""
  cfg = {}
  if CONFIG_FILE.exists():
    try:
      with open(CONFIG_FILE, "r", encoding="utf-8") as f:
        cfg = json.load(f)
    except Exception as e:
      logging.warning(f"Error reading config.json: {e}")

  # Check drive M:
  is_mounted = os.path.exists("M:\\")
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
  except Exception as e:
    logging.warning(f"Error querying task scheduler: {e}")

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
    except Exception:
      pass

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
          lines = f.readlines()[-15:]
          for l in lines:
            if l.strip():
              recent_logs.append({"file": log_name, "text": l.strip()})
      except Exception:
        pass

  import datetime

  return {
      "GeneratedAt": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
      "TenantId": cfg.get("azure", {}).get(
          "tenantId", "YOUR_TENANT_ID"
      ),
      "UserUPN": cfg.get("azure", {}).get(
          "userPrincipalName", "admin@yourdomain.onmicrosoft.com"
      ),
      "IsMounted": is_mounted,
      "DriveLetter": "M:",
      "MountRemote": mount_remote,
      "Tasks": tasks_info,
      "SuccessCount": success_count,
      "WarnCount": warn_count,
      "ErrorCount": error_count,
      "RecentLogs": recent_logs[-30:],
  }


def execute_action_command(action_name: str) -> dict:
  """Executes the mapped PowerShell or Python command."""
  cmd_map = {
      "run_all": f'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "{ROOT_DIR}\\Run-All.ps1"',
      "mount": f'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "{ROOT_DIR}\\core\\E5-RcloneMount.ps1" -Action Mount',
      "unmount": f'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "{ROOT_DIR}\\core\\E5-RcloneMount.ps1" -Action Unmount',
      "check_mount": f'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "{ROOT_DIR}\\core\\E5-RcloneMount.ps1" -Action Check',
      "graph_activity": f'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "{ROOT_DIR}\\core\\E5-GraphActivity.ps1" -BasePath "M:\\API_Output" -EnableGraphActivities',
      "sharepoint_sync": f'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "{ROOT_DIR}\\core\\E5-SharePointSync.ps1"',
      "python_app": f'python "{ROOT_DIR}\\python\\PingE5_App.py"',
      "onedrive_sync": f'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "{ROOT_DIR}\\core\\E5-OneDriveSync.ps1"',
      "setup_tasks": f'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "{ROOT_DIR}\\tasks\\Setup-ScheduledTasks.ps1" -IntervalHours 48',
      "check_tasks": f'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "{ROOT_DIR}\\tasks\\Check-TaskStatus.ps1"',
      "quick_renew": f'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "{ROOT_DIR}\\core\\E5-RenewHelper.ps1" -Action QuickRenew',
      "create_draft": f'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "{ROOT_DIR}\\core\\E5-RenewHelper.ps1" -Action CreateDraft',
      "reconnect_1drive": f'start cmd.exe /c "{ROOT_DIR}\\Reconnect-1Drive.bat"',
  }

  cmd = cmd_map.get(action_name)
  if not cmd:
    return {
        "Success": False,
        "Output": f"Hành động không hợp lệ: {action_name}",
        "ExitCode": 1,
    }

  logging.info(f"Executing action [{action_name}]: {cmd}")
  try:
    proc = subprocess.run(
        cmd,
        shell=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=300,
        check=False,
    )
    output = (proc.stdout + "\n" + proc.stderr).strip()
    return {
        "Success": proc.returncode == 0 or proc.returncode < 8,
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
  except Exception as e:
    return {
        "Success": False,
        "Output": f"Lỗi thực thi: {str(e)}",
        "ExitCode": -1,
    }


class DashboardHandler(BaseHTTPRequestHandler):

  def _set_cors_headers(self, content_type="application/json"):
    self.send_header("Access-Control-Allow-Origin", "*")
    self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
    self.send_header(
        "Access-Control-Allow-Headers", "Content-Type, Authorization"
    )
    self.send_header("Content-Type", f"{content_type}; charset=utf-8")
    self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")

  def do_OPTIONS(self):
    self.send_response(204)
    self._set_cors_headers()
    self.end_headers()

  def do_GET(self):
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
    parsed = urlparse(self.path)
    path = parsed.path

    if path == "/api/run":
      content_len = int(self.headers.get("Content-Length", 0))
      body = self.rfile.read(content_len).decode("utf-8", errors="ignore")
      try:
        req_json = json.loads(body)
        action_name = req_json.get("action", "")
      except Exception:
        action_name = ""

      if not action_name:
        self.send_response(400)
        self._set_cors_headers("application/json")
        self.end_headers()
        self.wfile.write(
            json.dumps({"Success": False, "Output": "Thiếu action parameter."})
            .encode("utf-8")
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


def start_server(port=PORT, open_browser=True):
  server_address = ("127.0.0.1", port)
  try:
    httpd = ThreadingHTTPServer(server_address, DashboardHandler)
    logging.info(
        f"E5 Dashboard Server started successfully at http://127.0.0.1:{port}"
    )
  except OSError as e:
    logging.error(f"Failed to bind port {port}: {e}")
    return

  if open_browser:
    import webbrowser

    webbrowser.open(f"http://localhost:{port}")

  print("=" * 65)
  print(f"  [+] MICROSOFT 365 E5 RENEW DASHBOARD SERVER RUNNING")
  print(f"  URL : http://127.0.0.1:{port}")
  print(f"  Press Ctrl+C to stop server")
  print("=" * 65)

  try:
    httpd.serve_forever()
  except KeyboardInterrupt:
    logging.info("Stopping Dashboard Server...")
    httpd.server_close()


if __name__ == "__main__":
  start_server(port=PORT, open_browser=True)
