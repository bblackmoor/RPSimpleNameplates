# Developer documentation

Start with the current behavior guides. Release history belongs in the [changelog](../CHANGELOG.md); completed implementation records describe decisions rather than tasks to repeat.

| Guide | Purpose |
| --- | --- |
| [Runtime notes](design/runtime-notes.md) | Artwork, text geometry, title lookup, setup, diagnostics, and presentation limits moved out of the user README |
| [Runtime evaluation](design/evaluation-overview.md) | Classification, presentation, and update order |
| [Settings architecture](design/settings-architecture.md) | Current pages, modules, refresh paths, and ownership |
| [Saved data](design/saved-data-model.md) | Validation, defaults, compatibility, and reset scopes |
| [Shared settings conventions](design/settings-conventions.md) | Widget and editor contracts shared with RP Emote Menu |
| [Profiling](design/profiling.md) | Reports, measurement scope, and interpretation |
| [Live verification](design/live-wow-verification.md) | Current client checks and recorded observations |
| [Cast-effect testing](design/cast-effect-testing.md) | Repeatable cast test and detection/rendering diagnosis |
| [Nameplate settings source review](design/nameplate-settings-review.md) | Evidence for native frame and overhead-name restrictions |
| [Library provenance](../RPSimpleNameplates/Libs/README.md) | Bundled dependencies and pinned upstream sources |
| [Packaging and releases](releasing.md) | Build numbering, automated builds, version tags, ZIP checks, and CurseForge setup |

## Local checks

Run from the repository root with LuaTeX:

```sh
python3 -m unittest discover -s tests -p 'test_*.py'
for test in tests/*-smoke.lua; do
    texlua "$test" || exit 1
done
git diff --check
```

The suites exercise addon modules and bundled libraries under native UI fixtures. They cannot prove WoW rendering, secure execution, CVar permissions, or secret-value handling in the live client. Keep outstanding client checks in the live verification guide, rather than duplicating phase-specific checklists.

## Completed implementation records

- [Settings and database refactor](design/implementation-plan.md)
- [World context and runtime separation](design/runtime-refactor-plan.md)
- [Details Framework conversion](design/details-framework-conversion.md)
- [Shared settings standardization](design/addon-standardization.md)
- [Performance changes](design/performance-plan.md)
- [Appearance convergence investigation](design/reconciliation-stall-plan.md)
- [Original test foundation](design/phase-1-baseline.md)

These retain useful implementation decisions. Superseded controls, intermediate-build installation instructions, and completed phase task lists have been removed from the cleaned records.
