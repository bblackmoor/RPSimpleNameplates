# World-context and runtime separation record

The runtime module separation, cached context, entity facts, and presentation/restoration work are implemented. Experimental overhead replacement was removed in 1.0.105. Earlier combat-dependent bar rules and category activation controls are superseded by profile Health Bar preferences.

## Resulting boundaries

- `WorldContext.lua` owns event-driven world observations and revision; unknown is distinct from false, and location names are not access permissions.
- `EntityFacts.lua` gathers readable identity, faction, ownership, directional attackability, interaction, and threat evidence. `NameplateClassification.lua` selects the first matching priority independently of game APIs.
- `PresentationCapabilities.lua` assesses accessible/missing/forbidden/restricted/unknown regions. `PresentationRules.lua` resolves the uniform current bar/title policy.
- Frame geometry/artwork, name/title layout, threat, cast effects, full/focused presentation, event scheduling, diagnostics, and restoration have separate modules.
- Restricted writes are skipped and retried. Deferred restoration continues with styling disabled and validates recycled units/replaced regions.
- Legacy overhead-replacement originals are restoration-only. Critter hiding remains independently managed; startup class-color handling is covered in the runtime notes.

Use [runtime evaluation](evaluation-overview.md) and [runtime notes](runtime-notes.md) for current behavior. Client checks are maintained only in [live verification](live-wow-verification.md); older phase-specific location and control checklists are retired. Release history is in the [changelog](../../CHANGELOG.md).
