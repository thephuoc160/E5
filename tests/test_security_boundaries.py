"""Regression tests for local command and OAuth security boundaries."""

import importlib.util
import json
import subprocess
import threading
import unittest
from datetime import datetime, timezone
from http.client import HTTPConnection
from pathlib import Path
from unittest.mock import patch
from urllib.parse import parse_qs, urlparse

from dashboard import server as dashboard_server
from python import PingE5_App as ping_app
from python import PingE5_User as ping_user

ROOT_DIR = Path(__file__).resolve().parent.parent


def load_module(module_name, path):
    spec = importlib.util.spec_from_file_location(module_name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


cloud_runner = load_module(
    "e5_cloud_runner", ROOT_DIR / ".github" / "scripts" / "e5_cloud_runner.py"
)


class DashboardRequestSecurityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = dashboard_server.ThreadingHTTPServer(
            ("127.0.0.1", 0), dashboard_server.DashboardHandler
        )
        cls.port = cls.server.server_address[1]
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join(timeout=5)

    def post_action(self, origin):
        body = json.dumps({"action": "check_mount"})
        headers = {
            "Content-Type": "application/json",
            "Content-Length": str(len(body.encode("utf-8"))),
        }
        if origin is not None:
            headers["Origin"] = origin

        connection = HTTPConnection("127.0.0.1", self.port, timeout=5)
        try:
            connection.request("POST", "/api/run", body=body, headers=headers)
            response = connection.getresponse()
            return response.status, json.loads(response.read().decode("utf-8"))
        finally:
            connection.close()

    def test_rejects_cross_origin_command_request(self):
        with patch.object(dashboard_server, "execute_action_command") as execute:
            status, body = self.post_action("https://attacker.example")

        self.assertEqual(403, status)
        self.assertFalse(body["Success"])
        execute.assert_not_called()

    def test_accepts_same_origin_command_request(self):
        result = {"Success": True, "Output": "ok", "ExitCode": 0}
        origin = f"http://127.0.0.1:{self.port}"
        with patch.object(
            dashboard_server, "execute_action_command", return_value=result
        ) as execute:
            status, body = self.post_action(origin)

        self.assertEqual(200, status)
        self.assertEqual(result, body)
        execute.assert_called_once_with("check_mount")

    def test_rejects_untrusted_host_and_origin(self):
        self.assertFalse(
            dashboard_server.is_trusted_request(
                "attacker.example", "http://attacker.example", 8765
            )
        )
        self.assertFalse(
            dashboard_server.is_trusted_request("127.0.0.1:8765", "null", 8765)
        )
        self.assertFalse(
            dashboard_server.is_trusted_request(
                "127.0.0.1:8765", "http://127.0.0.1:not-a-port", 8765
            )
        )

    def test_action_uses_argv_without_shell(self):
        completed = subprocess.CompletedProcess([], 0, stdout="ok", stderr="")
        with patch.object(
            dashboard_server.subprocess, "run", return_value=completed
        ) as run:
            result = dashboard_server.execute_action_command("python_app")

        argv = run.call_args.args[0]
        self.assertIsInstance(argv, list)
        self.assertEqual(dashboard_server.sys.executable, argv[0])
        self.assertNotIn("shell", run.call_args.kwargs)
        self.assertTrue(result["Success"])


class PythonCommandSecurityTests(unittest.TestCase):
    def test_rclone_arguments_are_not_evaluated_by_a_shell(self):
        completed = subprocess.CompletedProcess([], 0, stdout="", stderr="")
        untrusted_path = r"C:\folder & whoami"
        with (
            patch.object(ping_app.shutil, "which", return_value="rclone.exe"),
            patch.object(ping_app.subprocess, "run", return_value=completed) as run,
        ):
            return_code = ping_app.run_rclone(["copy", untrusted_path, "remote:path"])

        self.assertEqual(0, return_code)
        self.assertEqual(
            ["rclone.exe", "copy", untrusted_path, "remote:path"],
            run.call_args.args[0],
        )
        self.assertNotIn("shell", run.call_args.kwargs)

    def test_calendar_event_is_created_in_the_future(self):
        now = datetime(2026, 11, 3, 8, 0, tzinfo=timezone.utc)
        event_start, event_end = ping_user.get_calendar_window(now)

        self.assertEqual("2026-11-04T08:00:00", event_start)
        self.assertEqual("2026-11-04T09:00:00", event_end)

    def test_remote_cleanup_is_disabled_in_example_configuration(self):
        config = json.loads(
            (ROOT_DIR / "config" / "config.example.json").read_text(encoding="utf-8")
        )
        self.assertIs(config["settings"]["allowRemoteCleanup"], False)

    def test_robocopy_script_does_not_evaluate_a_command_string(self):
        script = (ROOT_DIR / "core" / "E5-OneDriveSync.ps1").read_text(encoding="utf-8")
        self.assertNotIn("Invoke-Expression", script)
        self.assertIn("& robocopy.exe @roboArgs", script)

    def test_mount_script_only_stops_the_managed_rclone_mount(self):
        script = (ROOT_DIR / "core" / "E5-RcloneMount.ps1").read_text(encoding="utf-8")
        self.assertIn("Get-ManagedRcloneMountProcess", script)
        self.assertNotIn('Get-Process -Name "rclone"', script)
        self.assertNotIn("rc core/quit", script)

    def test_create_draft_declares_and_forwards_its_parameters(self):
        helper = (ROOT_DIR / "core" / "E5-RenewHelper.ps1").read_text(encoding="utf-8")
        wrapper = (ROOT_DIR / "create_draft.ps1").read_text(encoding="utf-8")
        self.assertIn('[string]$Subject = "E5 Renew', helper)
        self.assertIn("[string[]]$Recipients", helper)
        self.assertIn("-OpenDraftInBrowser:$OpenDraftInBrowser", wrapper)

    def test_powershell_dashboard_rejects_wildcard_cors(self):
        script = (ROOT_DIR / "dashboard" / "E5-Dashboard.ps1").read_text(
            encoding="utf-8"
        )
        self.assertNotIn('AddHeader("Access-Control-Allow-Origin", "*")', script)
        self.assertIn("$trustedOrigin", script)
        self.assertIn("WaitForExit(300000)", script)

    def test_graph_activity_only_mutates_managed_files(self):
        script = (ROOT_DIR / "core" / "E5-GraphActivity.ps1").read_text(
            encoding="utf-8"
        )
        self.assertIn("function Get-ManagedActivityFile", script)
        self.assertIn("$allFiles = Get-ManagedActivityFile", script)
        self.assertIn("$folders = Get-ManagedActivityFolder", script)

    def test_graph_activity_does_not_request_unused_high_privilege_scopes(self):
        script = (ROOT_DIR / "core" / "E5-GraphActivity.ps1").read_text(
            encoding="utf-8"
        )
        self.assertNotIn('"Application.ReadWrite.All"', script)
        self.assertNotIn('"MailboxSettings.ReadWrite"', script)
        self.assertNotIn('"User.Read.All"', script)
        self.assertIn("$accountMatches", script)


class CloudRunnerSecurityTests(unittest.TestCase):
    def test_graph_client_rejects_non_relative_endpoint(self):
        client = cloud_runner.GraphCloudClient("tenant", "client", "secret", "user")
        client.access_token = "token"

        with self.assertRaises(ValueError):
            client.request("GET", "file:///etc/passwd")

    def test_missing_access_token_is_an_authentication_failure(self):
        client = cloud_runner.GraphCloudClient("tenant", "client", "secret", "user")

        class EmptyTokenResponse:
            def __enter__(self):
                return self

            def __exit__(self, exc_type, exc_value, traceback):
                return False

            @staticmethod
            def read():
                return b"{}"

        with patch.object(
            cloud_runner.urllib.request,
            "urlopen",
            return_value=EmptyTokenResponse(),
        ):
            authenticated = client.get_token()

        self.assertFalse(authenticated)
        self.assertFalse(client.metrics["token_acquired"])


class OAuthSecurityTests(unittest.TestCase):
    def setUp(self):
        ping_user.app.config.update(TESTING=True)
        self.client = ping_user.app.test_client()

    def test_login_redirect_contains_state(self):
        response = self.client.get("/")
        query = parse_qs(urlparse(response.headers["Location"]).query)

        self.assertEqual(302, response.status_code)
        self.assertTrue(query.get("state", [""])[0])

    def test_callback_rejects_invalid_state_without_network_call(self):
        with patch.object(ping_user.requests, "post") as post:
            response = self.client.get("/callback?code=fake&state=wrong")

        self.assertEqual(400, response.status_code)
        post.assert_not_called()

    def test_token_error_response_does_not_leak_provider_body(self):
        login_response = self.client.get("/")
        query = parse_qs(urlparse(login_response.headers["Location"]).query)
        state = query["state"][0]

        class FailedTokenResponse:
            status_code = 400
            text = "SENSITIVE_PROVIDER_RESPONSE"

            @staticmethod
            def json():
                return {"error": "invalid_grant"}

        with patch.object(
            ping_user.requests, "post", return_value=FailedTokenResponse()
        ):
            response = self.client.get(f"/callback?code=fake&state={state}")

        self.assertEqual(400, response.status_code)
        self.assertNotIn(b"SENSITIVE_PROVIDER_RESPONSE", response.data)


if __name__ == "__main__":
    unittest.main()
