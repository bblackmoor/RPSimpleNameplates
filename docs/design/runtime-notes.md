# Runtime and presentation notes

Current implementation notes for 1.0.246. These details were consolidated from the user README. See [runtime evaluation](evaluation-overview.md), [settings architecture](settings-architecture.md), and [saved data](saved-data-model.md) for their respective contracts.

## Classification and presentation access

`EntityFacts.lua` collects readable identity, faction, ownership, directional attackability, interaction, and threat observations. `NameplateClassification.lua` selects the first matching category: attacking, hostile, neutral, friendly, useful, useless. PvP flags and desired War Mode alone do not establish an eligible opponent. Readable attack permissions include duels; sanctuary context prevents flag-only inference. Unknown observations remain unknown. Interaction requires NPC interaction evidence, not a vendor catalog or an inference from title/color.

`WorldContext.lua` caches zone/subzone/map, instance, territory/sanctuary, faction, desired/active War Mode, PvP/FFA flags, player combat, and lockdown on relevant events, including while styling is disabled. Location names are not permissions. `PresentationCapabilities.lua` assesses individual frames and regions and skips forbidden, unknown, or combat-restricted access.

Available bars follow profile Health Bar preferences in both combat states. Widget-only plates retain widgets and suppress actor text to avoid duplicate labels. Missing frames cannot be recolored. Restoration uses current-unit names, retains backups after failure, and retries restricted frames even while styling is disabled; recycled/replaced regions require current identity and a fresh baseline.

## Plate setup and managed settings

Startup and explicit enable review Always Show Nameplates, Enemy Unit Nameplate, Friendly Player Nameplates, Friendly NPC Nameplates, and Only Show Names (required off). Unsupported/unreadable CVars are skipped. Setup does not change the NPC Names world-label filter, stacking, realm names, or size, and compatible settings produce no dialog.

Only approved changed values are backed up, separately per character. Originals survive reload and are retained until restoration succeeds. Writes/restoration defer during combat. Failed setup changes keep styling paused with retry/disable choices; failed legacy restoration completes before another compatibility review. Settings are checked on login/explicit enable rather than continuously overwritten. Independent critter/companion hiding owns its own prior-value restoration. Friendly class-color CVars are read-only.

## Text, geometry, and artwork

- Name font defaults to Friz Quadrata, threat font to Arial Narrow; both use the selected name size, default 18. Shared font selections survive missing providers and resume when registered; missing fonts temporarily use Arial Narrow.
- Default/custom names use Inside placement; High Contrast uses Above. Bar width is 80–150%, default 120% of native width. Names inside bars retain the selected size; bars expand to leave four UI units above and three below, and restore native height when appropriate.
- Threat sits at the right edge with three units of padding. Native health labels form a chain to its left with three-unit gaps. Inside names stop three units before the combined labels. Native visibility changes update layout; restoration restores label anchors.
- Slug is on by default. Styled text uses thin outlines with either renderer; no black glyph copies or health-dependent outline threshold remain. Sanctuary font matching selects the localized native world-name face for names and NPC/TRP3 titles, preserving chosen fonts elsewhere and the separate threat font.
- Gradient opacity scales an 80%-black left endpoint to clear at 95% of full health-bar width. The final 5% is clear. A native-fill mask clips the fixed geometry as health changes; it does not read secret health values or rescale the fade to remaining health. The full-health settings preview uses Sample and illustrative 255% threat.
- Background dimming uses #999999 when on and white when off, including titles. Health/threat labels retain white outlines.
- Native decorative bar borders, shaded overlays, cast sparks/shine/glow, and the health absorb overflow edge are suppressed. Absorb fill, healing prediction, spell icons, noninterruptible shields, target/mouseover treatment, and classification badges remain native-controlled.

Cast lookup supports direct legacy fields and Retail `CastBarsContainer.castBar`, with access checks. Cast spell/target labels preserve native face and size with thin outlines and no shadows. Accessible modern fill identifiers map to classic cast-state colors. Hidden identifiers are not classified: opaque texture values are retained only for direct renderer restoration, allowing fresh live fills to be flattened. Never write native cast control fields such as `classicStyleCastBar`; the 1.0.243 approach was removed in 1.0.244 after a reported secret-value taint error. Recent live fill/tint/restoration and taint checks remain open in [live verification](live-wow-verification.md).

## Titles and threat

NPC subtitles are resolved from structured GUID hyperlink tooltip data, unit-token data, and bounded session caches. An unambiguous readable NPC-name association can reuse a fuller target/mouseover/soft-interaction subtitle; conflicting titles disable that fallback. GUID/name caches each hold up to 256 entries. Parsing accepts a single subtitle between the typed name and typed level, or a plain level verified against the localized template and readable unit level. Unavailable/restricted data omits the subtitle. A detected title does not itself establish interaction.

NPC subtitles use 80% of name size. TRP3 long titles use name size minus two; full/short/long RP fields are limited to 32/20/48 characters with ellipses. Titles fit configured bar width even without a bar. Visible or unreadable cast/channel state hides them; native hooks/retries restore them when safe. TRP3 uses cached fields and normal-name fallback; `[OOC]` replaces the short title when enabled, with no IC marker.

Threat uses WoW’s scaled pull-aggression percentage and supported text formatting, forwarding secret values without arithmetic. Missing/rejected formatting leaves text blank. Raw percentage can pin at 255 and is not used. PvP attacking classification uses available threat or targeting of the player/controlled units and is best effort.

## Cast effects and previews

Addon-owned four-edge borders implement Pulse and Solid; Alert uses only centered top/bottom gradient segments. All anchor to the native bar without dimension reads. Thickness defaults to 4, outward offset to 3 (range 0–6). Pulse fades between 35% and 100%, with 0.1-second fade times. Alert defaults to 20–100% length, 0.2-second shrink/grow times, and 0% end/100% center opacity. Native Scale animations on the half textures hold their shared midpoint and reverse shrink during growth; no Lua frame polling is needed.

Color/Active are on Colors; effect/geometry/timing are on Highlight. Both previews use the selected effect. Inactive previews are grey/dimmed and stop both animation groups; enabling resumes the selected effect. Page hide stops the preview. Reset Highlight preserves color and Active; Reset Colors resets all color/highlight preferences.

Native icon/shield visibility supplies initial interruptibility; explicit interruptibility-change events become authoritative mid-cast. Stop events clear it. Never call secrecy-wrapped `IsInterruptable()` to classify casts. Missing/unreadable state retries; preview state never classifies real casts.

## Diagnostics

| Command | Scope |
| --- | --- |
| `/rpsn debug` | Cached world context and target assessment |
| `/rpsn debug mouseover` | Hovered unit without targeting; suitable for a keybound macro |
| `/rpsn debug nearby [name]` | Existing-plate snapshot; literal case-insensitive substring filter; at most 20 matches |
| `/rpsn perf start`, `/rpsn perf stop`, `/rpsn perf report` | Session-only timing capture; see the profiling guide |

Target diagnostics distinguish direct/identity matches from readable same-name candidates and report each relevant frame once. Unrelated plates contribute only scan counts. Reports cover classification facts/winning rule, requested versus observed presentation, region visibility/alpha/geometry, cast effect state/source/hooks, restoration errors, and NPC tooltip parsing/source evidence (up to twelve lines). Existing effects are inspected without creating frames or hooks. Missing matches do not prove who owns an overhead label.

Nearby snapshots avoid direct unit lookups, classification, and tooltip collection. For disappearing names, capture while missing with no target and the mouse away. The 1.0.227 snapshot identified zero-width health bars/containers; 1.0.228 preserves width while releasing opposing anchors and supports untargeted width recovery. Its client verification remains recorded separately, not assumed from local checks.

Profiling is off by default and resets on reload. Inclusive timing rows overlap and must not be summed; aggregate memory changes do not prove a leak. The 1.0.218 crowded-scene report established appearance convergence only in that scene. Details and evidence are in [profiling](profiling.md) and [the convergence record](reconciliation-stall-plan.md).

## Presentation limits register

Record limits by entity type and context, not individual character name. Do not convert a missing frame into a claimed settings solution or extend an observation to untested entity types.

| Entity/context | Presentation unavailable | Evidence/status |
| --- | --- | --- |
| Nonattackable opposite-faction PCs in sanctuary | Native purple overhead name, guild/title color, font, size, text, and position | Silvermoon City/The Bazaar, Alliance viewer/Horde PCs, 2026-10-02: direct lookups missing and no matching accessible scan frames; unresolved |

Friendly/enemy/always-show settings were enabled and Only Show Names was tested off without yielding frames. No supported workaround was demonstrated in the [source review](nameplate-settings-review.md). This is observed behavior, not proof that no workaround can ever exist.

Resolved: duplicate widget-only and ordinary friendly service-NPC labels in Silvermoon sanctuary. Since 1.0.117, widget-only actor text is suppressed while widgets remain; ordinary NPC names/titles remain styled. Ordinary friendly NPC plates depend on Friendly NPC Nameplates being enabled.

## Dependency boundary

LibSharedMedia/CallbackHandler provide fonts and provider notifications. Details Framework minor 762 is bundled for settings widgets; neither its replacement unit/cast bars nor its border/glow constructors drive runtime plates. No texture selector or external font files are bundled. Source/license details are in [library provenance](../../RPSimpleNameplates/Libs/README.md).
