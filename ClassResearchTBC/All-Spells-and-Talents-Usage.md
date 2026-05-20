# All Spells and Talents Usage Index

This pass adds usage tags on top of the DB2 class spell/talent extracts. The CSVs are intentionally broad: they include rank rows, passives, utility, PvP/control, healing, tanking, and damage entries so no class spellbook area is invisible.

## Files

- `All-Spells-Usage-Index.csv` - every DB2 class/pet skill-line ability row with usage and playstyle tags.
- `All-Talents-Usage-Index.csv` - every DB2 talent row with usage and playstyle tags.

## Spell Usage Counts by Class

| Class | Damage | Healing | Tanking | PvP/control | Talent/passive | Utility/rank |
|---|---:|---:|---:|---:|---:|---:|
| Druid | 48 | 50 | 16 | 1 | 66 | 267 |
| Hunter | 74 | 2 | 8 | 37 | 53 | 698 |
| Mage | 100 | 11 | 0 | 9 | 43 | 288 |
| Paladin | 109 | 38 | 5 | 0 | 53 | 248 |
| Pet | 0 | 0 | 8 | 0 | 0 | 94 |
| Priest | 49 | 108 | 0 | 11 | 62 | 258 |
| Rogue | 28 | 0 | 0 | 11 | 57 | 257 |
| Shaman | 38 | 87 | 0 | 2 | 64 | 262 |
| Warlock | 82 | 24 | 0 | 6 | 43 | 428 |
| Warrior | 65 | 26 | 27 | 8 | 90 | 165 |

## Usage

- Use `UsageTag` to decide whether a spell belongs in a DPS, healing, tanking, PvP, passive, or utility review.
- Use `PlaystyleTags` for automation buckets such as `single-target`, `multi-target`, `healing`, `tanking`, `pvp`, `dispel-cleanse`, and `state-maintenance`.
- The tags are research labels, not runtime authority. DB2 spell IDs remain the authoritative identifiers.
