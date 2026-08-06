# EaxRotations Spell Coverage Audit

**Generated**: 2026-06-09
**Method**: Parse `NS.spell_action({...})` blocks from every `.lua` in `EaxRotations/classes/*/`, extract spell IDs, then cross-reference against canonical WoW spell corpus in `wowhead_data/corpus/{tbc,vanilla}/spells.jsonl` (837 TBC + 639 Vanilla class spells).

**Coverage rule**: A corpus spell is 'covered' if ANY rank of that spell (any of its spell IDs) is referenced in any EaxRotations file. Different ranks share a spell name; rotations only need to reference one rank to be considered covered.

---

## Summary

| Class | TBC corpus families | TBC covered | TBC missing | Van corpus families | Van covered | Van missing |
|-------|--------------------:|------------:|------------:|--------------------:|------------:|------------:|
| Warrior | 27 | 27 | 0 | 24 | 24 | 0 |
| Paladin | 19 | 19 | 0 | 15 | 15 | 0 |
| Hunter | 18 | 17 | 1 | 14 | 13 | 1 |
| Rogue | 15 | 15 | 0 | 15 | 15 | 0 |
| Priest | 26 | 22 | 4 | 17 | 16 | 1 |
| Shaman | 20 | 19 | 1 | 17 | 16 | 1 |
| Mage | 21 | 20 | 1 | 13 | 12 | 1 |
| Warlock | 20 | 18 | 2 | 11 | 9 | 2 |
| Druid | 37 | 37 | 0 | 33 | 33 | 0 |
| **TOTAL** | **203** | **194** | **9** | **159** | **153** | **6** |

**TBC coverage: 95.6%** (194/203)

**Vanilla coverage: 96.2%** (153/159)

## Missing spells by class

### Warrior

_Full coverage in both TBC and Vanilla._

### Paladin

_Full coverage in both TBC and Vanilla._

### Hunter

**TBC missing (1)**:

- `14315` Explosive Trap Effect

**Vanilla missing (1)**:

- `14315` Explosive Trap Effect

### Rogue

_Full coverage in both TBC and Vanilla._

### Priest

**TBC missing (4)**:

- `34754` Clearcasting
- `34860` Holy Concentration
- `33154` Surge of Light
- `6788` Weakened Soul

**Vanilla missing (1)**:

- `6788` Weakened Soul

### Shaman

**TBC missing (1)**:

- `25360` Grace of Air

**Vanilla missing (1)**:

- `25360` Grace of Air

### Mage

**TBC missing (1)**:

- `22959` Fire Vulnerability

**Vanilla missing (1)**:

- `22959` Fire Vulnerability

### Warlock

**TBC missing (2)**:

- `17937` Curse of Shadow
- `17935` Major Firestone Attack

**Vanilla missing (2)**:

- `17937` Curse of Shadow
- `17935` Major Firestone Attack

### Druid

_Full coverage in both TBC and Vanilla._

