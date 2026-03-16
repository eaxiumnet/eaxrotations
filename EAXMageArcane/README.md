# EAX Mage Arcane

Minimal Arcane Mage rotation for TBC-flavored Project Sylvanas play.

## What It Is

`EAXMageArcane` is a lightweight Arcane Mage plugin focused on Arcane Blast pressure, Arcane Missiles stack dumps, mana gem support, and Evocation recovery.

## Rotation

- **Burst** - `Arcane Power` and self-cast trinkets open high-mana burn windows.
- **Primary** - `Arcane Blast` builds and sustains pressure.
- **Stack Dump** - `Arcane Missiles` clears stacked `Arcane Blast` pressure in sustain windows, on Clearcasting, or when mana dips.
- **Movement** - `Fire Blast` is the moving fallback.

## Mana

- **Mana Gem** below a configurable mana threshold while in combat.
- **Evocation** below a configurable mana threshold when Arcane needs to recover.

## Modes

- **Auto** - Detects group size from party members.
- **Solo** - Looser burst gating to keep questing fluid.
- **Dungeon** - Balanced burn and sustain.
- **Raid** - Higher mana requirement before opening burst cooldowns.

## Install

1. Put the `EAXMageArcane` folder inside your Sylvanas `scripts` folder.
2. Reload Sylvanas or restart the client.
3. Open the menu and enable `EAX Mage Arcane`.

## Notes

- Folder: `scripts/EAXMageArcane`
- Spec gate: Mage Arcane (`get_specialization_id() == 1`)
- Primary design target: Arcane Blast / Arcane Missiles / Arcane Power / Evocation
