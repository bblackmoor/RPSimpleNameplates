"""Check release consistency and real Git-index preparation in disposable repos."""

from pathlib import Path
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SOURCE / "scripts"))
import validate_release as release

TOC = "RPSimpleNameplates/RPSimpleNameplates.toc"
BASE_TOC = "## Title: RP Simple Nameplates\n## Version: 1.0.1\n"
BASE_NOTES = "## 1.0.1 — 2026-10-11\n\n- Initial release notes.\n"


class ReleaseMetadataTests(unittest.TestCase):
    def test_matching_tag_extracts_only_current_notes(self):
        old = "\n## 0.9.0 — 2026-10-10\n\n- Earlier notes.\n"
        self.assertEqual(release.release_metadata(BASE_TOC, BASE_NOTES + old, "refs/tags/v1.0.1"),
                         ("1.0.1", BASE_NOTES))

    def test_mismatched_tag_or_first_entry_is_rejected(self):
        for notes, ref in ((BASE_NOTES, "refs/tags/v1.0.2"),
                           ("## 0.9.0 — earlier\n" + BASE_NOTES, "")):
            with self.assertRaises(ValueError):
                release.release_metadata(BASE_TOC, notes, ref)


class StagedBuildTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="rp-nameplates-release-test-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        for directory in ("RPSimpleNameplates", "scripts", ".githooks"):
            (self.root / directory).mkdir()
        for name in ("scripts/validate_release.py", ".githooks/pre-commit"):
            shutil.copy2(SOURCE / name, self.root / name)
        (self.root / TOC).write_text(BASE_TOC, encoding="utf-8")
        (self.root / "CHANGELOG.md").write_text(BASE_NOTES, encoding="utf-8")
        (self.root / "README.md").write_text("Initial text.\n", encoding="utf-8")
        self.git("init", "--quiet")
        self.git("add", ".")
        self.git("-c", "user.name=Release tests", "-c", "user.email=tests@example.invalid",
                 "commit", "--quiet", "--no-verify", "-m", "Baseline")
        (self.root / "README.md").write_text("Changed text.\n", encoding="utf-8")
        self.git("add", "README.md")

    def git(self, *args):
        return subprocess.check_output(["git", *args], cwd=self.root, encoding="utf-8",
                                       stderr=subprocess.PIPE)

    def hook(self):
        return subprocess.run(["sh", ".githooks/pre-commit"], cwd=self.root,
                              capture_output=True, encoding="utf-8", check=False)

    def stage_metadata(self, toc, notes):
        (self.root / TOC).write_text(toc, encoding="utf-8")
        (self.root / "CHANGELOG.md").write_text(notes, encoding="utf-8")
        self.git("add", "--", TOC, "CHANGELOG.md")

    def test_hook_updates_toc_and_unpublished_notes_together(self):
        result = self.hook()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.git("show", f":{TOC}"), BASE_TOC.replace("1.0.1", "1.0.2"))
        notes = self.git("show", ":CHANGELOG.md")
        self.assertTrue(notes.startswith("## 1.0.2 — "))
        self.assertIn("- Update `README.md`.", notes)
        self.assertTrue(notes.endswith(BASE_NOTES), "Previous notes remain intact")
        self.assertEqual((self.root / TOC).read_text(), self.git("show", f":{TOC}"))
        self.assertEqual((self.root / "CHANGELOG.md").read_text(), self.git("show", ":CHANGELOG.md"))

    def test_prepared_version_is_kept_and_unstaged_edits_are_untouched(self):
        prepared_toc = BASE_TOC.replace("1.0.1", "2.0.0")
        prepared_notes = BASE_NOTES.replace("1.0.1", "2.0.0")
        self.stage_metadata(prepared_toc, prepared_notes)
        (self.root / TOC).write_text(prepared_toc.replace("2.0.0", "3.0.0"))
        (self.root / "CHANGELOG.md").write_text(prepared_notes.replace("2.0.0", "3.0.0"))
        result = self.hook()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.git("show", f":{TOC}"), prepared_toc)
        self.assertEqual(self.git("show", ":CHANGELOG.md"), prepared_notes)
        self.assertIn("3.0.0", (self.root / TOC).read_text())
        self.assertIn("3.0.0", (self.root / "CHANGELOG.md").read_text())
        self.assertFalse((self.root / "dist").exists(), "Index validation writes no build artifacts")

    def test_autonumbering_refuses_to_stage_unstaged_metadata(self):
        unstaged = BASE_NOTES + "\n- Unstaged work.\n"
        (self.root / "CHANGELOG.md").write_text(unstaged)
        before = self.git("write-tree")
        result = self.hook()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unstaged edits", result.stderr)
        self.assertEqual(self.git("write-tree"), before)
        self.assertEqual((self.root / "CHANGELOG.md").read_text(), unstaged)
        self.assertEqual((self.root / TOC).read_text(), BASE_TOC)

    def test_partial_version_edit_is_rejected_even_if_working_files_agree(self):
        self.stage_metadata(BASE_TOC.replace("1.0.1", "2.0.0"), BASE_NOTES)
        (self.root / "CHANGELOG.md").write_text(BASE_NOTES.replace("1.0.1", "2.0.0"))
        before = self.git("write-tree")
        checked = subprocess.run([sys.executable, "scripts/validate_release.py", "--staged"],
                                 cwd=self.root, capture_output=True, encoding="utf-8", check=False)
        self.assertNotEqual(checked.returncode, 0)
        result = self.hook()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.git("write-tree"), before)

    def test_tagged_notes_get_a_new_entry_without_manual_changelog_work(self):
        self.git("tag", "v1.0.1")
        result = self.hook()
        self.assertEqual(result.returncode, 0, result.stderr)
        staged = self.git("show", ":CHANGELOG.md")
        self.assertTrue(staged.startswith("## 1.0.2 — "))
        self.assertTrue(staged.endswith(BASE_NOTES), "Published notes stay unchanged")
        self.assertIn("- Update `README.md`.", staged)

    def test_handwritten_unreleased_notes_are_retained(self):
        self.git("tag", "v1.0.1")
        notes = "## Unreleased — 2026-10-11\n\n- Next release.\n\n" + BASE_NOTES
        self.stage_metadata(BASE_TOC, notes)
        result = self.hook()
        self.assertEqual(result.returncode, 0, result.stderr)
        staged = self.git("show", ":CHANGELOG.md")
        self.assertTrue(staged.startswith("## 1.0.2 — "))
        self.assertTrue(staged.endswith(BASE_NOTES), "Published notes stay unchanged")
        self.assertIn("- Next release.", staged)
        self.assertNotIn("Update `README.md`", staged)

    def test_empty_unreleased_entry_gets_generated_notes(self):
        self.stage_metadata(BASE_TOC, "## Unreleased — 2026-10-11\n\n" + BASE_NOTES)
        result = self.hook()
        self.assertEqual(result.returncode, 0, result.stderr)
        notes = self.git("show", ":CHANGELOG.md")
        self.assertIn("- Update `README.md`.", notes)
        self.assertTrue(notes.endswith(BASE_NOTES))

    def test_published_notes_cannot_be_edited_or_removed(self):
        self.git("tag", "v1.0.1")
        notes = "## Unreleased — 2026-10-11\n\n- New notes.\n\n"
        for old in (BASE_NOTES.replace("Initial release", "Changed published"), ""):
            self.stage_metadata(BASE_TOC, notes + old)
            before = self.git("write-tree")
            result = self.hook()
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Published changelog entry 1.0.1", result.stderr)
            self.assertEqual(self.git("write-tree"), before)

    def test_already_committed_mismatch_is_repaired_automatically(self):
        self.stage_metadata(BASE_TOC.replace("1.0.1", "1.0.2"), BASE_NOTES)
        self.git("-c", "user.name=Release tests", "-c", "user.email=tests@example.invalid",
                 "commit", "--quiet", "--no-verify", "-m", "Version only")
        self.git("tag", "v1.0.2", "HEAD^")
        (self.root / "README.md").write_text("Next change.\n", encoding="utf-8")
        self.git("add", "README.md")
        result = self.hook()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("## Version: 1.0.3", self.git("show", f":{TOC}"))
        self.assertTrue(self.git("show", ":CHANGELOG.md").endswith(BASE_NOTES))

    def test_only_staged_changes_are_described(self):
        (self.root / "draft.txt").write_text("Unstaged draft.\n")
        (self.root / "new.txt").write_text("Staged addition.\n")
        self.git("add", "new.txt")
        result = self.hook()
        self.assertEqual(result.returncode, 0, result.stderr)
        notes = self.git("show", ":CHANGELOG.md")
        self.assertIn("- Add `new.txt`.", notes)
        self.assertNotIn("draft.txt", notes)
        self.assertNotIn("draft.txt", self.git("diff", "--cached", "--name-only"))

    def test_normal_git_commits_include_generated_metadata_and_leave_a_clean_tree(self):
        self.git("config", "core.hooksPath", ".githooks")
        self.git("config", "user.name", "Release tests")
        self.git("config", "user.email", "tests@example.invalid")
        self.git("tag", "v1.0.1")
        self.git("commit", "--quiet", "-m", "Change readme")
        toc = self.git("show", f"HEAD:{TOC}")
        notes = self.git("show", "HEAD:CHANGELOG.md")
        self.assertEqual(release.release_metadata(toc, notes)[0], "1.0.2")
        self.assertIn("Update `README.md`", notes)
        self.assertEqual(self.git("status", "--porcelain"), "")
        self.git("tag", "v1.0.2")
        (self.root / "README.md").write_text("Another change.\n")
        self.git("add", "README.md")
        self.git("commit", "--quiet", "-m", "Change readme again")
        self.assertIn("## Version: 1.0.3", self.git("show", f"HEAD:{TOC}"))
        self.assertTrue(self.git("show", "HEAD:CHANGELOG.md").endswith(notes))
        self.assertEqual(self.git("status", "--porcelain"), "")

    def test_windows_python_launcher_is_supported(self):
        launchers = self.root / "launchers"
        launchers.mkdir()
        launcher = launchers / "py"
        marker = launchers / "used"
        interpreter = str(Path(sys.executable).resolve()).replace("'", "'\"'\"'")
        launcher.write_text("#!/bin/sh\n[ \"$1\" = -3 ] || exit 1\nshift\n"
                            + f"touch '{marker}'\nexec '{interpreter}' \"$@\"\n")
        launcher.chmod(0o755)
        env = dict(os.environ, PATH=str(launchers) + os.pathsep + os.environ["PATH"])
        result = subprocess.run(["sh", ".githooks/pre-commit"], cwd=self.root,
                                capture_output=True, encoding="utf-8", env=env)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(marker.exists(), "The hook used py -3")

    def test_an_empty_index_does_not_create_a_metadata_only_commit(self):
        self.git("reset", "--quiet", "HEAD", "README.md")
        before = self.git("write-tree")
        result = self.hook()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Stage changes", result.stderr)
        self.assertEqual(self.git("write-tree"), before)

    def test_existing_build_tag_prevents_reusing_a_version(self):
        self.git("tag", "v1.0.2")
        before = self.git("write-tree")
        result = self.hook()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("already tagged", result.stderr)
        self.assertEqual(self.git("write-tree"), before)

    def test_shallow_history_is_rejected_before_any_rewrite(self):
        (self.root / ".git/shallow").write_text(self.git("rev-parse", "HEAD"))
        before = self.git("write-tree")
        result = self.hook()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("full Git history", result.stderr)
        self.assertEqual(self.git("write-tree"), before)


if __name__ == "__main__":
    unittest.main()
