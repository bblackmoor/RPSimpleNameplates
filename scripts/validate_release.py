#!/usr/bin/env python3
"""Check release metadata and the installable ZIP using only Python's stdlib."""

import argparse
import os
from pathlib import Path, PurePosixPath
import re
import sys
import xml.etree.ElementTree as ET
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
ADDON = "SimpleNameplates"
TOC = PurePosixPath(f"{ADDON}/{ADDON}.toc")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def normalized(text):
    # Match the whitespace-only normalization of bundled upstream sources.
    lines = []
    for line in text.splitlines():
        indent = re.match(r"^[ \t]*", line).group()
        lines.append((indent.expandtabs(4) + line[len(indent):]).rstrip())
    return "\n".join(lines).rstrip() + "\n"


def load_entries(toc):
    return [line.strip().replace("\\", "/") for line in toc.splitlines()
            if line.strip() and not line.lstrip().startswith("#")]


def metadata():
    toc = (ROOT / TOC).read_text(encoding="utf-8")
    match = re.search(r"^## Version: (\d+\.\d+\.\d+)\s*$", toc, re.MULTILINE)
    require(match is not None, "TOC must contain a numeric three-part version")
    version = match.group(1)
    ref = os.environ.get("GITHUB_REF", "")
    if ref.startswith("refs/tags/"):
        require(ref == f"refs/tags/v{version}",
                f"Release tag must be v{version}, matching the TOC version")

    changelog = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
    sections = re.split(r"(?m)(?=^## )", changelog)
    notes = next((part for part in sections if part.startswith(f"## {version} — ")), None)
    require(notes is not None, f"Missing changelog entry for {version}")
    require(changelog.lstrip().startswith(f"## {version} — "),
            "The first changelog entry must match the TOC version")
    output = ROOT / "dist/release-notes.md"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(notes.strip() + "\n", encoding="utf-8")
    return version, toc


def verify_archive(path, version, source_toc):
    with ZipFile(path) as archive:
        files = [item.filename for item in archive.infolist() if not item.is_dir()]
        require(len(files) == len(set(files)), "ZIP contains duplicate file paths")
        for name in files:
            parts = PurePosixPath(name).parts
            require(parts and parts[0] == ADDON and ".." not in parts
                    and "\\" not in name, f"Invalid ZIP layout: {name}")

        def read(name):
            require(str(name) in files, f"Missing packaged file: {name}")
            return archive.read(str(name)).decode("utf-8-sig")

        packaged_toc = read(TOC)
        require(re.search(rf"^## Version: {re.escape(version)}\s*$",
                          packaged_toc, re.MULTILINE), "Packaged version does not match source")
        require(load_entries(packaged_toc) == load_entries(source_toc),
                "Packaged TOC load order differs from source")
        for field in ("Interface", "SavedVariables", "OptionalDeps"):
            pattern = rf"^## {field}: (.+)$"
            expected = re.search(pattern, source_toc, re.MULTILINE)
            actual = re.search(pattern, packaged_toc, re.MULTILINE)
            require(expected and actual and
                    expected.group(1).replace(" ", "") == actual.group(1).replace(" ", ""),
                    f"Packaged {field} metadata differs from source")

        loaded = set()

        def check_file(name):
            require(".." not in name.parts and not name.is_absolute(),
                    f"Invalid load path: {name}")
            if name in loaded:
                return
            loaded.add(name)
            contents = read(name)
            source = ROOT / name
            require(source.is_file(), f"Unexpected runtime file: {name}")
            require(normalized(contents) == normalized(source.read_text(encoding="utf-8-sig")),
                    f"Packaged runtime differs from tested source: {name}")
            if name.suffix == ".xml":
                for element in ET.fromstring(contents).iter():
                    if element.tag.rsplit("}", 1)[-1] in ("Script", "Include"):
                        require("file" in element.attrib, f"Missing XML file attribute: {name}")
                        check_file(name.parent / element.attrib["file"].replace("\\", "/"))

        for entry in load_entries(packaged_toc):
            check_file(PurePosixPath(ADDON) / entry)

        legal = {
            f"{ADDON}/LICENSE",
            f"{ADDON}/Libs/CallbackHandler-1.0/LICENSE",
            f"{ADDON}/Libs/LibSharedMedia-3.0/LICENSE",
            f"{ADDON}/Libs/DetailsFramework/LICENSE",
        }
        for name in legal:
            read(name)
        assets = set()
        for source in (ROOT / ADDON / "Media").rglob("*"):
            if source.is_file():
                name = source.relative_to(ROOT).as_posix()
                require(name in files and archive.read(name) == source.read_bytes(),
                        f"Missing or changed packaged artwork: {name}")
                assets.add(name)
        allowed = {str(name) for name in loaded} | legal | {
            str(TOC), f"{ADDON}/README.md", f"{ADDON}/CHANGELOG.md",
            f"{ADDON}/Libs/DetailsFramework/UPSTREAM.json",
        } | assets
        unexpected = set(files) - allowed
        require(not unexpected, "Unexpected files in ZIP: " + ", ".join(sorted(unexpected)))
        print(f"Verified {path.name}: {len(loaded)} runtime files; versions, layout and licenses match")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path)
    args = parser.parse_args()
    version, toc = metadata()
    if args.archive:
        verify_archive(args.archive, version, toc)
    else:
        print(version)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, ET.ParseError) as error:
        print(f"Release validation failed: {error}", file=sys.stderr)
        sys.exit(1)
