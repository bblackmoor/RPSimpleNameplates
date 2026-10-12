# Packaging and releases

The [Build and release workflow](../.github/workflows/release.yml) uses the
[BigWigs packager](https://github.com/BigWigsMods/packager) and the repository's
[`.pkgmeta`](../.pkgmeta) recipe. All action versions and library sources are
pinned. GitHub builds run on its hosted runners; no local build server or
personal access token is needed.

The repository, addon folder and TOC filename use `RPSimpleNameplates`. The
display name is **RP Simple Nameplates**, and release ZIPs are named
`RPSimpleNameplates-<version>.zip`. The saved data variable remains
`SimpleNameplatesDB`.

## Build a ZIP without publishing

Push to `main`, open or update a pull request against `main`, or select
**Actions → Build and release → Run workflow**. These builds do not publish a
release. Select the completed run and download its
`RPSimpleNameplates-<version>` artifact. GitHub's artifact download wraps the
installable addon ZIP and `release-notes.md` in another ZIP; install the inner
`RPSimpleNameplates-<version>.zip`. Artifacts are retained for 30 days.

The workflow:

1. Requires a numeric three-part TOC version and a matching first changelog entry.
2. Runs the release-tool unit tests and all existing Lua smoke suites on the source checkout.
3. Fetches the four libraries at the exact commits in `.pkgmeta` and builds a
   ZIP with a single top-level `RPSimpleNameplates` folder.
4. Checks the full TOC/XML load chain against the tested source, retaining
   library licenses and artwork and rejecting unexpected files. Library
   whitespace differences are normalized for the comparison.
5. Runs all smoke suites again using the addon extracted from that ZIP.
6. Saves the ZIP and the current changelog entry as build artifacts.

The framework's core `fw.lua` is copied verbatim rather than processed for
packager keywords. It contains no required keyword substitutions. Standalone
library TOCs, tests, examples, documentation, temporary checkouts and the unused
legacy LibCustomGlow copy are excluded from the installable ZIP.

The bundled library copies remain in the repository so **Code → Download ZIP**
and local tests continue to work. When changing a library, update its commit
pin, bundled source, license/provenance records and tests together. The package
check rejects a fetched runtime file that differs from the bundled copy beyond
the documented whitespace normalization.

## Prepare matching build metadata

Build numbers normally use the next commit count from a full-history checkout.
Enable the local hook once, from the repository folder:

```sh
git config --local core.hooksPath .githooks
```

Then edit, stage and commit normally. The pre-commit hook creates a new changelog
entry summarizing the staged file changes and sets the matching TOC version.
You do not need to edit the changelog or start an `Unreleased` section first.
Python 3 is required; the hook supports Windows's `py -3` launcher as well as
`python3` and `python`. Hooks and generated TOC/changelog files retain LF line
endings on Windows, preventing carriage returns from failing Git's whitespace
check. This setting is local to each clone.

You can still write more descriptive notes: stage an `Unreleased` section or a
new matching numeric version and heading, and preparation keeps your notes.
Otherwise, automatic notes name added, removed and updated files. Git's commit
message is not available during the pre-commit hook, so it is not used for
automatic notes.

To run the same preparation without the hook:

```sh
python3 scripts/validate_release.py --prepare-staged
python3 scripts/validate_release.py --staged
```

Preparation stages the TOC and changelog together. Automatic entries retain
previous notes, and tagged entries cannot be rewritten. A new matching numeric
version and heading that you explicitly staged are retained. Unstaged metadata
edits are never added implicitly. Shallow history, partially staged version
overrides and already-used build tags are rejected before any metadata rewrite.
An existing mismatch already committed to HEAD is repaired by adding a new
entry, preserving the previous notes.

GitHub web/API commits do not execute local hooks, so run the preparation before
creating those commits too. Commit-count versions describe the prepared build;
branches can share a count, and rewriting history can change it. An explicitly
prepared version provides an override when needed.

## Publish a GitHub release

Commit with the local hook enabled (or run preparation before a web/API commit)
and push. Read the resulting version in
`RPSimpleNameplates/RPSimpleNameplates.toc`. Tag that commit with `v` followed by
the exact TOC version, then push the tag. For
version 1.0.289, for example:

```sh
git tag -a v1.0.289 -m "RP Simple Nameplates 1.0.289"
git push origin v1.0.289
```

The tag push runs the same checks and publishes the verified ZIP to GitHub
Releases with that version's changelog entry. Mismatched tags fail validation.
A manual workflow run creates an artifact even if a tag is selected; publication
requires the tag-push event. A failed build prevents publication.

Only the release job has `contents: write`; it uses GitHub's supplied
`GITHUB_TOKEN`. It creates a new release and does not overwrite an existing one.
If Actions are disabled or an account policy blocks the pinned actions, enable
them in [repository Actions settings](https://github.com/bblackmoor/RPSimpleNameplates/settings/actions).

## Publish to CurseForge

The addon metadata identifies
[CurseForge project 1740403](https://authors.curseforge.com/#/projects/1740403).
Create an [author API token](https://authors.curseforge.com/#/settings/api-tokens)
and save it as `CF_API_TOKEN` in
[GitHub Actions secrets](https://github.com/bblackmoor/RPSimpleNameplates/settings/secrets/actions).
Keep the token out of commits, chat and documentation.

For future matching version-tag pushes, the `curseforge` job waits for the build
and GitHub release to succeed, then uploads the same ZIP bytes to the
[CurseForge author upload API](https://support.curseforge.com/support/solutions/articles/9000197321-curseforge-upload-api).
It reads the project ID and supported Retail patch versions from the TOC,
resolves those versions against CurseForge's Retail catalog, includes the
current release notes and embedded-library relations from `.pkgmeta`, and
reports the returned file ID. It does not rebuild the package or fall back to
a different game version if a declared version is missing from the catalog.

If the secret is absent, the job posts a clear skipped-upload notice and the
GitHub release still succeeds. After setting the secret, rerun only that
`curseforge` job to upload its retained artifact. If an upload failed or timed
out, check the project's files before retrying so an accepted upload is not
submitted again. Existing published tags are not moved or republished by this
setup change; the next version tag must include this workflow.

An accepted upload may still await CurseForge's normal review before becoming
public. Confirm supported Retail versions and the included libraries on the
first accepted file. TRP3 remains an optional integration; required libraries
are embedded in the ZIP.

## Local packaging checks

With Git, Bash, ZIP and LuaTeX installed, clone the packager at its pinned
`v2.6.1` release outside this repository. From the RP Simple Nameplates repository:

```sh
python3 scripts/validate_release.py
python3 -m unittest discover -s tests -p 'test_*.py'
for test in tests/*-smoke.lua; do texlua "$test" || exit 1; done
bash /path/to/packager/release.sh -d -l -u -n 'RPSimpleNameplates-1.0.289'
python3 scripts/validate_release.py --archive .release/RPSimpleNameplates-1.0.289.zip
python3 scripts/upload_curseforge.py --archive .release/RPSimpleNameplates-1.0.289.zip --notes dist/release-notes.md --dry-run
```

Use the current TOC version in the ZIP name. `.release/`, `dist/` and Python
bytecode caches are ignored by Git. `dist/release-notes.md` contains the current
changelog entry generated by the validation script.
