# EAX Paladin Retribution — v2.1.0

Retribution Paladin DPS automation for TBC on Project Sylvanas.

## Status
- **Current state:** release-candidate after major seal / judgement cleanup
- **Best roles:** solo / dungeon / raid DPS
- **Main deferred gap:** deeper twist timing polish, not core TBC flow

## Rotation
- Maintains the correct Seal based on mode (Seal of Command / Blood / Righteousness).
- `Crusader Strike` on cooldown.
- `Judgement` now uses a real TBC seal → judgement flow, including `Wisdom` / `Crusader` / `Light` setup when chosen.
- `Consecration` for multi-target.
- `Exorcism` against undead/demons.
- `Consecration` for sustained AoE.
- `Hammer of Wrath` at <20% HP (execute range).
- Seal twisting in raids (enabled by default).
- Optional prepull `Judgement of the Crusader` setup.
- `Retribution Aura` upkeep is available, but now respects manual aura swaps.

## TBC Cleanup (this version)
- Removed Holy Power engine (Templar's Verdict, Inquisition, Hammer of the Righteous) — not in TBC Ret.
- Removed Divine Plea — replaced with Divine Illumination.
- Rotation now follows a real TBC Seal → Judgement → Crusader Strike cycle with cleaner reseal timing.

## Menu Options
- Seal selection, Judgement choice, Consecration
- Use Hammer of Wrath, Divine Illumination, Lay on Hands
- HP/mana thresholds
- Aura Upkeep toggle

## Install
1. Extract `EAXPaladinRetribution` into your Sylvanas `scripts` folder.
2. Reload or restart.
3. Enable `EAX Paladin Retribution` in the menu.
