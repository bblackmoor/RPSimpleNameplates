# Performance implementation record

The four original code phases (1.0.202–1.0.205) and subsequent targeted repairs are implemented. This records the resulting design; completed tasks, visit-count backoff, and intermediate-build test instructions have been removed.

## Baseline

The 2026-10-06 report covered 119.6 seconds: 8,454 full styles (20,134.112 ms inclusive), 440 all-plate reconciliation passes (11,435.746 ms inclusive; 25.990 ms average, 116.109 ms maximum), and 9,866 cached-text repairs (5,232.329 ms inclusive). Native name/color hooks triggered full styling and glyph copies synchronized through setter hooks. Inclusive totals overlap; unmatched scenes do not establish FPS gains or leaks.

## Implemented changes

1. Remove glyph copies and their health-dependent alpha logic; use thin outlines. Add optional timings and bounded reason counters.
2. Separate focused native-name/health-color repair from full styling. Coalesce per-unit classification, content, threat, cast, and layout work. Invalid identity/presentation caches still trigger full styling.
3. Reuse access assessments only within an operation; selectively repair readable differences. Unchanged plates write nothing; unknown observations do not establish drift.
4. Share a fair due-time scheduler across reconciliation and deferred restoration/cast/unit/plate/global work. The budget is at most four atomic jobs per frame with a one-millisecond target checked between jobs. Discovery and served-plate cadence are 0.25 seconds; elapsed unknown-property retry eligibility backs off from 0.25 to four seconds.

Explicit unit work and current/previous target, mouseover, and interaction plates remain immediate. Broad settings/context updates settle over successive frames. A time target cannot interrupt an atomic operation, and a backlog can delay service beyond eligibility. Restoration remains eligible while styling is disabled.

The follow-up [appearance convergence record](reconciliation-stall-plan.md) captures the measured boundary fixes. Use [profiling](profiling.md) for equivalent timing definitions and [live verification](live-wow-verification.md) for unconfirmed client behavior. Exact FPS impact remains unestablished; another diagnostic phase is warranted only by a reproduced problem.

## Phase 4 allocation measurements (2026-11-17)

Run `luatex --luaonly tests/runtime-allocation-benchmark.lua` from the repository root.
An optional source-directory argument selects another revision. The harness loads
the production layout module and extracts the production discovery function.
Native APIs and scheduler calls are stubbed; the native plate snapshot is reused
to isolate addon-owned bookkeeping. GC is paused during 10,000 calls after warmup.

| Isolated operation | Before | After |
| --- | ---: | ---: |
| Suppress auxiliary text | 1015.7 KiB | 0.1 KiB |
| Discover 40 plates | 20546.9 KiB | 0.0 KiB |

Discovery reuses a membership table and clears its references after each scan
(and before reuse, to recover from an interrupted prior scan). Removal and
reappearance assertions verify that membership does not leak between scans.
Text layout and reconciliation share module-local constant field lists.

Discovery remains at 0.25 seconds. Scheduler budgets, retry backoff, and repair
ordering are unchanged. Reconciliation closures remain local: this benchmark
does not establish a benefit for replacing them with additional shared state.
These measurements isolate allocation savings, not live WoW CPU time or FPS.
