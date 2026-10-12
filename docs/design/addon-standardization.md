# RP Emote Menu / RP Simple Nameplates standardization

Documentation reviewed for 1.0.220 on 2026-10-08. Shared settings contracts are unchanged; native settings/picker coexistence acceptance remains open. Current RP Simple Nameplates control inventory and reset scopes are in [settings architecture](settings-architecture.md) and [saved data](saved-data-model.md).

Use common conventions where the purpose is the same; preserve addon-specific behavior and practical control layouts. Keep the embedded libraries and each addon's scroll backend.

## Phase 1 — About and visual conventions (implemented)

Both About pages use a large About heading, muted description, Version/Author/Category/License metadata, a copyable Source link, Commands, and addon-specific reference sections. RP Emote Menu's page is extracted to SettingsAbout.lua and uses its existing Details Framework canvas adapter. Paragraphs and the source link reflow on resize and show; content grows and shrinks with wrapped text. RP Simple Nameplates now documents the profiling command. Settings headings use the same font and supporting descriptions the same muted color; adjacent info links use a 12-unit gap. Existing control widths, setters, reset scope and page registration remain in place.

Validation: both complete smoke suites pass, including responsive About expansion/contraction and source-copy behavior. Verify final appearance and native scrolling in WoW at narrow and normal Settings widths.

## Phase 2 — Naming and page registration (implemented)

Settings modules now use addon, UI and Widgets for equivalent locals. Both addons publish page factories through SettingsPanels and use RegisterSettingsPanels with explicit pageOrder, rootCategory, categories and panels. Registration checks all required APIs and factories before constructing pages and ignores repeated calls. Visible page order and slash routes are preserved.

Ordinary editable pages expose panel.Refresh; RP Emote Menu retains RefreshEditors, category selection and font refresh, and RP Simple Nameplates retains its OnHide edit-cancellation behavior. Equivalent layout fields use LayoutFullWidth/ LayoutText and the info helper is CreateInfoLink. Runtime namespace structure, database contracts and embedded libraries remain addon-specific.

Validation: complete smoke suites, registration preflight/retry/idempotence/order/routing, silent construction and control refresh, profile switching, picker cancellation and editor-target tests. Native appearance verification in WoW remains pending.

## Phase 3 — Database, dialog and picker contracts (implemented)

Both addons now keep native RGB picker lifecycle in SettingsColorPicker.lua, with SettingsUI.OpenColorEditor/CancelColorEdit, owner, target {name, object}, original RGB, opening guard and retirement before rollback. SettingsWidgets retains swatch rendering and adapts its callbacks to RGB tables. Another addon's picker is never closed or rolled back.

RP Simple Nameplates profile dialogs are extracted to SettingsProfileDialogs.lua. Copy, rename and delete require the captured name and object to remain selected; bundled restore checks every captured object, including missing bundled names. RP Emote Menu retains its captured-target policy that permits acting on an unchanged original object after selection changes.

RP Simple Nameplates database mutations cancel drafts before profile selection/CRUD/restore or color and appearance resets. Invalid profile mutations do not cancel drafts. GetProfile(name) supplies identity lookup while existing namespace exports and saved-data schemas stay intact.

Validation includes direct database changes during previews, callback retirement, same-name replacement, stale lifecycle and bundled restore confirmations, missing bundled target replacement, and shared-picker takeover. Full smoke suites pass; native visual verification remains pending.

## Phase 4 — Shared regression checks and documentation (implemented)

The [shared conventions](settings-conventions.md) document module names, API contracts, deliberate differences, the test coverage map and pending native WoW acceptance. Both repositories have identical settings-contracts.lua helpers and repository-specific smoke entry points. The default test checks the local actual picker module; a peer path enables both actual modules together, including both takeover directions and native setup/hide variants. Existing integration suites cover actual libraries, registration, refresh, disabled controls, responsive layout, dialogs and database mutations.

Architecture documents and README development commands reflect the current modules. No shared runtime dependency or packaging workflow was introduced. All four code phases are implemented; client acceptance remains pending.

## Post-phase picker review fixes

Opening sessions now ignore native OnHide emitted during setup of the previous owner, so the incoming session remains active until its own native lifecycle begins. Coexistence tests assert actual preview writes, original-color rollback and picker closure in both takeover directions, with and without setup hiding the previous picker.

RP Simple Nameplates color rows provide a saved-RGB getter to the swatch adapter. Opening reads that getter and refreshes the displayed swatch silently; it no longer captures a stale display color as the rollback original. Priority and effect color tests cover direct database changes without a page refresh. Generic swatches without a saved getter retain their display-RGB fallback.

Both complete suites and actual-addon coexistence checks pass. Native WoW verification remains pending; no client occurrence is claimed for the simulated setup-hide ordering.
