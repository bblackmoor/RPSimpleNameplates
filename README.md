# Simple Nameplates

**Simple Nameplates** makes it easier to see who is attacking you, who might, and who is worth talking to. It gives Blizzard's nameplates clear, consistent colors and readable names, with optional roleplaying names and titles. It is for players who want a useful view of the people and creatures around them, especially during everyday play and roleplay. Choose it over Blizzard's defaults for more control over colors and text, or over **EllesmereUI** or **Plater** when a few straightforward settings cover what you need.

## Features

- Color names and health bars by danger, friendliness, and NPC interaction.
- Choose which categories show health bars and which show names alone.
- Adjust fonts, text size, bar width, and name placement.
- Add a dark health-bar gradient to make white text easier to read.
- Dim background NPC names to make other names stand out.
- Display NPC service titles and optional threat percentages.
- Highlight interruptible casts with a solid, pulsing, or animated alert border.
- Use **Total RP** 3 names, titles, and out-of-character markers.
- Save appearance profiles and let each character choose its own.
- Start with editable Default and High Contrast profiles.

Simple Nameplates styles Blizzard's existing nameplates. Health and cast progress, spell icons, and target behavior remain controlled by the game.

## Screenshots

<img width="2560" height="1600" alt="Alliance-in-Stormwind" src="https://github.com/user-attachments/assets/81273266-ac83-4481-9451-a5551c2b32a1" />&nbsp;&nbsp;&nbsp;&nbsp;
<img width="2560" height="1600" alt="Alliance-in-Elwynn-Forest" src="https://github.com/user-attachments/assets/f680789f-cb78-4afd-9a7f-593d0a2ee1cb" />    

<img width="2560" height="1600" alt="Alliance-in-Combat" src="https://github.com/user-attachments/assets/56ce9b44-0c10-4a2a-a030-16999bbce8d1" />&nbsp;&nbsp;&nbsp;&nbsp;
<img width="2560" height="1600" alt="Alliance-in-Dalaran" src="https://github.com/user-attachments/assets/cbd7afa8-e023-4c21-bf8a-ddc86931cb7a" />    

<img width="2560" height="1600" alt="Alliance-in-Silvermoon" src="https://github.com/user-attachments/assets/36b93a25-a2f9-48f8-a462-7898c3f01edf" />&nbsp;&nbsp;&nbsp;&nbsp;
<img width="2560" height="1600" alt="Alliance-in-Horde-Silvermoon" src="https://github.com/user-attachments/assets/3b494dcf-712e-4eaf-9d5f-a14fd5b22eae" />

## Installation

Simple Nameplates is available on CurtseForge.

Alternatively, download the installable ZIP from [GitHub Releases](https://github.com/bblackmoor/SimpleNameplates/releases), extract it, and copy its `SimpleNameplates` folder to:

```text
World of Warcraft/_retail_/Interface/AddOns/SimpleNameplates/
```

Start World of Warcraft and enable the addon at character selection. Simple Nameplates is for Retail WoW. No separate library installation is needed.

On your first login, the addon may ask to enable the nameplate settings it needs. Choose **Apply and enable** to accept the listed changes, or **Disable styling** to leave it off. Disabling styling restores the settings changed by that setup.

## Using Simple Nameplates

Type `/snp` to open settings, or find **Simple Nameplates** under **Options → AddOns**.

| Page | What you can change |
| --- | --- |
| Profiles | Turn styling on or off; select, create, copy, rename, delete, or restore profiles |
| Text | Fonts, text size, bar width, names inside or above bars, threat display, and critter/companion name hiding |
| Colors | Category colors and health bars, background-name dimming, gradient strength, and cast-highlight color and activation |
| Highlight | Cast-highlight effect, border thickness and offset, animation timing, and previews |
| TRP3 | Roleplaying names, short and long titles, and OOC markers |
| About | Installed version, source, commands, and known limitations |

Changes apply immediately and are saved. Settings cannot be changed during combat; entering combat cancels unfinished edits.

### Colors and health bars

The first matching category wins:

| Priority | Category | Default color |
| --- | --- | --- |
| 1 | Attacking me | Red |
| 2 | Hostile | Orange |
| 3 | Neutral | Yellow |
| 4 | Friendly | Blue |
| 5 | NPC – Interactive | Green |
| 6 | NPC – Background | Grey |

An enemy that is attacking you uses red even if it also offers an interaction.

Each category has a **Health Bar** switch. Turn it off to show a colored name and title without a bar. Background NPCs use names alone by default. Names inside bars use white outlined text, with optional dimming for background NPCs.

Cast highlighting is off by default. Enable **Active** beside the cast-highlight color on **Colors**, then choose the effect on **Highlight**.

### Profiles

Profiles are shared across your account, and each character remembers its selection. **Create** starts with default settings; **Copy** duplicates the selected profile. Default can be edited and restored, but cannot be renamed or deleted. High Contrast can also be edited. **Restore bundled profiles** restores both presets without changing custom profiles.

Additional fonts are available through SharedMedia font packs or other font-providing addons.

### Total RP 3

TRP3 integration is optional and off by default. Enable **Display TRP3 profile information** on **TRP3**, then choose the fields you want: roleplaying name, short title, long title, or OOC marker. If a profile is unavailable, the normal WoW name is used. NPC service titles work without TRP3. Casts temporarily take the place of titles beneath the nameplate.

## Known limitations

Simple Nameplates can style only nameplates WoW makes available to addons. Some separate overhead names remain controlled by Blizzard, including nonattackable opposite-faction players in sanctuaries.

Detecting which player is attacking you in PvP is best effort.

Threat percentages appear only when WoW supplies usable threat information.

Use one nameplate addon at a time. If you see competing colors or duplicate displays, disable other nameplate addons and reload the UI.

## Commands

| Command | Action |
| --- | --- |
| `/snp`, `/snp text`, `/snp appearance` | Open Text settings |
| `/snp profiles` | Open Profiles |
| `/snp colors` | Open Colors |
| `/snp highlight` | Open Highlight |
| `/snp trp3` | Open TRP3 settings |
| `/snp about` | Open About |

## Development

[Developer documentation](docs/README.md) covers implementation, diagnostics, testing, and known client restrictions. [CHANGELOG.md](CHANGELOG.md) records release history.

---

**AI disclaimer:** AI-assisted tools were used in development. The author reviewed and approved the code and documentation and remains responsible for the project.

Copyright © 2026 Brandon Blackmoor (<bblackmoor@blackgate.net>)

Licensed under [GPL-3.0](https://www.gnu.org/licenses/gpl-3.0.en.html)

Source: [bblackmoor/SimpleNameplates](https://github.com/bblackmoor/SimpleNameplates)
