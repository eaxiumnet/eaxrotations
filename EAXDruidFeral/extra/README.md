# EAX Druid Feral — v2.1.0

Dual-lane Cat DPS and Bear Tank automation for TBC Feral Druid on Project Sylvanas.

## Rotation

### Cat (DPS)
- Maintains `Mangle (Cat)` debuff and `Rake` bleed uptime.
- Builds combo points with `Shred` (from behind) or `Claw`/`Mangle` as fallback.
- Spends CPs on `Rip` first, then `Ferocious Bite` in execute windows when Rip is stable.
- Uses `Tiger's Fury` for energy recovery. `Maim` as a stun finisher when not behind.
- Opens from stealth with `Pounce` (stun) or `Ravage` (high damage).
- `Feral Charge` closes the gap from range then shifts back to Cat once in melee.

### Bear (Tank)
- Maintains `Mangle (Bear)`, `Demoralizing Roar`, `Lacerate`, and `Faerie Fire (Feral)`.
- Queues `Maul` as a rage dump. `Swipe` when pack size hits the configured threshold.
- Auto-casts `Growl` when the current target is not targeting you.
- `Frenzied Regeneration` and `Berserk` for survival and threat windows.

## CC & Utility (new in 2.1.0)
- **War Stomp** — fires automatically when 2+ melee attackers are in range or HP < 35%.
- **Cyclone** — fires automatically when the target is a healer actively healing an enemy.
- **Entangling Roots** — fires automatically when the target is kiting (moving, out of melee).

## Form Management (updated in 2.1.0)
- OOC: stays in Travel Form. Combat forms only engage when in combat.
- After Feral Charge (Bear), waits until in melee range before shifting back to Cat.
- Travel Form re-applied automatically when leaving combat.

## Combo Points (fixed in 2.1.0)
- Now reads via `me:get_power(enums.power_type.COMBOPOINTS_TBC)` on the player.
- Previous builds called `get_power()` on the target mob which always returned 0.
- Cast-callback fallback still active as last resort.

## Menu Options
- Lane: Auto / Force Cat / Force Bear
- Auto Form, Powershift (Wolfshead), Feral Charge
- Use Shred, Mangle, Rake, Rip, Ferocious Bite, Tiger's Fury, Maim, Pounce, Ravage
- Use War Stomp, Cyclone, Entangling Roots
- Bear: Mangle, Maul, Swipe, Growl, Frenzied Regeneration, Berserk, Bash
- HP thresholds for Frenzied Regeneration and Ferocious Bite

## Install
1. Extract `EAXDruidFeral` into your Sylvanas `scripts` folder.
2. Reload or restart.
3. Enable `EAX Druid Feral` in the menu.
