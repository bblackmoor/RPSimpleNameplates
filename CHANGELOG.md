## 1.0.295 — 2026-10-12

- Update `.gitattributes`.
- Update `docs/releasing.md`.
- Update `scripts/validate_release.py`.
- Update `tests/test_release_metadata.py`.

## 1.0.294 — 2026-10-12

- Remove `Media/icon-64.tga`.
- Update `README.md`.

## 1.0.293 — 2026-10-12

- Add `.gitattributes`.
- Update `.githooks/pre-commit`.
- Update `docs/releasing.md`.
- Update `scripts/validate_release.py`.
- Update `tests/test_release_metadata.py`.

## 1.0.289 — 2026-10-11

- Retire blocked cast-highlight retries when styling or highlighting is disabled; avoid requeuing disabled work from native visibility hooks.
- Prepare commit-count versions and changelog headings together from staged metadata. Preserve explicitly prepared versions and published release notes, and reject partial staging or incomplete Git history before metadata changes.
- Use the author’s current 64-pixel icon in the addon list and check its packaged metadata.

- Complete the rename to RP Simple Nameplates: use `RPSimpleNameplates` for the addon folder, TOC filename, build artifacts and installable ZIP; update source links, display names, packaging, release checks, tests and developer paths.
- Retain `/rpsn` commands and current nameplate styling and settings behavior. Installation instructions describe a first release.

- Connect release metadata to CurseForge project 1740403 and add tag-triggered uploads of the same verified ZIP published on GitHub.
- Include the current release notes, exact supported Retail versions, and embedded-library relations in CurseForge uploads. Configure the CF_API_TOKEN repository secret to enable publishing.
- Retain the author's latest README, screenshots and icon source assets; no nameplate styling or settings behavior changes.

## 1.0.247 — 2026-10-10

- Add automated GitHub builds with pinned upstream libraries, source and packaged-addon checks, installable ZIP artifacts, and GitHub releases when matching version tags are pushed.
- Keep manual builds and ordinary commits as downloadable build artifacts. Document release steps and the remaining CurseForge project/token setup.
- Preserve the library versions and addon behavior already tested; reject packages whose runtime files differ from the bundled development copies.

## 1.0.246 — 2026-10-09

- Rewrite the README for users, following RP Emote Menu’s structure: audience/pitch, features, installation, settings, profiles, TRP3, limitations, and commands.
- Consolidate technical README material into a developer documentation entry point and runtime notes. Replace obsolete phase tasks and intermediate-build instructions with concise implementation records; retain evidence and current client checks.
- Correct stale developer descriptions of cast effects, saved-field validation, and preview behavior. No runtime or settings behavior changes.

## 1.0.245 — 2026-10-09

- Flatten fresh live cast fills even when their texture identifier is hidden and no artwork backup exists. Preserve opaque native texture values solely for renderer restoration, without inspecting cast state or writing native control fields.
- Stop Pulse and Alert preview animations when interruptible highlight is off, leaving both page previews grey, dimmed and inert. Resume the selected effect when enabled.

## 1.0.244 — 2026-10-09

- Remove 1.0.243’s writes to Blizzard’s native classicStyleCastBar field, including restoration, to avoid tainting native secret-value execution. Keep the plain-fill repair for hidden live texture identifiers.
- Add a regression guard rejecting native cast-style writes during styling and restoration. Live taint and visual acceptance require a fresh UI session.

## 1.0.243 — 2026-10-09

- Keep cast fills plain when live enemy cast texture identifiers are hidden. Use the native classic cast-color path and repair saved fills without requiring a readable current atlas; restore the original cast style when styling ends.

## 1.0.242 — 2026-10-09

- Label the page reset buttons Reset text settings, Reset color settings and Reset highlight settings. Preserve their existing reset behavior.

## 1.0.241 — 2026-10-09

- Set the shared border offset default to 3 UI units outward. Preserve valid saved offsets; resets and missing/invalid values use 3.

## 1.0.240 — 2026-10-09

- Grey and dim both interruptible effect previews when the Colors Active switch is off; restore the selected highlight color and normal brightness when enabled. Apply the same behavior to Pulse, Solid and Alert previews without changing live cast colors.
- Remove the explanatory text beneath the shared preview on Colors and Highlight.

## 1.0.239 — 2026-10-09

- Rename the Appearance tab to Text; add Highlight between Colors and TRP3, with `/rpsn text` and `/rpsn highlight` routes. Keep `/rpsn appearance` as an alias.
- Keep interruptible color/Active on Colors; move effect, shared thickness/offset, Pulse and Alert settings to Highlight. Both pages have previews. Highlight has a selected-profile control and a scoped reset preserving color/Active.
- Default Pulse Fade in/Fade out to 0.1 seconds each, and factory interruptible color to #3300FF. Preserve valid saved timing/color choices; Alert timing remains 0.2 seconds each way.
- Preserve profile-switch, page-hide and combat draft cancellation for moved controls; update current documentation and UI regression coverage.

## 1.0.238 — 2026-10-09

- Fix Alert growth snapping: later Scale orders compound with the completed shrink, so grow from identity to maximum/minimum to reverse the shrink and return continuously to the maximum length.
- Add shared Border offset (0–6 UI units, default 2 outward) for Pulse, Solid and Alert, reducing overlap with the cast fill without changing thickness.
- Add regression coverage for composed growth, loop continuity, custom maximum lengths and outward anchoring.

## 1.0.237 — 2026-10-09

- Restore Pulsing border as the original four-edge opacity pulse (35–100%, Fade in/Fade out defaulting to 0.2 seconds).
- Add the gradient length pulse as the separate Alert border effect. Hide its side borders and keep centered top/bottom segments with fixed thickness.
- Add Alert settings below Pulse settings; default Alert minimum length to 20%. Keep maximum length 100%, shrink/grow times 0.2 seconds, end opacity 0% and center opacity 100%, with shared thickness 4 and magenta default color.
- Keep current valid settings in place; discard obsolete length/gradient values under PULSE without migrating them into ALERT.

## 1.0.236 — 2026-10-09

- Fix Pulse shrinking toward corners: animate each gradient half-texture directly around its shared opaque midpoint (horizontal RIGHT/LEFT pivots; vertical TOP/BOTTOM pivots), rather than scaling the containing edge frame.
- Both halves now stay joined at the center while transparent endpoints move inward/outward. Keep all 1.0.235 settings, constant thickness and magenta defaults.
- Add geometric regression coverage for all four edges and multiple pulse lengths; live rendering confirmation remains pending.

## 1.0.235 — 2026-10-09

- Replace Pulse’s opacity animation with centered gradient segments that shrink/grow along each edge while thickness stays constant. Native synchronized Scale animations follow anchored geometry without reading cast dimensions or using per-frame Lua polling.
- Add Colors controls for minimum/maximum edge length (10%/100%), shrink/grow time (0.2 seconds each), and gradient end/center opacity (0%/100%). Keep shared thickness at 4 and Solid fully opaque/full length; update the preview and layout.
- Set the default interruptible color to magenta #FF00FF for Default, High Contrast and new custom profiles. Keep valid saved colors. Discard retired fadeIn/fadeOut timings without migration; retain valid current parameters and default missing/invalid values.

## 1.0.234 — 2026-10-09

- Repair cast fills after native texture/state changes while the bar is already visible, using the actual status-bar texture rather than a potentially stale alias.
- Convert accessible modern cast atlases to flat fills using Blizzard’s classic cast-state colors, preserving yellow casts, green completion/channels, gray non-interruptible casts and red interruptions.
- Suppress native cast sparks, shine and glow; keep spell icons, non-interruptible shields, progress and the configured interruptible border. Restore native artwork/tint when styling ends.

## 1.0.233 — 2026-10-09

- Revert only 1.0.232's native-name text clearing: retain native name content and suppress its duplicate display using the previous opacity behavior.
- Keep the 40-unit gradient slider/preview gap and all earlier width-preservation/recovery fixes.

## 1.0.232 — 2026-10-09

- Clear native name glyphs while the addon inside-bar name is displayed, preventing residual native text/outline behind it. Native text callbacks, reconciliation and bounded finalization preserve the empty native region; the addon label keeps the complete name and normal restoration restores the native unit name.
- Double the gradient slider/preview gap again, from 20 to 40 UI units.

## 1.0.231 — 2026-10-09

- Double the gap between the Gradient opacity slider and preview from 10 to 20 UI units.

## 1.0.230 — 2026-10-09

- Remove the current percentage readout between the gradient slider and preview. Move the preview to the original control column and the slider between the Gradient opacity label and preview; retain the slider's 0%/100% endpoint captions.

## 1.0.229 — 2026-10-09

- Move the full-health gradient preview beside the Gradient opacity slider and remove its separate label/row.
- Apply the slider directly to the left gradient endpoint: 100% means 80% black, 50% means 40% black, and 0% hides the tint. Texture opacity stays full; the linear fade still reaches clear at 95% of full bar width and uses native fill clipping.

## 1.0.228 — 2026-10-09

- Fix zero-width health bars/containers when height-only styling releases Blizzard's opposing native anchors. Preserve readable positive width before clearing those anchors; leave unmeasurable native geometry intact for later retries.
- Track released-anchor widths in reconciliation even at 100% bar width, so collapsed bars recover without targeting. Configured width scaling remains authoritative and original native anchors restore when styling ends.
- The 1.0.227 failure-state snapshot showed accessible/shown/opaque hostile NPC plates with both health-container and bar width zero. Added a regression fixture where clearing native anchors collapses width, covering initial/repeated styling, untargeted recovery, convergence, restoration and zero-width initialization.
- All 23 smoke suites pass. Live confirmation of the width fix remains pending.

## 1.0.227 — 2026-10-09

- Add `/rpsn debug nearby [name]` to capture disappearing names before target/mouseover refresh can conceal the failed state. Enumerates existing plates directly without direct unit lookup, classification, tooltip collection or presentation writes.
- Reports shown/visible state, local/effective alpha and dimensions across the base plate, unit frame, health container/bar, native name, inside name and additional inside-name ancestors. Deduplicates frames and bounds output to 20 matches.
- All 23 smoke suites pass, including read-only failure preservation, inherited alpha reporting and literal name filtering.
- The reported hostile NPC disappearance persists after 1.0.226. Its cause remains unconfirmed; this build collects the missing failure-state evidence rather than changing additional native fades without evidence.

## 1.0.226 — 2026-10-09

- Recover readable health-bar, health-container and inside-name opacity resets, including native distance/detail transitions that leave regions shown but transparent. Bar/container show, hide and alpha callbacks repair immediately; periodic reconciliation also covers native changes that bypass Lua hooks.
- Keep whole-plate/unit-frame fades Blizzard-controlled. Restore captured native bar/container alpha when styling ends; restricted values remain deferred.
- Diagnostics now includes local and effective alpha for addon name/title regions. Added untargeted opacity recovery, convergence, immediate callback and native restoration regression coverage.
- All 23 local smoke suites pass. Live verification of the reported disappearing hostile NPC names remains pending.

## 1.0.225 — 2026-10-09

- Replaced the Colors gradient toggle with a profile Gradient opacity slider from 0 to 100%. Zero hides the tint, 100 preserves the existing gradient, and intermediate values scale opacity while preserving fade position, native fill clipping and text outlines.
- Defaults and Colors reset use 100% for Default/custom profiles and 0% for High Contrast. Valid current values survive copies/reloads; removed toggle values are discarded without conversion and invalid opacity values use defaults.
- The full-health preview updates immediately. Unfinished typed/drag opacity edits cancel on combat entry, page hide, reset and profile changes.
- All 23 local smoke suites pass, including partial opacity, geometry/clipping preservation, persistence/defaults and combat cancellation. Native-client visual verification remains pending.

## 1.0.224 — 2026-10-08

- Removed Soft border, Marching ants, Spell-alert glow, their settings, and the Advanced page/routes.
- Colors now contains a shared Border thickness slider (default 4 on all sides) and pulse Fade in/Fade out (0.2 seconds each). Both remaining effects use four edges anchored directly to the cast bar, with zero inset/offset; solid has full opacity and pulse ranges from 35% to 100%.
- Imports valid current values in place, discards removed/invalid settings, and supplies defaults for the rest. Removed the legacy cast-style activation conversion. Colors reset restores border defaults.
- Updated renderer, saved-data, settings and combat cancellation coverage. Live-client alignment and appearance verification remain pending.

## 1.0.223 — 2026-10-08

- Added a profile-scoped Advanced tab with sliders and switches for five cast effects: pulse thickness/inset/opacity/timing, solid thickness/extension/distance, three-layer soft border spread/opacity/visibility, marching-ants speed/distance/frame count/opacity, and spell-alert extent/position/opacity.
- Added five previews, reset, validation, persistence, and combat edit cancellation. The Colors page continues to control cast color, effect selection, and activation.
- Marching-ants dash length/spacing and spell-alert template timing and intrinsic texture thickness remain fixed. Live-client acceptance is pending.

## 1.0.222 — 2026-10-08

- Entering combat cancels unfinished RGB/typed-slider/slider-drag previews, closes dropdowns and profile dialogs, restores controls from saved values and disables settings changes across pages. Completed edits remain saved.
- Combat exit restores normal editing while preserving profile protections and TRP3 dependencies. Retained cancelled picker/dialog callbacks remain inert; direct callbacks also check current combat/lockdown. Debug/perf remain available.
- Added combat lifecycle coverage using actual bundled DF controls. All 23 local smoke suites pass; native client verification remains open. Updated settings and live-testing documentation.

# Changelog

Entries describe their recorded releases; later fixes and the current guides supersede older controls, defaults and pending investigations.

## 1.0.221

* Adds a profile Effect dropdown on Colors: Pulsing border, Solid border, Soft border, Marching ants and Spell-alert glow. Keeps the separate Active switch and adds a labeled always-demonstrative preview to separate renderer checks from real cast detection. Effect copies/reloads and survives Appearance reset; Colors reset restores pulse without enabling Active.
* Uses the existing Details Framework border/ants/glow constructors without adding dependencies or inspecting native cast dimensions. Unavailable renderers/templates visibly fall back to pulse and expose the reason in debug. Owned ants animation handles Midnight clients lacking AnimateTexCoords; effects stop/reuse on disable, cast end and selection changes.
* Covers native icon/shield SetShown/Show/Hide and cast-bar visibility callbacks. Hidden cast bars gate explicit event state; unknown initial interruptibility retries without assuming an interruptible cast. This fixes reproduced callback gaps, not a proven explanation of every missing live highlight.
* Expands targeted diagnostics and adds a repeatable enemy/preview test guide. All 22 local smoke suites pass, including actual bundled DF effect construction, lifecycle/fallback, native callback recovery, saved defaults and Colors selection/reset. In-game verification remains pending.

## 1.0.220

* Reviews all repository documentation against the current source. Corrects category Health Bar ownership/defaults, background-name dimming, cast pulse activation, saved compatibility conversion, reset scopes, load order, broad-refresh scheduling and removed library references.
* Replaces obsolete live checks with a current acceptance matrix; preserves the versioned investigation history and records 1.0.218 convergence without claiming an exact FPS improvement or complete native acceptance. Marks earlier implementation/conversion plans as historical and links current authoritative guides.
* Corrects the Colors reset explanation: gradients reset On for Default/custom profiles and Off for High Contrast. Documentation/help text and version metadata only; runtime behavior and schema remain unchanged.
* All 21 local smoke suites, documentation-link checks and whitespace checks pass. Broader normal-play, settings, combat/context and native secure acceptance remain open.

## 1.0.219

* Removes the temporary appearance checkpoint reads, native Show audit hook, cached audit fields, origin counters and profiler session tokens introduced in 1.0.217. Retains the validated appearance finalizer, setter hooks, deferred repairs and ordinary profiling counters.
* Records the 94.4-second 1.0.218 live report: 4,686 reconciliation checks and 11,534 checkpoints with no reported appearance drift or repair fallback; 660 color finalizations caught resets at completion. Runtime update/Urgent refresh maxima were 4.728/2.951 ms. This confirms convergence in the tested scene; broader normal-play verification remains pending.
* All 21 smoke suites pass, including visibility-callback and standalone-artwork reset regressions, unknown/stale/inaccessible sources, alpha-only recovery and failed-write guard recovery.

## 1.0.218

* Finishes selective color/vertex/alpha writes after visibility, dimensions and label layout callbacks. Color repair also restores native opacity if a readable post-color alpha differs. Consumes pending artwork before selective repair reports completion, so trailing artwork cannot silently undo that repair.
* Adds one bounded cached-appearance finalization after standalone artwork and selective repair. Fresh access/cache/context/ownership/readable GUID checks gate recovery through the existing validated color or alpha hook; it performs no name font writes, classification, layout, timers or full styling. Unknown/non-finite observations remain for reconciliation. Converged appearance needs no extra setters; color recovery includes alpha and alpha-only recovery avoids color writes. Error/reentry guards are released on failure.
* Adds Appearance finalization: color/alpha counters. Retains the profiling-only completed-state checkpoints so the next live report can verify the operation now ends with the intended appearance. Scheduler budgets are unchanged.
* Records the 118.4-second 1.0.217 report: all 551 white-to-grey color first mismatches were present after cached repair; 170 alpha observations were present after cached repair. Artwork/cached-repair checkpoints each recorded 618 color and 185 alpha failures, with no reported full-style/name-hook checkpoint failures. Runtime update/Urgent refresh maxima were 2.986/1.724 ms. These locate failed operation boundaries, not the exact native writer; live confirmation of this fix remains pending.
* All 21 smoke suites pass. A visibility-callback regression fails against 1.0.217, and an independent artwork-reset regression fails with the old artwork completion path. Tests cover pending-artwork convergence, alpha-only and no-op recovery, unknown/non-finite observations, disabled/restoring/forbidden/recycled/stale-context sources and failed-write guard recovery.

## 1.0.217

* Adds profiling-only, read-only native-name appearance checkpoints after full/focused updates, cached repair, standalone artwork, appearance setter repair and native Show calls. Each uses fresh access, current cache/context/ownership and readable GUID checks; guarded, restoring, disabled, inaccessible or stale-source calls are skipped. They observe completed text RGB and native alpha without applying another repair.
* Adds Appearance checkpoints, Appearance checkpoint drift/unreadable, and Name color/alpha origin rows. Reconciliation now distinguishes mismatch present at the last checkpoint from mismatch after a verified checkpoint, or unavailable evidence. Unreadable/non-finite values are unknown. These checkpoints narrow timing boundaries, not the exact engine writer.
* Uses a small opaque per-session token rather than retaining profiling records from frame caches. Restarts and rebuilt presentation intent invalidate previous observations. Disabled checkpoints return before frame inspection, UI reads or measurement allocations. Profiling overhead increases while enabled; scheduler/repair behavior is unchanged.
* Records the 1.0.216 report: all 504 sampled text-color mismatches were white (1.000/1.000/1.000) versus intended background grey (0.600/0.600/0.600), with 131 native-alpha first mismatches. Runtime update/Urgent refresh maxima were 4.231/1.976 ms; memory increased 61,646.8 KiB versus 299,053.5 KiB in the previous report. No alpha/deferred appearance counter appeared. Runs are not matched benchmarks and do not prove the native writer or a retained-memory leak.
* All 21 smoke suites pass. Coverage exercises native Show callbacks, complete full/focused update boundaries, post-update resets, read-only observation, unknown/non-finite values, disabled measurement work, stale/recycled/forbidden/restoring/guarded sources and session restart/token isolation. Native diagnosis remains pending.

## 1.0.216

* Repairs direct native SetAlpha writes against the current cached presentation, retaining guarded alpha notifications for readable checks after styling/artwork completes. Inside and widget-only native names remain concealed; above-bar names remain opaque. Appearance color/font repairs now finish with the required native-name opacity after color setters. Identity, context, access, disabled styling and restoration checks still gate writes; restoration clears pending alpha.
* Adds at most eight distinct readable Name color drift RGB samples plus an overflow counter during profiling. These diagnose the unresolved live color changes without unit identities, unrestricted reads or formatting while profiling is disabled.
* Removes the per-field temporary closure from conservative access checks, preserving pcall error handling and secret/forbidden/protected checks. The manual capabilities allocation benchmark reports 65,079.8 -> 12,579.8 KiB allocated for 10,000 simulated assessments with GC paused under texlua (about 81% less). This measures allocation pressure in that fixture, not live WoW retained memory or a proven leak.
* Records the latest 1.0.215 report: Runtime update maximum 4.493 ms, Urgent refresh maximum 2.372 ms, 525 text-color and 162 inside native name alpha first mismatches, 687 cached repairs and no reported geometry drift or reconciliation full-style fallback. No deferred-color counter was reported; the remaining text-color source is unconfirmed.
* All 21 smoke suites pass. Direct-opacity regression fails against 1.0.215; a second regression fails if post-color opacity restoration is removed. Coverage includes guarded and converged writes, inside/above/widget presentation, recycled/disabled/forbidden/restoring frames and bounded profiler color samples. Native confirmation remains pending.

## 1.0.215

* Retains native text/vertex color writes made while styling or artwork guards are active. On guard release, checks the completed readable color against the current cache and repairs a mismatch through the existing identity/access/restoration-validated appearance hook. Converged addon writes require no extra setters; color-only recovery does not rewrite fonts. Restoration clears the pending color flag.
* Splits the ambiguous inside-name visibility drift counter into inside native name alpha and inside label visibility. Adds Name appearance deferred: color repair for guarded color recovery. This identifies which part of the live visibility drift needs further work.
* Records the 97-second 1.0.214 profile: Runtime update maximum 5.323 ms and Urgent refresh maximum 3.198 ms, down from 21.265/20.085 ms in the prior report. No reported geometry drift or reconciliation full-style fallback. There were 528 text-color, 136 inside-name visibility and four suppressed-alpha first mismatches. These runs are not matched benchmarks; the exact source of all live color/visibility writes remains unconfirmed.
* All 21 smoke suites pass. The guarded-color regression fails against 1.0.214. Coverage includes nested visibility callbacks, green-channel-only drift, text/vertex recovery, artwork guards, no font rewrites and no redundant repairs after converged own writes. Native confirmation is pending.

## 1.0.214

* Moves broad global refreshes (including settings, callbacks and login passes) into per-plate jobs sharing the existing four-job/one-millisecond cooperative scheduler. Current and previous target/mouseover/interaction plates and explicit unit requests remain immediate. A running plate operation cannot be interrupted; immediate priority work is outside the periodic budget.
* Coalesces full/focused global work, merges pending global flags into immediate unit updates and cancels duplicate jobs. Each deferred job reads fresh context/access and validates assignment, unit generation, native lookup and readable GUID. Removal, missing snapshot entries, disable and newer full refreshes cancel stale work. Failed writes retain flags and the original error for bounded retries.
* Adds Global plate refresh timing and Periodic jobs: global refresh counters. Global refresh now times discovery/enqueueing plus immediate priority work, rather than styling every plate synchronously. Global refresh plates still counts actual full/focused visits.
* Records 1.0.213 live confirmation: no reported geometry drift or reconciliation full-style fallbacks; 571 full styling calls and 501 cached repairs over 95.3 seconds. Urgent/global maxima were 20.085/20.080 ms. Broad batches are the next measured target; this patch still needs live timing confirmation. The 440 text-color reconciliation repairs remain a separate investigation.
* All 21 smoke suites pass. New and updated regressions cover pacing, convergence, current/previous target priority, unit/global merging, stale GUIDs, removal/snapshot cancellation, disable and error recovery. The paced-settings regression fails against 1.0.213.

## 1.0.213

* Treats readable native health-bar/container visibility differences as selective repair work rather than invalid cache identity. Reconciliation can restore bar, container and inside-name visibility together without classification, font writes, name/title styling or full restyling. Unknown visibility remains subject to the existing retry backoff; identity, context, region and access checks are retained.
* Adds a native bar OnHide hook using the current validated presentation to restore required bar/container visibility immediately. Disabled styling, restoration, inaccessible frames, suppressed presentations and retired source bars are skipped. Replacement bars receive their own hook without duplicating existing hooks.
* Records the 1.0.212 live report: 4,495 reconciliation checks, 402 visibility-driven full-style fallbacks, 81 cached repairs, six width-first mismatches, 543 initial and 403 late reuse counters, and a 19.472 ms urgent-refresh maximum. Native confirmation and the remaining urgent spike stay open; scheduler behavior is unchanged.
* All 21 smoke suites pass. The new combined-visibility regression fails against 1.0.212 and covers convergence, native hide callbacks, intentionally hidden bars, unreadable visibility, disabled styling, access restrictions and restoration.

## 1.0.212

* Repairs cached bar dimensions immediately after native UpdateAnchors, without classification, fonts, name/title styling or full restyling. Current settings, identity, context and access checks still gate the hook; synchronous updates during styling/artwork are retained and serviced after their guard releases.
* Uses half a physical pixel of tolerance for bar/container dimensions where pixel factor and effective scale are readable. Font, color and other comparisons retain their strict tolerance.
* Reuses a valid presentation if a native lookup already initialized the plate through the name hook. The initial and half-second late passes use focused data updates; missing or stale caches still receive full styling. Generation checks prevent old delayed callbacks from updating recycled unit tokens.
* Adds Geometry hook repair and Global refresh timing rows, Initialization reuse counters, Global refresh plates counts, and Urgent batches counts. The 94.2-second 1.0.211 report had cached repairs on 464 of 4,236 checks, with a 27.196 ms urgent-refresh maximum. Native confirmation and that spike remain open; scheduler limits are unchanged.
* All 21 smoke suites pass, including native geometry callbacks, rounding versus real geometry/font drift, pending callback handling, initialization reuse, cache fallback and delayed-token recycling. New regression coverage fails against 1.0.211.

## 1.0.211

* Fixes anchor preparation on Retail nameplates whose GetPoint cannot be queried. Uses the known Blizzard HealthBarsContainer/CastBarsContainer hierarchy and NamePlateSetupOptions with PixelUtil to release opposing anchors and restore native modern/classic offsets. IsAnchoringRestricted bypasses GetPoint; a failed getter can use the same validated layout fallback. Unknown hierarchies remain untouched.
* Adds regressions for throwing GetPoint, restriction predicates, width/height convergence, native anchor resets, classic offsets, full restoration, default sizing and unsupported layouts. The regression fails on 1.0.210.
* Records the 84.4-second 1.0.210 live report: 10,436 point-getter failures and 3,806 cached reconciliation repairs. Native sizing and runtime timing acceptance remain pending; scheduler limits and name-color rules are unchanged.

## 1.0.210

* Adds opt-in Bar anchor preparation counters explaining successful anchor release or a skipped preparation: unreadable count/point/offset/relative frame, inaccessible relative frame, differing relatives, unsupported layout or unreadable height. Geometry writes and the scheduler are unchanged; the next live report can distinguish preparation skips from repeated native anchor resets.
* Records live confirmation that 1.0.209 stopped NPC blinking. The new 83.8-second report still shows a cached repair on all 3,565 reconciliation jobs: widths near 258 remain below the requested 309, with two anchors present. Size-loop acceptance remains open.

## 1.0.209

* Fixes a reproduced grey-to-white reconciliation path: a vertex-color repair now always finishes with the configured text color. Calibrates the expected vertex getter after styling instead of assuming a separate white channel, so shared text/vertex color state does not create perpetual false drift. Classification and background dimming rules are unchanged. Live blinking acceptance remains pending.
* Adds a regression that fails on 1.0.208 when a FontString exposes shared text/vertex color state, plus convergence checks for external color changes. Retains coverage for independent color channels.
* Adds bounded, opt-in Name size drift samples showing observed/requested dimensions and anchor count. The new 74.6-second live report still repairs dimensions on all 3,680 reconciliation jobs; the prior sizing change did not resolve that loop. Size behavior remains unchanged pending these measurements.

## 1.0.208

* Fixes a remaining immediate name-color repair gap: native bar visibility or geometry no longer vetoes cached grey/color repair. Current access, assignment/identity, context and presentation are still checked. Native confirmation of the reported blinking remains pending.
* Makes configured health-bar width and inside-name height effective on native bars with two opposing anchors. Captures the original corner/edge anchors, uses a centered single anchor while sizing, and restores native anchors at default sizing or full restoration. Reconciliation reapplies sizing after native anchor resets and converges instead of endlessly writing ineffective dimensions. Restricted or unrecognized anchor layouts remain untouched.
* Ignores raid/party and cleared-unit frames in global CompactUnitFrame repair hooks instead of treating them as uninitialized nameplates. Genuine nameplate initialization still falls back safely.
* Adds regressions for color repair during native visibility changes, anchor-constrained sizing, convergence after native resets, original-anchor restoration and unrelated-frame hooks.

## 1.0.207

* Repairs direct native name font, font-object, text-height, text-color and vertex-color writes immediately using the current cached appearance. Background names retain their intended grey without waiting for periodic reconciliation; category rules remain unchanged. Setter hooks avoid classification, layout and full styling, skip addon writes/restoration, and validate access, assignment and readable identity. Native confirmation of the reported flashing remains pending.
* Compares font paths without slash/case differences and font flags as unordered token sets. Equivalent native getter results no longer create repeated font drift; different faces, sizes and outline/rendering flags still repair.
* Adds font-drift component counters, explicit focused-cache invalidation reasons, direct name-appearance write counters and an inclusive Urgent refresh timing row. Legitimate structural fallbacks remain; the next report can identify their actual reasons. Scheduler limits are unchanged.
* Adds regression coverage for direct native appearance writes, recursion/error guards, normalized font getters, distinct outlines, disabled/restoring/inaccessible regions and recycled identity.

## 1.0.206

* Adds a detailed reconciliation-stall follow-up plan (phases 5–8), with build verification, matched screenshot recordings, conditional diagnostics, measured fixes and live acceptance gates.
* Records that the October 8 screenshot lacks current profiler rows/counters and does not confirm post-phase-4 performance. Older all-plate reconciliation averages cannot be compared directly with current per-plate averages.
* Links the plan from README, the original performance plan and the profiling guide. Documentation only; runtime behavior remains unchanged from 1.0.205.

## 1.0.205

* Implements performance phase 4 of 4: routine per-plate reconciliation, deferred restoration, cast recovery and pending unit/plate retries share a fair scheduler with at most four jobs per frame and a one-millisecond cooperative time target. A native list snapshot discovers plates every 0.25 seconds; each served plate becomes due again after 0.25 seconds.
* Flushes urgent event updates before periodic work. Jobs obtain fresh context/access, validate current assignments and cancel departed/recycled work; full refreshes and disable/reset invalidate routine queues. Restoration stays eligible while styling is disabled and refreshes only the recovered unit when active.
* Converts unreadable-property and cast/title backoff from visit counts to elapsed-time deadlines (0.25–4 seconds). Cast hooks/events bypass backoff; actual retry service can lag a deadline under load. No assessments or property observations persist between jobs.
* Adds Periodic work and Plate discovery timings plus job/limit counters. Reconciliation now measures one plate job, so older all-plate call counts/averages are not directly comparable.
* All 21 smoke suites pass, including scheduler count/time limits, fairness, cancellation, callback failures, crowded runtime queues, urgent updates, recycling and disabled restoration. All four performance code phases are implemented; in-game FPS, rendering and secure acceptance remain pending. The initial budget awaits live tuning and cannot preempt one expensive UI operation.

## 1.0.204

* Implements performance phase 3 of 4: reconciliation shares one operation-local access assessment across lookup, observation and selective repair. Text setup and restoration helpers also reuse their caller's assessment; restoration/region changes renew it.
* Collects readable differences and writes only affected text, font, shadow, color, visibility or dimensions. Unchanged scans make no repair writes. Native label-chain changes reuse their observations and update only layout, without a full-style fallback.
* Treats unreadable properties as unknown and backs off retries to at most sixteen reconciliation passes; independent readable differences still repair. Unknown cast visibility keeps titles hidden without repeat writes, while native cast hooks and events remain immediate.
* Adds setter/read-count regressions for unchanged scans, isolated/combined differences, unknown-value recovery, layout reuse, stale assessments and write failures. Reconciliation remains on its 0.25-second cadence; live FPS/secure acceptance and phase 4 remain pending.

## 1.0.203

* Implements performance phase 2 of 4: native name and health-color hooks use focused repairs; ordinary hooks no longer collect entity facts, resolve titles, or reapply bar artwork. Invalid cache/settings/context, changed regions and presentation structure retain safe full-styling fallbacks.
* Coalesces classification, name/title, threat, cast and layout work per unit and across global requests. Preserves work queued by synchronous callbacks and blocked unit lookups; removal discards departed-unit work. TRP3 callbacks queue content updates.
* Separates threat values from font setup and updates name space only when threat/native-label presence changes. Cast events update highlight/title visibility without unrelated classification or layout.
* Preserves native restoration baselines for replaced name regions and native artwork callbacks during focused writes; adds focused-path timings, counters and regression coverage. Thin solid outlines and the 95% gradient endpoint are unchanged.

## 1.0.202

* Implements performance phase 1 of 4: all styled names, titles, threat, native health and cast labels use thin solid outlines. Removes black glyph copies, their synchronization hooks, the threat health-threshold curve, and its health-event/reconciliation updates. Gradient geometry remains unchanged.
* Adds optional timings for access assessment, artwork, name/title styling, health-text layout and drift checks. Chat-only reason counters identify styling triggers/outcomes, queued events, first-observed drift and cached/full-style reconciliation repairs. Disabled profiling allocates no measurement records.
* Updates outline/restoration, preview, gradient, profiler lifecycle and runtime diagnostics checks and records the remaining performance phases.

## 1.0.201

* Extends the linear health gradient from 80% black at the left edge to clear at 95% bar width; the final 5% stays clear. The settings preview matches. Threat percentages retain their existing 80% health threshold for black glyph copies.

## 1.0.200

* Fades the health gradient linearly from 80% black at the left edge to clear at 80% bar width; the final 20% stays clear. Applies to health bars and the settings preview while preserving native health clipping and threat-underlayer behavior.

## 1.0.199

* Lightens the health gradient’s darkest left edge from 90% black to 80% black, including the settings preview. Preserves the fade to 55% black at 80% width and to clear at the right edge.

## 1.0.198

* Repairs cast-highlight test fixtures by creating the real pulsing border with animation-capable UI stubs. Updates profile, settings, and loader checks for the Active switch and removal of the four library effects.
* Fixes pulse-test native visibility restoration and resets its cast-stop state before testing another cast. Supplies scaled threat in the replacement-label fixture instead of leaving only raw threat available.
* All 21 local smoke suites pass, including title dimming and cast pulse integration. No production behavior changes beyond the version metadata.

## 1.0.197

* Makes subtitles beneath dimmed background NPC names use the same grey as the name. Turning dimming off restores white titles; other categories retain white titles.

## 1.0.196

* Displays only WoW's scaled threat percentage instead of preferring raw threat percentage, preventing the label from sticking at the raw 255% cap while the player is tanking.
* Removes the cast highlight's call to Midnight's secrecy-wrapped `IsInterruptable()`. Spellcast interruptibility/start/stop events now trigger nameplate refreshes; the initial state comes from Blizzard's already-rendered cast icon/shield, while explicit interruptible/not-interruptible events become authoritative for subsequent changes.
* Keeps the geometry-independent pulsing border and its existing Active/color settings; adds coverage for interruptible/not-interruptible events, Modern icon state, Classic shield state, restricted native state, and geometry independence.


## 1.0.195

* Places the interruptible-cast **Active** label and switch on the same row as its color swatch, using the same label and toggle spacing as the Priority Color health-bar controls.


## 1.0.194

* Removes the four LibCustomGlow interruptible-cast effects and their selector. Interruptible casts now use the addon-owned pulsing border, which is anchored to Blizzard's cast bar without reading restricted width or height.
* Replaces the effect selector with a per-profile Active switch on Colors. Existing profiles with any retired effect selected remain enabled; None remains inactive. Reset all colors disables the highlight.
* Stops loading LibCustomGlow for Simple Nameplates and updates the documentation for the single reliable cast-highlight path.

## 1.0.193

* Hides Blizzard’s bright right-edge absorb overflow glow on styled health bars, supporting native bar-owned and legacy frame-owned regions. Preserves absorb fill, healing predictions, and threat/gradient behavior; restores the original glow alpha when styling ends.

## 1.0.192

* Defaults health-bar name placement to Inside for Default and new custom profiles, Above for High Contrast. Missing/invalid placement and Appearance reset use the active profile’s default. Existing saved choices and profile copies are preserved.

## 1.0.191

* Defaults gradients to On for Default and new custom profiles, Off for High Contrast. Missing/invalid settings and Colors reset use the profile default; existing saved choices and profile copies are preserved. Appearance reset and threat-percentage behavior are unchanged.

## 1.0.190

* Constrains NPC subtitles and TRP3 long titles to the configured health-bar width even when the bar is hidden. Native single-line font layout truncates overflow; the source text is retained so widening restores more text. Cached repair follows width changes.
* Defaults health-bar width to 120%, including new profiles and Appearance reset. Existing saved width choices remain unchanged.

## 1.0.189

* Matches the requested Default palette: red #FF0000, orange #FF6600, yellow #FFCC00, blue #0000FF, green #00FF00, grey #999999. Health bars default On except NPC - Background; background-name dimming defaults On. Existing saved choices are preserved; missing/invalid values and Colors reset use the new defaults. High Contrast retains its separate palette.
* Removes the background-category fallback note. Applies a thin black outline to all styled plate text, including inside-bar names, threat percentages, native health labels and preview text, with Slug either On or Off. Existing gradient/underlayer visibility rules are preserved.

## 1.0.188

* Adds the per-profile Dim background NPC names toggle below NPC - Background on Colors, off by default. Background NPC names use #999999 when On and #FFFFFF when Off, above or inside bars and when their bar is disabled. Titles, threat text and bar colors are unchanged.
* Persists and copies the setting; Reset all colors disables it while Reset Appearance preserves it. Verifies settings refresh/reset, persistence/validation, name placement and cached repair.

## 1.0.187

* Renders TRP3 long titles and NPC subtitles in white with a thin black outline, independently of category color. Slug follows the selected profile.
* Preserves title size, position, and cast-driven visibility; verifies white titles across categories and NPC tooltip sources.

## 1.0.186

* Defaults Slug rendering to On for new profiles, missing/invalid settings, and Appearance reset. Existing saved On/Off choices remain authoritative.
* Uses thin outlines for outside-bar names, titles and cast labels with Slug either On or Off. Inside-bar text, gradients and threat underlayers keep their existing behavior.
* Updates profile/default/reset and rendering checks and documentation.

## 1.0.185

* Uses nearest filtering for the rectangular gradient mask to avoid blending with transparent outside pixels, which can expose a bright left strip and faint rim when stretched over the bar. Uses a solid-color texture beneath the smooth gradient.
* Keeps the bar darker toward the right: fades from 90% black at the left to 55% black at 80% width, then to clear at the far right. Both continuous segments share native health clipping. The 80% threat-underlayer threshold is unchanged.
* Verifies mask sampling and tint configuration alongside the existing geometry, health-threshold, secret-alpha and restoration checks. In-game verification of the reported strip and border remains necessary.

## 1.0.184

* Extends the fixed health gradient across the full bar: 90% black at the far left, fading linearly to 0% at the far right. The full-health settings preview uses the same fade.
* Preserves threat underlayers at health >=80% and removes them below 80%; the threshold is independent of gradient width.
* Updates gradient geometry and preview checks while retaining threshold and secret-alpha coverage.

## 1.0.183

* Adds a per-profile Gradients toggle above Priority colors and a full-health preview with a white sample name and 255% threat. Gradients default off; Reset all colors turns them off.
* Tints health fills from 90% black at the left to clear at 80% width, leaving the last 20% at its category color. A mask follows native fill geometry so health loss crops the fixed gradient without health arithmetic.
* Removes name/native health-label black copies with gradients enabled. Threat copies remain at health >=80%, disappear below 80%, and return on healing, using a secret-safe cached display curve. Health events and reconciliation update layer alpha independently of threat changes.
* Verifies profile persistence/reset scopes, preview behavior, fixed geometry, replacement-fill reuse, restoration, threshold boundaries, secret alpha forwarding and runtime health events. All 21 smoke suites and whitespace checks pass; native rendering still requires in-game verification.

## 1.0.182

* Places black glyph copies on ARTWORK under white OVERLAY text, using each source label's actual parent so frame ordering cannot reverse them.
* Replaces the six category Active controls with per-profile Health Bar switches and removes individual color reset buttons. Retired Active values no longer suppress styling. Reset all colors restores this profile's bars to On.
* Bar-off entities show colored names and titles with a one-unit gap; inaccessible Blizzard plates retain native presentation. Casts still replace titles.
* Defaults name size to 18 and sets long titles to name size minus two; preserves saved name sizes.
* Adds bar-toggle, title spacing/sizing, native reshow repair, profile copy/reload/reset, and differing-parent text-layer regressions.

## 1.0.181

* Preserves both name and realm from UnitFullName when the player GUID is unavailable. Same-named characters on different realms retain independent fallback profile selections; GUID identity still takes precedence.
* Adds cross-realm, missing-realm, missing-API and GUID-precedence regressions. All twenty smoke suites and whitespace checks pass.

## 1.0.180

* Fixes /rpsn debug cast-hook reporting to read the current icon's entry in the registered-hook table instead of the obsolete single-icon field. Replacement and missing icons report no hook until registered; returning hooked icons report correctly. Diagnostics remain read-only.
* Adds real-hook, replacement, returning-icon and missing-icon diagnostic regressions; updates documentation. All twenty smoke suites and whitespace checks pass. Native WoW verification remains pending.

## 1.0.179

* Coordinates native health labels, addon threat and inside-bar names. Threat stays at the right edge; displayed health labels form a chain to its left, and names reserve the whole group. Region anchors track changing text widths without inspecting restricted health values. Unknown health visibility conservatively reserves space.
* Reconciles native label visibility changes, including hidden middle labels, and restores original native anchors when styling ends. Inaccessible native health text defers styling/restoration until access returns.
* Adds layout combinations for both name placements, native percentages/values and threat; visibility-change, restoration, restricted-value and access-retry regressions. Updates documentation; all twenty smoke suites and whitespace checks pass. Native WoW verification remains pending.

## 1.0.178

* Resolves Retail's native CastBarsContainer.castBar alongside legacy direct cast fields. Checks container access before reading the nested bar and retains conservative checks for restricted bars and icons. Titles now follow native cast/channel visibility, and nested cast bars receive artwork styling and interruptibility effects.
* Adds native-layout capability/access tests, runtime title and disable transitions, real LibCustomGlow integration, artwork restoration and deferred-access retry coverage. Updates documentation; all twenty smoke suites and whitespace checks pass. Native WoW verification remains pending.

## 1.0.177

* Keeps classification badges under Blizzard control during styling, repairs and restoration. Hidden retained elite/rare artwork cannot be exposed on reused plates, and native rarity-display and raid-marker rules remain effective.
* Forwards the native cast-bar interruptibility decision directly to the glow visibility API, without inspecting restricted values. Icon updates remain change notifications; visible Classic-style icons no longer cause uninterruptible casts to glow. Unavailable decisions hide the effect.
* Adds classification lifecycle, Classic-style interruptibility, deferred retry and restricted-result regressions, and updates documentation. All twenty smoke suites and whitespace checks pass; native WoW verification remains pending.

## 1.0.176

* Calls the modern addon enable-state API with addon name before character, retaining the reversed argument order for the legacy global. Unloaded enabled nameplate addons are included in the conflict warning; disabled addons are excluded.
* Leaves selection-highlight visibility to Blizzard during styling, repairs and restoration, preserving current target/mouseover state rather than forcing every Active plate to appear selected or restoring a stale snapshot.
* Adds modern/legacy conflict-scan and live-selection regressions for both disable paths. All twenty smoke suites and whitespace checks pass; native WoW verification remains pending.

## 1.0.175

* Binds captured health-bar and container presentation to the native regions being styled. Restores retired regions before capturing replacement baselines, including container-only changes detected during reconciliation. Replacement bars retain their own dimensions, visibility and colors on disable; inaccessible retired regions defer work until access returns.
* Keeps setup paused when restoration of legacy managed CVars fails. Retained originals are retried before compatibility is reviewed or styling resumes, preventing later restoration from silently invalidating setup consent.
* Adds replacement geometry/color/visibility, restricted-region retry and deferred-CVar setup regressions. Updates documentation; all twenty smoke suites and whitespace checks pass. Native WoW verification remains pending.

## 1.0.174

* Repairs hidden native names and readable text-only drift in both above-bar and inside-bar layouts. Compares only accessible strings; restricted current or expected names remain uninspected and are forwarded only to the text API.
* Queues cast-highlight callbacks missed during frame/region access restrictions, then retries current visibility and presentation once access returns. Retries also run while styling is disabled and cannot revive disabled or restored effects.
* Adds runtime regressions and real LibCustomGlow retry coverage, updates documentation, and passes all twenty smoke suites plus whitespace checks. Native WoW verification remains pending.

## 1.0.173

* Preserves current native cast/channel visibility when styling is disabled or a category becomes Inactive, rather than restoring a stale idle/casting snapshot.
* Restores the current WoW unit name after name changes instead of the initial captured text; keeps removed-unit cleanup and secret-safe SetText behavior.
* Persists deletion and renaming of High Contrast across reloads with an optional validated removal marker. Fresh databases still receive both bundles; explicit recreation or Restore bundled profiles clears the marker. Renamed custom profiles retain their settings.
* Adds regressions for both disable paths, cast start/end, name updates, profile reload and explicit restoration. All twenty smoke suites and whitespace checks pass; native WoW verification remains pending.

## 1.0.163

* Adds session-only, off-by-default `/rpsn perf start`, `stop` and `report` commands. Measures full styling, classification, NPC-title lookup, cached text repair, runtime updates and reconciliation without changing refresh behavior or saved settings.
* Reports call count and total/average/longest elapsed time, explicitly labels overlapping inclusive timings, and samples addon memory only at start/stop. Disabled wrappers perform no timing or memory work.
* Adds deterministic lifecycle, return/error preservation and real runtime/slash integration coverage. All eighteen smoke suites and whitespace checks pass; native-client profiling and security checks remain pending.

## 1.0.162

* Simplifies ordinary Active plates to one presentation policy: show every available health bar, independent of category, world context or combat state, colored by priority. Keeps missing-bar floating names, Inactive/disabled native presentation and widget-only exceptions. Uses existing Blizzard bars without a new dependency or fabricated health values.
* Places NPC service subtitles and enabled TRP3 long titles below the health bar, falling back below the name when no bar exists. Native cast/channel visibility replaces the title; cast end restores it immediately. Does not force idle cast bars visible. Deferred visibility reads retry, and stale/replaced cast bars cannot revive a title.
* Updates settings, runtime evaluation and installation documentation, plus uniform-policy and lifecycle regressions. All seventeen smoke suites and whitespace checks pass. Native-client rendering, cast transitions and security checks remain pending.

## 1.0.161

* Adds a per-profile Use smoother font rendering (Slug) switch near Appearance's font choices, off by default. Applies Slug to accessible names, titles, native health labels, threat text and cast labels; uses thin outlines outside health bars and preserves both black underlayers and padding inside.
* Centralizes rendering flags across plate text and prevents cached repair from restoring a previous rendering mode. Copies/reloads retain the switch, invalid values use the default, and Reset settings disables it. Native presentation restores when styling ends; schema stays 2.
* Extends profile, settings, artwork, threat, underlayer and nameplate regressions. All seventeen smoke suites and whitespace checks pass; visual smoothness, UI-scale and native-client security checks remain pending in game.

## 1.0.160

* Fixes retired cast icons starting or stopping the current bar's interruptible effect after icon replacement. Reuses one secure hook per icon when icons return, and clears the effect when visibility cannot be read instead of retaining stale glow state.
* Uses the same name-positioning helper for initial styling and cached repair, removing duplicate placement branches and the redundant owning-frame cache field.
* Extends the real LibCustomGlow regression with icon replacement, returning-icon hook reuse, stale callback isolation and failed visibility reads; adds missing-bar cached-placement coverage. All seventeen smoke suites and whitespace checks pass. Native client checks remain pending.

## 1.0.159

* Fixes the Profiles styling switch/status remaining Inactive after setup approval while the page is visible. Centralizes pending-state changes and silently refreshes the control on suspension, approval, refusal, restoration and combat-deferred completion.
* Adds real-DF/database/setup integration coverage reproducing the stale approval display before the fix, plus rejected writes, refusal, status text and deferred approval. Keeps existing native input and picker regressions.
* Updates the saved-data guide to current cast-effect fields, font/width ownership, character-specific setup backups and read-only friendly class-color CVars. Schema and stored values are unchanged. All seventeen smoke suites and whitespace checks pass; native client checks remain pending.

## 1.0.158

* Fixes Enter acceptance in profile-name dialogs on current Blizzard UI by using GetButton1(), retaining the legacy button1 fallback and respecting disabled accept buttons. Adds a regression that failed before the fix and coverage for both button contracts.
* Corrects README and live-checklist omissions: inside-bar text is white without an outline, with two black underlayers; bar padding is four units above and three below. Runtime text presentation is unchanged.
* All seventeen smoke suites and whitespace checks pass. Native client keyboard/rendering/security checks remain pending.

## 1.0.157

* Fixes stale color-picker callbacks that could undo a later reset or affect a newly selected profile. Each opening owns a token; resets, profile switches, swatch disable/hide and page hide cancel previews, while accepted edits retire their callbacks. Another addon's picker is not closed or edited. Native setup's initial color event does not write settings or refresh plates.
* Binds Copy, Rename and Delete dialogs to the profile selected when opened. If selection changes before acceptance, the action is rejected with a prompt to reopen the dialog instead of operating on the new selection.
* Separates picker opening/application/completion from swatch construction and adds regressions for both reproduced bugs, accepted/replaced/disabled editors, cross-profile rollback and foreign-picker ownership. All seventeen smoke suites and whitespace checks pass; native client checks remain pending.

## 1.0.156

* Completes phase 6 repository cleanup for the Details Framework conversion: removes unused native switch/toggle/action implementations and shares adapted switch rows, activation status, dropdown alignment and page-action layout across settings pages. Keeps page-specific setters, refreshes, dialog behavior, reset scope and preview cancellation.
* Updates README settings ownership, cast-effect controls, reset placement and full-suite instructions; records the completed code conversion while leaving final native client verification open. Corrects the obsolete adapter fallback comment.
* Updates the wrapped-layout regression to use an adapted page action. All seventeen smoke suites and whitespace checks pass; in-game rendering, input, library coexistence and combat/taint checks remain pending.

## 1.0.155

* Completes phase 5 of the Details Framework conversion: Profiles uses adapted selectors, management buttons and the global styling switch; TRP3 uses adapted switches; About uses a borderless source link and dedicated read-only color displays. Native dialogs, yellow info links, layout helpers and database semantics remain unchanged.
* Refreshes shared profile-menu choices after management changes, retains Appearance preview cancellation before profile selection, and preserves setup consent/restoration and TRP3 disabled preferences. About no longer describes the removed Pulse effect.
* Adds real-DF/database integration coverage for profile confirmations, independent copies, cross-character assignments, protected Default, bundled restoration, setup suspension, TRP3 gating and informational widgets. All seventeen smoke suites pass; native client rendering, combat/taint and external-library coexistence remain pending.

## 1.0.154

* Completes phase 4 of the Details Framework conversion: Appearance's font/placement menus, size/width sliders, switches and Reset settings button now use the adapter. Retains the shared native profile selector, existing ranges/steps, adjacent unit labels, layout and profile/global reset scope.
* Keeps FontMedia's missing/late-provider policy and targeted font refreshes. Font labels update without evaluating menu providers; choices invalidate on media/selection changes and rebuild only when opened. Cancels typed slider previews before profile changes, resets and page hide so rollback cannot overwrite another profile or undo a reset.
* Adds real-DF/SharedMedia/database integration checks for both sliders, cancellation lifecycle, a sixty-font scrollable menu, missing/returning fonts, profile switching, resets and silent refreshes. All sixteen smoke suites pass; native client rendering, combat/taint and actual external-library coexistence remain pending.

## 1.0.153

* Fixes typed slider cancellation in the DF adapter: each slider owns its editor and Escape restores its own opening value, including saved-setting changes from previews. Enter commits a valid rounded/clamped value; closing, focus loss or disabling cancels the preview. Does not patch the bundled library or convert Appearance yet.
* Adds real-DF regressions for two different sliders, cancellation isolation, Enter, invalid input and editor cleanup. All fifteen smoke suites pass.

## 1.0.152

* Completes phase 3 of the Details Framework conversion: Colors now uses DF color swatches, sliding switches, reset buttons and its five-choice cast effect dropdown. Retains the shared native profile selector, top page reset, control spacing, swatch insets, button dimensions and RGB-only picker apply/cancel.
* Consolidates Colors redraws into one silent refresh path while preserving six global activation modes, profile colors/effects, individual reset scope, and High Contrast/whole-page reset behavior. Other settings pages and nameplate rendering are unchanged.
* Updates the existing settings suite to exercise real DF controls and adds a converted-page integration suite using the actual profile database. All fifteen smoke suites pass; client layout, combat/taint and external-embedder checks remain pending.

## 1.0.151

* Completes phase 2 of the Details Framework conversion: bundles the pinned minor 762 library's complete Lua/XML load chain and LGPL license, and adds an isolated settings widget adapter. Existing settings pages still use their original controls; saved settings and nameplate behavior are unchanged.
* Adapts native frame boundaries, toggle switches, slider rounding and silent refreshes, cached dropdown choices, action buttons, and RGB-only picker apply/cancel. Supplies Blizzard widget assets, including the nested dropdown scroll thumb, so Details and Plater are not required.
* Adds a smoke suite that loads the actual library with native UI stubs and exercises adapter behavior and LibStub arbitration; recursively validates the embedded load manifest in the core suite. Client startup/rendering and coexistence with installed external copies remain pending in-game checks.

## 1.0.150

* Completes phase 1 of the Details Framework settings conversion: records the source-verified UI baseline, setting ownership/defaults, exact reset/profile semantics, verified upstream widget APIs and dependencies, and later implementation/verification checkpoints. No widgets or runtime behavior change.
* Marks older architecture prose as historical and corrects obsolete Pulse/toggle references in README and the live-verification checklist. All thirteen existing smoke suites pass.

## 1.0.149

* Fixes shared-font availability validation: a global override can no longer disguise empty or non-string data in the selected font's own registration. Availability checks always return a boolean; invalid registrations use the existing fallback.
* Refreshes only the two font controls when shared media changes, resolves their labels without rebuilding/sorting full menus, and queues nameplate work only for the active profile's affected shared selections. Consolidates shared label/path handling and font-dropdown construction.

## 1.0.148

* Adds LibSharedMedia font choices to both Name font and Threat-percentage font menus while preserving all existing built-in selections and defaults. Bundles LibSharedMedia and CallbackHandler with source attribution and licenses.
* Keeps shared font selections through profile copying, reloads, and absent providers. Uses Arial Narrow while a selected shared font is unavailable, resolves late registrations automatically, updates settings choices, and queues presentation refreshes.

## 1.0.147

* Replaces the interruptible-cast Active switch and Pulse option with one profile Effect selector: None, Moving dashes, Autocast Shine, Action Button Glow, or Proc Glow. None disables the highlight and is the default/reset value.
* Uses the bundled LibCustomGlow renderers with the selected color. Stops the previous effect on changes, hide, disable, or bar replacement; skips rendering when geometry is restricted. Previously enabled Pulse profiles become Moving dashes; disabled profiles stay off.

## 1.0.146

* Adds a profile Effect selector below the interruptible-cast color on Colors: Moving dashes (default) or Pulse. Reset all colors also restores the default effect.
* Bundles LibCustomGlow and LibStub for Pixel Glow dashed borders using the selected color. Preserves Blizzard-driven interruptibility detection, stops effects on hide/disable/bar replacement, and uses explicit readable geometry with pulse fallback when dimensions are restricted.

## 1.0.145

* Checks fallback nameplate formatting and retries pending plates every 0.25 seconds instead of 0.50 seconds, reducing the wait for formatting repairs.

## 1.0.144

* Replaces the single inside-bar text shadow with two black text underlayers: one right 1/down 2 and one right 2/down 1 UI units. White text remains on top with no outline.
* Applies to names, threat percentages, and native health labels. Reuses layers, synchronizes native text/font/visibility changes, passes secret text directly to the rendering API, and hides copies on disable or bar replacement.

## 1.0.143

* Adds a profile Health bar width slider on Appearance: 80–150% of native width in 5% steps, default 100%. Reset settings restores the default; disabling category styling restores native width.
* White text inside health bars uses a black shadow one UI unit right and down, with no outline. Names and titles outside bars retain native thick outlines.
* Increases minimum top padding for inside-bar text from three to four UI units, preserving three below. Includes threat text even when names are above bars, and restores native health-label anchors on disable.

## 1.0.142

* Stops changing friendly class-color CVars, whose synchronous Blizzard callbacks can compare secret health values while executing from addon code. Category and cast-highlight switches now refresh only addon presentation.
* Restores captured native name font, colors, anchors, text, and health-bar color without calling CompactUnitFrame update functions. Blizzard retains responsibility for health and heal-prediction updates.
* Adds repeated category-toggle, native-presentation restoration, and failed-write retry regressions; preserves native thick outlines and white inside-bar text.

## 1.0.141

* Guards styling and artwork updates against synchronous native callback reentry. Releases both guards after failed writes so a subsequent update can recover.
* Adds repeated hostile-category off/on regression coverage with native callbacks during font writes, plus artwork reentry and failure recovery checks. Native thick outlines and white inside-bar text remain unchanged.

## 1.0.140

* Uses WoW's native THICKOUTLINE for names, NPC/TRP3 titles, threat percentages, and native health/cast labels. Leaves outline rendering to the game, without selecting outline colors or layering text copies.
* Keeps names, threat percentages, and native labels inside health bars white regardless of bar color. Preserves outside-bar text colors, selected fonts, sizing, placement, and flat bar artwork.

## 1.0.139

* Trims repeated settings explanations and information dialogs, retaining reset scope, global/profile distinctions, exceptions, and verified presentation limits.
* Consolidates Appearance bar guidance under Health bars, removes the explanation-only Out of combat section, and lets About notes size to their shorter text. Setting behavior is unchanged.

## 1.0.138

* Chooses black or white for inside-bar names, threat percentages, and native health labels using the configured bar color's relative luminance and the higher contrast. Above-bar and name-only colors retain their behavior; cached repair and native-label restoration preserve the new treatment.
* Removes the redundant cast-highlight switch from Appearance and updates the Colors explanation. Appearance reset now leaves the Colors-only cast-highlight setting unchanged.

## 1.0.137

* Moves Reset all colors beneath the Colors profile selector and removes the bottom reset section and separate Reset priority colors button. Restores the factory High Contrast palette only for High Contrast; all other profiles use Default.
* Resets every setting below the button, including global priority activation to Active and profile cast highlighting to Inactive. Adds a matching Active/Inactive switch beside the cast-highlight color, shared with Appearance.

## 1.0.136

* Places Reset settings directly below the Appearance profile selector; resets all settings below it, including cast highlighting and global critter/companion hiding. Colors and activation remain unchanged.
* Moves global addon activation to Profiles beside a left-shifted profile selector, using the Colors-style switch with Active/Inactive status and preserving startup compatibility checks.

## 1.0.135

* Removes native health/cast-bar decorative borders, shaded overlays, and cast-label outlines/shadows. Uses flat fills and backgrounds while preserving progress, icons, and interruptibility indicators; restores artwork when styling ends.
* Anchors inside-bar names three units before displayed threat text, or three units from the bar edge when threat is blank, avoiding unused reserved space and retaining the layout during cached repair.

## 1.0.134

* Removes dark outlines and shadows from styled names, NPC/TRP3 titles, and threat percentages, and removes the dark backing around interruptible-cast borders.
* Makes threat percentages follow the selected name size while preserving the separate threat font; inside-bar names reserve proportionate space for the larger percentage.

## 1.0.133

* Keeps inside-bar names at the full selected font size and expands health bars and containers as needed, with three UI units of padding above and below. Original heights are restored when inside-bar styling ends.
* Renders threat percentages through WoW's supported formatter, including secret values without inspecting them. Ensures labels have a valid font, are shown above bar artwork, and follow replacement health bars.
* Adds threat-display status to diagnostics; absent or undisplayable threat percentages remain blank.

## 1.0.132

* Adds `/rpsn debug mouseover` to inspect hovered creatures without changing the target or their nameplate presentation. Existing `/rpsn debug` continues to inspect the target.
* Identifies the inspected token in reports and handles missing mouseover units explicitly.

## 1.0.131

* Removes the redundant Sanctuary colors section and its duplicate controls and descriptions. Priority colors remains the single place to edit all six categories; color and activation behavior is unchanged.

## 1.0.130

* Makes Player - Friendly share its profile color and global activation switch between Priority colors and Sanctuary colors, matching the NPC controls. Keeps green as the default and retains existing Friendly color choices.
* Removes the separate sanctuary player color; obsolete saved values are discarded without migration.

## 1.0.129

* Ensures a restoration error cannot leave an accessible plate permanently marked as restoring. Failed work stays queued, and successful retries resume styling for the frame's current unit.
* Reports the last restoration error in diagnostics, and shows no blocked region or active restoration when those fields are absent.

## 1.0.128

* Renames the NPC color labels to NPC - Interactive and NPC - Background in both color sections; saved category keys and behavior are unchanged.

## 1.0.127

* Removes the obsolete behavior command alias and its help references. Startup setup guidance points to Appearance.
* Keeps Enable Simple Nameplates global; appearance-profile selection and resets do not change it.

## 1.0.126

* Moves global Active/Inactive category handling to thumb switches beside their colors, including synchronized sanctuary copies. Colors remain profile-specific.
* Moves global Enable styling and Hide critter/companion switches above Reset text and layout on Appearance, preserving startup compatibility checks and restoration behavior.
* Removes the empty Behavior tab; `/rpsn` and the existing behavior/general/settings aliases open Appearance. Reset actions do not alter the global switches.

## 1.0.125

* Reorganizes settings into About, Behavior, Profiles, Appearance, Colors, and TRP3. Appearance/Colors keep compact profile selectors; management actions move to Profiles.
* Uses sentence-case headings, white labels, muted wrapping descriptions, a shared control column, and section actions below controls.
* Keeps all global TRP3 options together, moves informational native-label swatches into About, and preserves the combat sections on Appearance.
* Names reset scopes explicitly, adds a six-category priority reset, and preserves the existing complete color and text/layout resets. Saved fields and runtime presentation rules are unchanged.

## 1.0.124

* Corrects regression checks to identify color controls separately from matching Behavior labels and to test inside-bar font restoration when the bar is visible.
* Changes the default Name font to Friz Quadrata and the default name size to 21 points. New profiles, missing/invalid values, and Reset Appearance use these defaults; existing valid profile choices are retained.

## 1.0.123

* Adds the profile setting "Match Blizzard font in sanctuaries," enabled by default and included in Reset Appearance.
* Uses Blizzard's localized SystemFont_World font face for accessible names and NPC/TRP3 titles in sanctuaries, including names inside health bars. Preserves selected fonts elsewhere, size, outline, colors, placement, and the separate threat font.
* Invalidates cached name styling when the effective font changes; adds regression checks for defaults, profile values, the switch, sanctuary transitions, titles, and bar names.

## 1.0.122

* Uses one Useful color and one Useless color per appearance profile, shared inside and outside sanctuaries and across combat states. Both settings copies update immediately on picker changes, cancellation, and reset.
* Keeps existing Priority Colors values; obsolete separate sanctuary NPC color fields are discarded by ordinary validation without migration. Factory defaults are light grey for Useful and medium grey for Useless; High Contrast keeps its blue and white defaults.
* Retains the separate same-faction player sanctuary color and higher danger priorities. Updates developer notes and regression checks.

## 1.0.121

* Reorganizes Appearance below the existing profile controls into Shared Appearance, Out of Combat, and In Combat sections. Fonts, sizes, Priority Colors, and sanctuary colors remain shared.
* Groups health-bar name placement, threat font/display, and cast highlighting under In Combat, explaining that they also apply to danger-category bars out of combat.
* Moves the existing global TRP3 long-title switch to Appearance / Out of Combat, preserves its saved value and integration enablement, and keeps other TRP3 options on their existing page. NPC service titles remain automatic.
* Preserves runtime presentation, profile/reset behavior, and all existing saved-setting keys; no separate combat configuration or data migration.

## 1.0.120

* Describes presentation limits by entity type and world context, removing individual character names from the README, About notes, and developer review.

## 1.0.119

* Records unresolved presentation limits in the README and in-game About notes: nonattackable opposite-faction PCs in Silvermoon sanctuary without accessible matching plates.
* Distinguishes those unresolved contexts from resolved duplicate widget-plate text on NPCs and ordinary NPC visibility fixed by enabling friendly NPC plates.
* Documents the actual implemented evaluation order and decision trees in the developer notes. No runtime classification change.

## 1.0.118

* Checks Blizzard plate visibility settings on login and when enabling styling. Conflicts pause styling and offer a reviewable Apply-and-enable or Disable-styling choice; compatible settings require no dialog.
* Keeps Only Show Names off so the addon can control friendly bars in combat. Setup changes only listed conflicts, saves originals per character across reloads, and restores them when styling is disabled.
* Defers setup/restoration during combat and verifies writes before resuming styling. Failed writes keep styling paused; failed restoration retains backups for retry.
* Added regression coverage for consent, reloads, character isolation, rejected writes, unsupported CVars, and combat deferral. Documented current Blizzard/Plater findings and the unresolved sanctuary opposite-faction plate case.

## 1.0.117

* Suppresses name/title text on confirmed widget-only plates in Active categories while preserving their frames, widgets, and Blizzard bar visibility. Ordinary plates continue displaying NPC names and service titles.
* Repairs text suppression after Blizzard updates and restores original name opacity when styling is disabled, the category becomes Inactive, or a frame changes plate type.
* Added regressions for simultaneous widget-only/ordinary NPC plates, text drift, frame reuse, unavailable flags, and restoration.

## 1.0.116

* Limits `/rpsn debug` plate details to the target, its direct lookup, and plates with the same readable unit name. Nearby unrelated units no longer flood the chat history.
* Distinguishes same-name diagnostic candidates from verified target identity, retains widget-only and subtitle reports, and prints each relevant frame only once.
* Added regression coverage for unrelated plates, duplicate enumeration, multiple same-name presentations, and unavailable names.

## 1.0.115

* Tries a structured `unit:<GUID>` hyperlink tooltip first for confirmed NPC subtitles, then retains the working unit-token and GUID/name cache fallbacks. Missing, failed, restricted, or rejected hyperlink data does not prevent fallback.
* Preserves affirmative interaction evidence learned with a subtitle so direct hyperlink extraction does not revert a useful nameplate to the useless-NPC color.
* `/rpsn debug` reports hyperlink title/extraction results, each unit's soft-interaction match and widget-only flag, and the `nameplateShowFriendlyNpcs` CVar. These reads do not alter name visibility or suppress duplicate world labels.
* Added regressions for hyperlink precedence, failed/restricted reads, rejected layouts, secret GUIDs, player exclusion, useful title/color presentation, and interaction-plate diagnostics.

## 1.0.114

* Allows unambiguous NPC-name subtitle fallback when a readable nameplate GUID cannot be associated with a fuller world-unit tooltip, as well as when GUIDs are unavailable.
* Learns matching-name target, mouseover, and soft-interaction NPC subtitles during normal rendering, without requiring a debug command. Exact GUID evidence remains preferred, and name associations never populate the exact-GUID cache.
* Bounds both session caches to 256 entries. Conflicting subtitles block name fallback; diagnostics distinguish unmatched and unavailable GUIDs.
* Added regressions for cold title discovery, readable unmatched GUIDs, conflicting names, exact-GUID precedence, and nameplate title/color presentation.

## 1.0.113

* When an NPC nameplate exposes a readable name but no GUID, it can reuse an unambiguous subtitle previously learned from a verified full NPC tooltip with the same name.
* GUID matching remains preferred; conflicting verified subtitles for the same NPC name disable the name fallback for that name.


## 1.0.112

* Accepts NPC subtitles followed by a plain level line when its text matches WoW's localized level template and the unit's readable level, including the observed service-NPC tooltip layout.
* Fills missing nameplate subtitles from target, mouseover, or soft-interaction tooltips only when readable NPC GUIDs match; remembers up to 256 NPC subtitles for the session and refreshes on mouseover changes.
* Uses the resolved subtitle beneath name-only NPC labels and carries verified interaction evidence into useful-NPC classification, allowing the sanctuary useful color to apply to both name and title. Subtitles alone do not establish usefulness.
* Diagnostics report the resolved title source and unavailable identity. Added regressions for sparse tooltips, localization, target changes, restricted identities, token reuse, and sanctuary presentation.

## 1.0.111

* NPC title diagnostics now distinguish missing APIs/data, failed reads, restricted fields, rejected line layouts, and unsupported or empty subtitles.
* `/rpsn debug` reports up to twelve readable tooltip line types and left/right texts for the target and each scanned NPC nameplate, with explicit field-access status. Diagnostic text escapes tooltip markup; no visible tooltip is created or changed.

## 1.0.110

* Reads NPC subtitles such as "Voidforge Steward" from readable structured unit-tooltip data and displays them in angle brackets below addon-controlled name-only NPC labels at 80% of the name size.
* NPC subtitles are independent of TRP3 settings, share the name's configured color, and hide when a health bar is displayed. Missing, restricted, or ambiguous tooltip layouts omit the title.
* Added subtitle diagnostics and extraction/presentation regressions. Blizzard overhead-name duplication remains a separate issue.

## 1.0.109

* `/rpsn debug` now reports every enumerated nameplate, including frames that do not match the target: current unit token/name, displayed name text, visibility, addon markers, original unit, and cached name/presentation.
* Keeps unknown identities and inaccessible frames explicit; these read-only diagnostics do not change nameplate presentation.

## 1.0.108

* Expanded `/rpsn debug` to search existing nameplates for the selected unit when direct lookup misses it, using readable unit identity rather than displayed names.
* Reports matching frames, lookup restrictions, Simple Nameplates styling markers, cached text/presentation, and inside-name/long-title regions to investigate duplicate labels without changing name visibility.

## 1.0.107

* Added independent sanctuary color defaults: sky blue (#87CEEB) for same-faction players, light grey (#D3D3D3) for useful NPCs, and medium grey (#999999) for other NPCs.
* Sanctuary colors are editable and resettable in Appearance profiles, including existing profiles that lack these new values. Combat danger categories and opposite-faction colors retain their existing behavior.
* Applied the selected sanctuary color consistently to accessible name text, TRP3 long titles, and supported health bars. Blizzard-controlled world names remain under Blizzard control.

## 1.0.106

* Completed runtime phase 4: added independent presentation rules with narrow sanctuary/PvP/non-PvP opposite-player cases and shared defaults.
* During player combat, all Active entities with supported accessible bars display them; out of combat only Attacking, Hostile, and Neutral use bars. Missing bars use colored names; Inactive or unknown-combat presentation falls back to Blizzard.
* Names, TRP3 titles, sizing, threat, cast effects, and both Blizzard repair hooks share the decision. Stale caches cannot restore an old combat layout. Long titles are suppressed for requested/observed bars or unknown shown state on an existing bar.
* Added original-visibility capture and restoration retries after restrictions end, including while styling is disabled, plus blocked-refresh and removed-unit cleanup handling. No nameplate-visibility CVar claims were introduced.
* Expanded runtime regressions and added pure rule tests. Phase 5 live-client verification remains pending.

## 1.0.105

* Removed experimental Blizzard overhead-name replacement, including its control, defaults, saved preference, runtime APIs/actions, CVar claims, and diagnostic field.
* Retained valid previously captured Blizzard name/nameplate originals solely for restoration, including failed-write and combat-deferred retries. The obsolete preference is discarded without conversion.
* Retained independent critter/companion hiding, friendly class-color handling, and normal accessible-nameplate styling. Updated documentation and regression checks; phase 4 remains pending.

## 1.0.104

* Completed runtime phase 3: separated entity facts from classification and implemented Attacking, Hostile, Neutral, Friendly, Useful, and Useless in first-match order.
* Eligible PvP opponents use readable attackability; a PvP flag alone no longer promotes sanctuary/non-eligible players. Faction and interaction facts remain independent of category; higher combat priorities override NPC usefulness.
* Updated defaults, High Contrast, settings rows, validation, and documentation together. Obsolete category fields are discarded without conversion; valid current settings remain.
* Experimental overhead replacement now requires every category Active because its CVars overlap categories; mixed modes restore replacement originals. Independent critter control remains.
* Diagnostics reports shared facts and the winning rule, and correctly describes Inactive/disabled styling as Blizzard presentation. Added entity and regression coverage; the phase-4 combat bar policy and live-client checks remain pending.

## 1.0.103

* Completed runtime refactor phase 2: added cached, event-driven world context, including independent player-combat and combat-lockdown facts and desired versus active War Mode. Unknown values remain distinct from false.
* Centralized frame and region access assessment for refresh, hooks, styling, restoration, cleanup, drift repair, and cast effects.
* Expanded read-only `/rpsn debug` reporting for world context, frame capabilities, and observed visibility; diagnostics no longer creates cast overlays or hooks.
* Added context/access regression checks and the phase-2 client checklist. Existing categories, settings, and health-bar policy remain unchanged.

## 1.0.102

* Completed runtime refactor phase 1: separated frame access, name/title layout and repair, threat text, cast highlighting, presentation/restoration, runtime events, and diagnostics into focused modules.
* Fixed `/rpsn debug` calling an unavailable targeting helper by sharing the classification predicate explicitly.
* Extended runtime checks for presentation, TRP3 titles, inside-bar sizing, drift repair, restoration, diagnostics, and module load order. Current category and combat behavior remain unchanged.

## 1.0.101

* Removed Hide Blizzard-controlled minion names and its dedicated defaults, saved setting, CVar claims, and runtime callbacks.
* Validate recognized saved settings individually regardless of the schema marker; retain valid fields and silently discard invalid or unknown fields without conversion.
* Retained critter/companion hiding, experimental overhead replacement, and managed CVar restoration.

## 1.0.100

* Removed Hide from all six Priority Color category selectors, saved-setting validation, and runtime handling; categories now support Active or Inactive only.
* Invalid saved category modes, including the removed Hide value, silently fall back to Active. Existing managed CVar originals remain available for restoration.
* Retained the independent minion-name and critter/companion-name hide switches and experimental overhead replacement.

## 1.0.98

* Updated source and saved-data documentation to match the completed module split; clarified the README's Priority Color classification and local development checks.
* Recorded the remaining live WoW integration matrix separately from the Lua smoke checks. No saved-data schema or settings behavior changed.

## 1.0.97

* Isolated priority unit classification in `NameplateClassification.lua` while leaving the coupled styling, frame repair, and event pipeline together.
* Added a runtime smoke check for category decisions, event/hook registration, and Lua upvalue counts; removed an unused dead function.

## 1.0.96

* Split the settings UI into focused shared-control, About, Behavior, Profile, Appearance, and TRP3 modules while preserving the existing tabs and settings behavior.
* Added a settings registration and callback smoke test, including color-picker cancel rollback.

## 1.0.95

* Moved managed Blizzard name and friendly class-color CVar handling into `ManagedNames.lua` without changing the version-2 saved-data schema.
* Retained captured original CVar values when a restore is blocked or refused, and retried deferred restoration after combat.

## 1.0.84

* Replaced settings checkboxes with on/off switches while keeping their saved settings and effects.
* Aligned labels, controls, reset actions, and Blizzard color info links; replaced question-mark buttons with yellow circled info glyphs.
* Reorganized appearance profile management around selection, actions, restore, and concise guidance.

## 1.0.79

* Display restricted Midnight unit names directly in the inside-bar font string instead of replacing them with empty text.
* Skip Lua prefix concatenation when the unit name is restricted.

## 1.0.78

* Render inside-bar names on the health bar's overlay layer so the bar cannot cover them.
* Corrected the inside-bar height check to match the configured two-unit padding above and below the name.

## 1.0.77

* Removed the attacking glow, its appearance control, and its saved profile field.
* Made the optional interruptible cast border thicker and opaque with a dark outer edge and a pulsing animation.

## 1.0.76

* Aligned Appearance labels and controls in compact rows and narrowed the name-size slider.
* Moved the name-size explanation beside its control and placed section reset buttons on their heading rows.

## 1.0.75

* Added named appearance profiles shared account-wide with per-character active-profile selection.
* Added editable bundled Default and High Contrast profiles plus Create, Copy, Rename, Delete, and Restore Bundled Profiles controls.
* Protected Default as the permanent fallback; deleting another profile returns assigned characters to Default.
* Combined profile management, text and layout, colors, and visual effects on one Appearance tab; `/rpsn colors` remains an alias for it.
* Replaced the one-shot High Contrast preset with the editable High Contrast profile.

## 1.0.74

* Split saved settings into a validated global section for addon behavior and user preferences and an appearance profile for colors, visual effects, fonts, sizing, placement, and threat display.
* Added a Behavior settings page, renamed Text to Appearance, and reordered the settings pages as Behavior, Appearance, Colors, and TRP3.
* Moved category modes and Blizzard overhead-name controls out of Colors and into Behavior.
* Added a schema version and intentionally ignore older or incompatible saved layouts instead of carrying one-off migration code.

## 1.0.73

* Renamed the six-color system and its saved setting to **Priority Colors** and `priorityColors`.
* Clarified that rows are evaluated from top to bottom and the first matching category wins.
* Kept the rows ordered from immediate danger through friendly and least-consequential units.
* Does not import the obsolete `relationshipColors` key; only the exact current `priorityColors` setting is accepted.

## 1.0.72

* Replaced the former color model with six explicitly prioritized categories: attacking, aggressive, neutral-attackable, opposing PC, same-faction PC, and all other colorable units.
* Added an Active, Inactive, or Hide behavior selector to every prioritized category.
* Limited Simple Nameplates coloring, threat text, and effects to Active categories; Inactive categories restore Blizzard's presentation.
* Added best-effort category hiding for addon-accessible frames and matching Blizzard overhead-name CVars, with prior game settings restored when released.
* Preserved only previous settings whose names and values exactly match current valid settings; no renamed or legacy setting aliases are imported.
* Updated the defaults, High Contrast preset, settings descriptions, diagnostics, and documentation for the six-category model.

## 1.0.71

* Added 90-day development ZIP artifacts for every commit to `main`, identified by addon version and short commit SHA.
* Reserved permanent, cleanly named GitHub Releases for matching version tags.

## 1.0.70

* Added an experimental toggle that hides selected Blizzard overhead player, minion, and NPC names while requesting colorable Blizzard nameplates in their place.
* Combined Midnight's forced-name and friendly-player name-only CVars so hidden world-name settings do not also suppress replacement nameplate text.
* Restores every affected WoW CVar when the experiment or Simple Nameplates styling is disabled.
* Reports the replacement state through `/rpsn debug`.

## 1.0.69

* Removed legacy SavedVariables migration and import behavior for the fresh-install release.
* Kept recognized valid current settings while silently replacing invalid values with defaults and discarding unknown or obsolete saved fields.

## 1.0.68

* Moved the High Contrast and Reset Colors buttons to the top of the Colors panel.
* Added a locked green row documenting Blizzard-controlled vendor-NPC overhead names.
* Stopped writing health and maximum-health values into Blizzard nameplate bars, preventing secret-number taint in Blizzard heal prediction.

## 1.0.67

* Fixed a Midnight secret-string error in the cached name-style reconciliation loop.

## 1.0.66

* Added an option to hide Blizzard overhead names for noncombat critters and companions.
* Added a locked yellow row documenting Blizzard-controlled interactive-NPC overhead names.
* Restored the prior Blizzard name setting when the option is disabled.

## 1.0.65

* Moved TRP3 long titles beneath names and sized them to 80% of the configured name size.
* Hidden long titles for units with visible health bars.

## 1.0.64

* Added an option to hide Blizzard-controlled friendly and enemy pet, guardian, totem, and minion names while leaving opposing-player names visible.
* Restored the prior Blizzard name settings when the option is disabled.

## 1.0.63

* Increased inside-bar name padding to two UI units above and below.

## 1.0.62

* Expanded the shared name-size range to 8–36 points.

## 1.0.61

* Prevented health events for forbidden target-of-target unit tokens from being passed to the nameplate API.

## 1.0.60

* Replaced **Colorblind — Web Safe** with a brighter **High Contrast** preset that avoids relying on red versus green.
* Moved each color's affected-element explanation beneath its relationship label so it no longer looks attached to the Reset button.
* Fixed the preset and reset button row floating over the panel description.

## 1.0.59

* Made inside-bar names 80% of the selected name size, rounded to the nearest point.
* Resized inside-name health bars with one UI unit of vertical margin on each side and restored Blizzard's original height otherwise.

## 1.0.58

* Added a shared 6–24 point name-size setting, defaulting to 12, for addon-controlled floating names and names above health bars.
* Limited TRP3 roleplaying names to 32 characters, short titles to 20, and full titles to 48, adding an ellipsis when truncated.

## 1.0.57

* Centered friendly names and TRP3 full titles when their health bars are hidden.

## 1.0.56

* Fixed some friendly-player names disappearing when name-only styling hid Blizzard's containing health-bar frame.
* Expanded `/rpsn debug` with the name region's text, shown state, effective visibility, alpha, and immediate-parent visibility.

## 1.0.50

* Fixed TRP3 full-title refreshes attempting to set text before their custom FontString had a font.

## 1.0.49

* Added a confirmed **Colorblind — Web Safe** preset for all editable colors.
* Applying the accessibility preset also enables the attacking glow without changing Blizzard's colorblind settings.

## 1.0.48

* Added cast-highlight state to `/rpsn debug`.
* Added versioned SavedVariables migrations and separated unit-state colors from effect colors internally.
* Made every settings page scrollable and replaced fixed vertical coordinates with a layout cursor.
* Moved release history out of the README and removed the redundant packaged `README.txt`.

## 1.0.47

* Added an optional, customizable interruptible cast-bar highlight, cyan by default.
* Preserves Blizzard's cast, channel, and non-interruptible treatments while drawing the highlight above the attacking glow.

## 1.0.46

* Renamed Blizzard's fixed overhead-name color from lavender to periwinkle blue.

## 1.0.45

* Clarified that addons can request nameplates but cannot force Blizzard to create them.
* Simplified the attacking-glow label and corrected descriptions of engine-controlled overhead names.

## 1.0.44

* Changed the optional glow into an attacking-state indicator for both PCs and NPCs.
* The glow now always uses the configured Attacking color.

## 1.0.43

* Consolidated hostile NPCs and PvP-enabled opposing PCs into one orange setting.
* Consolidated attacking PCs and NPCs into one red combat-override setting.
* Added a locked informational row explaining Blizzard-controlled periwinkle-blue overhead names.
* Migrates customized NPC hostile and attacking colors and removes obsolete PC-specific colors.

## 1.0.42

* Removed the nonfunctional global overhead-name font setting and its saved value.

## 1.0.41

* Prevented recursive database initialization when legacy CVar restoration fires `CVAR_UPDATE`.
* Clears obsolete replacement-name state before restoring its saved WoW settings.

## 1.0.40

* Delayed overhead-font initialization until saved variables are available.
* Added a safe Blizzard-font fallback for missing or invalid saved selections.

## 1.0.39

* Added a global font selector for Blizzard's engine-drawn overhead unit names.
* Preserves Blizzard's locale-appropriate font by default and warns when a full restart may be needed.

## 1.0.38

* Removed the ineffective replacement-name toggle and ongoing CVar enforcement.
* Restores saved WoW nameplate settings once for users who enabled the removed option.
* Retained nameplate-frame availability in `/rpsn debug` for diagnosing engine-drawn names.

## 1.0.37

* Made replacement names persistent by temporarily enabling Always Show Nameplates and forcing nameplate names to appear.
* Added nameplate-frame availability to `/rpsn debug` output.

## 1.0.36

* Kept Blizzard's ordinary-name settings enabled because they also control whether nameplate text can appear.
* Restores any ordinary-name settings previously captured and changed by version 1.0.35.

## 1.0.35

* Added an optional, reversible replacement for Blizzard's uncolorable overhead player and minion names.

## 1.0.34

* Replaced the screenshot-sampled default values with a clean web-safe RGB palette.

## 1.0.33

* Neutralized Blizzard's additional vertex tint so configured name colors display accurately.
* Updated all eight default colors to match the documented settings palette.

## 1.0.32

* Added a master styling switch that restores Blizzard nameplates and friendly-color settings when disabled.
* Added `/rpsn debug` diagnostics for the current target.
* Labeled every color row as a colored name or health bar and added individual reset buttons.
* Added a threat-percentage display toggle, enabled by default.
* Clarified that PC glow applies only to PCs with visible health bars.

## 1.0.31

* Reduced attack detection to the player and the player's pets, guardians, and minions.
* Health events now update only health instead of reclassifying and restyling the plate.
* Coalesced duplicate event refreshes and narrowed Blizzard hooks to the visual they repair.
* Replaced repeated name rewriting with a slower cached drift check.
* Reduced new-nameplate delayed refreshes and refreshes TRP3 text from profile events.

## 1.0.30

* Reset the standalone addon's release line to `1.0.(build number)`.
* Updated the tracked Git hook to generate future `1.0` build versions automatically.

## 1.0.29

* Changed the defaults to light-blue friendly NPCs and green friendly PCs and player-controlled units.
* Uses yellow for both attackable non-aggressive NPCs and attackable non-attacking PCs.
* Uses actual two-way attackability rather than inferred War Mode to decide whether an opposing PC receives a health bar.
* Correctly recognizes the player's own temporary guardians and minions as friendly player-controlled units.
* Added an optional same-color glow around PC health bars, disabled by default.

## 1.0.28

* Left-aligned names and TRP3 full titles with the health bar.
* Kept threat percentages right-aligned with the health bar.

## 1.0.27

* Added optional TRP3 roleplaying full names with automatic WoW-name fallback.
* Added optional short titles before names.
* Added `[OOC]` indicators that replace short titles; IC profiles receive no marker.
* Added optional full titles on a separate line above the name and always outside the health bar.

## 1.0.26

* Added an optional `TRP3.lua` integration skeleton using public TRP3 APIs.
* Added a TRP3 settings page with a master profile-display toggle, disabled by default.
* Added TRP3 availability status and `/rpsn trp3`.
* No TRP3 profile fields are displayed yet.

## 1.0.25

* Added a Text settings page with separate name and threat-font selectors.
* Changed both default fonts to Arial Narrow with a normal outline.
* Added Above Bar and Inside Bar placement for names on hostile-unit health bars.
* Inside-bar names automatically shrink and reserve space for the threat percentage.
* Added `/rpsn text`.

## 1.0.24

* Distinguishes same-faction and opposite-faction players by actual faction rather than sanctuary reaction.
* Keeps non-PvP opposite-faction players name-only and applies their configured name color.
* Repairs Blizzard name-color overwrites with a lightweight cached-state reconciliation pass.

## 1.0.23

* Fresh standalone release with no previous-version or legacy-settings handling.
* Warns at login when another enabled third-party “plate” addon may conflict.
* Uses `/rpsn` for settings and About commands.
