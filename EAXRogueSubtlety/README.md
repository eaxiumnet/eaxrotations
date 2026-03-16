# EAX Rogue Subtlety

Minimal Subtlety Rogue rotation for TBC.

## What It Is

`EAXRogueSubtlety` is a lightweight Project Sylvanas plugin for Subtlety Rogues. It focuses on stealth openers, combo-point burst finishers, and Backstab-first combat with Hemorrhage fallback.

## Rotation

- **Premeditation** starts the opener when available.
- **Cheap Shot** is preferred in dungeon and raid control windows.
- **Ambush** is the default stealth damage opener.
- **Slice and Dice** refreshes before heavy finishers.
- **Rupture** handles sustained targets.
- **Eviscerate** handles burst finishers.
- **Backstab** is the primary builder, with **Hemorrhage** as fallback.

## Burst Tools

- **Shadowstep** helps re-enter burst range during non-solo modes.
- **Preparation** is reserved for raid-style reset windows.

## Modes

- **Auto** detects Solo, Dungeon, or Raid from group state.
- **Solo** emphasizes clean stealth openers and direct damage.
- **Dungeon** favors Cheap Shot control before Ambush-style pressure.
- **Raid** keeps the same stealth opener flow and enables Preparation-based reset logic.

## Install

1. Put the `EAXRogueSubtlety` folder inside your Sylvanas `scripts` folder.
2. Reload Sylvanas or restart the client.
3. Open the menu and enable `EAX Rogue Subtlety`.

## Notes

- Current repo folder: `EAXRogueSubtlety`
- Plugin name in-game: `EAX Rogue Subtlety`
- Required files: `header.lua`, `main.lua`, `menu.lua`, `spells.lua`, `utils.lua`, `README.md`
