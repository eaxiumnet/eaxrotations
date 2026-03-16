# EAX Druid Feral

EAX Druid Feral is a dual-role Project Sylvanas plugin that keeps both Cat DPS and Bear Tank logic inside one addon folder. It watches form state, routes into the correct lane automatically, and still lets you force Cat or Bear if you want a fixed profile.

## Lane Handling

- `Auto Detect` uses current form first, then falls back to the last practical lane.
- `Force Cat` locks the plugin to the Cat DPS lane.
- `Force Bear` locks the plugin to the Bear Tank lane.
- `Auto Form` can shift into Cat or Bear automatically for the selected lane.

## Cat Rotation

- Maintain `Mangle (Cat)` and `Rake`.
- Build combo points with `Shred`.
- Spend combo points on `Rip`, then use `Ferocious Bite` in execute windows when `Rip` is already stable.
- Use `Tiger's Fury` when energy is low.

## Bear Rotation

- Maintain `Mangle (Bear)` and `Faerie Fire (Feral)`.
- Queue `Maul` as a rage dump and `Swipe` when pack size reaches the configured threshold.
- Auto-cast `Growl` when the current target is not on you.
- Use `Frenzied Regeneration` and `Berserk` for survival and threat windows.

## Modes

- `Auto` resolves to `Solo`, `Dungeon`, or `Raid` from current group size.
- `Solo` naturally favors Cat play unless you force Bear or are already in Bear Form.
- `Dungeon` and `Raid` keep the same lane logic while making Bear cooldown use more practical for packs and threat windows.

## Install

1. Put the `EAXDruidFeral` folder inside your Sylvanas `scripts` folder.
2. Reload Sylvanas or restart the client.
3. Open the menu and enable `EAX Druid Feral`.

## Notes

- Repo folder: `scripts/EAXDruidFeral`
- Plugin name in-game: `EAX Druid Feral`
- Files included: `header.lua`, `main.lua`, `menu.lua`, `spells.lua`, `utils.lua`, `README.md`
