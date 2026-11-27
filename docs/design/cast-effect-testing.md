# Interruptible-effect testing

Local smoke tests cover rendering and callbacks; these steps verify the actual WoW client. The effect surrounds the enemy's **nameplate cast bar**, not the target-frame cast bar or health bar.

## Current controls

**Colors → Cast colors** contains interruptible fill (#FFFF00), non-interruptible fill (#999966), and interruptible border (#FFFF00). Both fills apply to casts and channels independently of the border. **Cast Highlight** contains border activation (default off), effect, geometry and timing. Use **Sample cast** to preview either fill or the idle nameplate. With the border off, the interruptible preview keeps its fill and shows the selected border effect in static grey. Each reset affects its own page.

## A simple enemy to try

Use a **Kobold Geomancer in or around Jasperlode Mine, Elwynn Forest**, east of Goldshire. The [Warcraft Wiki entry](https://warcraft.wiki.gg/wiki/Kobold_Geomancer) records that location and its Fireball cast. This is a practical low-level caster to try from an Alliance character; confirm the actual current-client cast with your interrupt rather than treating the location/spell listing as live proof of interruptibility. Avoid other nameplate addons for this test.

1. Open `/rpsn highlight` and select the profile used by this character. Turn **Highlight interruptible casts** on and select **Solid border**. On Colors, choose a bright **Interruptible cast border** and confirm the preview shows it.
2. Configure the effect before engaging: combat disables settings changes and cancels unfinished edits. Find one Geomancer, keep its enemy nameplate visible and stay within cast range. At high level, engage without damaging it if possible (a taunt, if available); stop attacks and dismiss attacking pets/minions so it survives. Stay out of melee reach while allowing it to cast.
3. Let one Fireball finish. Watch the small nameplate cast bar beneath its health bar. Repeat and interrupt another Fireball with your actual interrupt to confirm that particular cast can be interrupted. A stun or displacement alone does not establish interruptibility.
4. Leave combat before changing the selected effect. Repeat with Pulsing border. The indicator should stop at cast end/interruption, hide for noninterruptible casts, and remain absent while highlighting is off. Switching profiles changes both activation and effect.
5. If the preview works but the real cast has no effect, target the caster and capture `/rpsn debug` **while the cast is running**. A keybound macro helps capture the short cast:

```text
/rpsn debug
```

Include the Interruptible highlight line, Presentation access and cast-bar availability. A report after the cast ends correctly describes a hidden/inactive cast and cannot diagnose its preceding state. Repeat with a different real caster if this enemy's current cast is unavailable or cannot be interrupted.

## Distinguish rendering from detection

| Observation | What to check next |
| --- | --- |
| No effect in preview | Selected effect, color, thickness and UI scale |
| Preview works, real effect absent | Highlight interruptible casts enabled for the selected profile, accessible nameplate cast bar, running cast, resolved state/source and native icon/shield hooks |
| Debug says interruptibility unavailable | Capture during a longer active cast; unknown state retries rather than claiming the cast is interruptible |
| Target-frame bar glows nowhere | The effect belongs to the separate enemy nameplate cast bar |

## Implementation and acceptance

| Choice | Implementation |
| --- | --- |
| Pulsing border | Existing addon-owned four-edge alpha animation |
| Solid border | Addon-owned four-edge static border |
| Alert border | Addon-owned centered top/bottom gradient halves with native Scale animation |

All three effects share Border thickness (4) and Border offset (3 outward). Pulse Fade in and Fade out default to 0.1 seconds each, with fixed 35–100% opacity and no hold interval. Solid remains fully opaque. Alert has only top/bottom length-pulsing gradients. Verify these controls on Cast Highlight, both previews on Colors/Cast Highlight, and the absence of Advanced. Valid saved shared thickness and pulse timing stay in their existing locations; retired fields are discarded without conversion. No library effect constructor or native cast-dimension read is needed.

Cast events, native fill updates, bar visibility and icon/shield changes refresh the fill and border. Hidden, finished or unreadable casts use the native fill. An unreadable active state retries. Explicit interruptibility-change events remain authoritative, and casts are never classified solely from the preview. Validate casts/channels, modern/classic layouts, recycled bars/icons, temporary access loss, disabling styling and profile/color/effect changes in game. The callback regressions do not prove the cause of every previous missing live highlight.
