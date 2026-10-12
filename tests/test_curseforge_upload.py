"""Exercise release metadata and upload requests without contacting CurseForge."""

from email import policy
from email.parser import BytesParser
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import upload_curseforge as cf

VERSION = "1.0.248"
TOC = f"## Interface: 120100, 120105\n## Version: {VERSION}\n## X-Curse-Project-ID: 1740403\n"
NOTES = f"## {VERSION} — 2026-10-11\n\n- Release automation.\n"
RECIPE = "externals:\n  library:\n    curse-slug: libstub\n"
CATALOG = [{"id": 101, "name": "12.1.0", "gameVersionTypeID": 517},
           {"id": 102, "name": "12.1.5", "gameVersionTypeID": 517},
           {"id": 999, "name": "12.1.0", "gameVersionTypeID": 67408}]


class CurseForgeUploadTests(unittest.TestCase):
    def test_metadata_matches_project_notes_and_embedded_libraries(self):
        project, names, payload = cf.upload_metadata(VERSION, TOC, NOTES, RECIPE)
        self.assertEqual(project, 1740403)
        self.assertEqual(names, ["12.1.0", "12.1.5"])
        self.assertEqual(payload["releaseType"], "release")
        self.assertEqual(payload["changelog"], NOTES)
        self.assertEqual(payload["relations"]["projects"],
                         [{"slug": "libstub", "type": "embeddedLibrary"}])

    def test_versions_select_retail_and_keep_all_supported_patches(self):
        self.assertEqual(cf.resolve_versions(["12.1.0", "12.1.5"], CATALOG), [101, 102])

    def test_missing_or_ambiguous_version_rejected(self):
        for catalog in (CATALOG[:1], CATALOG + [CATALOG[0]]):
            with self.assertRaises(ValueError):
                cf.resolve_versions(["12.1.0", "12.1.5"], catalog)

    def test_missing_project_and_mismatched_notes_rejected(self):
        for toc, notes in (("## Interface: 120100\n", NOTES), (TOC, "Old release notes")):
            with self.assertRaises(ValueError):
                cf.upload_metadata(VERSION, toc, notes, RECIPE)

    def test_multipart_preserves_zip_bytes_and_unicode_notes(self):
        contents = b"PK\x00\xff\r\noriginal archive\x00"
        body, content_type = cf.multipart({"changelog": NOTES}, "addon.zip", contents)
        message = BytesParser(policy=policy.default).parsebytes(
            f"Content-Type: {content_type}\r\nMIME-Version: 1.0\r\n\r\n".encode() + body)
        parts = {part.get_param("name", header="content-disposition"): part
                 for part in message.iter_parts()}
        self.assertEqual(json.loads(parts["metadata"].get_payload(decode=True)), {"changelog": NOTES})
        self.assertEqual(parts["file"].get_payload(decode=True), contents)
        self.assertEqual(parts["file"].get_filename(), "addon.zip")

    def test_request_uses_header_authentication_and_original_body(self):
        with patch.object(cf, "urlopen", return_value=io.BytesIO(b'{"id": 55}')) as open_url:
            self.assertEqual(cf.request_json("https://wow.curseforge.com/api/projects/1740403/upload-file",
                                            "test-token", b"zip-body", "multipart/form-data"), {"id": 55})
            request = open_url.call_args.args[0]
            self.assertEqual(request.get_method(), "POST")
            self.assertEqual(request.get_header("X-api-token"), "test-token")
            self.assertNotIn("test-token", request.full_url)
            self.assertEqual(request.data, b"zip-body")

    def test_dry_run_missing_token_and_wrong_tag_never_contact_api(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            archive = root / "addon.zip"
            archive.write_bytes(b"original ZIP")
            notes = root / "notes.md"
            notes.write_text(NOTES)
            (root / ".pkgmeta").write_text(RECIPE)
            with patch.object(cf, "ROOT", root), patch.object(cf, "metadata", return_value=(VERSION, TOC)), \
                    patch.object(cf, "verify_archive"), patch.object(cf, "request_json") as api, \
                    patch.dict(cf.os.environ, {}, clear=True), patch("sys.stdout", new_callable=io.StringIO):
                cf.upload(archive, notes, dry_run=True)
                with self.assertRaisesRegex(ValueError, "version tag"):
                    cf.upload(archive, notes)
                with patch.dict(cf.os.environ, {"GITHUB_REF": f"refs/tags/v{VERSION}"}):
                    with self.assertRaisesRegex(ValueError, "CF_API_TOKEN"):
                        cf.upload(archive, notes)
                api.assert_not_called()

    def test_success_uploads_once_and_returns_file_id(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            archive = root / "addon.zip"
            archive.write_bytes(b"original ZIP")
            notes = root / "notes.md"
            notes.write_text(NOTES)
            (root / ".pkgmeta").write_text(RECIPE)
            with patch.object(cf, "ROOT", root), patch.object(cf, "metadata", return_value=(VERSION, TOC)), \
                    patch.object(cf, "verify_archive"), \
                    patch.object(cf, "request_json", side_effect=[CATALOG, {"id": 77}]) as api, \
                    patch.dict(cf.os.environ, {"GITHUB_REF": f"refs/tags/v{VERSION}", "CF_API_TOKEN": "test-token"}, clear=True), \
                    patch("sys.stdout", new_callable=io.StringIO) as stdout:
                cf.upload(archive, notes)
                self.assertEqual(api.call_count, 2)
                self.assertIn("/projects/1740403/upload-file", api.call_args.args[0])
                self.assertIn(b"original ZIP", api.call_args.args[2])
                self.assertIn("file ID 77", stdout.getvalue())
                self.assertEqual(archive.read_bytes(), b"original ZIP")


if __name__ == "__main__":
    unittest.main()
