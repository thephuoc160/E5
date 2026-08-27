"""PingE5_App.py - Microsoft Graph E5 Activity Ping (Client Credentials Flow).

Runs automated background Graph calls (User, Drive, Mail, Teams, Calendars)
using application permissions (client credentials flow).
"""

import json
import logging
import os
from pathlib import Path
import random
import shutil
import subprocess
import requests

# Set up logging
ROOT_DIR = Path(__file__).resolve().parent.parent
LOG_DIR = ROOT_DIR / "logs"
LOG_DIR.mkdir(parents=True, exist_ok=True)
LOG_FILE = LOG_DIR / "python_app.log"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(LOG_FILE, encoding="utf-8"),
        logging.StreamHandler(),
    ],
)

# Load configuration from config/config.json
CONFIG_FILE = ROOT_DIR / "config" / "config.json"
client_id = os.getenv("AZ_CLIENT_ID", "")
client_secret = os.getenv("AZ_CLIENT_SECRET", "")
tenant_id = os.getenv("AZ_TENANT_ID", "")
user_email = os.getenv("ADMIN_UPN", "admin@yourdomain.onmicrosoft.com")
recipients = ["user1@yourdomain.onmicrosoft.com", "user2@yourdomain.onmicrosoft.com"]

if CONFIG_FILE.exists():
  try:
    with open(CONFIG_FILE, "r", encoding="utf-8") as f:
      cfg = json.load(f)
      client_id = cfg.get("azure", {}).get("clientId", client_id)
      client_secret = cfg.get("azure", {}).get("clientSecret", client_secret)
      tenant_id = cfg.get("azure", {}).get("tenantId", tenant_id)
      user_email = cfg.get("azure", {}).get("userPrincipalName", user_email)
      recipients = cfg.get("graph", {}).get("teamMailRecipients", recipients)
  except Exception as e:
    logging.warning(f"Could not load config.json: {e}")

RCLONE_ONEDRIVE_REMOTE = "1Drive:Documents/API/App1"
RCLONE_SHAREPOINT_REMOTE = "sharepoint:Documents/API/App1"
LOCAL_IMAGES_FOLDER = Path.home() / "Pictures" / "Screenshots"


def get_access_token() -> str:
  token_url = f"https://login.microsoftonline.com/{tenant_id}/oauth2/v2.0/token"
  data = {
      "client_id": client_id,
      "scope": "https://graph.microsoft.com/.default",
      "client_secret": client_secret,
      "grant_type": "client_credentials",
  }
  logging.info("Requesting access_token via client_credentials...")
  resp = requests.post(token_url, data=data, timeout=30)
  token = resp.json().get("access_token")
  if not token:
    logging.error(f"Failed to obtain token: {resp.text}")
    raise SystemExit(1)
  logging.info("Access token acquired successfully.")
  return token


def safe_get(url: str, label: str, headers: dict):
  try:
    res = requests.get(url, headers=headers, timeout=20)
    logging.info(f"{label} -> Status: {res.status_code}")
    return res
  except Exception as exc:
    logging.warning(f"{label} -> Error: {exc}")
    return None


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
  if result.stdout:
    logging.info(f"rclone stdout: {result.stdout.strip()}")
  if result.stderr:
    logging.info(f"rclone stderr: {result.stderr.strip()}")
  return result.returncode


def main():
  logging.info("=== STARTING PING E5 APP SESSION ===")
  token = get_access_token()
  headers = {
      "Authorization": f"Bearer {token}",
      "Content-Type": "application/json",
  }

  # 1. Send verification email
  mail_payload = {
      "message": {
          "subject": "Mail ping tu dong E5 Renew",
          "body": {
              "contentType": "Text",
              "content": (
                  "Xin chao team,\n\nDay la email kiem tra he thong tu dong"
                  " Microsoft 365 E5.\n\nCam on moi nguoi."
              ),
          },
          "toRecipients": [
              {"emailAddress": {"address": email}} for email in recipients
          ],
      }
  }
  logging.info("Sending verification mail...")
  try:
    send_mail_res = requests.post(
        f"https://graph.microsoft.com/v1.0/users/{user_email}/sendMail",
        headers=headers,
        json=mail_payload,
        timeout=30,
    )
    logging.info(f"Send mail status: {send_mail_res.status_code}")
  except Exception as e:
    logging.warning(f"Send mail error: {e}")

  # 2. Ping Microsoft Graph Endpoints
  safe_get(
      f"https://graph.microsoft.com/v1.0/users/{user_email}",
      "User info",
      headers,
  )
  safe_get(
      f"https://graph.microsoft.com/v1.0/users/{user_email}/drive",
      "OneDrive root",
      headers,
  )
  safe_get(
      f"https://graph.microsoft.com/v1.0/users/{user_email}/mailFolders",
      "Mail folders",
      headers,
  )
  safe_get(
      f"https://graph.microsoft.com/v1.0/users/{user_email}/joinedTeams",
      "Teams list",
      headers,
  )
  safe_get(
      f"https://graph.microsoft.com/v1.0/users/{user_email}/calendars",
      "Calendar list",
      headers,
  )

  # 3. Clean OneDrive folder and create random files
  logging.info("Cleaning OneDrive folder via rclone (if configured)...")
  run_rclone(f'delete "{RCLONE_ONEDRIVE_REMOTE}"')

  logging.info("Creating random dummy files in OneDrive...")
  for idx in range(random.randint(3, 5)):
    filename = f"note_{random.randint(1000, 9999)}.txt"
    content = f"File gia thu {idx + 1} duoc upload tu script Python vao {os.getenv('COMPUTERNAME', 'Local')}."
    upload_url = (
        f"https://graph.microsoft.com/v1.0/users/{user_email}/drive/root:/"
        f"Documents/API/App1/{filename}:/content"
    )
    try:
      res = requests.put(
          upload_url, headers=headers, data=content.encode("utf-8"), timeout=30
      )
      logging.info(f"Upload {filename} -> Status: {res.status_code}")
    except Exception as e:
      logging.warning(f"Upload {filename} failed: {e}")

  # 4. Upload local images folder via rclone if available
  if LOCAL_IMAGES_FOLDER.is_dir():
    logging.info(f"Syncing local folder {LOCAL_IMAGES_FOLDER} to SharePoint...")
    run_rclone(
        f'copy "{LOCAL_IMAGES_FOLDER}" "{RCLONE_SHAREPOINT_REMOTE}"'
        " --transfers=4 --checkers=8 --fast-list"
    )

  logging.info("=== PING E5 APP SESSION COMPLETED ===")


if __name__ == "__main__":
  main()
