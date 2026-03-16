# EAX Rogue Combat

Minimal Combat Rogue rotation for TBC.

## What It Is

`EAXRogueCombat` is a lightweight Project Sylvanas plugin for Combat Rogues. It keeps Slice and Dice as the highest finisher priority, builds with Sinister Strike, and drives Blade Flurry plus Adrenaline Rush burst windows.

## Rotation

- **Sinister Strike** is the primary builder.
- **Slice and Dice** refreshes before it falls off.
- **Rupture** is preferred on sustained targets.
- **Eviscerate** is the fallback finisher when Slice and Dice is safe.
- **Kick** interrupts enemy casts.

## Burst

- **Blade Flurry** is used for cleave pressure and grouped burst.
- **Adrenaline Rush** is held for dungeon and raid windows instead of solo trash.

## Modes

- **Auto** detects Solo, Dungeon, or Raid from group state.
- **Solo** focuses on the clean SnD loop without spending major cooldowns early.
- **Dungeon** enables cooldowns once the target has an established combo-point window.
- **Raid** holds cooldowns for stronger 4+ combo-point burst alignment.

## Install

1. Put the `EAXRogueCombat` folder inside your Sylvanas `scripts` folder.
2. Reload Sylvanas or restart the client.
3. Open the menu and enable `EAX Rogue Combat`.

## Notes

- Current repo folder: `EAXRogueCombat`
- Plugin name in-game: `EAX Rogue Combat`
- Required files: `header.lua`, `main.lua`, `menu.lua`, `spells.lua`, `utils.lua`, `README.md`
