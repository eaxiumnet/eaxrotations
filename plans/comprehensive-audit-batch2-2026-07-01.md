# Comprehensive Audit — Batch 2: Vanilla Leveling Spell Coverage

**Started:** 2026-07-01
**Status:** COMPLETE — all 12 spells added, nil-guard fixes applied, 214+13 tests pass

## Web Verification (2026-07-01)

All 12 spell IDs verified against 4 authoritative sources:

| Spell | ID | DBC | Wowhead Classic | wowsims_classic | Existing Vanilla Specs |
|-------|-----|-----|-----------------|-----------------|----------------------|
| RaptorStrike | 2973 | ✅ | ✅ (lvl 1, Hunter) | ✅ | ✅ survival_vanilla |
| MongooseBite | 1495 | ✅ | ✅ (lvl 16, Hunter) | ✅ | ✅ survival_sylvanas |
| Fireball | 133 | ✅ | ✅ (lvl 1, Mage) | ✅ | ✅ fire_vanilla |
| Sap | 6770 | ✅ | ✅ (lvl 10, Rogue) | ✅ | ✅ subtlety_vanilla |
| VampiricEmbrace | 15286 | ✅ | ✅ (talent lvl 40, Priest) | ✅ | ✅ shadow_vanilla |
| DesperatePrayer | 13908 | ✅ | ✅ (lvl 10, Priest racial) | ❌ (sim doesn't model racials) | ✅ priest class_sylvanas |
| Stormstrike | 17364 | ✅ | ✅ (talent lvl 40, Shaman) | ✅ | ✅ enhancement_vanilla |
| Pummel | 6552 | ✅ | ✅ (lvl 38, Warrior) | ✅ | ✅ fury_vanilla |
| Bloodthirst | 23881 | ✅ | ✅ (talent lvl 40, Warrior) | ✅ | ✅ fury_sylvanas |
| ShieldSlam | 23922 | ✅ | ✅ (talent lvl 40, Warrior) | ✅ | ✅ protection_sylvanas |
| HolyShield | 20925 | ✅ | ✅ (talent lvl 40, Paladin) | ✅ | ✅ protection_vanilla |
| RetributionAura | 7294 | ✅ | ✅ (lvl 16, Paladin) | ✅ | ✅ retribution_sylvanas |

**Result: 12/12 confirmed Classic-valid.** DesperatePrayer is a Dwarf/Human priest racial spell (level 10 quest) — not modeled in wowsims_classic (which doesn't simulate racials) but confirmed on Wowhead Classic and present in the DBC.

## Context

Systematic audit of all 9 class leveling rotations (TBC vs vanilla parity).
Found 8 confirmed Classic-valid spells missing from vanilla leveling files.

## Findings: Missing Spells in Vanilla Leveling

### Confirmed Classic-valid (used in existing *_vanilla.lua spec files)

| # | Class | Spell | Used in vanilla spec | Level | Category |
|---|-------|-------|---------------------|-------|----------|
| 1 | Hunter | RaptorStrike | survival_vanilla.lua | 6 | Melee weave |
| 2 | Mage | Fireball | arcane_vanilla, fire_vanilla | 6 | Core nuke |
| 3 | Rogue | Sap | subtlety_vanilla.lua | 10 | CC (OOC stealth) |
| 4 | Priest | VampiricEmbrace | shadow_vanilla.lua | 30 | Self-heal buff |
| 5 | Warrior | Pummel | fury_vanilla, protection_vanilla | 24 | Interrupt |
| 6 | Shaman | Stormstrike | enhancement_vanilla.lua | 40 | Melee attack |
| 7 | Priest | DesperatePrayer | holy_vanilla.lua | 18 | Emergency heal |
| 8 | Paladin | HolyShield | protection_vanilla.lua | 30 | Defensive |

### Correctly excluded (TBC-only or handled elsewhere)
- IceLance, WaterElemental (Mage) — TBC-only
- SealBlood, SealOfTheMartyr (Paladin) — TBC-only (backported to 2.5.5)
- ShadowWordDeath, VampiricTouch, Shadowfiend (Priest) — TBC-only
- SteadyShot (Hunter) — TBC-only
- Bloodthirst, ShieldSlam, Rampage, VictoryRush (Warrior) — TBC talents or not in vanilla specs
- FelArmor, SummonFelguard (Warlock) — TBC-only
- MangleBear, MangleCat (Druid) — TBC-only
- CrusaderStrike, RetributionAura (Paladin) — TBC-only or not in vanilla specs

## Plan (per class, atomic commits)

### Wave 1: Hunter + Mage + Rogue (3 files)
- Add RaptorStrike to `hunter/leveling_vanilla.lua`
- Add Fireball to `mage/leveling_vanilla.lua`
- Add Sap to `rogue/leveling_vanilla.lua`

### Wave 2: Priest + Shaman (2 files)
- Add VampiricEmbrace + DesperatePrayer to `priest/leveling_vanilla.lua`
- Add Stormstrike to `shaman/leveling_vanilla.lua`

### Wave 3: Warrior + Paladin (2 files)
- Add Pummel to `warrior/leveling_vanilla.lua`
- Add HolyShield to `paladin/leveling_vanilla.lua`

### Wave 4: Test + Validate
- `luac -p` on all modified files
- `lua EaxRotations/tests/run_rotation_tests.lua` — 214 pass
- `lua EaxRotations/tests/run_leveling_tests.lua` — 13 pass

## Validation
- `luac -p` on every modified file
- Full test suite (214 rotation + 13 leveling)
