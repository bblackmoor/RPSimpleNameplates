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

## Release checklist

Do the [local setup](#prepare-matching-build-metadata) once for each clone.
Then use this sequence for each release:

1. **Pull the latest `main`.** Start in the repository folder, on `main`, with
   no unfinished changes. Use your normal Git client or Git Bash:

   ```sh
   git switch main
   git pull --ff-only https://github.com/bblackmoor/RPSimpleNameplates.git main
   ```

2. **Edit, stage the intended files, and commit.** The local hook chooses the
   build number, creates a changelog entry from the staged changes, and stages
   the TOC and changelog together. Manual changelog entries are optional.

3. **Push `main` and wait for its build to pass.** Use your authenticated Git
   client or `git push origin main`. In
   [Actions](https://github.com/bblackmoor/RPSimpleNameplates/actions), open the
   **Build and release** run for that commit. This verifies the source and ZIP
   and saves a build artifact; publication starts with the tag push below.

4. **Tag that exact commit with its committed version.** The version is the
   `## Version:` field in `RPSimpleNameplates/RPSimpleNameplates.toc`; the first
   changelog heading must match it. A Git client can create an annotated tag
   named `v` followed by that version. Select the commit that passed the build,
   rather than an earlier commit or another branch. From Git Bash, with `HEAD`
   still on that tested commit and the working tree clean:

   ```sh
   release_version=$(git show HEAD:RPSimpleNameplates/RPSimpleNameplates.toc |
     sed -nE 's/^## Version: ([0-9]+\.[0-9]+\.[0-9]+)[[:space:]]*$/\1/p')
   git tag -a "v${release_version}" -m "RP Simple Nameplates ${release_version}" HEAD
   git push origin "v${release_version}"
   ```

   These commands read the version from the commit being tagged. If you have
   made another commit since its build passed, verify that newer build before
   tagging it. Creating a tag locally is followed by a separate tag push.

5. **Confirm both publications.** Open the Actions run whose branch/ref is the
   new `v<version>` tag. The `build`, `release`, and `curseforge` jobs should
   succeed. In [GitHub Releases](https://github.com/bblackmoor/RPSimpleNameplates/releases),
   confirm the release has `RPSimpleNameplates-<version>.zip`. In the
   `curseforge` job, check that **Upload verified ZIP to CurseForge** actually
   ran and its log or summary contains:

   ```text
   CurseForge accepted RPSimpleNameplates-<version>.zip for project 1740403; file ID <id>.
   ```

   A green run alone does not prove a CurseForge upload: a missing token can
   skip the upload while the job succeeds. The returned file ID confirms API
   acceptance. Check the project's files in the CurseForge author dashboard
   for approval/public availability; acceptance and public approval are
   separate steps.

Pushing `main` or selecting **Run workflow** creates a build artifact. Pushing
the matching version tag publishes the GitHub release and uploads its verified
ZIP to CurseForge. Creating another tag does not change the build number; the
hook prepares that number when the commit is made.

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
git config --get core.hooksPath
```

The second command should print `.githooks`. This setting is stored in the
local Git configuration and must be enabled separately in each clone. Pulling
the hook file does not enable it. In a Windows shell, use forward slashes in
paths, for example `cd "D:/path/to/RPSimpleNameplates"`.

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

For script commands on Windows, use `py -3` in place of `python3` if that is how
Python is available in the shell. The hook chooses a supported interpreter
automatically.

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

Follow the [release checklist](#release-checklist). The tag push runs the same
checks and publishes the verified ZIP to GitHub Releases with that version's
changelog entry. Mismatched tags fail validation.
A manual workflow run creates an artifact even if a tag is selected; publication
requires the tag-push event. A failed build prevents publication.

Only the release job has `contents: write`; it uses GitHub's supplied
`GITHUB_TOKEN`. It creates a new release and does not overwrite an existing one.
If Actions are disabled or an account policy blocks the pinned actions, enable
them in [repository Actions settings](https://github.com/bblackmoor/RPSimpleNameplates/settings/actions).

## Publish to CurseForge

The addon metadata identifies
[CurseForge project 1740403](https://authors.curseforge.com/#/projects/1740403).
This repository's upload is already configured; releases reuse the
`CF_API_TOKEN` repository secret. To configure a new repository, create an
[author API token](https://authors.curseforge.com/#/settings/api-tokens) and save
it as `CF_API_TOKEN` in
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
process; a new release tag must point to a commit containing this workflow.

An accepted upload may still await CurseForge's normal review before becoming
public. Confirm supported Retail versions and the included libraries on the
first accepted file. TRP3 remains an optional integration; required libraries
are embedded in the ZIP.

## Troubleshooting a release

| Symptom | Action |
| --- | --- |
| `fatal: not a git repository` | Open the shell in the repository folder, or `cd` there using forward slashes on Windows. |
| `Permission denied (publickey)` | The shell's SSH authentication failed. The HTTPS pull in the checklist works for this public repository. For pushes, use your authenticated Git client or follow [GitHub's SSH troubleshooting](https://docs.github.com/en/authentication/troubleshooting-ssh/error-permission-denied-publickey). |
| Build number did not change, or `Missing changelog entry` | Check `git config --get core.hooksPath` and whether the client ran the hook. GitHub web/API commits bypass local hooks; prepare the staged metadata before creating those commits. |
| `Release tag must be ... matching the TOC version` | The tag name or selected commit is wrong. Read the version from the intended commit and create a matching unused tag for the corrected build. |
| Trailing whitespace on every TOC/changelog line | Use the current hook and `.gitattributes`, which force LF for generated metadata on Windows. Commit the correction as a new build. |
| Main/manual build is green, but no release exists | Push the matching version tag. Main pushes and manual workflow runs produce artifacts. |
| CurseForge job is green, but upload was skipped | Configure `CF_API_TOKEN`, then rerun only the `curseforge` job and confirm its upload step and returned file ID. |
| GitHub release exists, but CurseForge failed | Check whether CurseForge already accepted the file, especially after a timeout. If it has not, fix the reported token/API issue and rerun only the `curseforge` job using the retained artifact. |

To rerun a job, open its Actions run and use that job's rerun control; see
[GitHub's job rerun guide](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/re-run-workflows-and-jobs).
Rerunning uses the original commit and tag. If a fix changes files, commit the
fix, let the hook prepare a new version, and publish a new matching tag. A
rerun of the old tag cannot build a correction on `main`. Existing tags are
preserved, including failed attempts; the preparation step rejects reused
version tags.

## Local packaging checks

With Git, Bash, ZIP and LuaTeX installed, clone the packager at its pinned
`v2.6.1` release outside this repository. From the RP Simple Nameplates repository:

```sh
python3 scripts/validate_release.py
python3 -m unittest discover -s tests -p 'test_*.py'
for test in tests/*-smoke.lua; do texlua "$test" || exit 1; done
release_version=$(python3 scripts/validate_release.py)
bash /path/to/packager/release.sh -d -l -u -n "RPSimpleNameplates-${release_version}"
python3 scripts/validate_release.py --archive ".release/RPSimpleNameplates-${release_version}.zip"
python3 scripts/upload_curseforge.py --archive ".release/RPSimpleNameplates-${release_version}.zip" --notes dist/release-notes.md --dry-run
```

Use the current TOC version in the ZIP name. `.release/`, `dist/` and Python
bytecode caches are ignored by Git. `dist/release-notes.md` contains the current
changelog entry generated by the validation script.
