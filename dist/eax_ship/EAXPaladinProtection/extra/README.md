# EAX Paladin Protection — v2.1.0

Protection Paladin tank automation for TBC on Project Sylvanas.

## Status
- **Current state:** release-candidate after major TBC/NAG cleanup
- **Best roles:** dungeon / raid tanking
- **Main deferred gap:** full `Seal of Vengeance / Seal of Corruption` parity

## Rotation
- `Righteous Fury` maintained for threat generation.
- `Holy Shield` maintained for block uptime, including safe prepull preload.
- `Avenger's Shield` as a ranged opener / snap-threat tool.
- `Judgement` maintains configured `Wisdom` / `Crusader` assignments on durable targets with conservative fallback behavior.
- `Consecration` for sustained AoE threat, plus a conservative single-target filler path when mana is healthy.
- `Holy Wrath` only on valid undead/demon cases.
- `Seal of Light` can step in as a narrow survivability fallback.
- `Devotion Aura` upkeep is available, but now respects manual aura swaps.

## Notes
- Blessing spam protections and anti-retry throttles are built in.
- The spec is intentionally using a safer seal engine than full NAG parity for tonight's release candidate.
- Full `SoV / SoCorruption` stack logic is still deferred.

## Install
1. Extract `EAXPaladinProtection` into your Sylvanas `scripts` folder.
2. Reload or restart.
3. Enable `EAX Paladin Protection` in the menu.
