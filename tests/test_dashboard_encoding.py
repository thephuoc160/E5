"""Guard the Windows PowerShell -> HTML/HTTP UTF-8 boundaries."""

import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from dashboard import server


class DashboardEncodingTests(unittest.TestCase):
    def test_task_query_failure_is_not_reported_as_empty_schedule(self):
        import subprocess

        failed_query = subprocess.CompletedProcess([], 1, stdout="", stderr="denied")
        with patch.object(server.subprocess, "run", return_value=failed_query):
            telemetry = server.get_telemetry()
        self.assertEqual([], telemetry["Tasks"])
        self.assertIn("Không đọc được lịch chạy", telemetry["TasksError"])

    def test_startup_replaces_stale_generated_html_with_utf8_source(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "template.html"
            output = root / "Dashboard.html"
            source.write_text("<h1>Bảng điều khiển · Đồng bộ</h1>", encoding="utf-8")
            output.write_text("old corrupted content", encoding="ascii")
            with (
                patch.object(server, "TEMPLATE_FILE", source),
                patch.object(server, "HTML_FILE", output),
            ):
                server.ensure_dashboard_html()
            self.assertEqual(source.read_bytes(), output.read_bytes())

    @unittest.skipUnless(os.name == "nt", "Requires Windows PowerShell 5.1")
    def test_redirected_powershell_output_preserves_vietnamese(self):
        with tempfile.TemporaryDirectory() as directory:
            script = Path(directory) / "Vietnamese output.ps1"
            script.write_text("Write-Output 'Đồng bộ thành công'", encoding="utf-8-sig")
            argv = [
                "powershell.exe",
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                str(script),
            ]
            with patch.object(server, "get_action_command", return_value=argv):
                result = server.execute_action_command("encoding_test")
            self.assertTrue(result["Success"], result["Output"])
            self.assertEqual("Đồng bộ thành công", result["Output"])


if __name__ == "__main__":
    unittest.main()
