# EAX Druid Restoration

EAX Druid Restoration is a Project Sylvanas healing plugin focused on HoT coverage, Lifebloom maintenance, and emergency cooldown timing. It keeps a primary tank target stabilized with `Lifebloom`, spreads `Rejuvenation` and `Regrowth` to injured allies, and escalates into `Swiftmend`, `Wild Growth`, `Tranquility`, or `Nature's Swiftness` when damage spikes.

## Healing Priorities

- Maintain `Lifebloom` stacks on the primary tank target.
- Refresh `Rejuvenation` on the current priority heal target before it falls off.
- Use `Regrowth` as the heavier HoT/direct-heal bridge when damage continues.
- Trigger `Swiftmend` when a HoT is already present and the target drops below the configured health threshold.
- Use `Wild Growth` and `Tranquility` only when enough allies are injured.

## Mode Handling

- `Auto` resolves to `Solo`, `Dungeon`, or `Raid` from current group size.
- `Solo` defaults the tank target to yourself.
- `Dungeon` and `Raid` prefer a real tank role when one is visible in the object list.
- `Mana Saver` delays expensive spells unless the situation is urgent.

## Utility

- `Innervate` recovers mana automatically at a configurable threshold.
- `Nature's Swiftness` pairs with `Regrowth` for emergency saves when `Swiftmend` is not available.
- `Mark of the Wild` can be refreshed out of combat as a light maintenance buff.

## Install

1. Put the `EAXDruidRestoration` folder inside your Sylvanas `scripts` folder.
2. Reload Sylvanas or restart the client.
3. Open the menu and enable `EAX Druid Restoration`.

## Notes

- Repo folder: `scripts/EAXDruidRestoration`
- Plugin name in-game: `EAX Druid Restoration`
- Files included: `header.lua`, `main.lua`, `menu.lua`, `spells.lua`, `utils.lua`, `README.md`
