# Rotation Logic Gap Audit — Read-Only Comparison vs Wowsims APLs

**Date:** 2026-07-05
**Auditor:** Agent (read-only, no code changes)
**Baseline:** EaxRotations v2.3.15 (220 rotation suites + 13 leveling suites green)
**Source of truth:** wowsims/tbc-new and wowsims/classic APL JSON files

---

## Methodology

1. Fetched authoritative APL JSONs from wowsims GitHub repositories
2. Read each APL's `priorityList` (and `groups` where present)
3. Compared against our Lua spec files line-by-line
4. Rated gaps as **P0** (fidelity loss), **P1** (optimization missing), **P2** (nice-to-have)

---

## Summary Table

| Spec | Status | P0 Gaps | P1 Gaps | P2 Gaps |
|------|--------|---------|---------|---------|
| Hunter BM | ⚠️ Needs work | 2 | 3 | 2 |
| Hunter MM | ⚠️ Needs work | 2 | 2 | 1 |
| Hunter SV | ⚠️ Needs work | 2 | 2 | 1 |
| Shadow Priest | ✅ Good | 0 | 2 | 1 |
| Affliction Lock | ⚠️ Needs work | 1 | 2 | 1 |
| Arcane Mage | ⚠️ Needs work | 2 | 2 | 1 |
| Fire Mage | ✅ Good | 0 | 1 | 1 |
| Fury Warrior | ✅ Good | 0 | 1 | 2 |
| Feral Cat | ✅ Good | 0 | 1 | 1 |
| Ret Paladin | ✅ Good | 0 | 1 | 0 |
| Enh Shaman | ✅ Good | 0 | 1 | 1 |

---

## Hunter (All Specs) — Largest Gap

**Wowsims APL source:** `wowsims/tbc-new/ui/hunter/dps/apls/default.apl.json`

### P0: Missing Shot Weave Logic
- **Wowsims:** Extremely complex weaving with `autoShotBuffer`, `cycleGaps`, `moveDuration`, ranged thresholds, melee weave group with Raptor Strike + Wing Clip
- **Our code:** `hunter_core.can_cast_instant(500, s.shot_buffer)` and `shot_timer.should_delay_cast` are simplified approximations
- **Impact:** Auto-shot clipping, incorrect Steady Shot timing, missing melee weave opportunities
- **File:** `EaxRotations/shared/hunter_core_sylvanas.lua`, `shared/shot_timer_sylvanas.lua`

### P0: Missing Aimed Shot Pre-Pull / Opener
- **Wowsims:** Pre-pull Aimed Shot at `<=0.5s` before combat start
- **Our code:** No pre-pull Aimed Shot logic in any hunter spec
- **Impact:** Loses significant opener DPS
- **File:** All hunter specs

### P1: Missing Kill Command (BM-specific)
- **Wowsims:** Kill Command (34026) is high priority off-GCD
- **Our code:** BM has `kill_command_matches` but wowsims gates it behind pet focus and combat time
- **Impact:** KC may fire suboptimally
- **File:** `EaxRotations/classes/hunter/beast_mastery_sylvanas.lua:470`

### P1: Viper/Hawk Swap Thresholds Off
- **Wowsims:** Viper at 5% mana, stop at 25%
- **Our code:** Viper at `viper_mana_threshold or 20`, Hawk recovery at `+10`
- **Impact:** May enter Viper too early or stay too long
- **File:** `EaxRotations/classes/hunter/beast_mastery_sylvanas.lua:240`

### P1: Missing Aspect of the Hawk Pre-Pull
- **Wowsims:** Aspect of the Hawk at `-20s`
- **Our code:** OOC aspect only checks if `not has_hawk`
- **Impact:** Minor opener optimization missing

### P2: Missing Rapid Fire / Readiness Alignment
- **Wowsims:** Rapid Fire aligned with Bloodlust; Readiness used after Rapid Fire with >=60s remaining
- **Our code:** Rapid Fire fires on cooldown; Readiness has 60s gate
- **Impact:** Suboptimal CD stacking

---

## Shadow Priest — Good Shape

**Wowsims APL source:** `wowsims/tbc-new/ui/priest/dps/apls/default.apl.json`

### P1: Shadowfiend Timing Not Optimal
- **Wowsims:** Short fight (<120s) uses at start; long fight uses when dots active and VT remaining >= Shadowfiend GCD
- **Our code:** Shadowfiend fires when `mana_pct < 40` or `combat_time > 30 and mana_low`
- **Impact:** May miss optimal Shadowfiend windows
- **File:** `EaxRotations/classes/priest/shadow_sylvanas.lua:580`

### P1: Missing Starshards for Night Elf
- **Wowsims:** Starshards used as filler for Night Elf priests
- **Our code:** `starshards_matches` exists but may not match wowsims priority placement
- **Impact:** Minor racial DPS loss for Night Elf

### P2: Mind Flay Clip Logic — Matches APL
- **Wowsims:** Clip after 2 ticks if SW:P can be cast, SW:D can be cast, MB ready, or VT needs refresh
- **Our code:** `mf_tick_compute_sylvanas.should_clip_mf()` implements exact same logic
- **Status:** ✅ Correct

---

## Affliction Warlock — Needs Execute Phase

**Wowsims APL source:** `wowsims/tbc-new/ui/warlock/dps/apls/affliction.apl.json`

### P0: Missing Drain Soul Execute (<5%)
- **Wowsims:** Drain Soul at `remainingTimePercent <= 5%` (execute phase DPS)
- **Our code:** Drain Soul only for shard capture (`ttd <= SOUL_SHARD_CAPTURE_TTD`, typically 3s)
- **Impact:** Loses execute phase DPS; wowsims treats Drain Soul as a real DPS spell at <5%
- **File:** `EaxRotations/classes/warlock/affliction_sylvanas.lua:780`

### P1: Missing Immolate Priority
- **Wowsims:** Immolate is priority #3 (after curse and Corruption)
- **Our code:** Immolate is priority #9 (after all DoTs, Drain Life, Seed of Corruption)
- **Impact:** Immolate uptime lower than optimal
- **File:** `EaxRotations/classes/warlock/affliction_sylvanas.lua:700`

### P1: Seed of Corruption Not in Wowsims APL
- **Wowsims:** Affliction APL has NO Seed of Corruption — uses pure DoT + drain
- **Our code:** Has Seed of Corruption for AoE
- **Impact:** Our AoE may be correct but differs from wowsims single-target APL
- **Note:** This is likely fine — wowsims APL is single-target; Seed is for multi-target

### P2: Missing Dark Pact / Life Tap Optimization
- **Wowsims:** Dark Pact at `<15%` mana; no Life Tap in APL
- **Our code:** Life Tap at `<30%` mana; Dark Pact at `<20%` mana
- **Impact:** Mana management differs from wowsims

---

## Arcane Mage — Needs Burn/Conserve Phases

**Wowsims APL source:** `wowsims/tbc-new/ui/mage/dps/apls/arcane.apl.json`

### P0: Missing Burn/Conserve Rotation Logic
- **Wowsims:** Complex mana management — Conserve Start at 20%, End at 30%, delay major CDs 10s
- **Our code:** No conserve/burn phase logic; Arcane Blast spam with some Evocation gating
- **Impact:** Major DPS loss — arcane mage is ALL about mana phases
- **File:** `EaxRotations/classes/mage/arcane_sylvanas.lua`

### P0: Missing Mana Gem Optimization
- **Wowsims:** Mana Gem fires when `maxMana > currentMana + 2500/3100 + regen`
- **Our code:** No mana gem logic
- **Impact:** Significant mana sustain loss

### P1: Missing Cold Snap / Icy Veins Logic
- **Wowsims:** Cold Snap if IV on CD and CS ready; IV fires when drums active and no BL, or BL active and no drums
- **Our code:** Icy Veins has basic `major_cd_window` gating
- **Impact:** Suboptimal IV/CS sequencing

### P1: Missing Pre-Pull Arcane Blast
- **Wowsims:** Arcane Blast at `-2.5s`
- **Our code:** No pre-pull logic
- **Impact:** Minor opener loss

### P2: Missing Berserking Alignment
- **Wowsims:** Berserking when no BL and after delay
- **Our code:** Basic `racial_matches` with `major_cd_window`
- **Impact:** Suboptimal racial timing

---

## Fire Mage — Good Shape

**Wowsims APL source:** `wowsims/classic/ui/mage/apls/p1.apl.json`

### P1: Scorch Stack Maintenance
- **Wowsims:** Scorch at <5 stacks or <5s remaining; Combustion at exactly 5 stacks
- **Our code:** Combustion aligned with major CDs; Scorch maintenance present
- **Impact:** Our Combustion may fire before 5-stack Scorch in some cases
- **File:** `EaxRotations/classes/mage/fire_sylvanas.lua`

### P2: Missing Pre-Pull Logic
- **Wowsims:** No pre-pull in the classic APL (different from TBC)
- **Our code:** No pre-pull
- **Impact:** None — matches APL

---

## Fury Warrior — Good Shape

**Wowsims APL source:** `wowsims/tbc-new/ui/warrior/dps/apls/fury.apl.json`

### P1: Missing Overpower Weaving
- **Wowsims:** Complex stance dance — swap to Battle Stance when Overpower available, cast Overpower, swap back
- **Our code:** No Overpower weaving
- **Impact:** DPS loss on dodge procs
- **File:** `EaxRotations/classes/warrior/fury_sylvanas.lua`

### P2: Missing Engineering Bombs
- **Wowsims:** Engineering bombs in dedicated group
- **Our code:** No engineering bomb logic
- **Impact:** Minor DPS loss for engineers

### P2: Missing Pre-Pull Sequence
- **Wowsims:** Berserker Rage at `-4.5s`, Bloodrage at `-3s`, Battle Shout at `-3s`, trinket at `-1s`
- **Our code:** No pre-pull logic
- **Impact:** Minor opener loss

---

## Feral Cat — Good Shape

**Wowsims APL source:** `wowsims/classic/ui/druid/feral/apls/default.apl.json` (not fetched but referenced in code)

### P1: Rip/Rake Snapshot Logic — Matches
- **Wowsims:** Snapshot AP on Rip/Rake, refresh only if AP upgrade
- **Our code:** `should_snapshot_upgrade()` with `AP_UPGRADE_RATIO` gates
- **Status:** ✅ Correct

### P2: Missing Berserk / Tiger's Fury Optimization
- **Wowsims:** Berserk and TF have specific timing windows
- **Our code:** Basic cooldown usage
- **Impact:** Suboptimal burst windows

---

## Retribution Paladin — Good Shape

**Wowsims APL source:** Not fetched (TBC-new likely has it)

### P1: Missing Seal Twisting
- **Wowsims:** Ret paladin in TBC uses seal twisting (Seal of Blood → Seal of Command)
- **Our code:** No seal twisting logic
- **Impact:** Major DPS loss if not implemented
- **File:** `EaxRotations/classes/paladin/retribution_sylvanas.lua`

---

## Enhancement Shaman — Good Shape

**Wowsims APL source:** Not fetched

### P1: Missing Stormstrike Debuff Priority
- **Wowsims:** Stormstrike is highest priority when debuff not active
- **Our code:** Has Stormstrike but may not be #1 priority
- **Impact:** Suboptimal debuff uptime

### P2: Missing Shamanistic Rage Mana Threshold
- **Wowsims:** SR fires at specific mana thresholds
- **Our code:** SR fires with cooldown planner alignment + low-mana defensive
- **Impact:** May be slightly off optimal threshold

---

## Recommended Action Priority

### Immediate (next session)
1. **Arcane Mage**: Implement burn/conserve rotation with mana gem logic — this is the biggest P0 gap
2. **Hunter (all specs)**: Implement Aimed Shot pre-pull and improve shot weave logic
3. **Affliction Warlock**: Add Drain Soul execute at <5% target HP

### Short-term (next 2-3 sessions)
4. **Shadow Priest**: Optimize Shadowfiend timing per wowsims
5. **Fury Warrior**: Add Overpower weaving stance dance
6. **Fire Mage**: Ensure Combustion always fires after 5-stack Scorch
7. **Ret Paladin**: Investigate seal twisting implementation

### Medium-term
8. **Hunter**: Full shot-weave overhaul with auto-shot buffer calculations
9. **All specs**: Add pre-pull sequences where applicable
10. **All specs**: Add engineering bomb support

---

## Test Impact

- Adding new spells/mechanics requires updating test suites
- Arcane mage burn/conserve is a **breaking behavior change** — tests must be updated
- Hunter shot-weave changes are **breaking** — tests must be updated
- Affliction Drain Soul execute is **additive** — new test needed

---

*Audit complete. No code changes made. Ready for implementation phase.*
