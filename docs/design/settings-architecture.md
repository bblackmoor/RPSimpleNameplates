# Settings and runtime architecture

Current architecture for 1.1.297. Saved data remains schema 2, with global behavior, character activation, and account-wide appearance profiles selected per character. Completed records are indexed in [developer documentation](../README.md); live-client checks are tracked separately.

## Settings ownership and pages

The pages are About, Profiles, Text, Colors, Cast Highlight and TRP3, in that order. All use the Details Framework widget adapter with shared layout helpers, native dialogs and yellow circled-i links. There is no Behavior page or slash route.

| Page | Current responsibility |
| --- | --- |
| About | Metadata, source link, commands, known presentation limits and read-only native-label swatches |
| Profiles | Account-wide profile management and per-character Enabled and theme import/export |
| Text | Profile fonts, Slug rendering, name size/placement, health-bar width and threat display; global critter/companion hiding |
| Colors | Six profile priority colors and Health Bar switches, background-name dimming, gradient opacity (0–100%) and complete preview |
| Cast Highlight | Activation, color, effect, shared geometry, conditional Pulse/Alert parameters, complete preview and reset |
| TRP3 | Global integration and RP-name/title/OOC preferences |

Visible pages refresh their selected-profile controls immediately; hidden pages reread on show. Profile switching cancels active previews before changing selection and refreshes plates. Native profile dialogs capture name and object identity at opening and reject acceptance after selection changes or same-name replacement. Database mutations cancel affected drafts before switching or replacing their targets.

Reset text settings on Text restores profile appearance and threat display plus global critter hiding. Reset color settings restores the selected profile's factory category colors, background dimming on, gradient opacity 100% for Default/custom profiles or 0% for High Contrast, and Health Bar preferences On except NPC - Background. There are no individual color reset buttons. Reset cast highlight settings restores only cast highlighting, including activation and color. No tab reset changes per-character Enabled or TRP3 preferences. See the [saved-data model](saved-data-model.md) for exact field ownership.

## Current source ownership

| Module | Responsibility |
| --- | --- |
| `Defaults.lua` | Factory values, bundled profiles and valid ranges |
| `FontMedia.lua` | Built-in/shared font registry, IDs, provider changes and fallback policy |
| `Core.lua` | Metadata, conflict warning and safe accessibility helpers |
| `Profiler.lua` | Off-by-default session timing wrappers and performance commands; no saved data |
| `WorldContext.lua` | Event-driven world snapshot, revision and unknown-value preservation |
| `ManagedNames.lua` | Critter CVar ownership, legacy restoration ledger and combat deferral; friendly class-color CVars are read-only |
| `NameplateSetup.lua` | Consent-based plate-visibility compatibility review and per-character restoration |
| `Database.lua` | Schema-2 field validation, profiles, character selection and scoped settings access |
| `TRP3.lua` | Optional cached RP integration with normal-name fallback |
| `EntityFacts.lua` / `NameplateClassification.lua` | Safe observations and six-category first-match priority |
| `PresentationCapabilities.lua` / `PresentationRules.lua` | Frame access and profile Health Bar presentation policy |
| `PeriodicWork.lua` | Fair due-time scheduler, shared job/time budgets and elapsed-time retry clock |
| `FontRendering.lua` | Shared thin solid outline flags for all styled plate text |
| `NameplateFrames.lua` | Region access, native geometry/restoration baselines, restricted-anchor fallback and flat-fill artwork |
| `HealthGradient.lua` | Opacity-scaled fixed 80%-black to clear-at-95% tint clipped by the native fill |
| `NPCTitles.lua` | Safe structured-tooltip subtitle resolution and bounded session caches |
| `NameplateText.lua` | Names/titles, placement, bar-height padding, cast/title visibility and cached repair |
| `NameplateThreat.lua` | Secret-safe formatted threat percentage; blank when unavailable |
| `CastHighlight.lua` | Addon-owned Pulse/Solid/Alert border lifecycle, static disabled previews, and native bar/icon/shield hooks |
| `NameplateRestoration.lua` | Original presentation restoration and deferred cleanup/retries |
| `NameplatePresentation.lua` | Full styling, focused native name/health-color repairs and data updates |
| `Nameplates.lua` | Single event frame, secure hooks, urgent refresh queues, periodic discovery and per-plate reconciliation |
| `Diagnostics.lua` | Read-only context, targeted-unit and relevant-plate reporting |
| `SettingsControls.lua` / `SettingsWidgets.lua` | Shared layout/reflow and the Details Framework widget adapter |
| `SettingsColorPicker.lua` | Native RGB session ownership, captured target, preview/commit/cancel and stale callbacks |
| `SettingsProfileDialogs.lua` | Captured profile identity and native lifecycle/restore confirmations |
| `SettingsAbout.lua` / `SettingsProfiles.lua` | About page, profile management and shared selectors |
| `SettingsBehavior.lua` | Character Enabled control and setup/restoration callbacks |
| `SettingsAppearance.lua` (Text) / `SettingsColors.lua` / `SettingsHighlight.lua` / `SettingsTRP3.lua` | Page construction, refresh and scoped user actions |
| `Themes.lua` | Versioned, allowlisted, non-executable visual theme exchange |
| `SettingsThemes.lua` | Copy/paste theme dialog with captured profile identity and combat cancellation |
| `SettingsPreview.lua` | Shared complete sample renderer and preview lifecycle |
| `Settings.lua` | Settings registration and slash routing |

## Shared settings contracts

Factories live in SettingsPanels; RegisterSettingsPanels uses explicit pageOrder and keyed categories/panels with API/factory preflight and duplicate protection. Ordinary editable pages expose panel.Refresh. SettingsControls, then SettingsColorPicker and SettingsWidgets, load before page construction; SettingsProfileDialogs loads before SettingsProfiles. Native scroll/reflow remains page-owned. See [shared conventions and coverage](settings-conventions.md) and [the completed four-phase record](addon-standardization.md).

## Runtime contracts

Classification determines priority color. Every ordinary accessible plate shows its available health bar when its category Health Bar preference is on in and out of combat; disabled/missing-bar plates use colored floating names with titles directly underneath. Disabled styling restores native presentation. Widget-only plates keep widgets while actor text is suppressed. Blizzard controls cast/channel lifecycle; a visible cast replaces the NPC/TRP3 long title below the health bar. No unknown health value is fabricated. See the [runtime evaluation](evaluation-overview.md) for the complete order.

WorldContext reads game APIs only on refresh events; its Get operation returns the cache. Presentation and repair paths assess frame access before inspecting or writing regions. Unknown and secret observations remain distinct from false. Threat percentages use the supported text formatter without addon arithmetic on secret values.

Queued refresh flags merge per unit and across all-plate requests, then run from a detached batch in the per-frame callback. Ordinary Blizzard name/color hooks use focused repair paths; invalid cached presentation falls back to full styling. Broad global refreshes, restoration, cast and pending unit/plate retries share a scheduler budget with per-plate reconciliation: at most four jobs per frame with a one-millisecond target checked between jobs. List discovery runs every 0.25 seconds; served plates become due again after 0.25 seconds. Explicit unit work and current/previous target, mouseover and interaction plates remain immediate; broad global work is coalesced into fresh per-plate jobs. Background settings/context updates settle over several frames. Restoration continues while styling is disabled. Reconciliation shares its lookup assessment through observation/repair, writes only readable differences and reuses native-label observations for changed layout. Unknown properties use elapsed-time retry deadlines of 0.25–4 seconds without blocking readable checks; unchanged plates receive no repair writes. It does not routinely reclassify every visible entity; structural invalidation can fall back to full styling. Profiling measures periodic slices, native-list discovery and individual plate jobs; it does not change scheduling settings.

## Load order and CVar safety

The `.toc` is authoritative. Bundled libraries load first, then Defaults, FontMedia, Core, Profiler, PeriodicWork and WorldContext. ManagedNames constructs the restoration allowlist before Database validates saved records; its callbacks resolve database functions after loading. NameplateSetup also loads before Database. Runtime modules follow Database/TRP3, and settings modules follow Nameplates/Diagnostics.

Critter hiding claims only its supported world-name CVar. Legacy managed-name records are restoration-only. Approved setup changes have a separate per-character backup. Failed writes retain originals, and restricted writes/restoration defer until allowed. Friendly class-color CVars are observed without mutation. Profile switches do not change plate-visibility CVars.

## Verification

Run the smoke suites and whitespace checks using [the developer commands](../README.md#local-checks). They cover real bundled libraries under UI stubs, saved-field validation, profile/reset scopes, previews/dialogs, context/access gates, uniform presentation, cast/title transitions, restoration, secret-safe formatting, lifecycle and reachable upvalue limits. Profiling has deterministic timing and actual runtime/slash coverage.

Local tests cannot establish native rendering, client frame permissions or secret-value safety. Record observations in the [live WoW checklist](live-wow-verification.md); client items remain open until observed.

## Native callback completion and live status

Native font/color/alpha setter hooks retain guarded notifications and repair the current cached appearance after guards release. Geometry callbacks restore configured dimensions without full styling. Known Retail restricted-anchor layouts use the native hierarchy/options and PixelUtil rather than relying on GetPoint; unsupported layouts remain untouched. Half a physical pixel tolerates dimension rounding where scale is readable, without weakening font/color comparisons.

Selective repairs finish color/opacity after visibility, sizing and layout callbacks, consume pending artwork, and perform one bounded validated color/alpha finalization. Standalone artwork receives the same completion check. Fresh access, context, ownership/cache and readable GUID validation gate writes; unknown observations remain for reconciliation. The finalizer adds no classification, name-font/layout work, scheduling or full styles.

The 1.0.218 crowded-scene report confirms appearance convergence in that scene. Version 1.0.219 removed temporary checkpoint/audit reads and retained the fixes. Broader normal-play, secure behavior and settings acceptance are recorded in the live checklist.

## Interruptible effects

All cast highlight controls are on Cast Highlight: activation, color (#3300FF by default), effect, shared thickness (4) and offset (3), Pulse fade times (0.1 seconds each), and Alert length (20–100%), shrink/grow times (0.2 seconds each), end opacity (0%) and center opacity (100%). Pulse and Alert sections appear only for their selected effect; Solid shows shared controls only. Hidden values are retained. Text, Colors and Cast Highlight share a complete sample preview with category selection, name/title, partial health fill, optional threat and a cast/title switch. Disabled cast highlighting dims the preview cast and stops its effect animations. Page hide stops preview animations. Reset cast highlight settings restores activation, color, effect and all border parameters; Text and Colors resets preserve them.

## Settings refresh scopes and themes

Settings request `text`, `color`, or `castSettings` work through the existing coalescing queue. Each scope permits only its owned cache differences. Text updates fonts, geometry, artwork and threat configuration; Colors updates fill/gradient/name appearance; Cast Highlight updates cast effects. Initialized frames reuse their presentation and classification. Profile changes, Health Bar switches, Colors reset and invalid/replaced cache state use full styling. These jobs retain the existing per-frame scheduler budget and priority plates.

A theme is a portable visual snapshot applied to the selected profile, not a separate selected collection. Theme fields are profile colors, health-bar preferences, gradient/dimming, appearance/threat and cast highlights. It excludes character Enabled, profile assignments/names, global visibility, TRP3 and restoration ledgers. Import/export dialogs name their captured profile. Import rejects stale selection/identity and closes on profile changes or combat. Imports refresh all plate presentation because they can change structure.
