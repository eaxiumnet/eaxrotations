# Rogue Subtlety — Implementation Checklist

**Spec:** Rogue Subtlety  
**Job:** 020  
**Date:** 2026-05-20  
**Files:** `EaxRotations/classes/rogue/class_sylvanas.lua`, `EaxRotations/classes/rogue/subtlety_sylvanas.lua`, `EaxRotations/classes/rogue/schema_sylvanas.lua`

---

## DB2 Corrections — class_sylvanas.lua

| # | Spell | Old Levels | New Levels (DB2) | Status |
|---|-------|-----------|-------------------|--------|
| 1 | Ambush | 70,62,54,46,38,30,18 | 66,58,50,42,34,26,18 | ✅ Fixed |
| 2 | Backstab | 70,62,52,44,36,28,20,14,8,4 | 68,60,60,52,44,36,28,20,12,4 | ✅ Fixed |
| 3 | Blind (CD) | cooldown=120 | cooldown=180 | ✅ Fixed |
| 4 | CloakOfShadows | 62 | 66 | ✅ Fixed |
| 5 | DeadlyThrow | 66 | 64 | ✅ Fixed |
| 6 | Envenom | 69,70,62 | 69,69,62 | ✅ Fixed |
| 7 | Evasion | 70,22 | 50,8 | ✅ Fixed |
| 8 | Eviscerate | 70,62,54,46,38,30,22,14,8,1 | 64,60,56,48,40,32,24,16,8,1 | ✅ Fixed |
| 9 | ExposeArmor | 70,64,56,48,40,32 | 66,56,46,36,26,14 | ✅ Fixed |
| 10 | Feint | 70,62,52,44,36,28,16 (7 levels for 6 IDs!) | 64,60,52,40,28,16 | ✅ Fixed |
| 11 | Garrote | 70,62,52,44,36,28,14 (7 levels for 8 IDs!) | 70,61,54,46,38,30,22,14 | ✅ Fixed |
| 12 | Gouge | 68,60,50,40,30,22 | 67,60,46,32,18,6 | ✅ Fixed |
| 13 | Hemorrhage | 70,62,54,40 | 70,58,46,30 | ✅ Fixed |
| 14 | KidneyShot | 60,30 | 50,30 | ✅ Fixed |
| 15 | Kick | {1769,1768,1767,1766} levels {24,18,12,6} | {38768,1769,1768,1767,1766} levels {69,58,42,26,12} | ✅ Fixed |
| 16 | Mutilate | 70,64,56,48 | 70,60,50,40 | ✅ Fixed |
| 17 | Rupture | 70,62,52,44,36,28,20 | 68,60,52,44,36,28,20 | ✅ Fixed |
| 18 | Sap | 62,52,24 | 48,28,10 | ✅ Fixed |
| 19 | SinisterStrike | 70,62,52,44,36,28,20,14,8,1 | 70,62,54,46,38,30,22,14,6,1 | ✅ Fixed |
| 20 | SliceAndDice | 60,30 | 42,10 | ✅ Fixed |
| 21 | Sprint | 64,54,22 | 58,34,10 | ✅ Fixed |
| 22 | Stealth | 60,50,40,30 | 60,40,20,1 | ✅ Fixed |
| 23 | Vanish | 70,40,22 | 62,42,22 | ✅ Fixed |

---

## Behavioral Requirements (Subtlety)

| # | Requirement | Research Source | Status | Notes |
|---|------------|----------------|--------|-------|
| 1 | Hemorrhage debuff maintenance at <3s refresh | Angle 5 | ✅ Present | `HEMO_REFRESH = 3`, `hemo_refresh_needed()` |
| 2 | Slice and Dice maintain 100% uptime | ST Priority | ✅ Present | `slice_remains > SND_REFRESH` |
| 3 | Rupture on long-lived targets | ST Priority | ✅ Present | `context.ttd` check, `RUPTURE_TTD_FLOOR` |
| 4 | Eviscerate when maintenance finishers safe | ST Priority | ✅ Present | Priority after Rupture/Expose |
| 5 | Hemorrhage as primary builder | ST Priority | ✅ Present | `hemorrhage_matches` with energy gate |
| 6 | Backstab positional burst only | ST Priority | ✅ Present | `is_behind` + energy >= 75 gate |
| 7 | Stealth opener: Ambush/Garrote/CheapShot | PvP Playstyle | ✅ Present | `opener_preference` with auto/caster/PvP logic |
| 8 | Sap from stealth (PvP) | PvP Playstyle | ✅ Present | `sap_matches` gates on stealth + OOC |
| 9 | Premeditation while stealthed | Angle 5 | ✅ Present | `premeditation_matches` checks `stealth_up` |
| 10 | Shadowstep for gap closing | Angle 5 | ✅ Present | `shadowstep_gap_matches` with 10-25yd range |
| 11 | Preparation resets Vanish/Sprint/Evasion | CD Usage | ✅ Present | `preparation_matches` checks CD states |
| 12 | Vanish defensive/re-burst | CD Usage | ✅ Present | `vanish_burst_matches` with HP and burst gates |
| 13 | Kidney Shot stun chain (PvP) | PvP | ✅ Present | `kidney_shot_matches` |
| 14 | Blind control (PvP) | PvP | ✅ Present | `blind_matches` |
| 15 | Gouge interrupt/control | PvP | ✅ Present | `gouge_matches` |
| 16 | Kick interrupt | Utility | ✅ Present | `kick_matches` |
| 17 | Cloak of Shadows defensive | Utility | ✅ Present | `cloak_matches` |
| 18 | Evasion defensive | Utility | ✅ Present | `evasion_matches` |
| 19 | Energy pooling < 40 (builder) / < 25 (finisher) | Resource Mgmt | ✅ Present | `energy_low`, `energy_pool_finisher` |
| 20 | Deadly Throw ranged finisher | PvP | ✅ Present | `deadly_throw_matches` |
| 21 | Expose Armor when assigned | PvE | ✅ Present | `expose_armor_matches` |
| 22 | Feint threat management | Threat Mgmt | ✅ Present | `feint_matches` |
| 23 | Ghostly Strike (PvP/survival) | Automation Notes | ✅ Present | `ghostly_strike_matches` |
| 24 | Sprint gap closer | Utility | ✅ Present | `sprint_gap_matches` |
| 25 | Sinister Strike fallback builder | — | ✅ Present | `fallback_builder_matches` |

---

## Forbidden Mechanics Check

| Mechanic | Status |
|----------|--------|
| Shadow Dance | ✅ Absent |
| Fan of Knives | ✅ Absent |
| Honor Among Thieves | ✅ Absent |
| Tricks of the Trade | ✅ Absent |
| Killing Spree | ✅ Absent |
| WotLK+ abilities | ✅ None present |

---

## Schema Verification

| Key | Type | Default | Status |
|-----|------|---------|--------|
| shadowstep_usage | dropdown | always | ✅ Present |
| shadowstep_min_range | slider | 10 | ✅ Present |
| hemo_debuff_priority | checkbox | true | ✅ Present |
| opener_preference | dropdown | auto | ✅ Present |
| subtetly_prep_hp | slider | 40 | ✅ Present |
| subtetly_feint_threat | slider | 90 | ✅ Present |

---

## Validation

- ✅ `luac -p` passes on all modified files
- ✅ Code review cleared
- ✅ 23/23 DB2 level corrections applied
- ✅ 25/25 behavioral requirements Present
- ✅ 0 forbidden mechanics present

---

## Remaining Risk

- Premeditation level (56) kept as-is — DB2 shows talent-point requirement (20) not character level
- GhostlyStrike level (56) kept as-is — talent spell with no reliable DB2 character level
- ColdBlood level (40) kept as-is — talent spell
