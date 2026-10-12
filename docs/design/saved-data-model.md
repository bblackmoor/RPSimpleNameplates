# Saved data model

Current for 1.0.246. Implemented version-2 schema. RP Simple Nameplates uses Global behavior and appearance Profiles, with no separate Theme layer.

## Why two scopes are sufficient

Unlike RP Emote Menu, RP Simple Nameplates has no user-defined emote categories, emotes, window state, or other substantial Profile content to separate from appearance. Its current Profiles already hold the visual configuration. A Profile -> Theme reference would make Profiles mostly wrappers, add shared-reference and deletion rules, and complicate selection without a clear user benefit.

Each character selects an account-wide appearance Profile. Global behavior applies across characters.

Account-wide Profiles are selected independently by each character through `profileKeys`. A character without a valid assignment uses Default. There is no Theme collection or Theme reference.

Name placement defaults to Inside for Default and new custom profiles, and Above for High Contrast. Missing or invalid placement uses that profile default; saved choices and copies retain it. Text reset restores the active profile’s placement default.

## Current schema (version 2)

```lua
SimpleNameplatesDB = {
    schemaVersion = 2,
    global = { categoryModes = { ... }, trp3 = { ... },
               stylingEnabled = true, hideCritterCompanionNames = false,
               highContrastRemoved = true, -- Optional; only after removal of the bundle.
               managedNameCVarOriginals = { ... },
               nameplateSetupOriginals = { ["Player-GUID"] = { ... } } },
    profiles = {
        Default = { priorityColors = { ... }, effectColors = { ... },
                    appearance = { ... }, healthBars = { attacking = true, hostile = true,
                        neutral = true, friendly = true, useful = true, useless = false },
                    showThreat = true, gradientOpacity = 100, dimBackgroundNames = true,
                    interruptibleHighlight = false, interruptibleEffect = "PULSE" },
        ["High Contrast"] = { ... },
    },
    profileKeys = { ["Player-GUID"] = "Default" },
}
```

A valid version-2 saved database separates behavior from look and feel. The structural refactor kept this shape and version. Validation reconstructs settings from defaults, discards invalid and unknown fields, and retains recognized valid settings regardless of the saved schema marker. No one-off migration or import/export facility is needed.

Useful and Useless each have one `priorityColors` entry per profile, used in all world and combat contexts. Player - Friendly uses one `friendly` entry in all world and combat contexts, with blue (`#0000FF`) as the default. The former `sanctuaryFriendly`, `sanctuaryUseful`, and `sanctuaryUseless` fields are unknown settings and are discarded during validation; valid `useful` and `useless` values are retained without conversion.

`appearance.useSlugRendering` is a per-profile boolean, on by default. It selects Slug rendering for styled plate text, with thin black outlines on all styled text, including inside health bars. Copies and reloads retain it; Reset Text enables it. Missing or invalid values use the default. Schema remains 2.

`appearance.matchSanctuaryFont` is a per-profile boolean, enabled by default. It selects Blizzard's localized world-name font face in sanctuaries without replacing the saved `nameFont`. Profile copies retain it and Reset Text restores the default; invalid or missing values use the default.

Profiling introduced in 1.0.163 is session-only. It adds no fields to `SimpleNameplatesDB`, does not follow profile selection and starts disabled after every UI reload. Stopped results are retained only in memory until a new session or reload.

## Ownership inventory

| Setting | Owner | Reason |
| --- | --- | --- |
| `stylingEnabled` | Global | Master addon behavior |
| Six `healthBars` booleans | Profile | Per-category health-bar visibility; on for the first five categories, off for NPC - Background |
| Legacy `categoryModes` | Global | Retained for compatibility; ignored by rendering |
| `hideCritterCompanionNames` | Global | Blizzard name management |
| `trp3.enabled`, `useRoleplayingName`, `showShortTitle`, `showFullTitle`, `showOOC` | Global | TRP3 integration and display policy |
| Six `priorityColors`, `effectColors.interruptible` | Profile | Appearance colors |
| `appearance.nameFont`, `nameSize`, `threatFont`, `namePlacement`, `matchSanctuaryFont`, `useSlugRendering`, `healthBarWidth` | Profile | Text and layout |
| `showThreat`, `interruptibleHighlight` | Profile | Threat visibility (default on) and cast highlight activation (default off) |
| `interruptibleEffect` | Profile | `PULSE` (default), `SOLID`, or `ALERT`; independent of Active |
| `gradientOpacity`, `dimBackgroundNames` | Profile | Gradient opacity 0–100%, default 100 for Default/custom and 0 for High Contrast; background-name dimming default on |
| `profileKeys` | Account-wide character selection map | Independent Profile choice per character |
| `global.managedNameCVarOriginals` | Internal restoration ledger | Original critter and legacy managed values, retained until restored |
| `global.nameplateSetupOriginals` | Internal ledger keyed by character GUID | Visibility values captured after setup consent, restored when styling is disabled |

Do not confuse the six editable Priority Colors with fixed Blizzard-controlled lavender/yellow/green overhead names. The latter are explanations in the settings UI, not Profile values. The classification precedence is runtime logic, not a saved setting.

## Bundled Profile rules

Default and High Contrast are editable account-wide Profiles. Default always exists and can be restored but cannot be renamed or deleted. High Contrast can be edited and restored or recreated, and the current lifecycle permits renaming and deleting it. A validated optional `global.highContrastRemoved` marker preserves deletion or renaming of High Contrast across reloads. Fresh databases still receive both bundles. Recreating High Contrast or restoring bundled profiles clears the marker. The Restore Bundled Profiles action restores both factory definitions. Deleting a selected Profile reassigns every affected character to Default. Creating a Profile starts with Default factory values; Copy duplicates the active Profile. Profile changes refresh visible nameplates.

## CVar safety and compatibility

Managed overhead-name original values are persisted in `global.managedNameCVarOriginals` and must survive the refactor unchanged until restored. Setup-approved visibility originals are stored separately per character in `global.nameplateSetupOriginals`. Friendly class-color CVars are observed only; the addon does not capture or write them. Keep combat deferral, capture-before-set, and restoration on disable or when no longer managed. A code-layout refactor has no reason to bump `schemaVersion`; it remains descriptive metadata rather than a reason to reset valid settings. The saved schema marker does not reject an otherwise valid setting. Recognized fields are validated in their current locations; retired cast selector values are discarded without conversion. Retain valid restoration-ledger entries until they are restored.

## Runtime phase-3 category fields

Both Global category modes and Profile priority colors recognize only `attacking`, `hostile`, `neutral`, `friendly`, `useful`, and `useless`. Valid values at these keys are retained. The obsolete `unfriendlyNPC`, `unfriendlyPC`, `friendlyPC`, and `other` keys are discarded without remapping. Unrelated valid preferences, profile selections, and managed-CVar restoration records remain valid. The schema marker remains 2; it never overrides individual field validation.

## Removal of experimental replacement (1.0.105)

`replaceBlizzardOverheadNames` is no longer a recognized field and is silently discarded. No preference is converted. Valid `managedNameCVarOriginals` entries for its former Blizzard settings remain restoration records: normal managed-settings processing restores them without capturing or applying new replacement values, retains them after failed writes, and defers restricted restoration until combat ends. Only the independent critter/companion control makes ordinary-name CVar claims now; friendly class-color CVars are read-only.


`healthBars` accepts boolean values only. Copies and reloads retain false; missing or invalid values use the category default (first five on, background off). Reset color settings restores those defaults in the selected profile. Reset Text preserves these choices. Names default to size 18; saved sizes are preserved, and long titles use the chosen name size minus two.

`gradientOpacity` is a whole-percent profile number from 0 to 100. Default/custom profiles default to 100; High Contrast defaults to 0. At 0 the tint is hidden, at 100 its existing 80%-black-to-clear gradient is unchanged, and intermediate values scale the left endpoint darkness directly (50% means 40% black) while texture opacity stays full, without moving the fade or mask. Copies/reloads retain valid values; missing, wrong-type, non-finite and out-of-range values use defaults. The retired `gradients` boolean is discarded without conversion. Colors reset restores the opacity default; Text reset preserves it. Opacity does not affect cast fill, health values or text outlines.

Health bars default On for the first five categories and Off for NPC - Background. `dimBackgroundNames` is a per-profile boolean, default On: background names use #999999 when enabled and #FFFFFF when disabled. Colors reset restores both defaults; Text reset preserves them. Valid saved choices remain authoritative.

## Cast settings validation and reset scope

Validation imports only valid current values. `interruptibleCastStyle` is discarded without conversion. Current effects are PULSE, SOLID and ALERT; invalid selections default to PULSE, and activation defaults off. `castAdvanced.PULSE` stores shared thickness (4), offset (3), fadeIn (0.1s) and fadeOut (0.1s). `castAdvanced.ALERT` stores minLength (20%), maxLength (100%), shrinkTime/growTime (0.2s), endOpacity (0%) and centerOpacity (100%). Valid existing values remain authoritative; missing/invalid fields use defaults without migration. Alert minLength greater than maxLength resets both to 20/100. The default `effectColors.interruptible` is #3300FF for all factory profiles, while saved colors remain unchanged. ResetHighlightSettings restores only effect and castAdvanced; color and activation remain on Colors.

Reset color settings restores the selected profile's six priority colors, cast color, cast activation (off), cast effect (Pulsing border), health-bar defaults, background dimming (on) and gradient default. High Contrast uses its factory palette and gradient opacity 0%; Default and custom profiles use factory Default values. It also resets retained global category modes to active internally; rendering ignores those modes. It preserves profile selection, appearance/threat settings, styling enablement, critter hiding and TRP3.

Reset text settings on Text restores that profile's appearance defaults and threat on, plus global critter hiding off. It preserves all Colors preferences, styling enablement, TRP3 and selection. Restore bundled profiles replaces Default/High Contrast while preserving custom profiles and globals.
