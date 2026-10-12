#!/usr/bin/env python3
"""Check release metadata and the installable ZIP using only Python's stdlib."""

import argparse
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
ADDON = "RPSimpleNameplates"
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


def release_metadata(toc, changelog, ref=""):
    match = re.search(r"^## Version: (\d+\.\d+\.\d+)\s*$", toc, re.MULTILINE)
    require(match is not None, "TOC must contain a numeric three-part version")
    version = match.group(1)
    if ref.startswith("refs/tags/"):
        require(ref == f"refs/tags/v{version}",
                f"Release tag must be v{version}, matching the TOC version")

    sections = re.split(r"(?m)(?=^## )", changelog)
    notes = next((part for part in sections if part.startswith(f"## {version} — ")), None)
    require(notes is not None, f"Missing changelog entry for {version}")
    require(changelog.lstrip().startswith(f"## {version} — "),
            "The first changelog entry must match the TOC version")
    return version, notes.strip() + "\n"


def metadata():
    toc = (ROOT / TOC).read_text(encoding="utf-8")
    version, notes = release_metadata(toc, (ROOT / "CHANGELOG.md").read_text(encoding="utf-8"),
                                      os.environ.get("GITHUB_REF", ""))
    output = ROOT / "dist/release-notes.md"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(notes, encoding="utf-8")
    return version, toc


def git_text(*args, required=True):
    result = subprocess.run(["git", *args], cwd=ROOT, capture_output=True,
                            encoding="utf-8", check=False)
    require(not required or result.returncode == 0, "Cannot read Git metadata for release preparation")
    return result.stdout if result.returncode == 0 else None


def staged_text(path):
    text = git_text("show", f":{path}", required=False)
    require(text is not None, f"Stage {path} before preparing or checking a build")
    return text


def prepare_staged():
    toc, changelog = staged_text(TOC), staged_text("CHANGELOG.md")
    version_match = re.search(r"^## Version: (\d+\.\d+\.\d+)\s*$", toc, re.MULTILINE)
    require(version_match is not None, "TOC must contain a numeric three-part version")
    version = version_match.group(1)
    trimmed = changelog.lstrip()
    heading = re.match(r"## (Unreleased|\d+\.\d+\.\d+) — [^\n]+", trimmed)
    require(heading is not None, "Start the changelog with a numbered or Unreleased release entry")
    if heading.group(1) != "Unreleased":
        release_metadata(toc, changelog)
        require(git_text("rev-parse", "--verify", "--quiet", f"refs/tags/v{version}",
                         required=False) is None,
                "The current release is tagged; start a new Unreleased changelog entry before preparing a build")
        previous = git_text("show", f"HEAD:{TOC}", required=False) or ""
        previous_version = re.search(r"^## Version: (\d+\.\d+\.\d+)\s*$", previous, re.MULTILINE)
        # An explicitly staged matching version/entry is already prepared.
        if previous_version and previous_version.group(1) != version:
            return version

    require(git_text("rev-parse", "--is-shallow-repository").strip() == "false",
            "Fetch full Git history before deriving a commit-count build number")
    head = git_text("rev-parse", "--verify", "--quiet", "HEAD", required=False)
    count = int(git_text("rev-list", "--count", "HEAD")) if head else 0
    next_version = version.rsplit(".", 1)[0] + f".{count + 1}"
    require(git_text("rev-parse", "--verify", "--quiet", f"refs/tags/v{next_version}",
                     required=False) is None,
            f"Build {next_version} is already tagged; prepare a distinct version and changelog entry")
    # Never fold unstaged edits into the commit as a side effect of preparation.
    for path, staged in ((TOC, toc), ("CHANGELOG.md", changelog)):
        require((ROOT / path).read_text(encoding="utf-8") == staged,
                f"Stage or stash unstaged edits to {path} before preparing a build")
    next_toc = toc[:version_match.start(1)] + next_version + toc[version_match.end(1):]
    offset = len(changelog) - len(trimmed)
    next_changelog = (changelog[:offset + heading.start(1)] + next_version
                      + changelog[offset + heading.end(1):])
    release_metadata(next_toc, next_changelog)
    (ROOT / TOC).write_text(next_toc, encoding="utf-8")
    (ROOT / "CHANGELOG.md").write_text(next_changelog, encoding="utf-8")
    git_text("add", "--", str(TOC), "CHANGELOG.md")
    return next_version


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
        for field in ("Title", "Interface", "SavedVariables", "OptionalDeps", "IconTexture", "X-Website", "X-Curse-Project-ID"):
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
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--archive", type=Path)
    mode.add_argument("--staged", action="store_true", help="Check the release metadata in Git's index")
    mode.add_argument("--prepare-staged", action="store_true",
                      help="Prepare and stage matching commit-count metadata; retain explicitly prepared versions")
    args = parser.parse_args()
    if args.prepare_staged:
        print(prepare_staged())
        return
    if args.staged:
        version, _ = release_metadata(staged_text(TOC), staged_text("CHANGELOG.md"))
        print(version)
        return
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
