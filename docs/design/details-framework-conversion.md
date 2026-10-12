# Details Framework conversion record

The six code phases of the settings-widget conversion completed in 1.0.163. Superseded widget inventories, intermediate-build instructions, and phase task lists have been removed.

## Decisions retained

- Bundle Details Framework for settings widgets and place the adapter in `SettingsWidgets.lua`.
- Keep Blizzard Settings registration, native dialogs/RGB picker, page-owned scroll layout, description reflow, shared row spacing, and information links.
- Preserve database validation, schema 2, global/profile ownership, per-character selection, font policy, and setup/restoration callbacks.
- Do not adopt AceDB, framework addon/profile scaffolding, or framework replacement unit/cast bars.
- Capture profile name and object identity for editor sessions. Retired callbacks cannot change replacement profiles or another addon’s color-picker session.
- Refresh the global Active control when asynchronous setup approval/suspension changes effective state.
- Test actual bundled widget constructors with native UI fixtures and cover modern/legacy native dialog acceptance.

Current pages and modules are listed in [settings architecture](settings-architecture.md), shared editor contracts in [settings conventions](settings-conventions.md), and dependencies in [library provenance](../../RPSimpleNameplates/Libs/README.md). Outstanding native rendering/security checks belong in [live verification](live-wow-verification.md), rather than the completed conversion record. Detailed release history is in the [changelog](../../CHANGELOG.md).
