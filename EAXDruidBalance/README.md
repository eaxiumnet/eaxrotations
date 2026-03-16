# EAX Druid Balance

EAX Druid Balance is a lightweight TBC-style Project Sylvanas rotation plugin for Balance Druids. It keeps Moonkin Form active, maintains `Moonfire` and `Insect Swarm`, uses `Faerie Fire` for armor reduction, and pivots between `Starfire` and `Wrath` based on available Eclipse-style buffs.

## Rotation

- Keep `Moonkin Form` active when the option is enabled.
- Refresh `Moonfire` and `Insect Swarm` inside the configured refresh window.
- Maintain `Faerie Fire` early so cast windows are not wasted on missing debuffs.
- Use `Force of Nature` after DoTs are established, and `Starfall` when enemy count or raid pressure justifies it.
- Default to `Starfire`, swapping to `Wrath` when a Lunar Eclipse-style buff is detected.

## Modes

- `Auto` resolves to `Solo`, `Dungeon`, or `Raid` from current group size.
- `Solo` stays conservative with cooldowns unless multiple enemies are close.
- `Dungeon` and `Raid` allow more aggressive `Starfall` and cooldown usage.

## Utility

- `Innervate` can recover mana automatically at a configurable threshold.
- `Tranquility` can be enabled as an emergency self-preservation button.
- Debug logging traces rotation decisions without changing the control panel footprint.

## Install

1. Put the `EAXDruidBalance` folder inside your Sylvanas `scripts` folder.
2. Reload Sylvanas or restart the client.
3. Open the menu and enable `EAX Druid Balance`.

## Notes

- Repo folder: `scripts/EAXDruidBalance`
- Plugin name in-game: `EAX Druid Balance`
- Files included: `header.lua`, `main.lua`, `menu.lua`, `spells.lua`, `utils.lua`, `README.md`
