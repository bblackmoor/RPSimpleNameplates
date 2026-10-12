#!/usr/bin/env python3
"""Upload the verified release ZIP unchanged to the CurseForge author API."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import sys
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen
from uuid import uuid4

from validate_release import ROOT, metadata, require, verify_archive

API = "https://wow.curseforge.com/api"
RETAIL_VERSION_TYPE = 517


def upload_metadata(version, toc, notes, recipe):
    project = re.search(r"^## X-Curse-Project-ID: (\d+)\s*$", toc, re.MULTILINE)
    require(project and int(project.group(1)) > 0, "Missing CurseForge project ID in TOC")
    interface = re.search(r"^## Interface: ([\d, ]+)\s*$", toc, re.MULTILINE)
    require(interface is not None, "Missing supported Retail interface versions")
    builds = [int(value.strip()) for value in interface.group(1).split(",")]
    versions = list(dict.fromkeys(f"{build // 10000}.{build // 100 % 100}.{build % 100}"
                                 for build in builds))
    slugs = re.findall(r"(?m)^\s+curse-slug:\s*([\w-]+)\s*$", recipe)
    require(slugs, "Missing embedded-library relations in .pkgmeta")
    require(notes.startswith(f"## {version} — "), "Release notes do not match the addon version")
    payload = {
        "displayName": f"RP Simple Nameplates {version}",
        "releaseType": "release",
        "changelog": notes,
        "changelogType": "markdown",
        "relations": {"projects": [{"slug": slug, "type": "embeddedLibrary"}
                                    for slug in dict.fromkeys(slugs)]},
    }
    return int(project.group(1)), versions, payload


def resolve_versions(names, catalog):
    ids = []
    for name in names:
        matches = [entry["id"] for entry in catalog
                   if entry.get("gameVersionTypeID") == RETAIL_VERSION_TYPE
                   and entry.get("name") == name]
        require(len(matches) == 1 and isinstance(matches[0], int) and matches[0] > 0,
                f"CurseForge has no unique Retail version match for {name}")
        ids.append(matches[0])
    return ids


def multipart(payload, filename, contents):
    boundary = "RPSimpleNameplates-" + uuid4().hex
    require('"' not in filename and "\r" not in filename and "\n" not in filename,
            "Invalid archive filename")
    body = (
        f'--{boundary}\r\nContent-Disposition: form-data; name="metadata"\r\n'
        'Content-Type: application/json; charset=utf-8\r\n\r\n'
        + json.dumps(payload, ensure_ascii=False)
        + f'\r\n--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="{filename}"\r\n'
        + 'Content-Type: application/zip\r\n\r\n'
    ).encode("utf-8") + contents + f"\r\n--{boundary}--\r\n".encode("ascii")
    return body, f"multipart/form-data; boundary={boundary}"


def request_json(url, token, body=None, content_type=None):
    headers = {"X-Api-Token": token, "Accept": "application/json"}
    if content_type:
        headers["Content-Type"] = content_type
    request = Request(url, data=body, headers=headers)
    with urlopen(request, timeout=60) as response:
        return json.load(response)


def upload(archive, notes_path, dry_run=False):
    version, toc = metadata()
    verify_archive(archive, version, toc)
    project, versions, payload = upload_metadata(
        version, toc, notes_path.read_text(encoding="utf-8"),
        (ROOT / ".pkgmeta").read_text(encoding="utf-8"))
    contents = archive.read_bytes()
    if dry_run:
        print(json.dumps({"project_id": project, "archive": archive.name,
                          "sha256": hashlib.sha256(contents).hexdigest(),
                          "retail_versions": versions, "metadata": payload}, indent=2))
        return
    require(os.environ.get("GITHUB_REF") == f"refs/tags/v{version}",
            "Upload requires the matching version tag")
    token = os.environ.get("CF_API_TOKEN", "").strip()
    require(token, "Add the CF_API_TOKEN repository secret before uploading")
    catalog = request_json(f"{API}/game/wow/versions", token)
    require(isinstance(catalog, list), "CurseForge returned an invalid version catalog")
    payload["gameVersions"] = resolve_versions(versions, catalog)
    body, content_type = multipart(payload, archive.name, contents)
    # A single upload avoids resubmitting a file after an ambiguous POST timeout.
    result = request_json(f"{API}/projects/{project}/upload-file", token, body, content_type)
    file_id = result.get("id") if isinstance(result, dict) else None
    require(isinstance(file_id, int) and file_id > 0, "CurseForge did not return an uploaded file ID")
    message = f"CurseForge accepted {archive.name} for project {project}; file ID {file_id}."
    print(message)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as output:
            output.write(message + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--notes", type=Path, required=True)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    upload(args.archive, args.notes, args.dry_run)


if __name__ == "__main__":
    try:
        main()
    except HTTPError as error:
        print(f"CurseForge API rejected the request (HTTP {error.code}); check the author token, project access and file requirements.", file=sys.stderr)
        sys.exit(1)
    except URLError:
        print("Cannot reach the CurseForge API; inspect project files before retrying an upload.", file=sys.stderr)
        sys.exit(1)
    except (ValueError, OSError) as error:
        print(f"CurseForge upload failed: {error}", file=sys.stderr)
        sys.exit(1)
