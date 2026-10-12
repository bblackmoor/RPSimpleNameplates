# Shared settings conventions

Documentation reviewed for 1.0.220 on 2026-10-08. Shared settings contracts are unchanged; native settings/picker coexistence acceptance remains open. Current RP Simple Nameplates control inventory and reset scopes are in [settings architecture](settings-architecture.md) and [saved data](saved-data-model.md).

Current conventions for RP Emote Menu and RP Simple Nameplates after the four standardization phases. Each repository keeps this document and the contract harness in sync when their shared contract changes; there is no shared runtime dependency.

## Names and boundaries

| Name | Meaning |
| --- | --- |
| `addon` | This addon's private namespace inside settings modules |
| `UI` / `Widgets` | Settings layout/lifecycle helpers / Details Framework widget adapters |
| `SettingsPanels` | Page factory registry; page constructors do not register categories |
| `RegisterSettingsPanels` | One-time registration after APIs and all factories are available |
| `pageOrder` / `rootCategory` / `categories` / `panels` | Ordered page descriptors / root category / categories by key / page instances by key |
| `panel.Refresh` | Ordinary control refresh; does not apply user settings |
| `LayoutFullWidth` / `LayoutText` | Responsive region / text measured inside a responsive control |
| `CreateInfoLink` | Yellow circled-i link, 12 units after its anchor |
| `target = {name, object}` | Captured data identity; a reused name is insufficient |
| `activeEdit` / `owner` / `original` / `opening` | Live picker session / owning control / original RGB / native setup guard |

SettingsControls owns layout, SettingsWidgets owns widget rendering, SettingsColorPicker owns native picker sessions, and SettingsProfileDialogs owns profile confirmations. The `.toc` is authoritative for startup order. Factories resolve their helpers after all modules load. Registration preflight prevents missing APIs/factories from producing partial pages; repeated registration leaves existing categories intact.

About uses a large heading, muted description, Version/Author/Category/License metadata, copyable Source, Commands and domain-specific reference sections. Text and source-link hit areas reflow on resize and show. Other pages retain practical control arrangements and domain-specific widths. Applicable rows follow label, control, reset, info.

## Behavior deliberately retained

| Area | RP Emote Menu | RP Simple Nameplates |
| --- | --- | --- |
| Saved ownership | Global preferences, content/behavior Profiles, shared appearance Themes | Global behavior/integration and appearance Profiles |
| Database API | `addon.Database` | Existing flat addon exports, including `GetProfile(name)` |
| Scroll backend | Details Framework canvas adapter | Native scroll frame |
| Default settings route | Behavior | Text |
| Profile confirmation after selection change | Unchanged captured original may remain valid | Captured original must still be selected |
| Specialized refresh | Editor targets, category selection, font refresh | Text draft cancellation, font refresh, runtime plate refresh |

Both pickers use RGB tables for get/apply callbacks. Setup is silent and ignores hides emitted while the new session is opening; live previews apply, cancellation restores the original only while target identity remains current, native Okay/hide commits, and retired callbacks are inert. CancelColorEdit(owner) only cancels that owner; callers using frame scripts must wrap a global cancellation in a zero-argument callback. Native picker extraInfo identifies ownership. An addon must not close or roll back a picker owned by another addon.

Database mutations retire affected previews before changing their selection or replacing data. Profile dialogs validate captured identity at acceptance; bundled restore also validates formerly missing names. These rules do not migrate saved data or change reset ownership.

## Local verification

From either repository root, run every suite in a separate process:

```sh
for test in tests/*-smoke.lua; do
    texlua "$test" || exit 1
done
git diff --check
```

LuaTeX is the verified interpreter; `luatex --luaonly "$test"` is equivalent. Run whitespace checks in an actual git checkout. Suites use actual bundled libraries and addon modules with native UI fixtures.

| Contract | Coverage |
| --- | --- |
| Startup, factories, page order, retries and duplicate protection | settings and settings-registration smoke suites |
| Silent refresh, disabled controls and preserved reset scope | adapter and page integration suites |
| About wrapping, source copy and responsive hit areas | Profile/utility (RP Emote Menu) and secondary settings (RP Simple Nameplates) suites |
| Target identity, direct mutations and stale confirmations | picker, Profile/Theme and settings integration suites |
| Identical picker lifecycle expectations | settings-contract smoke suite and settings-contracts helper |

The default settings-contract suite tests its repository's actual picker module. To test both actual addons together, provide the peer module path; no copied peer source or second runtime dependency is needed:

```sh
# In RPEmoteMenu:
texlua tests/settings-contract-smoke.lua /path/to/RPSimpleNameplates/RPSimpleNameplates/SettingsColorPicker.lua
# In RPSimpleNameplates:
texlua tests/settings-contract-smoke.lua /path/to/RPEmoteMenu/RPEmoteMenu/SettingsColorPicker.lua
```

RP Simple Nameplates color rows pass a saved-RGB getter to their widget adapter; opening refreshes the swatch silently and captures current saved RGB for rollback. Generic adapter swatches may use display RGB when no saved getter is supplied.

The coexistence check runs both takeover directions and setup variants with and without an intermediate native hide. It checks committed/displaced previews, owner-specific cancellation and stale callbacks against the actual modules.

## Native WoW acceptance — pending

- Load each addon separately and both together; check for Lua errors and the expected settings hierarchy.
- Open About at narrow and normal widths; confirm paragraph/source wrapping, copy popup, wheel/scrollbar operation and shrinking content.
- Confirm headings, muted descriptions, switches, disabled controls, reset/info order and adjacent spacing.
- Preview and cancel colors; accept a color; switch profiles and restore defaults while drafts are active.
- Open a profile confirmation, then replace or change its target; confirm acceptance respects the documented per-addon policy.
- With both addons enabled, move between their color controls and close settings; confirm neither cancels or closes the other's picker.
- Reload and confirm existing saved settings and per-character Profile selection remain intact.

Local fixtures do not establish native rendering, client frame restrictions or protected API behavior. All client acceptance items above remain pending until observed in WoW.
