# Blizzard settings and sanctuary plate availability

Pinned source review recorded 2026-10-02 for v1.0.118; documentation checked against the addon for 1.0.220 on 2026-10-08. No new external source or client verification is claimed. These source findings establish the setup controls, not a fix for every game-engine visibility decision.

## Verified settings

The pinned Blizzard [Nameplates settings definition](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_SettingsDefinitions_Frame/Nameplates.lua) maps the controls as follows:

| Control | CVar | Setup value |
| --- | --- | --- |
| Always Show Nameplates | `nameplateShowAll` | `1` |
| Enemy Unit Nameplate | `nameplateShowEnemies` | `1` |
| Friendly Player Nameplates | `nameplateShowFriendlyPlayers` | `1` |
| Friendly NPC Nameplates | `nameplateShowFriendlyNpcs` | `1` |
| Only Show Names | `nameplateShowOnlyNameForFriendlyPlayerUnits` | `0` |

The [unit-frame implementation](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_NamePlates/Blizzard_NamePlateUnitFrame.lua) shows that Only Show Names changes bars, auras, classification, anchors, and hit testing on an existing friendly-player frame. Turning it off lets RP Simple Nameplates manage bars itself; it does not establish that a missing sanctuary plate will be created. Widget-only mode is a separate property, explaining why a widget-only NPC plate must suppress actor text while preserving its widgets.

These files are pinned snapshots of the public UI-source mirror, not proof that every engine behavior or deployed client build is identical.

## Plater comparison

[Plater.lua](https://github.com/Tercioo/Plater-Nameplates/blob/96e5c4393daa014b4c84bd5c382b23af7153a595/Plater.lua) uses `C_NamePlate.GetNamePlateForUnit` and plate-added events. Its Midnight combat visibility toggles use the same friendly-player, enemy, always-show, and Only Show Names CVars. Its first-run defaults turn friendly NPC plates off, which conflicts with this addon's goal of styling NPC names and service subtitles. Copying those defaults would therefore be inappropriate.

Its forbidden-plate handler unloads any previously managed plate and does not implement a Retail text-recoloring workaround for forbidden frames. No sanctuary-specific solution for nonattackable opposite-faction players was found in the reviewed main file. This is a bounded source finding, not proof that no workaround can exist elsewhere.

The previously reviewed public Platynator snapshot is historical; it is not evidence of how the current release handles this case.

## What the screenshots establish

The observed entity type is opposite-faction PCs in sanctuary, nonattackable in both directions; the verified world context is Silvermoon City / The Bazaar, with an Alliance viewer and Horde PCs. With friendly, enemy, and always-show settings enabled, diagnostics still find no accessible matching plate. Classification already resolves the correct sanctuary rule; presentation is skipped because the frame is missing. Their visible native overhead labels are not identified as addon-accessible FontStrings.

The [driver](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_NamePlates/Blizzard_NamePlates.lua) manages frames after the engine supplies them, including forbidden plates. The [manager API](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/NamePlateManagerDocumentation.lua) exposes existing-plate sizing/hit-testing/simplification and events; it does not document a function to force a nameplate for an arbitrary world unit. Registering a script frame alone does not supply a world anchor or replace native labels.

The setup check addresses verified configuration conflicts, including the friendly NPC setting that made ordinary plates available for friendly service NPCs. It must not promise to fix the remaining Horde sanctuary case or treat a missing frame as evidence of an incorrect setting.
