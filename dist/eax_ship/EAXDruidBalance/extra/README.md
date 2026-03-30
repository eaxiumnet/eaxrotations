# EAX Druid Balance — v2.1.0

Balance Druid (Moonkin) automation for TBC on Project Sylvanas.

## Rotation
- Applies `Faerie Fire` to boss or elite targets when missing.
- Maintains `Moonfire` and `Insect Swarm` DoT uptime.
- Uses `Hurricane` on 3+ target packs when mana allows.
- `Force of Nature` on cooldown when available.
- Primary filler: `Starfire` when stationary and in range; falls back to `Wrath` when needed.
- Uses `Innervate` for low mana and `Tranquility` as an emergency self-save.

## New in 2.1.0
- **TBC Cleanup:** Removed Wrath-only `Eclipse`, `Starfall`, `Typhoon`, and `Berserk` logic.
- **Moonkin Priority:** Rebuilt around TBC DoT upkeep into `Starfire`/`Wrath` filler casting.
- **Tranquility:** Enabled by default for group emergency healing.
- **Mark of the Wild:** OOC group buffing now working correctly.

## Menu Options
- Use Faerie Fire, Moonfire, Insect Swarm, Force of Nature
- Use Hurricane, Innervate, Tranquility, and DoT refresh tuning

## Install
1. Extract `EAXDruidBalance` into your Sylvanas `scripts` folder.
2. Reload or restart.
3. Enable `EAX Druid Balance` in the menu.
