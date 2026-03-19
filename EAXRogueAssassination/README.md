# EAX Rogue Assassination — v2.1.0

Assassination Rogue automation for TBC on Project Sylvanas.

## Rotation
- `Mutilate` is the primary combo point builder.
- `Slice and Dice` maintained before falling off.
- `Envenom` at 4-5 CP when Deadly Poison is stacked.
- `Eviscerate` as fallback finisher when poison stacks are low.
- `Rupture` for sustained fights (now enabled by default).
- `Cold Blood` reserved for finisher windows in dungeon/raid.
- `Garrote` as a stealth opener bleed.
- `Shiv` for guaranteed poison application.

## New in 2.1.0
- **Combo points fixed:** Now reads via `me:get_power(COMBOPOINTS_TBC)` on the player — was previously reading from the target mob, always returning 0.
- **Vanish:** Auto-triggers at <30% HP as emergency escape.
- **Sprint:** Auto-triggers when target is out of melee range.
- **Blind:** Auto-triggers at <35% HP for defensive CC.
- **Rupture:** Enabled by default.

## Menu Options
- Use Mutilate, Envenom, Rupture, Eviscerate, Cold Blood
- Use Vanish, Sprint, Blind, Evasion, Feint
- Envenom/Rupture CP thresholds

## Install
1. Extract `EAXRogueAssassination` into your Sylvanas `scripts` folder.
2. Reload or restart.
3. Enable `EAX Rogue Assassination` in the menu.
