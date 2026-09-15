# WoW Forever — Racial & Talent research (era-wide)

> SAFETY: names/semantics only; NO spell IDs until the Forever DBC lands
> (docs/forever/dbc_runbook.md).

## Racial framework (Deep Dive 2026-09-13)

Every race ships **2 active + 2 passive** abilities, retuned so each race is
useful for all its classes/specs with similar offensive power.

### Confirmed reworks
| Race | Ability | Change |
|---|---|---|
| Dwarf | Stoneform | Keeps Bleed/Poison/Disease removal + immunity; bonus now **reduces Physical damage taken** (was armor) |
| Dwarf | Mace Specialization | **Crit with all spells and abilities** while a mace is equipped |
| Dwarf | Find Treasure | Can stay active alongside other tracking |
| Dwarf | Big Game Hunter | +damage vs Beasts |
| Undead | Will of the Forsaken | Removes Charm/Fear/Sleep; **no longer grants immunity** |
| Undead | Cannibalize | Restores **mana as well as health** |
| Undead | Touch of the Grave | NEW damage passive: attacks may drain life |
| Undead | Underwater Breathing | Unchanged |

### New race/class combos
Gnome Priest, Human Hunter, Dwarf Shaman, Orc Mage, Troll Warlock,
**Undead Paladin**.

### New race: Skyborne
Horde-aligned: Shaman. Alliance-aligned: Mage. Both: Warrior, Hunter, Rogue,
Druid (custom druid forms). Zephras Isle starting experience (1–12).

### EAX follow-ups (Phase 5)
- `shared/racial_manager_sylvanas.lua`: Forever racial tables guarded by
  `is_forever()`; new actives castable, passives folded into stat reads.
- Race/class combo validation must accept the six new combos + Skyborne.
- Racial autocast/battery lanes: strict never=0 — every new active needs a
  battery-observable scenario.

## Talent framework (Deep Dive 2026-09-13)

- Familiar 1.12 tree structure, same row count.
- Milestone one-pointers at 11/21/31 **plus a NEW 16-point milestone**.
- **Baseline now**: Divine Spirit, Blessing of Kings, Improved Mark of the Wild
  (their old talents are gone/reworked).
- Stated goal: every tree viable for dungeons or raids.

### EAX follow-ups (Phase 5)
- `shared/talent_inference_sylvanas.lua`: Forever mode treats the three
  key-buff talents as baseline (always-on context fields, no talent probe).
- 16-point milestone: once beta shows the Talent DB2 shape, map it; until then
  no inference changes.
