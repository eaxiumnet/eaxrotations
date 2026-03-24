# EAX Paladin Retribution — v2.1.0

Retribution Paladin DPS automation for TBC on Project Sylvanas.

## Rotation
- Maintains the correct Seal based on mode (Seal of Command / Blood / Righteousness).
- `Crusader Strike` on cooldown.
- `Judgement` triggers the current seal's damage effect and refreshes the seal on target.
- `Consecration` for multi-target.
- `Exorcism` against undead/demons.
- `Consecration` for sustained AoE.
- `Hammer of Wrath` at <20% HP (execute range).
- Seal twisting in raids (enabled by default).

## TBC Cleanup (this version)
- Removed Holy Power engine (Templar's Verdict, Inquisition, Hammer of the Righteous) — not in TBC Ret.
- Removed Divine Plea — replaced with Divine Illumination.
- Rotation follows TBC Seal → Judgement → Crusader Strike cycle.

## Menu Options
- Seal selection, Judgement choice, Consecration
- Use Hammer of Wrath, Divine Illumination, Lay on Hands
- HP/mana thresholds

## Install
1. Extract `EAXPaladinRetribution` into your Sylvanas `scripts` folder.
2. Reload or restart.
3. Enable `EAX Paladin Retribution` in the menu.
