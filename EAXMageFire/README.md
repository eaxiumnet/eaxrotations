# EAX Mage Fire

Minimal Fire Mage rotation for TBC-flavored Project Sylvanas play.

## What It Is

`EAXMageFire` is a lightweight Fire Mage plugin centered on Scorch stack upkeep, Fireball filler casts, and Combustion burst support.

## Rotation

- **Setup** - `Scorch` builds and refreshes Fire Vulnerability stacks.
- **Primary** - `Fireball` is the default filler.
- **Burst** - `Combustion` and self-cast trinkets line up in combat.
- **Proc Window** - `Pyroblast` is reserved for available burst/proc windows.
- **Movement** - `Fire Blast` is the moving fallback.

## Modes

- **Auto** - Detects group size from party members.
- **Solo** - Conservative trinket usage unless already bursting.
- **Dungeon** - Standard Scorch maintenance with burst on pull.
- **Raid** - Full Scorch stack support for raid debuff maintenance.

## Install

1. Put the `EAXMageFire` folder inside your Sylvanas `scripts` folder.
2. Reload Sylvanas or restart the client.
3. Open the menu and enable `EAX Mage Fire`.

## Notes

- Folder: `scripts/EAXMageFire`
- Spec gate: Mage Fire (`get_specialization_id() == 2`)
- Primary design target: Scorch / Fireball / Combustion
