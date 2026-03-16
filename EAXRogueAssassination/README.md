# EAX Rogue Assassination

Minimal Assassination Rogue rotation for TBC.

## What It Is

`EAXRogueAssassination` is a lightweight Project Sylvanas plugin for Assassination Rogues. It prioritizes poison-aware finishers, maintains Slice and Dice, and uses Mutilate as the main builder.

## Rotation

- **Mutilate** builds combo points quickly.
- **Slice and Dice** refreshes before it falls off.
- **Envenom** fires at 4-5 combo points when Deadly Poison is stacked.
- **Eviscerate** is the fallback finisher when poison stacks are low.
- **Rupture** is optional for sustained fights.
- **Cold Blood** is reserved for dungeon and raid finisher windows.

## Modes

- **Auto** detects Solo, Dungeon, or Raid from group state.
- **Solo** plays the default poison-first loop.
- **Dungeon** enables stronger finisher burst behavior.
- **Raid** keeps the same poison priorities and saves Cold Blood for raid-target finishers.

## Poison Focus

- Tracks **Deadly Poison** on the current target.
- Assumes the player is handling weapon poison application manually.
- Includes poison item references in `spells.lua` for documentation and future extension.

## Install

1. Put the `EAXRogueAssassination` folder inside your Sylvanas `scripts` folder.
2. Reload Sylvanas or restart the client.
3. Open the menu and enable `EAX Rogue Assassination`.

## Notes

- Current repo folder: `EAXRogueAssassination`
- Plugin name in-game: `EAX Rogue Assassination`
- Required files: `header.lua`, `main.lua`, `menu.lua`, `spells.lua`, `utils.lua`, `README.md`
