# EAX Paladin Holy — v2.1.0

Holy Paladin healing automation for TBC on Project Sylvanas.

## Status
- **Current state:** release-candidate healer after cooldown, cleanse, sustain, and blessing cleanup
- **Best roles:** dungeon / raid healing
- **Main deferred gap:** deeper live tuning of raid-heal pacing, not missing core TBC tools

## Rotation
- `Lay on Hands` for emergency saves below critical HP.
- `Flash of Light` for fast emergency healing.
- `Divine Illumination` before heavy healing windows to reduce mana costs.
- `Divine Favor` for high-value emergency healing windows.
- `Holy Shock` on cooldown for instant healing.
- `Holy Light` as the main large heal, especially on tanks.
- `Avenging Wrath` for throughput when the party is under pressure.
- `Blessing of Might` on likely tanks and `Blessing of Wisdom` on mana users.
- `Hand of Freedom` for root/snare dispel.
- `Cleanse` / `Purify` for poison or disease removal.
- conservative low-mana `Seal of Wisdom` sustain.
- `Concentration Aura` upkeep with `Devotion Aura` fallback, without overwriting a manual aura.

## Notes
- OOC group top-off and triage behavior were strengthened.
- Blessing detection now handles greater blessings more safely.
- Judgement maintenance uses a refresh window instead of a one-time apply-only path.

## Install
1. Extract `EAXPaladinHoly` into your Sylvanas `scripts` folder.
2. Reload or restart.
3. Enable `EAX Paladin Holy` in the menu.
