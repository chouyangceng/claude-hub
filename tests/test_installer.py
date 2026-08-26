import unittest
from pathlib import Path


ROOT = Path(__file__).parents[1]


class InstallerSafetyTests(unittest.TestCase):
    def test_update_is_non_destructive_and_checks_copy_failures(self):
        script = (ROOT / "install.bat").read_text(encoding="utf-8-sig").lower()
        self.assertNotIn("rmdir ", script)
        self.assertNotIn("taskkill ", script)
        self.assertNotIn("iconcache", script)
        self.assertIn('if /i "%overwrite%"=="y" goto install', script)
        self.assertEqual(script.count("copy /y"), 3)
        for line in script.splitlines():
            if line.strip().startswith("copy /y"):
                self.assertIn("|| goto install_error", line)

    def test_launcher_resolves_the_powershell_script_relative_to_itself(self):
        launcher = (ROOT / "claude-hub.bat").read_text(encoding="utf-8-sig").lower()
        self.assertIn('set "hub_dir=%~dp0"', launcher)
        self.assertIn('"%hub_dir%claude-hub.ps1"', launcher)


if __name__ == "__main__":
    unittest.main()
