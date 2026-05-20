# All Spells Timing Index

This is the down-to-seconds pass for all DB2 class and pet skill-line spell rows. Values are generated from Wago Tools `wow_anniversary` DB2 exports.

Blank means no joined DB2 row was present in the pulled timing table. `0` means the DB2 timing row reports zero milliseconds.

## Generated File

- `All-Spells-Timing-Index.csv`

## Timing Coverage By Class

| Class | Spell rows | Cast-time rows | GCD rows | Cooldown rows | Duration rows |
|---|---:|---:|---:|---:|---:|
| Druid | 448 | 63 | 231 | 13 | 327 |
| Hunter | 872 | 57 | 470 | 18 | 420 |
| Mage | 451 | 107 | 234 | 19 | 341 |
| Paladin | 453 | 41 | 196 | 9 | 318 |
| Pet | 102 | 0 | 8 | 1 | 86 |
| Priest | 488 | 88 | 264 | 9 | 352 |
| Rogue | 353 | 28 | 105 | 10 | 216 |
| Shaman | 453 | 50 | 233 | 10 | 310 |
| Warlock | 583 | 104 | 285 | 5 | 405 |
| Warrior | 381 | 6 | 113 | 11 | 254 |

## Timing Columns

- `CastTimeSec`: spell cast time in seconds from `SpellMisc.CastingTimeIndex -> SpellCastTimes.Base`.
- `GCDSec`: start recovery/GCD in seconds from `SpellCooldowns.StartRecoveryTime`.
- `CooldownSec`: spell recovery/cooldown in seconds from `SpellCooldowns.RecoveryTime`.
- `CategoryCooldownSec`: category cooldown in seconds from `SpellCooldowns.CategoryRecoveryTime`.
- `DurationSec`: aura/effect duration in seconds from `SpellMisc.DurationIndex -> SpellDuration.Duration`.
- `RangeMinYd` and `RangeMaxYd`: range row from `SpellMisc.RangeIndex -> SpellRange`.
- `PowerCost`, `RequiredTotems`, `RequiredReagents`, and equipped-item columns expose spell constraints useful for automation.
