# Runtime profiling

Current guide reviewed for 1.0.221 on 2026-10-08. Ordinary timing/reason counters remain; temporary 1.0.217–1.0.218 appearance checkpoints and origin rows are removed. Normal play with profiling off is the next verification step; capture a complete report if flicker or hitches return.

Available since 1.0.163. Profiling is an optional diagnostic, off by default. It helps identify frequent or expensive runtime paths before changing them; enabling it does not make the addon faster.

## Run a session

1. Choose a representative scene, such as a crowded area or combat with several visible plates.
2. Enter `/snp perf start`.
3. Play normally for a short, consistent interval, for example 30 seconds.
4. Enter `/snp perf stop`, then `/snp perf report`.
5. Capture the entire chat output with consecutive screenshots, including the timing and reason rows, alongside the addon version, client build, scene, approximate plate count, combat state and other enabled nameplate addons.

These commands also work during combat. No target is required.

| Command | Behavior |
| --- | --- |
| `/snp perf start` | Starts a fresh session, replacing the previous stopped results; an already-running session is left intact |
| `/snp perf stop` | Stops collection and captures the end memory reading; repeated stops leave results intact |
| `/snp perf report` or `/snp perf` | Prints the running or last stopped session; does not stop collection |

Results remain available until a new session or UI reload. There is no saved setting, automatic startup, periodic memory scan, log file or new library dependency. A missing or unreadable precise timer prevents starting; unavailable memory readings do not prevent timing.

## Read the timings

Rows appear in descending total elapsed time, with call count, total milliseconds, average milliseconds per call and longest call. Only paths called during the session appear.

| Report row | Measured path |
| --- | --- |
| Full styling | Complete presentation setup used by initialization, settings/context refreshes, changed structure and invalid-cache fallbacks |
| Classification | Entity-fact collection and priority classification together |
| NPC title lookup | Title resolution, including cache and tooltip paths when used |
| Text repair | Selective cached-name repair attempts; direct calls may return without writing |
| Runtime update | The per-frame callback: elapsed clock, urgent queued refreshes, periodic native-list discovery and the shared routine-work budget |
| Urgent refresh | The detached urgent event batch, including immediate explicit-unit/priority-plate updates and broad-request enqueueing before the routine budget; idle calls also count |
| Periodic work | The scheduler slice, including bounded global-refresh/reconciliation/restoration/cast/unit/plate jobs; idle calls are also counted |
| Plate discovery | Native visible-list snapshot and Lua queue membership bookkeeping, normally every 0.25 seconds while enabled |
| Reconciliation | One current plate job for pending artwork/title visibility and cached-name drift; due again 0.25 seconds after service, with later service possible under load |
| Access assessment | Complete frame/region capability assessment; routine reconciliation shares one across lookup, observation and repair, with renewal after invalidation |
| Bar artwork | Guarded application of flat fills, gradient, native text outlines and decorative edge removal |
| Health text layout | Native health-label/threat anchoring; can run multiple times within styling |
| Name/title styling | Name content, fonts, dimensions, layout and full-title presentation |
| Name drift check | Cached presentation validation and readable property observations, collecting selective differences or returning no drift |
| Geometry hook repair | Cached dimensions and required native visibility restored after native callbacks |
| Global refresh | Broad-request snapshot/enqueueing plus immediate priority work; changed definition in 1.0.214 |
| Global plate refresh | One current full/focused global plate operation, deferred or immediate |
| Name hook repair | Focused native-name repair; includes content updates or full fallback if needed |
| Health-color repair | Focused category bar-color/visibility repair; includes full fallback if needed |
| Data update | Coalesced classification, name/title, threat, cast and layout work for one current plate |
| Name layout update | Existing name/title geometry updated for changed native-label/threat presence, without content/font work |

These are inclusive elapsed timings, not exclusive CPU accounting. For example, Full styling can include Classification, which can include NPC title lookup. Runtime update can include Reconciliation and Text repair. Do not add the rows together or interpret their sum as total addon CPU. The elapsed session duration measures wall time, not time spent executing addon code.

Call counts include early-return and failed attempts. High call counts alone do not prove a bottleneck: compare total time, average and longest call. Frequent low-cost updates and rare long tooltip lookups can have very different implications. The report covers selected entry points, not every addon or library function.

Profiling itself adds clock reads, protected calls and temporary return-value storage. Nested timings include some of that overhead. Compare sessions with similar duration, plate counts, settings and activity; differences between unrelated scenes cannot establish an optimization's effect.

## Read the reason counters

After the timing rows, the same chat report prints one short row for each observed reason. Counters are session-only, reset on a fresh start, freeze on stop and create no records or clock reads when profiling is disabled. Labels contain no unit names, GUIDs or secret native values. Group names are sorted; reasons within each group are sorted by descending count, then alphabetically.

| Group | Meaning |
| --- | --- |
| Styling requests | Every full-styling entry, including all/unit refreshes, new/late/pending plates, reconciliation fallbacks and invalid-cache/structure fallbacks from focused paths |
| Styling outcomes | Styled, text suppressed, inaccessible, guarded, deferred/native, or failed; one outcome per request that reaches the guarded styling entry |
| Queued unit events | Event requests before per-unit coalescing |
| Queued global refresh | Requests affecting all visible plates before coalescing: context/settings/CVar/restoration can require full styling, while target/mouseover/TRP3 callbacks request focused work |
| Focused requests | Name hook, health-color hook or data-update entries, including guarded/inaccessible attempts |
| Focused outcomes | Updated, guarded, inaccessible, native/restored, restoration pending, failed, or invalid-cache/presentation-change fallback |
| Name drift | First observed readable mismatch or structural invalidation for a plate in each pass; simultaneous mismatches repair together but are not enumerated |
| Name size drift | From 1.0.209: observed -> requested dimensions and anchor count for every readable bar/container size mismatch; at most eight distinct samples plus an overflow row per session |
| Bar anchor preparation | From 1.0.210: success or skip reason for sizing preparation. `released opposing anchors` distinguishes successful preparation from unreadable/inaccessible or unsupported layouts; `already unconstrained` means fewer than two anchors. Counts are preparation calls, not unique plates. |
| Reconciliation repairs | Successful cached repair versus a full-style fallback request; a fallback request does not establish that full styling succeeded |
| Font drift components | Readable face, size and/or flag differences; multiple components can count for one drift repair |
| Focused cache invalidation | Specific reason for a focused path falling back, including initialization, context/settings, region replacement and identity |
| Name appearance writes | External native name setters repaired immediately from the cache; addon/restoration writes do not count |
| Appearance finalization | Readable color/alpha mismatches submitted to bounded cached recovery at operation completion; not unique plates or guaranteed successful writes |
| Name appearance deferred | Guarded color/alpha notifications that resulted in readable recovery after guard release |
| Initialization | Initial/late plate setup reused through a valid cached presentation |
| Global refresh plates | Actual full/focused global plate visits |
| Urgent batches | Broad full/focused requests and remaining explicit unit jobs; not individual durations |
| Name color drift | At most eight distinct readable RGB transitions plus overflow; no unit identities |
| Periodic jobs | Cast retries retire when styling or cast highlighting is disabled. Attempted jobs by group: global refresh, reconciliation, restoration frame/plate, cast retry and unit/plate retry; includes guarded/blocked/no-write jobs |
| Periodic limits | Slices stopped by job count or time target, plus discarded stale plate assignments; count/time reasons can overlap |

Reason counters explain call volume, not elapsed time or unique plate counts. Queued requests can merge, hook requests can return under a guard, and checks can return unknown or early. A drift label identifies a readable mismatch or structural cache invalidation. Unknown property values do not count as drift and do not trigger repair writes; they retry with elapsed-time backoff from 0.25 seconds to four seconds. Independent readable properties continue to be checked. Native label-chain changes use selective layout repair, while replaced regions or invalid presentation require full styling. Unchanged reconciliation plates perform no repair writes; plates become eligible again after 0.25 seconds, with actual service subject to the shared budget.

From 1.0.205, Reconciliation counts individual plate jobs rather than complete
visible-list passes. Do not compare its call counts or per-call averages directly
with older builds. Compare matching sessions' total elapsed rows and FPS,
including Runtime update, Periodic work and Plate discovery, without adding
inclusive totals. A count/time limit indicates deferred routine work, not lost
updates or proof of a bottleneck. The initial four-job/one-millisecond budget is
cooperative: it cannot preempt one slow operation, and discovery/urgent events
are measured separately. Retry deadlines establish eligibility, not a hard
wall-time recovery guarantee under heavy queues or low FPS.

The additional wrappers increase profiling overhead. Compare each build in matching scenes, with profiling both off and on. Do not treat timing changes across different instrumentation versions as an exact performance gain.

## Read the memory figures

The profiler refreshes WoW's addon memory accounting at start and stop and reports RP Simple Nameplates' start/end KiB and change. Reporting while running shows only the start reading; reporting a stopped session reuses the frozen readings.

These are aggregate addon readings, not allocations by function. They can include profiler storage and shared-library attribution, and garbage collection can produce a negative change. The profiler does not force garbage collection. A growing reading from a single session is insufficient evidence of a leak.

## Implementation and verification

`Profiler.lua` loads after `Core.lua` and before the runtime consumers. Wrappers preserve return values, including nil positions, and propagate the original error object. With profiling disabled they only check the active session and call the original function; they read no clock or memory API and allocate no measurement records. Reason counters only check whether a session is active while disabled. Calls spanning stop/restart cannot modify stopped results or a new session.

`tests/profiler-smoke.lua` checks deterministic nested timings, lifecycle, disabled measurement work, return/error preservation, missing timer and failed memory APIs, counter reset/freeze and the disabled counter path. Runtime and settings smoke suites check the actual hooks and combat command routing. Native timing, rendering and secret-value/taint checks remain on the [live WoW checklist](live-wow-verification.md).


## Follow-up for long stalls

Use the [reconciliation stall plan](reconciliation-stall-plan.md) to confirm the
installed version, capture the entire report with consecutive screenshots and
run matched profiling-off/on recordings before tuning the scheduler. A current
runtime report includes Periodic work whenever Runtime update runs; missing new
rows and counters warrant checking installation and screenshot coverage first.

From 1.0.207, name appearance setter hooks repair font/color updates that bypass
CompactUnitFrame_UpdateName before rendering. They use fresh access and current
assignment/identity checks, avoid full styling and skip addon writes/restoration.
Font comparison ignores filename slash/case and flag ordering/duplicates, while
retaining real differences. Component counters report face, size and flags
separately. Urgent refresh is inclusive within Runtime update and outside the
routine scheduler target. Cache invalidation reasons distinguish legitimate
initialization from recurring failures; their counts do not prove every fallback
is unnecessary. Subsequent reports located the remaining appearance completion reset; 1.0.218 confirms convergence in its tested scene. Broader normal-play verification remains open.

From 1.0.208, the focused outcome `not a nameplate` identifies global native
hooks for raid/party or cleared-unit frames, which no longer request full
styling. Native nameplate initialization remains a legitimate cache fallback.
Bar dimension repairs now release opposing native anchors while preserving their
restoration baseline. Later reports confirmed geometry convergence after the 1.0.211–1.0.213 fixes and appearance convergence in the 1.0.218 scene. Future recordings should check whether geometry or appearance drift returns under a new context. A current cached color is repaired independently of those
mutable layout properties.


In 1.0.211, `Bar anchor preparation: released native restricted anchors`
identifies sizing using the known Retail hierarchy without positional getters.
`restricted layout unsupported` leaves an unknown restricted hierarchy untouched.
A successful release should be followed by stable dimensions; repeated releases
can indicate Blizzard is resetting anchors. See the live verification checklist.


Version 1.0.212 adds inclusive `Geometry hook repair` and `Global refresh`
timings. `Initialization: reused initial plate` / `reused late plate` identify
focused refreshes replacing duplicate initialization. `Global refresh plates`
counts full/focused plate visits, and `Urgent batches` counts global full/focused
batches and remaining unit jobs. These counts do not identify the duration of
an individual batch. Compare matched runs; do not add nested timings or assume
that separately reported maxima occurred together.


As of 1.0.213, `Name drift: bar visibility` and `container visibility` can
request a cached repair instead of a full-style fallback. Native bar OnHide
also uses `Geometry hook repair` for current visibility and dimensions.
Compare Reconciliation repairs and Styling requests to distinguish selective
visibility recovery from actual cache invalidation.


Version 1.0.214 changes `Global refresh` to snapshot/enqueueing plus immediate
priority work. `Global plate refresh` times one plate operation; `Periodic jobs:
global refresh` counts deferred scheduler service, sharing the existing four
jobs/one-millisecond target with reconciliation and retries. `Global refresh
plates` counts actual full/focused visits, and Styling requests identifies
`global refresh`. Target/mouseover/interaction and explicit unit work can run
outside the periodic budget. Compare runtime/urgent maxima and completion
latency; old and new Global refresh averages measure different operations.


## Native opacity and color samples (1.0.216)

Name appearance writes now includes SetAlpha when a validated native opacity
write is serviced immediately. Name appearance deferred: alpha repair counts
readable mismatches retained while styling/artwork guards were active. Converged
own alpha writes produce no follow-up setter. Appearance font/color recovery
finishes with native alpha zero for inside names, or one for above-bar names;
widget-only suppression remains zero. Existing reconciliation stays as recovery
for changes that do not pass through a hooked Lua setter.

Name color drift captures up to eight distinct readable RGB transitions, plus
an additional samples counter. It records actual -> cached intended color for
text-color drift even if another mismatch is first in the Name drift row. It
contains no unit identity and ignores unreadable/non-finite components. Samples
are session-only and do no formatting when profiling is disabled. Include these
rows if a new report records color drift, to identify which actual colors replace the cache.

For a manual allocation comparison, run from the repository root:

```sh
texlua tests/capabilities-allocation-benchmark.lua
texlua tests/capabilities-allocation-benchmark.lua path/to/older/PresentationCapabilities.lua
```

This pauses GC only in the standalone test process and repeats 10,000 access
assessments on one fixed synthetic frame. The 1.0.215/current comparison gave
65,079.8/12,579.8 KiB under texlua, about 81% less allocation for that fixture.
WoW's memory attribution, allocator and GC behavior differ. This is evidence
of less temporary allocation, not a live retained-memory or leak measurement.
The addon itself does not pause or force GC.


## Historical appearance timing checkpoints (1.0.217–1.0.218)

Removed in 1.0.219 after live convergence was confirmed. The description below
records the diagnostic reports from those versions; these rows and reads are
no longer active.

During profiling, Appearance checkpoints: sampled counts validated observations
of completed native text RGB and alpha. Checkpoints run after full style,
focused name/health-color/data updates, cached repair, standalone artwork,
font/color/alpha setter repair and unguarded native Show. The latter is a
post-hook on the method call; it does not necessarily mean visibility changed.
Guarded Show calls are skipped and observed at the enclosing update boundary.

Appearance checkpoint drift reports the boundary and component already wrong
there, for example full style: color. Appearance checkpoint unreadable means
the component was unknown, not matched. Name color origin / Name alpha origin
classify reconciliation observations using the last checkpoint in the current
profiling session:

| Reason | Meaning |
| --- | --- |
| after verified `<boundary>` | The component matched at that checkpoint and differs now |
| present after `<boundary>` | The component was already wrong when that checkpoint ran |
| checkpoint unavailable | No current-session readable checkpoint of the current intent |

These are timing boundaries, not causal attribution to that operation. An early
native Show mismatch may be corrected by a later name hook. Checkpoint drift
counters retain that observation; origin uses the latest checkpoint. Rebuilding
the cached presentation or starting a new session invalidates older evidence.
Fresh access/context/assignment/source/GUID validation gates observation. A
frame cache stores an opaque token and scalar results, not profiling tables or
histories. Disabled checkpoints do no inspections or UI reads.

This instrumentation adds reads and Access assessment timings while profiling
is active. Compare visible behavior and profiling off/on; timing differences
between instrumentation versions are not exact performance gains. Read-only
checks do not add repairs, scheduling jobs, timers or forced garbage collection.


## Complete appearance after selective/artwork work (1.0.218)

Appearance finalization: color/alpha counts readable mismatches submitted to
validated cached-appearance recovery after standalone artwork or selective
repair. It is one bounded attempt, not a loop. Color recovery finishes with the
required alpha; an alpha-only mismatch does not rewrite colors. No name fonts,
classification, layout, timers or full restyling are part of that finalizer.

Selective repair now performs planned color/opacity writes after structural
callbacks and consumes pending artwork before reporting completion. The final
check uses fresh access/current context, ownership/cache and readable GUID
validation. Unknown/non-finite observations are not proof of mismatch and stay
subject to reconciliation retry. Converged state requires no extra setters.

The 94.4-second 1.0.218 live report contained 4,686 reconciliation checks and
11,534 checkpoints with no reported appearance drift or repair fallback.
There were 660 color finalizations. Runtime update/Urgent refresh maxima were
4.728/2.951 ms. This confirms convergence in that scene, not a matched benchmark
or acceptance of every combat/context transition.

## Profiling after diagnostic cleanup (1.0.219)

Temporary checkpoints, origin counters, audit cache fields and the native Show
audit hook have been removed. Appearance finalization: color/alpha and ordinary
Name drift/reconciliation counters remain available when profiling is enabled.
The working bounded finalizer and appearance hooks remain active during normal
play. First verify visible behavior with profiling off; capture another report
if drift, flicker or hitches return. No forced garbage collection is added.

## Interruptible effects (1.0.239)

Colors contains the interruptible color and Active switch, with default color #3300FF. Highlight (between Colors and TRP3) contains Effect (Pulsing border, Solid border, Alert border), shared Border thickness (4) and outward Border offset (3), Pulse Fade in/Fade out (0.1 seconds each), and Alert length (20–100%), shrink/grow times (0.2 seconds each), end opacity (0%) and center opacity (100%). Pulse fades all four edges between 35% and 100%; Solid is fully opaque; Alert animates centered top/bottom gradient segments with hidden sides. Both Colors and Highlight have labeled effect previews, greyed out while the interruptible Active switch is off. Reset highlight settings restores effect/geometry/timing/gradient without changing Colors color/Active; Reset color settings retains its broader reset scope. Native icon/shield hooks and spellcast events drive detection without reading secret interruptibility. Live visual acceptance remains open. See [cast-effect testing](cast-effect-testing.md).
