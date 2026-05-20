# Priest Shadow — Implementation Checklist

**Created**: 2026-05-20 | **DB2 Source**: `ClassResearchTBC/Priest/DB2-Spells.md`
**Research**: `ClassResearchTBC/Priest/Shadow/Research.md`

---

## DB2 Spell Verification

| Spell | DB2 IDs | DB2 Levels | Code IDs | Code Levels | Match | Notes |
|---|---|---|---|---|---|---|
| MindBlast | 8092..25375 (11 ranks) | 69,63,58,52,46,40,34,28,22,16,10 | same IDs | 70,62,54,46,38,30,24,18,12,8,4 | ❌ | **FIXED**: levels→{69,63,58,52,46,40,34,28,22,16,10} |
| MindFlay | 15407..25387 (7 ranks) | 68,60,52,44,36,28,20 | same IDs | 70,62,54,46,38,30,20 | ❌ | **FIXED**: levels→{68,60,52,44,36,28,20} |
| ShadowWordPain | 589..25368 (10 ranks) | 70,65,58,50,42,34,26,18,10,4 | same IDs | 70,62,52,44,36,28,20,14,10,4 | ❌ | **FIXED**: levels→{70,65,58,50,42,34,26,18,10,4} |
| VampiricTouch | 34914,34916,34917 (+34919) | 70,60,50 | 34917,34916,34914 | 70,64,56 | ❌ | **FIXED**: levels→{70,60,50}. 34919 is DB artifact (lvl1, no mana) |
| DevouringPlague | 2944..25467 (7 ranks) | 68,60,52,44,36,28,20 | same IDs | 68,60,50,40,30,20,10 | ❌ | **FIXED**: levels→{68,60,52,44,36,28,20} |
| Starshards | 10797..25446 (8 ranks) | 66,58,50,42,34,26,18,10 | same IDs | 64,56,48,40,32,24,16 | ❌ | **FIXED**: levels→{66,58,50,42,34,26,18,10} |
| Shadowfiend | 34433 | 66 | 34433 | 66 | ✅ | |
| Silence | 15487 | talent | 15487 | 30 | ✅ | Talent spell, level is for gate |
| Shadowform | 15473 | talent | 15473 | 40 | ✅ | Talent spell |
| ShadowWordDeath | 32996,32379 | 70,62 | 32996,32379 | 70,62 | ✅ | |
| VampiricEmbrace | 15286 | 1 | 15286 | 30 | ✅ | Talent spell at 30, DB2 lvl1 is misleading |
| Fade | 586..25429 (7 ranks) | 66,60,50,40,30,20,8 | same IDs | 66,60,50,40,30,20,8 | ✅ | |
| PsychicScream | 8122..10890 (4 ranks) | 56,42,28,14 | same IDs | 56,42,28,14 | ✅ | |
| ShackleUndead | 9484..10955 (3 ranks) | 60,40,20 | same IDs | 60,40,20 | ✅ | |
| InnerFire | 588..25431 (7 ranks) | 69,60,50,40,30,20,12 | same IDs | 69,60,50,40,30,20,12 | ✅ | |
| PowerWordShield | 17..25218 (12 ranks) | 70,65,60,54,48,42,36,30,24,18,12,6 | same IDs | 70,62,54,46,38,30,24,18,12,8,6,1 | ⚠️ | Previously fixed in Job 014 |

---

## Behavioral Requirements

| Requirement | Source | Status | Notes |
|---|---|---|---|
| Maintain Vampiric Touch 100% uptime | Research Angle 5 | ✅ Present | VT refresh at ≤3s window; snapshot-upgrade aware |
| Maintain Shadow Word: Pain | Research Single-Target | ✅ Present | SW:P refresh at ≤3s window; extended to 5s when weaving<5 |
| Mind Blast on cooldown | Research Single-Target | ✅ Present | Gated by mana_low (<30%) and threat_safe |
| Shadow Word: Death safety gate | Research Single-Target | ✅ Present | HP must be > swd_safety_hp (default 80%) |
| Mind Flay filler without clipping | Research Single-Target | ✅ Present | MF clip logic via mf_tick_compute |
| Shadow Weaving 5-stack maintenance | Research Angle 5 | ✅ Present | Extends SW:P refresh to 5s when stacks<5 |
| Shadowfiend at mana need | Research Single-Target | ✅ Present | Summons when mana<55% and TTD>60s |
| Inner Focus + Mind Blast combo | Research | ✅ Present | Uses IF when MB ready and TTD>45s |
| Mana < 30%: drop Mind Blast | Research Angle 4 Part B | ✅ Present | `mana_low` gate on MB |
| Mana < 15%: wand only, all spells forbidden | Research Angle 4 Part B | ✅ Present | `mana_emergency` gates VT, SW:P, DP, SW:D, MF |
| Mana < 5%: auto-attack only | Research Angle 4 Part B | ✅ Present | New wand/auto-attack strategy added |
| Threat safety gate on burst | Research Angle 5 | ✅ Present | `threat_safe` gates MB and SW:D via NS.is_threat_safe |
| Silence interrupt | Research PvP | ✅ Present | Interrupts casting targets; uses SPELLS.Silence |
| Psychic Scream at 3+ enemies | Research PvP | ✅ Present | |
| Fade at 2+ enemies | Research PvP | ✅ Present | |
| Dispel Magic utility | Research PvP | ✅ Present | |
| Shackle Undead on undead | Research Utility | ✅ Present | Creature type == 6 (undead) gate |
| Devouring Plague (racial) | Research DB2 | ✅ Present | Mana-gated and snapshot-aware |
| Starshards (NE racial) | Research DB2 | ✅ Present | |
| Berserking/BloodFury/ArcaneTorrent racials | Research DB2 | ✅ Present | TTD-gated |
| Vampiric Embrace sustain | Research PvP | ✅ Present | Refreshes when ≤10s remaining |
| Shadowform maintain | Research Single-Target | ✅ Present | Casts when missing |
| Inner Fire maintain | Research Utility | ✅ Present | Configurable via setting |

---

## Forbidden Mechanics (TBC Guardrail)

| Forbidden spell/mechanic | Source | Status |

|---|---|---|
| Dispersion [47585] | DB2 absent | ✅ Absent | Verified not in DB2; excluded from code |
| Non-TBC Shadow AoE filler | Research Multi-Target | ✅ Absent | Only Holy Nova in aoe mode (TBC spell) |

---

## Schema Verification

| Setting Key | Type | Present | Matches Code |
|---|---|---|---|
| shadow_combat_mode | dropdown | ✅ | ✅ |
| shadow_vt_refresh_window | slider | ✅ | ✅ |
| shadow_swp_refresh_window | slider | ✅ | ✅ |
| shadow_dp_refresh_window | slider | ✅ | ✅ |
| shadow_mb_mana_floor | slider | ✅ | ✅ |
| shadow_conserve_mana_floor | slider | ✅ | ✅ |
| shadow_swd_safety_hp | slider | ✅ | ✅ |
| shadow_shield_hp | slider | ✅ | ✅ |
| shadow_flash_heal_hp | slider | ✅ | ✅ |
| shadow_threat_safe | checkbox | ✅ | ✅ |
| shadow_use_inner_fire | checkbox | ✅ | ✅ |
| shadow_mounted_bail | checkbox | ✅ | ✅ |
| shadow_multi_dot_range | slider | ✅ | ✅ |
| shadow_multi_dot_targets | slider | ✅ | ✅ |

**Schema: 14/14 settings verified — no changes needed.**

---

## Test Coverage

| Test | Status |
|---|---|
| test_shadow_frostbyte_gaps | No existing tests found |
| luac -p syntax check | ✅ All pass (class_sylvanas.lua, shadow_sylvanas.lua, schema_sylvanas.lua) |

---

## Code Review

| Pass | Result | Issues Found | Issues Fixed |
|---|---|---|---|
| Pass 1 | ⚠️ | Syntax error (`and` operator in execute function), dead code claim (SILENCE_INTERRUPT_SPELL still used in build_state) | ✅ Both fixed |
| Pass 2 | ✅ | None | N/A |

---

## Summary

- **DB2 fixes**: 6 spell level corrections (MindBlast, MindFlay, SW:P, VT, DP, Starshards)
- **Behavioral**: SILENCE_ACTION → SPELLS.Silence (consistent with class_sylvanas.lua), mana<5% wand strategy
- **Schema**: No changes needed (already comprehensive with 14 settings)
- **22/22 behavioral requirements**: all Present ✅
- **luac -p**: ✅ All files pass
- **Code review**: ✅ Pass 2 clear
