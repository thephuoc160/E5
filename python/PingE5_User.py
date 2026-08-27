"""PingE5_User.py - Interactive Microsoft Graph E5 Activity (Delegated User Auth).

Flask web application facilitating user login via browser and triggering
comprehensive Graph operations (Mail, Drive, Calendar, Teams, SharePoint).
"""

import json
import logging
import os
from pathlib import Path
import random
import shutil
import string
import subprocess
from flask import Flask, redirect, request
import requests

ROOT_DIR = Path(__file__).resolve().parent.parent
LOG_DIR = ROOT_DIR / "logs"
LOG_DIR.mkdir(parents=True, exist_ok=True)
LOG_FILE = LOG_DIR / "python_user.log"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(LOG_FILE, encoding="utf-8"),
        logging.StreamHandler(),
    ],
)

CONFIG_FILE = ROOT_DIR / "config" / "config.json"
client_id = os.getenv("AZ_CLIENT_ID", "")
client_secret = os.getenv("AZ_CLIENT_SECRET", "")
tenant_id = os.getenv("AZ_TENANT_ID", "")
redirect_uri = "http://localhost:8000/callback"
team_id = ""
channel_id = ""
recipients = ["user1@yourdomain.onmicrosoft.com", "user2@yourdomain.onmicrosoft.com"]

if CONFIG_FILE.exists():
  try:
    with open(CONFIG_FILE, "r", encoding="utf-8") as f:
      cfg = json.load(f)
      client_id = cfg.get("azure", {}).get("clientId", client_id)
      client_secret = cfg.get("azure", {}).get("clientSecret", client_secret)
      tenant_id = cfg.get("azure", {}).get("tenantId", tenant_id)
      redirect_uri = cfg.get("azure", {}).get("redirectUri", redirect_uri)
      team_id = cfg.get("graph", {}).get("teamsTeamId", team_id)
      channel_id = cfg.get("graph", {}).get("teamsChannelId", channel_id)
      recipients = cfg.get("graph", {}).get("teamMailRecipients", recipients)
  except Exception as e:
    logging.warning(f"Could not load config.json: {e}")

authorize_url = (
    f"https://login.microsoftonline.com/{tenant_id}/oauth2/v2.0/authorize"
)
token_url = f"https://login.microsoftonline.com/{tenant_id}/oauth2/v2.0/token"

scopes = [
    "https://graph.microsoft.com/Mail.Send",
    "https://graph.microsoft.com/User.Read",
    "https://graph.microsoft.com/Files.ReadWrite",
    "https://graph.microsoft.com/Calendars.ReadWrite",
    "https://graph.microsoft.com/Group.ReadWrite.All",
    "https://graph.microsoft.com/ChannelMessage.Send",
]

app = Flask(__name__)


def run_rclone(cmd_args: str) -> int:
  rclone_bin = shutil.which("rclone")
  if not rclone_bin:
    candidates = [
        ROOT_DIR / "tools" / "rclone.exe",
        ROOT_DIR / "rclone.exe",
        Path(r"C:\Scripts\tools\rclone.exe"),
    ]
    for c in candidates:
      if c.exists():
        rclone_bin = str(c)
        break

  if not rclone_bin:
    logging.warning("rclone executable not found. Skipping rclone operation.")
    return 1

  command = f'"{rclone_bin}" {cmd_args}'
  result = subprocess.run(
      command, shell=True, capture_output=True, text=True, check=False
  )
  return result.returncode


@app.route("/")
def home():
  return redirect(
      f"{authorize_url}?client_id={client_id}&response_type=code"
      f"&redirect_uri={redirect_uri}&response_mode=query&scope={' '.join(scopes)}"
  )


@app.route("/callback")
def callback():
  code = request.args.get("code")
  if not code:
    return "Khong nhan duoc authorization code!", 400

  token_data = {
      "client_id": client_id,
      "scope": " ".join(scopes),
      "code": code,
      "redirect_uri": redirect_uri,
      "grant_type": "authorization_code",
      "client_secret": client_secret,
  }
  token_res = requests.post(token_url, data=token_data, timeout=30)
  token_json = token_res.json()
  access_token = token_json.get("access_token")

  if not access_token:
    logging.error(f"Failed to obtain user access token: {token_res.text}")
    return "Khong lay duoc access_token: " + token_res.text, 400

  headers = {
      "Authorization": f"Bearer {access_token}",
      "Content-Type": "application/json",
  }

  # 1. Send Email
  mail_payload = {
      "message": {
          "subject": "Mail ping tu dong E5 User Auth",
          "body": {
              "contentType": "Text",
              "content": "Ping mail tu dong kiem tra tai khoan E5 hoat dong.",
          },
          "toRecipients": [
              {"emailAddress": {"address": email}} for email in recipients
          ],
      }
  }
  mail_resp = requests.post(
      "https://graph.microsoft.com/v1.0/me/sendMail",
      headers=headers,
      json=mail_payload,
      timeout=30,
  )

  # 2. Upload file PingAlive
  file_resp = requests.put(
      "https://graph.microsoft.com/v1.0/me/drive/root:/Documents/API/App1/PingAlive.txt:/content",
      headers=headers,
      data="File E5 Renew OneDrive song.".encode("utf-8"),
      timeout=30,
  )

  # 3. Create random files
  random_files_status = []
  for _ in range(random.randint(4, 8)):
    name = (
        "".join(random.choices(string.ascii_lowercase + string.digits, k=8))
        + ".txt"
    )
    content = "".join(
        random.choices(
            string.ascii_letters + string.digits + " ",
            k=random.randint(100, 200),
        )
    )
    res = requests.put(
        f"https://graph.microsoft.com/v1.0/me/drive/root:/Documents/API/App1/{name}:/content",
        headers=headers,
        data=content.encode("utf-8"),
        timeout=30,
    )
    random_files_status.append(f"{name}: {res.status_code}")

  # 4. Create Calendar event
  calendar_payload = {
      "subject": "E5 Dev Sync Calendar Event",
      "start": {"dateTime": "2026-09-01T08:00:00", "timeZone": "UTC"},
      "end": {"dateTime": "2026-09-01T09:00:00", "timeZone": "UTC"},
  }
  calendar_resp = requests.post(
      "https://graph.microsoft.com/v1.0/me/events",
      headers=headers,
      json=calendar_payload,
      timeout=30,
  )

  # 5. Send Teams message
  teams_status = "Skipped"
  if team_id and channel_id:
    msg_payload = {
        "body": {
            "content": (
                "Ping xac thuc tai khoan Microsoft Teams (E5 Renew Interactive)"
            )
        }
    }
    teams_url = f"https://graph.microsoft.com/v1.0/teams/{team_id}/channels/{channel_id}/messages"
    try:
      teams_res = requests.post(
          teams_url, headers=headers, json=msg_payload, timeout=30
      )
      teams_status = str(teams_res.status_code)
    except Exception as e:
      teams_status = f"Error: {e}"

  summary = {
      "Mail": mail_resp.status_code,
      "PingAlive.txt": file_resp.status_code,
      "Random files": "; ".join(random_files_status),
      "Calendar": calendar_resp.status_code,
      "Teams": teams_status,
  }

  logging.info(f"Interactive E5 summary: {summary}")

  html = "<h2>✅ Microsoft 365 E5 Activities Executed Successfully!</h2><ul>"
  for k, v in summary.items():
    html += f"<li><b>{k}:</b> {v}</li>"
  html += "</ul><p>Ban co the dong trinh duyet bay gio.</p>"
  return html


if __name__ == "__main__":
  print("=" * 60)
  print(" Mo trinh duyet tai http://localhost:8000 de dang nhap ")
  print("=" * 60)
  app.run(host="0.0.0.0", port=8000)
