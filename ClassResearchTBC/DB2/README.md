# DB2 Cross-Check Extracts

Generated: 2026-05-18.

Source: Wago Tools DB2 CSV export with `branch=wow_anniversary`.

Observed current build from `https://wago.tools/builds` during this pass:

- Product: `wow_anniversary`
- Version: `2.5.5.67511`
- Created: `2026-05-14 19:04:06`

These files are database-backed cross-check indexes for TBC Classic Anniversary class abilities and talents. They are intended to verify spell IDs, ranks, talent trees, spell power costs, cooldowns, categories, class masks, and effects before rotation code changes.

## Files

- `wago_anniversary_class_skilllines.csv` - all DB2 `SkillLine` rows with `CategoryID=7`, plus inferred class labels where applicable.
- `wago_anniversary_class_skillline_abilities.csv` - all `SkillLineAbility` rows for class-category skill lines, joined with `SpellName`.
- `wago_anniversary_talents_by_tree.csv` - all 579 TBC class talent entries across the 27 talent trees, joined with talent tab and spell-rank names.
- `wago_anniversary_class_spell_levels.csv` - filtered `SpellLevels` rows for spell IDs used by class skill-line abilities and talents.
- `wago_anniversary_class_spell_power.csv` - filtered `SpellPower` rows for class/talent spell IDs.
- `wago_anniversary_class_spell_cooldowns.csv` - filtered `SpellCooldowns` rows for class/talent spell IDs.
- `wago_anniversary_class_spell_categories.csv` - filtered `SpellCategories` rows for class/talent spell IDs.
- `wago_anniversary_class_spell_class_options.csv` - filtered `SpellClassOptions` rows for class/talent spell IDs.
- `wago_anniversary_class_spell_effects.csv` - filtered `SpellEffect` rows for class/talent spell IDs.
- `wago_anniversary_db2_counts.csv` - row counts for the generated extracts.
- `wago_anniversary_itemset.csv` - DB2 `ItemSet` rows used by the S+ gear/set-piece pass.
- `wago_anniversary_itemsetspell.csv` - set-bonus spell mapping with threshold counts and item set IDs.
- `wago_anniversary_item.csv` - item rows used for item IDs and base item metadata.
- `wago_anniversary_itemsparse.csv` - item names and sparse item metadata used to label set pieces.
- `wago_anniversary_spellname.csv` - global spell names used to label set-bonus spell IDs.
- `wago_anniversary_spell.csv` - global spell descriptions and aura descriptions used to explain set bonuses.
- `wago_anniversary_spellauraoptions.csv` - global aura/proc metadata kept for later set/proc validation.
- `wago_anniversary_itemset_counts.csv` - row counts for the item/set/spell expansion CSVs.

## Counts

From `wago_anniversary_db2_counts.csv`:

- Class skill lines: 60
- Class skill-line ability rows: 4,584
- Talent rows: 579
- Unique class/talent spell IDs selected for metadata filtering: 4,296
- Filtered `SpellEffect` rows: 6,118

Additional S+ item/set DB2 rows:

- Item sets: 388
- Item-set bonus rows: 883
- Items: 30,057
- Item sparse rows: 30,044
- Spell names: 28,650
- Spell description rows: 28,650
- Spell aura option rows: 14,473

Talent row counts by class:

- Druid: 62
- Hunter: 64
- Mage: 67
- Paladin: 64
- Priest: 64
- Rogue: 67
- Shaman: 61
- Warlock: 64
- Warrior: 66

## How to Re-Check

Download a DB2 table from Wago Tools:

```powershell
Invoke-WebRequest -Uri "https://wago.tools/db2/SpellName/csv?branch=wow_anniversary" -UseBasicParsing
```

Useful DB2 tables for class research:

- `SkillLine` - class/spec/pet spellbook categories.
- `SkillLineAbility` - maps spell IDs into class/spec/pet skill lines.
- `TalentTab` - 27 class talent tree tabs.
- `Talent` - talent positions, prerequisites, and rank spell IDs.
- `SpellName` - spell ID to localized spell name.
- `SpellLevels` - spell level and base level data.
- `SpellPower` - mana/resource cost data.
- `SpellCooldowns` - cooldown and GCD data.
- `SpellCategories` - school/category/mechanic/dispel metadata.
- `SpellClassOptions` - spell class masks.
- `SpellEffect` - effect, aura, coefficient, trigger, radius, and misc values.

## Caveats

- Wago Tools is JavaScript-only in browser, but CSV export works directly.
- `wow_anniversary` is the current TBC Classic Anniversary branch. For old private-server-style 2.4.3 validation, also compare TBCDB, WoWClassicDB, Wowhead TBC, and the `tbctalentcalculator.net` 2.4.3 talent calculator.
- Generated `InferredClass` values are helper labels derived from known TBC class skill-line IDs. The underlying DB2 IDs/rows are the authoritative part.
- Pet skill lines are included. `Pet - Generic` is labeled as `Pet` because it is shared and should not be forced into one player class without a separate pet-family pass.
