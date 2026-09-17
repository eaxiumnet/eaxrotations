# WoW Forever — Racial & Talent research (era-wide)

> SAFETY: spell IDs below are DBC-verified (beta 1.60.1.69893, 2026-09-17)
> unless marked [PROBE]; see docs/forever/dbc_runbook.md.

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

Beta DBC evidence (2026-09-17): `ChrRaces` carries **High Order Skyborne**
(id 95, StartingLevel 1) and **Windshaper Skyborne** (id 96, StartingLevel
1) — StartingLevel 1 matches the Zephras 1–12 claim. Touch of the Grave
resolves as 1260189 / 1260198 / 1260201 (Undead proc family); per-tick vs
ICD semantics need in-game observation (P3 item stays open).

### EAX follow-ups (Phase 5)
- `shared/racial_manager_sylvanas.lua`: Forever racial tables guarded by
  `is_forever()`; new actives castable, passives folded into stat reads.
- Race/class combo validation must accept the six new combos + Skyborne.
- Racial autocast/battery lanes: strict never=0 — every new active needs a
  battery-observable scenario.

## Talent framework (Deep Dive 2026-09-13)

- Familiar 1.12 tree structure: **confirmed** — 7 rows per spec tree, 51
  points, gold-medal one-pointers at 11/21/31 **plus a fourth at 16 points**
  (four special one-point abilities per tree; Zierhut quote via Icy Veins
  talent-calculator article, 2026-09-16).
- **Baseline now**: Divine Spirit, Blessing of Kings, Improved Mark of the Wild
  (their old talents are gone/reworked).
- Stated goal: every tree viable for dungeons or raids.

### EAX follow-ups (Phase 5)
- `shared/talent_inference_sylvanas.lua`: Forever mode treats the three
  key-buff talents as baseline (always-on context fields, no talent probe).
- 16-point milestone: Beta DBC evidence (2026-09-17) — `Talent` carries 432
  rows over 27 `TalentTab` rows (9 classes × 3, classic 1.12 structure with
  standard TierID 0–6 rows); **no milestone-specific column exists**, so the
  16-point slot is not DBC-distinguishable from the 11/21/31 slots — map it
  in-game (talent UI), not from DB2. Until then no inference changes. The
  Icy Veins calculator's individual talent names/ranks are community
  reproductions: treat them as unverified until the beta DBC lands (DBC remains the source of truth; calculator data is
  a preview aid for the per-class watch lists, not rotation logic).
