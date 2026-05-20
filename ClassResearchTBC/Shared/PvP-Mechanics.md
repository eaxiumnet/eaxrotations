# PvP Mechanics

S+ pass shared PvP rules for TBC rotation research. PvP automation should be defensive, interrupt-aware, and matchup-aware; it should not blindly run a PvE damage loop.

## Global Rules

| Situation | Rule | Automation note |
|---|---|---|
| Enemy healer free-casting | Interrupt, CC, purge/dispel, or force movement before damage padding | High priority if cast is lethal or stabilizing |
| Player controlled | Use trinket/defensive only for lethal setups or assigned CC chains | Avoid wasting PvP trinket on low-value CC |
| Burst window available | Confirm target is controlled, healer is interrupted/CCed, and defensive immunity is absent | Burst requires state checks, not cooldown spam |
| Defensive pressure | Use class defensive before lethal threshold when enemy cooldowns are active | Threshold depends on class and healer status |
| Dispel target | Offensive dispel enemy buffs; defensive dispel magic/poison/disease/curse when lethal | Dispel can outrank damage/healing filler |
| DR-sensitive CC | Avoid reapplying the same CC family into low duration unless it secures a kill | Track diminishing returns if API/local code supports it |

## Class PvP Summaries

- **Druid:** Use mobility, forms, Cyclone, roots, HoTs, and shapeshift snare breaks. Feral wins with control into burst; Restoration wins by pre-HoT and line-of-sight; Balance wins by burst windows and control.
- **Hunter:** Win through range control, trap chains, pet pressure, Viper Sting, Scatter/Wyvern where talented, flare, and kiting. Do not let melee sit in dead-zone style pressure.
- **Mage:** Control first: Polymorph, Counterspell, novas, slows, Spellsteal, and Ice Block. Burst only when the target is controlled or interrupts are forced.
- **Paladin:** Use blessings, Cleanse, bubble, Freedom, BoP, auras, stun, and judgement pressure. Ret relies on burst and dispel support; Holy relies on efficient casting and defensive cooldowns.
- **Priest:** Dispel wins games. Use shields, fears, Mana Burn, defensive dispels, offensive dispels, and LoS. Shadow pressures with DoTs and silence; healers survive through triage and control.
- **Rogue:** Open from stealth with a plan: sap one, lock one, blind/trinket punish, and reset with Vanish. Energy pooling and DR awareness matter more than raw button speed.
- **Shaman:** Grounding, Tremor, Earth Shock, Purge, Bloodlust/Heroism, and totem management define PvP value. Enhancement uses burst; Elemental uses control burst; Restoration wins through totem utility and Chain Heal/LHW triage.
- **Warlock:** Fear/DoT/pet control and drain pressure. Protect pet, use curses by matchup, Banish/enslave demons, and do not overextend while dots do the work.
- **Warrior:** Uptime and rage are everything. Hamstring, Intercept, Pummel, Disarm, stance utility, and healer coordination decide whether pressure sticks.

## Source and Local Reference Notes

- Use class PvP guide links in `Sources.md` where available.
- Sonah local PvP modules are useful for toggles, enemy state, swing timers, and player-vs-player utility patterns.
- Project Sylvanas implementations should nil-guard menus and avoid assuming PvP-only API state exists.
