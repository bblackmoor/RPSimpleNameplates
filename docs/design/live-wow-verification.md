# Live WoW integration verification

Current client checklist for 1.0.246. Keep unobserved checks open. The 1.0.218 report confirms appearance convergence in its recorded crowded scene; local suites do not establish broader native acceptance.

Local UI stubs do not establish actual rendering, native permissions, secure CVar behavior or Midnight secret-value safety. Record addon version, client build, date, scene, profile, activity and observed result for client checks. Leave an item open until observed in game. Historical plans describe their original releases; this checklist replaces instructions to exercise removed controls or repeatedly install intermediate diagnostic builds.

## Recorded live evidence

| Build/report | Observation | Scope |
| --- | --- | --- |
| 1.0.213 | No reported geometry drift or reconciliation full-style fallback; broad refresh maxima around 20 ms | One reported scene; justified per-plate global scheduling |
| 1.0.214 | Runtime/Urgent maxima 5.323/3.198 ms; color/opacity drift remained | Unmatched recording; no exact FPS gain established |
| 1.0.217, 118.4 seconds | Appearance already wrong after cached/artwork completion | Located failing operation boundaries; exact native writer unconfirmed |
| 1.0.218, 94.4 seconds | 4,686 reconciliation checks with no reported appearance drift or repair fallback; 11,534 checkpoints with no failures; 660 color finalizations | Crowded-scene convergence confirmed; Runtime/Urgent maxima 4.728/2.951 ms |
| 1.0.219 | Temporary checkpoints/audit hooks removed; validated fixes retained; 21 smoke suites passed | Broader client acceptance pending |

These runs are not matched benchmarks. Inclusive timing rows overlap and must not be summed; separately reported maxima do not prove a shared callback. Memory deltas do not prove a leak. Earlier failed attempts and detailed versioned observations remain in the [follow-up record](reconciliation-stall-plan.md), [profiling guide](profiling.md) and [changelog](../../CHANGELOG.md).

## Normal play with profiling off

- [ ] Install the current inner `RPSimpleNameplates` folder using the README instructions and confirm the About version. Play normally with profiling off; observe grey background names and inside labels without duplicate native text or visible hitches.
- [ ] Change target/mouseover, enter/leave combat, move out of range/back, recycle plates and change zones. Verify current names/colors remain stable and no stale labels reappear.
- [ ] Gain/lose threat; start, interrupt and finish casts/channels. Check immediate affected-unit updates, name space, pulse and title substitution.
- [ ] Change profiles/fonts/size/width/gradients and toggle global Active off/on. Verify priority plates update immediately, background plates settle promptly over subsequent frames, and native presentation restores when disabled.
- [ ] Check sanctuary, eligible PvP/duel and restricted combat contexts, including deferred restoration while styling stays disabled. Record Lua, taint or protected-action errors.

Capture a complete current-build report if flicker or hitches return. Additional scheduler tuning or diagnostics requires a reproduced unresolved problem; another routine screenshot is not required just to continue normal play.

## Settings foundation and page layout

- [ ] With Details/Plater and standalone Details Framework disabled, log in/reload and open About, Profiles, Text, Colors, Highlight and TRP3. Confirm one registration, correct page order and scrolling. Repeat with an external DF embedder and record the selected DF minor version.
- [ ] Check headings, wrapping, switches, disabled labels, swatches, sliders, dropdowns and info-link spacing at narrow/normal widths and different UI scales. Test content growing/shrinking and wheel/scrollbar operation.
- [ ] Verify `/snp` and `/snp text` open Text (`/snp appearance` remains an alias); profiles/colors/highlight/trp3/about routes open their pages. Settings commands refuse combat opening; debug/perf commands remain available during combat.
- [ ] Enter combat with an open color picker, typed slider editor, held slider drag, dropdown menu or profile dialog. Verify unfinished previews roll back, menus/dialogs close, current selections are restored, and all settings mutations (including resets and profile actions) are disabled. Previously committed edits remain.
- [ ] Leave combat: controls resume their normal availability without resuming cancelled sessions; Default rename/delete and disabled TRP3 dependents remain disabled. Open the settings through the native Settings UI during combat and confirm controls cannot mutate saved values. Debug/perf remain usable.
- [ ] About reads the installed `.toc` version; the copy-source link and three read-only reference swatches work and never open editable pickers.
- [ ] Profiles' global Active switch reflects setup suspension while consent is pending, successful Apply and enable, refusal and failed/deferred writes without requiring a page reopen.

## Profiles, saved data and edit lifecycle

- [ ] Fresh install creates Default and High Contrast, selects Default, and uses documented factory values. Load valid existing schema-2 data and verify recognized preferences/ledgers survive; malformed or unknown fields are discarded individually regardless of schema marker.
- [ ] Select different account-wide profiles on two characters; verify independent assignments across reload/logout and shared edits wherever that profile is selected.
- [ ] Create/copy/rename/delete profiles, including long names and many entries. Copies are independent; rename updates assignments; deletion falls back to Default. Default cannot be renamed/deleted; High Contrast deletion/rename survives reload, and bundled restore recreates it without changing custom profiles or globals.
- [ ] Open Copy/Rename/Delete, then change selection or replace the captured object before accepting. Stale confirmations do nothing and request reopening; normal unchanged-target actions work. Test bundled restore with missing/replaced targets.
- [ ] Preview/accept/cancel RGB colors. Switch profiles, reset Colors, hide the page and open another swatch during drafts. Rollback stays with the original current target; retired callbacks cannot undo a reset or affect a later edit. Test with RP Emote Menu's actual picker enabled; neither addon closes or edits the other's session.
- [ ] Type slider values and test Enter/Escape, focus loss, page hide, profile switching and Text reset during previews. Check 8–36 points/step 1 and 80–150% width/step 5 without stale rollback.
- [ ] Retired cast-style strings are discarded without conversion; valid current activation/effect values are retained and missing/invalid values use defaults. Legacy category modes remain stored but do not affect rendering.

## Current Colors controls and reset scopes

- [ ] All six Health Bar switches follow the selected profile; On shows a supported bar in both combat states, Off shows its name/title without a bar. Verify first-match priority and no category Active/Inactive or Hide controls.
- [ ] Factory bars are On for the first five categories and Off for NPC - Background. Background-name dimming defaults On; On is grey #999999 and Off white #FFFFFF, with matching subtitles, inside/above/no-bar. Bar colors and threat styling are independent.
- [ ] Colors contains the interruptible color and Active switch, with default color #3300FF. Highlight (between Colors and TRP3) contains Effect (Pulsing border, Solid border, Alert border), shared Border thickness (4) and outward Border offset (3), Pulse Fade in/Fade out (0.1 seconds each), and Alert length (20–100%), shrink/grow times (0.2 seconds each), end opacity (0%) and center opacity (100%). Pulse fades all four edges between 35% and 100%; Solid is fully opaque; Alert animates centered top/bottom gradient segments with hidden sides. Both Colors and Highlight have labeled effect previews, greyed out and static while the interruptible Active switch is off. Reset highlight settings restores effect/geometry/timing/gradient without changing Colors color/Active; Reset color settings retains its broader reset scope. Native icon/shield hooks and spellcast events drive detection without reading secret interruptibility. Live visual acceptance remains open.
- [ ] Reset color settings restores the selected profile's factory palette, bars On except Background, background dimming On, cast activation Off, effect Pulsing border, and gradients On for Default/custom or Off for High Contrast. It preserves appearance/threat settings, selection, global styling, critter hiding and TRP3. Internal legacy category modes reset to active without affecting rendering.
- [ ] Text reset restores selected-profile fonts/rendering/size/placement/width and threat On, plus global critter hiding Off. It preserves Colors preferences, global Active, TRP3 and selection. Bundled restore has the separate scope described above.

## Fonts, geometry, gradients and native labels

- [ ] Compare Slug Off/On with built-in/SharedMedia fonts at several UI scales. All styled names, titles, native health/threat/cast labels keep thin solid outlines with no extra glyph copies or shadows.
- [ ] Default/custom names use Friz Quadrata, size 18, Inside placement and width 120%; High Contrast uses Above placement. Verify saved choices remain authoritative and reset returns profile defaults. Threat defaults to Arial Narrow at name size; TRP3 titles use name size minus two and NPC subtitles 80%.
- [ ] Open long font lists, select absent saved fonts and register providers late. Choices survive reload/copy; unavailable faces use Arial Narrow temporarily and resume when available. Sanctuary matching changes only the name/title face, using the localized world font.
- [ ] Inside names keep full size; bars leave four units above/three below. Native health labels and threat form the documented right-hand chain with three-unit gaps. Appearance changes, native label show/hide and rounded geometry converge without endless repair; switching Above or disabling restores captured dimensions/anchors.
- [ ] Known Retail restricted-anchor layouts size correctly without requiring readable GetPoint; unsupported layouts remain untouched. Test modern/classic layouts and different UI scales without Lua/secret-value errors.
- [ ] Full-health preview shows Sample and illustrative 255% threat. Gradients fade from 80% black at the left to clear at 95% full width, with the last 5% clear. Damage/heal clips the fixed tint to native remaining fill without rescaling, depleted-area tint or bright edge. Threat outlines remain unchanged at every health level; cast bars remain flat.
- [ ] Decorative bar edges/absorb overflow glow are suppressed; shield fill, heal prediction, icons, shields, target/mouseover treatment and classification visibility remain intact. Disable styling and verify native artwork/text baselines restore, including retired/replaced regions.

## Casts, threat, NPC subtitles and TRP3

- [ ] Observe interruptible/non-interruptible casts and channels with each effect Active/Inactive, including changing interruptibility mid-cast and cast start/stop/interruption. Preserve native shield/spell/target information, modern/classic support and geometry-independent anchoring. Check direct icon/shield Show/Hide, native cast-bar show/hide and initially unreadable visibility. Missing renderer methods/templates should fall back to the pulse with a debug reason, without frame churn.
- [ ] Reuse bars/icons/plates and temporarily block access. Old icons cannot control the current effect; missing callbacks recover using current state when access returns.
- [ ] Threat displays WoW's scaled percentage when supported, passes secret values only to the supported formatter and stays blank if unavailable/rejected. It does not pin at raw 255%. Threat appearing/disappearing updates name space promptly.
- [ ] NPC service subtitles resolve from supported structured/unit tooltips and bounded caches; test unambiguous name fallback, conflicting titles and unreadable data. Titles fit configured bar width even without a bar and disappear during active/unknown cast visibility, returning when safe after the cast.
- [ ] With TRP3 installed/absent and its master switch Off/On, test cached RP names, short/full titles, OOC marker, missing-field fallback and 32/20/48-character limits. Dependent options preserve saved choices while disabled. TRP3 callbacks update content through the next runtime batch.

## Classification, context, setup and restoration

- [ ] Test all six priorities: attacks on the player/controlled units, aggressive NPCs, eligible PvP opponents, directional Neutral attackability, Friendly players, interaction-evidenced NPCs and fallback Background. Titles/friendliness alone do not prove usefulness; unknown identity is not confirmed NPC identity.
- [ ] Compare same/opposite-faction players in sanctuary, eligible PvP and same-faction duels. Readable attack permission is authoritative; flags/faction/desired War Mode alone cannot promote a player. Targeting a friendly unit does not make it Attacking.
- [ ] Test zone/subzone and instance transitions (including shared/faction sanctuary boundaries), combat entry/exit and styling disabled. Debug context preserves faction, desired/active War Mode, flags, lockdown and unknowns; named locations are not hardcoded permissions.
- [ ] Startup compatibility requests only documented visibility settings with consent, skipping unreadable/unsupported CVars. Originals are per-character; failed writes/restores retain backups, and combat restrictions defer safely. Profile changes do not change plate-visibility CVars.
- [ ] Global critter/companion hiding captures/restores its own supported CVar. Legacy replacement records are restoration-only; experimental replacement and Behavior routes remain absent. Friendly class-color CVars are read-only.
- [ ] Disable styling while frames are forbidden/restricted; restore when access returns while still disabled. Recycled plates receive current-unit presentation and fresh replacement-region baselines, without clearing another entity's text or restoring obsolete cast visibility.
- [ ] Debug target/mouseover distinguishes missing from inaccessible plates, shows relevant identity/same-name candidates and subtitle evidence, and creates no effects/hooks. The documented opposite-faction nonattackable sanctuary world-label limitation remains unresolved; do not treat missing frames as a solved configuration problem or generalize to untested entities.

## Profiling and performance acceptance

- [ ] After login/reload profiling is Off and report has no session. Start/stop/report in and out of combat, while disabled and without a target. Duplicate start preserves the running session; stopped readings freeze; a new session clears counters and reload clears all results.
- [ ] If investigating a regression or quantifying improvement, record matched quiet/crowded/combat routes with similar durations/settings/activity, three repeats and profiling Off/On. Capture all timing/reason rows with consecutive screenshots and actual visible FPS/hitches separately. Compare only equivalent timing definitions.
- [ ] Current reports include per-plate Reconciliation, Runtime update, Urgent refresh, Periodic work, Plate discovery and observed reason rows. Broad Global refresh measures discovery/enqueueing plus immediate priority work; Global plate refresh measures one plate visit. Removed appearance checkpoints/origin rows are not expected on 1.0.219+.
- [ ] Verify current/previous target/mouseover/interaction and explicit unit updates stay prompt while broad background settings/context work settles through the shared four-job/one-millisecond cooperative budget. Check fairness, recycling, errors and deferred restoration; no continually growing visible backlog.
- [ ] Unknown properties remain unknown and use elapsed retry eligibility from 0.25–4 seconds, without blocking independent readable repairs. Native cast hooks/events bypass backoff. One atomic job and immediate priority work can exceed the periodic time target; do not tune it from a single unmatched maximum.

See [the repeatable cast test](cast-effect-testing.md) for enemy selection, preview versus detection checks and a targeted debug capture.

- [ ] Advanced is absent. Verify outward offset 3 and constant thickness 4; Pulse fades at 0.1 seconds each way, Solid stays opaque, and Alert has only top/bottom segments with continuous centered growth/shrink. Check previews on both pages and their independent hide/show lifecycle. Valid saved values survive reload; defaults fill missing values without migration.

- [ ] Gradient opacity on Colors spans 0–100%. Test 0 (none), 50 (half-strength tint) and 100 (original gradient); fade position, native health clipping and outlines remain unchanged. Preview updates immediately. Typed/drag edits roll back on combat entry and profile changes. Colors reset uses 100 for Default/custom and 0 for High Contrast; retired toggles are discarded without conversion.

## Recent cast-fill and preview regression checks

- [ ] On the current build, test a fresh live interruptible cast, then leave combat and change its highlight color/profile/effect. Subsequent casts keep a plain fill. Check actual tint, completion/interruption, native shields/icons, disable/re-enable, and restoration without secret-value or taint errors.
- [ ] Turn highlight Active off on Colors. Both Colors and Highlight previews are grey, dimmed, and completely static for Pulse, Solid, and Alert. Re-enable and verify the selected effect resumes; hide/show each page and repeat.

Acceptance remains partial until the applicable client checks are recorded. Passing local suites or one converged scene does not close unobserved native behavior.
