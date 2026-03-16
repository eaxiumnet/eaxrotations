# EAX Paladin Protection

Compact Sylvannas helper optimized for TBC Protection Paladins. It keeps the core threat tools active (Righteous Fury, Holy Shield, Consecration, Avenger's Shield, and Judgement) while honoring Solo/Dungeon/Raid workflows and the Auto mode that mirrors group size.

## Highlights
- **Threat upkeep:** automatically refreshes Righteous Fury and keeps Holy Shield on to maintain threat and mitigation.
- **Adaptive AoE:** Consecration only fires when the configured number of nearby targets is met; Auto mode defers to detected group size.
- **Utility casts:** Avenger's Shield is used when the target is out of melee range (suppressed in Raid) and Judgement keeps Crusader tick damage active.
- **Notifications & logging:** optional notifications and debug logging surface what the rotation is doing; toggle them in the menu.

## Modes
- **Auto:** detects group size (solo vs. dungeon vs. raid) and adjusts thresholds automatically.
- **Solo:** aggressive use of threat and mitigation to stay on top of single-target pressure.
- **Dungeon:** emphasizes cleaner Survivability with conservative AoE windows.
- **Raid:** conservative casting; Avenger's Shield is avoided to limit range damage.

## Controls
- Open the Sylvannas menu tree named "EAX Paladin Protection"; the rotation tree exposes the major cast toggles and Consecration sliders, while the defense tree covers Holy Shield.
- Use the top-level toggle or the assigned keybind to flip the addon on/off.
- The control panel also surfaces the master toggle and mode selector for quick access.

## References
- Design doc: `docs/superpowers/specs/2026-03-13-eax-paladin-protection-design.md`

Plugin folder: `scripts/EAXPaladinProtection`
