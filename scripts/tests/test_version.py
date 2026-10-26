import subprocess
import sys
import tempfile
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from version import next_version, parse_version, release_changelog


class VersionTests(unittest.TestCase):
    def test_bumps_reset_lower_components(self):
        for increment, expected in [("major", "2.0.0"), ("minor", "1.10.0"), ("patch", "1.9.10")]:
            with self.subTest(increment=increment):
                self.assertEqual(next_version("1.9.9", increment), expected)
        self.assertEqual(next_version("0.0.0", "patch"), "0.0.1")

    def test_rejects_malformed_or_nonrelease_versions(self):
        for value in ["01.2.3", "1.02.3", "1.2.03", "1.2", "v1.2.3", "-1.2.3", "1.2.3-beta", "1.2.3+4", "1.2.3\n"]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                parse_version(value)

    def test_releases_only_unreleased_notes(self):
        text = "# Changelog\n\n## [Unreleased]\n\n### Fixed\n\n- Current fix.\n\n## [0.1.0] - 2026-09-11\n\n- Earlier work.\n"
        updated = release_changelog(text, "0.1.1", "2026-10-27")
        self.assertIn("## [Unreleased]\n\n## [0.1.1] - 2026-10-27\n\n### Fixed\n\n- Current fix.", updated)
        self.assertTrue(updated.endswith("## [0.1.0] - 2026-09-11\n\n- Earlier work.\n"))
        with self.assertRaises(ValueError):
            release_changelog(updated, "0.1.1", "2026-10-27")

    def test_cli_dry_run_and_bump(self):
        script = Path(__file__).resolve().parents[1] / "version.py"
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "scripts").mkdir()
            tool = root / "scripts/version.py"
            tool.write_text(script.read_text())
            version = root / "VERSION"
            version.write_text("0.1.0\n")
            changelog = root / "CHANGELOG.md"
            notes = "# Changelog\n\n## [Unreleased]\n\n- Release tooling.\n"
            changelog.write_text(notes)
            subprocess.run([sys.executable, str(tool), "patch", "--dry-run"], check=True, capture_output=True)
            self.assertEqual(version.read_text(), "0.1.0\n")
            self.assertEqual(changelog.read_text(), notes)
            subprocess.run([sys.executable, str(tool), "minor"], check=True, capture_output=True)
            self.assertEqual(version.read_text(), "0.2.0\n")
            result = subprocess.run([sys.executable, str(tool), "patch"], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Add release notes", result.stderr)
            self.assertEqual(version.read_text(), "0.2.0\n")


if __name__ == "__main__":
    unittest.main()
