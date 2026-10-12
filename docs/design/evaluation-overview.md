# Onscreen entity evaluation

Reviewed 2026-10-08 for 1.0.221. This document describes the actual runtime order. It does not propose a different tree or change classification behavior.

## Runtime entry and frame checks

Startup checks setting compatibility before normal styling. Events, queued refreshes, and Blizzard update hooks feed the styling path. A full `NameplatePresentation.ApplySimpleStyle` pass runs in this order:

1. Get the current world context and inspect the frame's accessibility. Return if inaccessible.
2. Return while that frame is being restored, or if its readable unit token is not a `nameplateN` token.
3. If the frame belongs to a different original unit, restore it and inspect accessibility again. Return if restoration or access is unavailable.
4. Collect entity facts and classify them using the tree below.
5. Resolve context, color, profile Health Bar preference, and presentation policy using the presentation tree below.
6. For a non-style decision, request restoration and return. For a change into or out of text suppression, restore the prior presentation first.
7. Capture original values and save the selected state/decision. A widget-only decision suppresses actor text and returns.
8. Apply ordinary bar/indicator visibility, name/title styling, supported health-bar color, threat text, and cast highlighting, in that order.

`RefreshUnit` looks up a supplied plate before this pass; missing frames are queued for later retry. Each periodic plate reconciliation can repair current cached name styling without recollecting/classifying every entity. If cache repair cannot handle drift, it invokes a full styling pass. `/rpsn debug` separately collects target facts even when no plate exists, explaining why it can report Friendly for an entity that cannot be styled.

## Facts and classification

`EntityFacts.Collect` gathers identity, ownership/control, faction/reaction, directional attack permissions, sanctuary/combat context, threats/targets, widgets-only status, and NPC interaction/title evidence. Facts can be unknown. `NameplateClassification.Classify` then checks the following questions in order, stopping at the first Yes:

```mermaid
flowchart TD
    A{"Attacking you or your controlled unit?"}
    A -->|Yes| AT["Attacking"]
    A -->|No or unknown| B{"Eligible PvP opponent?"}
    B -->|Yes| H["Hostile"]
    B -->|No or unknown| C{"Aggressive confirmed NPC?"}
    C -->|Yes| H
    C -->|No or unknown| D{"Can attack you?"}
    D -->|Yes| N["Neutral"]
    D -->|No or unknown| E{"Player character?"}
    E -->|Yes| F["Friendly"]
    E -->|No or unknown| G{"Useful NPC interaction evidence?"}
    G -->|Yes| U["NPC - Interactive"]
    G -->|No or unknown| R["NPC - Background"]
```

| Order | Test | Category |
| --- | --- | --- |
| 1 | Attacking you or your controlled unit | Attacking |
| 2 | Eligible PvP opponent | Hostile |
| 3 | Aggressive confirmed NPC | Hostile |
| 4 | Can attack you | Neutral |
| 5 | Player character | Friendly |
| 6 | Useful NPC interaction evidence | NPC - Interactive (`useful`) |
| 7 | No earlier test matched | NPC - Background (`useless`) |

A PC means an actual player character, not its pet, guardian, or minion. Player control and ownership remain separate facts. An eligible player-controlled PvP opponent can therefore enter Hostile without being a PC. Unknown identity must not become a confirmed NPC merely because the PC test is unreadable.

Faction, sanctuary, PvP flags, and desired War Mode are separate observations. An opposite-faction PC is still Friendly when no higher priority applies. Sanctuary normally removes player attack eligibility, but it does not remove NPC danger checks. Readable actual attack permission remains authoritative, including special cases such as duels. A title or friendly reaction alone does not prove that an NPC is useful. The Useless fallback means no earlier rule matched; unknown facts do not establish non-usefulness.

## Context and presentation

Classification answers what the entity is doing. Priority determines color; each category has a profile Health Bar preference. Frame access determines whether anything can actually be changed.

`PresentationRules.Resolve` retains the priority color and uses this order:

```mermaid
flowchart TD
    A{"Accessible nameplate?"}
    A -->|No| L["Skip styling; leave native presentation"]
    A -->|Yes| B{"Styling enabled?"}
    B -->|No| R["Restore Blizzard presentation"]
    B -->|Yes| W{"Widget-only plate?"}
    W -->|Yes| S["Suppress actor text; preserve widgets"]
    W -->|No| P["Apply category Health Bar preference; keep native casts"]
```

| Context | Color after classification |
| --- | --- |
| Any danger category | Its danger color, including in sanctuary |
| Sanctuary, same-faction Friendly PC | Shared Friendly color; blue (`#0000FF`) by default |
| NPC - Interactive, any context | Shared Interactive color; green (`#00FF00`) by default |
| NPC - Background, any context | Shared Background bar color; medium grey (`#999999`) by default |
| Sanctuary, opposite-faction PC | Existing category color if an accessible plate exists; native overhead label otherwise |
| Other or unknown context/identity | Existing category color; no inferred sanctuary override |

After the presentation decision, `NameplateText` chooses the effective name/title font. In sanctuary with the profile's `matchSanctuaryFont` enabled, it reads the localized `SystemFont_World` face (Friz Quadrata fallback); otherwise it uses the selected profile Name font. The same face reaches floating names, inside-bar names, and NPC/TRP3 titles. Only the face changes. Cached style repair checks that the effective face still matches before reusing a cached decision.

For ordinary plates, show available health bars only when the category's profile Health Bar preference is on, in every combat state. Color the bar by priority and keep ordinary names white; a disabled or missing health bar uses the priority color for a floating name. Background names are the exception: their profile dimming setting selects grey (#999999) or white, including inside bars; their subtitles share that shade. The first five Health Bar preferences default on and Background defaults off. Retained global category modes do not gate styling. NPC service subtitles and optional TRP3 long titles sit below the health bar, or directly below the name with a one-unit gap when the bar is off or unavailable. An active native cast/channel hides that title; native cast OnShow/OnHide hooks update visibility immediately, and unreadable transitions retry during reconciliation. Disabled styling restores native presentation. No health values are fabricated.

Startup setting compatibility is checked before enabling styling; it is a prerequisite, not another entity category. The [developer presentation limits register](runtime-notes.md#presentation-limits-register) and in-game About notes record entity types and world contexts where classification succeeds but no matching accessible frame is supplied. Individual character names are irrelevant to these limits. Missing frames must never be reported as a solved settings problem.

## Focused runtime updates

Full styling initializes a plate, applies settings/context changes, or recovers
from changed regions and invalid cached presentation. Ordinary Blizzard name and
health-color hooks use focused repairs after checking the current unit, readable
GUID, original regions, settings and context revision. A readable native name
change can refresh content/classification without bar artwork.

Queued flags distinguish classification, name/title content, threat, cast state,
layout and full styling. Flags merge per unit and with all-plate requests. The
batch is detached before writing, so synchronous callbacks enqueue work for the
next frame. Unavailable unit lookups retain work; removal discards the departed
unit's flags. Classification updates priority color/content without artwork when
the structural decision is unchanged; a category Health Bar or widget-mode
transition falls back to full styling. Threat updates configure fonts only at
setup/new label creation and update name layout when label presence changes.
Cast events synchronize highlight/title visibility without classification or
name/layout work. TRP3 callbacks request queued name content.

Each periodic plate job shares one access assessment across plate lookup,
drift observation and repair. It collects readable mismatches and writes only
their properties; changed health-label chains reuse observed labels for layout.
Structural invalidation falls back to full styling. Assessments persist only for
one operation and renew after restoration or native artwork callbacks. Text
setup/layout/restoration helpers also accept their caller's assessment.

Unreadable properties are unknown, with independent retries backing off from
0.25 seconds to four seconds; they neither establish drift nor stop other checks. Pending
unknown cast visibility keeps titles hidden and backs off similarly, while native
cast hooks and events remain immediate. Unchanged plates make no repair writes.
The scheduler puts broad global refreshes, reconciliation and deferred restoration/cast/unit/plate retries
under one due-time scheduler: at most four jobs per frame with a one-millisecond
cooperative target. Native list discovery occurs every 0.25 seconds; plate jobs
are due again 0.25 seconds after service. Explicit unit work and current/previous target, mouseover and interaction updates run immediately; broad global requests enqueue fresh per-plate jobs. Urgent event queues run first; routine
backlog can extend service intervals. Removed/recycled assignments, full refreshes
and disabling styling cancel stale routine work. Restoration stays eligible
while disabled and refreshes only the recovered unit when active. Retry deadlines
use elapsed time instead of visit counts. See the [performance plan](performance-plan.md).

## Optional profiling

`Profiler.lua` wraps full styling, fact collection/classification, NPC-title lookup, cached text repair, periodic scheduling/native-list discovery, focused name/health-color repairs, data/name-layout updates, access assessments, bar artwork, name/title styling, health-text layout, drift checks, the per-frame callback and its reconciliation scan. The report also includes full/focused styling and queued-event reasons and reconciliation drift/repair counters. `/rpsn perf start`, `stop` and `report` control session-only collection; profiling is off by default and changes no refresh cadence or saved values. Rows are inclusive and overlap. See the [profiling guide](profiling.md) for command behavior and memory/timing limits.

## Fixed health gradients

`HealthGradient.lua` fades from 80% black at the left edge to clear at 95% of the full health-bar width; the final 5% stays clear. A nearest-filtered rectangular mask anchored to the native fill clips the overlay without health arithmetic; shrinking health never rescales the tint. All styled text uses thin solid black outlines with gradients on or off. There are no glyph underlayers, health-threshold curves or health-event text-layer updates. Restoration hides all owned gradients, including retired bars.

## Finish native callback work

Native geometry/show-hide callbacks can reset appearance during a repair. Cached selective work finishes structural changes and pending artwork before planned color/opacity writes. A bounded finalizer checks completed color/alpha after selective repair and standalone artwork, using fresh access and current cache/context/ownership/readable GUID validation. It repairs readable differences through the existing appearance hooks; unknown values remain for retry. Color recovery includes required native opacity, while alpha-only recovery does not rewrite colors. This finalizer does not reclassify, rewrite name fonts/layout, enqueue timers or perform full styling.

Direct font/color/alpha setters also use guarded cached repair. Dimension recovery uses the known Retail hierarchy for restricted anchors and readable pixel-scale tolerance. Equivalent font filename spelling or flag order does not establish drift. Version 1.0.218 confirmed convergence in the recorded crowded scene; 1.0.219 removed temporary appearance audit instrumentation. Broader native acceptance remains on the live checklist.

## Interruptible effects (1.0.221)

Colors has a profile Effect dropdown with Pulsing border and Solid border, one shared Border thickness slider (default 4), pulse Fade in and Fade out (0.2 seconds each), and a labeled preview. Both use addon-owned four-edge borders anchored directly to the cast bar at zero inset. Pulse opacity is fixed at 35–100%; solid opacity is 100%. Advanced and all other effects/controls are removed. Direct icon/shield Show/Hide and cast-bar visibility changes refresh detection, hidden casts gate explicit events, and unknown active state retries conservatively. Actual cast and visual acceptance remains open. See [cast-effect testing](cast-effect-testing.md).
