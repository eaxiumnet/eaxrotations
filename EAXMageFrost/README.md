# EAX Mage Frost

Minimal Frost Mage rotation for TBC-flavored Project Sylvanas play.

## What It Is

`EAXMageFrost` is a lightweight Frost Mage plugin built around Frostbolt filler casts, Ice Lance opportunism, and the Frost cooldown package.

## Rotation

- **Burst** - `Summon Water Elemental`, `Icy Veins`, and self-cast trinkets in combat.
- **Proc Window** - `Fireball` is available when a Brain Freeze style buff is detected.
- **Priority** - `Ice Lance` on frozen, proc-supported, or low-health targets.
- **Primary** - `Frostbolt` is the default filler.

## Modes

- **Auto** - Detects group size from party members.
- **Solo** - Holds trinkets unless a burst buff is already active.
- **Dungeon** - Standard cooldown cadence for packs and bosses.
- **Raid** - Full cooldown alignment and sustained Frostbolt priority.

## Install

1. Put the `EAXMageFrost` folder inside your Sylvanas `scripts` folder.
2. Reload Sylvanas or restart the client.
3. Open the menu and enable `EAX Mage Frost`.

## Notes

- Folder: `scripts/EAXMageFrost`
- Spec gate: Mage Frost (`get_specialization_id() == 3`)
- Primary design target: Frostbolt / Water Elemental / Ice Lance / Icy Veins
