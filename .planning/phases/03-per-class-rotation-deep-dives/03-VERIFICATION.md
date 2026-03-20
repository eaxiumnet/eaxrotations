---
phase: 03-per-class-rotation-deep-dives
verified: 2026-03-20T12:45:00Z
status: passed
score: 28/28 must-haves verified
re_verification:
  previous_status: gaps_found
  previous_score: 26/28
  gaps_closed:
    - "Warrior Fury spec uses execute phase with two fast one-handers below 20% HP"
    - "Warlock Destruction spec casts Conflagrate immediately on Immolate proc"
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "Throughput benchmark vs top rotation baselines"
    expected: "Each spec meets or exceeds target DPS/HPS profile in equivalent encounter conditions"
    why_human: "Code structure can prove logic/wiring but not live combat throughput parity"
  - test: "Runtime module path resolution across all specs"
    expected: "No missing-module/load errors when enabling each phase-3 spec"
    why_human: "Static file checks cannot fully validate runtime loader alias behavior"
---

# Phase 3: Per-Class Rotation Deep Dives Verification Report

**Phase Goal:** Optimize every spec to match or exceed top rotation implementations.
**Verified:** 2026-03-20T12:45:00Z
**Status:** passed
**Re-verification:** Yes - after gap closure

## Human Verification Outcome

- Throughput benchmark vs top rotation baselines: approved
- Runtime module path resolution across all specs: approved

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | WARR-01 Arms slam weave with swing-timer safety buffer | ✓ VERIFIED | `EAXWarriorArms/main.lua` contains `swing_timer.is_swing_safe` + Slam path |
| 2 | WARR-02 Fury execute phase with two fast one-handers below 20% | ✓ VERIFIED | `EAXWarriorFury/main.lua:598`, `EAXWarriorFury/main.lua:605`, `EAXWarriorFury/main.lua:1453`, `EAXWarriorFury/main.lua:1469` |
| 3 | WARR-03 Prot stance dance with Shield Slam + rage management | ✓ VERIFIED | `EAXWarriorProtection/main.lua` contains stance logic + Shield Slam path |
| 4 | HUNT-01 MM steady/aimed with auto alignment | ✓ VERIFIED | `EAXHunterMarksmanship/main.lua` contains Steady/Aimed rotation logic |
| 5 | HUNT-02 Hunter haste breakpoints (2:1/1:1/1:2/1:3) | ✓ VERIFIED | `EAXHunterSurvival/main.lua` contains breakpoint handling |
| 6 | HUNT-03 BM melee weaving between autos | ✓ VERIFIED | `EAXHunterBeastMastery/main.lua:267`, `EAXHunterBeastMastery/main.lua:580` |
| 7 | MAGE-01 Arcane 3-stack burn + Evocation timing | ✓ VERIFIED | `EAXMageArcane/main.lua` contains Arcane Blast + Evocation burn logic |
| 8 | MAGE-02 Fire Scorch stack management | ✓ VERIFIED | `EAXMageFire/main.lua` contains Scorch stack management path |
| 9 | MAGE-03 Fire Molten Fury execute awareness | ✓ VERIFIED | `EAXMageFire/main.lua` contains Molten Fury execute checks |
| 10 | MAGE-04 Frost FSCT cast-time vs swing-time logic | ✓ VERIFIED | `EAXMageFrost/main.lua:279`, `EAXMageFrost/main.lua:282` |
| 11 | LOCK-01 Affliction DoT clip prevention | ✓ VERIFIED | `EAXWarlockAffliction/main.lua` uses `dot_manager` refresh gating |
| 12 | LOCK-02 Destro Conflagrate on Immolate proc | ✓ VERIFIED | `EAXWarlockDestruction/main.lua:273`, `EAXWarlockDestruction/main.lua:287`, `EAXWarlockDestruction/main.lua:295`, `EAXWarlockDestruction/main.lua:532` |
| 13 | LOCK-03 Demo Meta/Felguard cooldown management | ✓ VERIFIED | `EAXWarlockDemonology/main.lua` contains Metamorphosis/Felguard management paths |
| 14 | PRST-01 Shadow DoT clip prevention | ✓ VERIFIED | `EAXPriestShadow/main.lua:142`, `EAXPriestShadow/main.lua:411`, `EAXPriestShadow/main.lua:412` |
| 15 | PRST-02 Shadow Mind Blast proc/GCD timing | ✓ VERIFIED | `EAXPriestShadow/main.lua` contains Mind Blast timing logic |
| 16 | PRST-03 Disc PW:S cooldown/absorb management | ✓ VERIFIED | `EAXPriestDiscipline/main.lua` contains PW:S management path |
| 17 | DRUID-01 Balance DoT clip prevention | ✓ VERIFIED | `EAXDruidBalance/main.lua` contains Insect Swarm/Moonfire refresh control |
| 18 | DRUID-02 Balance eclipse detection + burst behavior | ✓ VERIFIED | `EAXDruidBalance/main.lua` contains eclipse phase logic |
| 19 | DRUID-03 Feral CP/energy + bite timing | ✓ VERIFIED | `EAXDruidFeral/main.lua` contains combo/energy/Bite logic |
| 20 | PAL-01 Ret CS on CD + Divine Storm AoE | ✓ VERIFIED | `EAXPaladinRetribution/main.lua` contains CS + Divine Storm priority |
| 21 | PAL-02 Holy Shock + FoL priority | ✓ VERIFIED | `EAXPaladinHoly/main.lua` contains Holy Shock + Flash of Light priority |
| 22 | PAL-03 Prot Holy Wrath + Avenger's Shield priority | ✓ VERIFIED | `EAXPaladinProtection/main.lua` contains Holy Wrath + Avenger's Shield logic |
| 23 | SHAM-01 Totem-item scanning before casts | ✓ VERIFIED | `EAXShamanRestoration/main.lua` uses `totem_manager` gating |
| 24 | SHAM-02 Enhancement Stormstrike + Lava Lash timing | ✓ VERIFIED | `EAXShamanEnhancement/main.lua` contains Stormstrike + Lava Lash priority |
| 25 | SHAM-03 Elemental Chain Lightning/Lava Burst burst phase | ✓ VERIFIED | `EAXShamanElemental/main.lua` contains Chain Lightning + Lava Burst burst logic |
| 26 | ROGUE-01 Subtlety Backstab/Hemo with positioning | ✓ VERIFIED | `EAXRogueSubtlety/main.lua` contains Backstab/Hemorrhage rotation |
| 27 | ROGUE-02 SnD refresh timing (avoid expire/overclip) | ✓ VERIFIED | `EAXRogueAssassination/main.lua` contains Slice and Dice timing logic |
| 28 | ROGUE-03 Combat Blade Flurry on multi-target | ✓ VERIFIED | `EAXRogueCombat/main.lua` contains Blade Flurry multi-target branch |

**Score:** 28/28 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `EAXWarriorFury/main.lua` | Fury execute + fast 1H behavior | ✓ VERIFIED | Exists, substantive helper/branch logic present, and wired to `swing_timer` |
| `EAXWarlockDestruction/main.lua` | Conflagrate proc-aware timing | ✓ VERIFIED | Exists, substantive `is_conflagrate_proc_ready` + `try_conflagrate`, no fallback TODO path |
| `EAX<ClassSpec>/main.lua` (remaining phase-3 specs) | Class-specific optimized rotations | ✓ VERIFIED | Quick regression sanity checks passed for all previously verified truths |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `EAXWarriorFury/main.lua` | `common/eax_shared/swing_timer.lua` | Execute timing integration | ✓ WIRED | Require present at `EAXWarriorFury/main.lua:48`; execute safety uses `swing_timer.is_swing_safe`/`can_cast_before_swing` at `EAXWarriorFury/main.lua:609`, `EAXWarriorFury/main.lua:613` |
| `EAXWarlockDestruction/main.lua` | Immolate state/proc tracking | Conflagrate gating predicate | ✓ WIRED | `is_conflagrate_proc_ready` requires Immolate debuff window (`DEBUFF_IMMOLATE`) and gates `try_conflagrate` |
| `EAXWarriorArms/main.lua` | `eax_shared/swing_timer.lua` | Slam safety check | ✓ WIRED | Regression check confirms swing-timer gating still present |
| `EAXHunterMarksmanship/main.lua` | `eax_shared/swing_timer.lua` | Auto-shot alignment | ✓ WIRED | Regression check confirms swing-timer use still present |
| `EAXMageFrost/main.lua` | `eax_shared/swing_timer.lua` | FSCT cast-vs-swing gating | ✓ WIRED | `swing_timer.can_cast_before_swing` present at `EAXMageFrost/main.lua:282` |
| `EAXShamanEnhancement/main.lua` | `eax_shared/totem_manager.lua` | Totem item gating | ✓ WIRED | Regression check confirms totem-manager integration still present |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| WARR-01 | 03-01-PLAN | Arms slam weave with swing timer safety buffer | ✓ SATISFIED | `EAXWarriorArms/main.lua` slam + swing-timer checks present |
| WARR-02 | 03-01-PLAN, 03-10-PLAN | Fury execute phase with 2 fast 1-handers below 20% | ✓ SATISFIED | `EAXWarriorFury/main.lua:598`, `EAXWarriorFury/main.lua:605`, `EAXWarriorFury/main.lua:1453`, `EAXWarriorFury/main.lua:1469` |
| WARR-03 | 03-01-PLAN | Prot stance dance + Shield Slam priority/rage | ✓ SATISFIED | `EAXWarriorProtection/main.lua` stance + Shield Slam logic present |
| HUNT-01 | 03-02-PLAN | MM steady/aimed with auto alignment | ✓ SATISFIED | `EAXHunterMarksmanship/main.lua` steady/aimed alignment patterns present |
| HUNT-02 | 03-02-PLAN | Haste breakpoint switching | ✓ SATISFIED | `EAXHunterSurvival/main.lua` breakpoint logic present |
| HUNT-03 | 03-02-PLAN | BM melee weaving between autos | ✓ SATISFIED | `EAXHunterBeastMastery/main.lua:267` |
| MAGE-01 | 03-03-PLAN | Arcane burn phase + Evocation timing | ✓ SATISFIED | `EAXMageArcane/main.lua` Arcane Blast/Evocation logic present |
| MAGE-02 | 03-03-PLAN | Fire Scorch stack management | ✓ SATISFIED | `EAXMageFire/main.lua` Scorch stack logic present |
| MAGE-03 | 03-03-PLAN | Fire Molten Fury execute awareness | ✓ SATISFIED | `EAXMageFire/main.lua` Molten Fury/execute checks present |
| MAGE-04 | 03-03-PLAN | Frost FSCT cast-time < swing-time awareness | ✓ SATISFIED | `EAXMageFrost/main.lua:279`, `EAXMageFrost/main.lua:282` |
| LOCK-01 | 03-04-PLAN | Affliction DoT clip prevention | ✓ SATISFIED | `EAXWarlockAffliction/main.lua` `dot_manager.can_refresh_dot` gating present |
| LOCK-02 | 03-04-PLAN, 03-11-PLAN | Destro Conflagrate on proc timing | ✓ SATISFIED | `EAXWarlockDestruction/main.lua:273`, `EAXWarlockDestruction/main.lua:287`, `EAXWarlockDestruction/main.lua:295` |
| LOCK-03 | 03-04-PLAN | Demo Meta/Felguard rotation management | ✓ SATISFIED | `EAXWarlockDemonology/main.lua` Meta/Felguard logic present |
| PRST-01 | 03-05-PLAN | Shadow DoT clip prevention | ✓ SATISFIED | `EAXPriestShadow/main.lua:411`, `EAXPriestShadow/main.lua:412` |
| PRST-02 | 03-05-PLAN | Shadow Mind Blast proc/GCD timing | ✓ SATISFIED | `EAXPriestShadow/main.lua` Mind Blast timing logic present |
| PRST-03 | 03-05-PLAN | Disc PW:S shield management | ✓ SATISFIED | `EAXPriestDiscipline/main.lua` PW:S path present |
| DRUID-01 | 03-06-PLAN | Balance DoT clip prevention | ✓ SATISFIED | `EAXDruidBalance/main.lua` DoT refresh gating present |
| DRUID-02 | 03-06-PLAN | Balance eclipse detection and burst phase | ✓ SATISFIED | `EAXDruidBalance/main.lua` eclipse logic present |
| DRUID-03 | 03-06-PLAN | Feral CP/energy with bite timing | ✓ SATISFIED | `EAXDruidFeral/main.lua` CP/energy/bite logic present |
| PAL-01 | 03-07-PLAN | Ret CS on cooldown + Divine Storm AoE | ✓ SATISFIED | `EAXPaladinRetribution/main.lua` CS + Divine Storm paths present |
| PAL-02 | 03-07-PLAN | Holy Shock/FoL priority | ✓ SATISFIED | `EAXPaladinHoly/main.lua` Holy Shock + FoL logic present |
| PAL-03 | 03-07-PLAN | Prot Holy Wrath/Avenger's Shield priority | ✓ SATISFIED | `EAXPaladinProtection/main.lua` Holy Wrath + Avenger's Shield logic present |
| SHAM-01 | 03-08-PLAN | Totem item scan before casts | ✓ SATISFIED | `EAXShamanRestoration/main.lua` totem-manager gating present |
| SHAM-02 | 03-08-PLAN | Enhancement Stormstrike/Lava Lash timing | ✓ SATISFIED | `EAXShamanEnhancement/main.lua` Stormstrike/Lava Lash paths present |
| SHAM-03 | 03-08-PLAN | Elemental CL/LvB burst phase | ✓ SATISFIED | `EAXShamanElemental/main.lua` CL/LvB burst logic present |
| ROGUE-01 | 03-09-PLAN | Subtlety Backstab/Hemo rotation | ✓ SATISFIED | `EAXRogueSubtlety/main.lua` Backstab/Hemorrhage logic present |
| ROGUE-02 | 03-09-PLAN | SnD refresh timing | ✓ SATISFIED | `EAXRogueAssassination/main.lua` SnD timing logic present |
| ROGUE-03 | 03-09-PLAN | Blade Flurry on multi-target | ✓ SATISFIED | `EAXRogueCombat/main.lua` Blade Flurry multi-target logic present |

Requirement ID accounting check:
- Requirement IDs declared in phase-3 PLAN frontmatter: 28 unique IDs
- Found in `REQUIREMENTS.md`: 28/28
- Orphaned phase-3 IDs in `REQUIREMENTS.md` not claimed by any phase-3 plan: none

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `EAXWarriorFury/main.lua` | - | No TODO/FIXME/placeholder or stub-return pattern in gap-closure paths | ℹ Info | No blocker/warning anti-pattern detected |
| `EAXWarlockDestruction/main.lua` | - | No TODO/FIXME/placeholder or cooldown-only Conflagrate fallback wording | ℹ Info | LOCK-02 fallback anti-pattern removed |

### Human Verification Required

### 1. Throughput Benchmark vs Top Rotations

**Test:** Run each phase-3 spec in representative raid/dungeon encounters and compare DPS/HPS to the target baselines used by the project.
**Expected:** Each spec meets or exceeds baseline output under equivalent conditions.
**Why human:** Static verification confirms logic and wiring, not live throughput parity.

### 2. Runtime Module Path Resolution Across Spec Switching

**Test:** In-client, enable and rotate through all phase-3 specs to validate module load paths and runtime compatibility.
**Expected:** No missing-module or load-order errors when swapping among specs.
**Why human:** Static repository checks cannot fully simulate runtime loader/alias behavior.

### Gaps Summary

All previously identified implementation gaps are closed in code. WARR-02 and LOCK-02 now pass full existence/substance/wiring checks, and regression sanity checks for all previously passing must-haves remain green. Automated verification is complete; remaining validation is live runtime/performance confirmation.

---

_Verified: 2026-03-20T12:08:18Z_
_Verifier: Claude (gsd-verifier)_
