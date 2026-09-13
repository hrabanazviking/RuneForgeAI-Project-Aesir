#!/usr/bin/env python3
"""Bridge and desktop export contracts; no installed desktop or inference claim."""
import base64
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

from export_desktop_entry import desktop_entry
from launch_windows_bridge import decode_args

SCRIPTS = Path(__file__).resolve().parent


def encoded(value):
    return base64.b64encode(json.dumps(value).encode()).decode()


class PlatformLaunchTests(unittest.TestCase):
    def test_bridge_rejects_malformed_payload_before_launch(self):
        for payload in ["!", "YQ==", encoded(None), encoded({}), encoded([1]),
                        encoded(["a\0b"]), "a" * 24001,
                        base64.b64encode(b"\xff").decode()]:
            with self.assertRaises(ValueError):
                decode_args(payload)
        self.assertEqual(decode_args(encoded(["", "雪", "'\"\\; $() %f"])), ["", "雪", "'\"\\; $() %f"])

    def test_real_bridge_literal_argv_and_status(self):
        with tempfile.TemporaryDirectory(prefix="aesir bridge ' space ") as temp:
            root = Path(temp)
            bridge = root / "launch_windows_bridge.py"
            shutil.copyfile(SCRIPTS / bridge.name, bridge)
            (root / "launch.py").write_text("import json,sys\nprint(json.dumps(sys.argv[1:]))\nsys.exit(23)\n")
            args = ["--", "home", "", "store path", "'\"\\; $() %f", "雪"]
            result = subprocess.run([sys.executable, str(bridge), encoded(args)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 23, result.stderr)
            self.assertEqual(json.loads(result.stdout), args)
            result = subprocess.run([sys.executable, str(bridge), encoded([None])], capture_output=True, text=True)
            self.assertEqual(result.returncode, 1)
            self.assertEqual(result.stdout, "")

    def test_export_preview_no_overwrite_and_symlink_refusal(self):
        with tempfile.TemporaryDirectory(prefix="aesir desktop ") as temp:
            output = Path(temp) / "Aesir.desktop"
            command = [sys.executable, str(SCRIPTS / "export_desktop_entry.py")]
            preview = subprocess.run(command, capture_output=True, text=True)
            self.assertEqual(preview.returncode, 0)
            self.assertIn("Terminal=true\n", preview.stdout)
            self.assertEqual(list(Path(temp).iterdir()), [])
            result = subprocess.run([*command, "--output", str(output)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(output.read_text(), preview.stdout)
            original = output.read_bytes()
            result = subprocess.run([*command, "--output", str(output)], capture_output=True)
            self.assertEqual(result.returncode, 1)
            self.assertEqual(output.read_bytes(), original)
            link = Path(temp) / "link.desktop"
            link.symlink_to(output)
            result = subprocess.run([*command, "--output", str(link)], capture_output=True)
            self.assertEqual(result.returncode, 1)
            self.assertEqual(output.read_bytes(), original)

    def test_gio_parser_and_literal_desktop_path(self):
        try:
            from gi.repository import Gio, GLib
        except ImportError:
            self.skipTest("Gio is required for the independent desktop parser witness")
        with tempfile.TemporaryDirectory(prefix="aesir desktop ' ") as temp:
            root = Path(temp) / '雪 %f %U $(bad) `bad` "quote" \\path'
            root.mkdir()
            launcher = root / "launch.py"
            launcher.write_text("import json,sys\nprint(json.dumps([__file__,sys.argv[1:]]))\n")
            entry = root / "Aesir.desktop"
            entry.write_text(desktop_entry(launcher), encoding="utf-8")
            info = Gio.DesktopAppInfo.new_from_filename(str(entry))
            self.assertIsNotNone(info)
            self.assertTrue(info.get_boolean("Terminal"))
            valid, argv = GLib.shell_parse_argv(info.get_commandline())
            self.assertTrue(valid)
            result = subprocess.run(argv, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(result.stdout), [str(launcher), ["--", "home"]])


if __name__ == "__main__":
    unittest.main()
