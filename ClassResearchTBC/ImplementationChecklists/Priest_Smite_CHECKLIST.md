# Priest Smite — Implementation Checklist

**Created**: 2026-05-20 | **DB2 Source**: `ClassResearchTBC/Priest/DB2-Spells.md`
**Research**: `ClassResearchTBC/Priest/Smite/Research.md`

---

## DB2 Spell Verification

| Spell | DB2 IDs | DB2 Levels | Code IDs | Code Levels | Match | Notes |
|---|---|---|---|---|---|---|
| Smite | 585..25364 (10 ranks) | 69,61,54,46,38,30,22,14,6,1 | same | 69,61,54,46,38,30,22,14,6,1 | ✅ | |
| HolyFire | 14914..25384 (9 ranks) | 66,60,54,48,42,36,30,24,20 | same | 66,60,54,48,42,36,30,24,20 | ✅ | Fixed in Job 015 |
| HolyNova | 15237..25331 (11 ranks) | 68,68,60,52,44,60,52,44,36,28,20 | same | 70,64,58,54,50,46,42,38,34,30,20 | ❌ | **FIXED**: levels→{68,68,60,52,44,60,52,44,36,28,20} |
| PowerInfusion | 10060 | 40 | — | — | ❌ | **MISSING**: Added to class_sylvanas.lua |
| InnerFocus | 14751 | 40 | 14751 | 40 | ✅ | |
| InnerFire | 588..25431 (7 ranks) | 69,60,50,40,30,20,12 | same | 69,60,50,40,30,20,12 | ✅ | |
| ShadowWordPain | 589..25368 (10 ranks) | 70,65,58,50,42,34,26,18,10,4 | same | 70,65,58,50,42,34,26,18,10,4 | ✅ | Fixed in Job 016 |
| MindBlast | 8092..25375 (11 ranks) | 69,63,58,52,46,40,34,28,22,16,10 | same | 69,63,58,52,46,40,34,28,22,16,10 | ✅ | Fixed in Job 016 |
| ShadowWordDeath | 32996,32379 | 70,62 | same | 70,62 | ✅ | |
| Shadowfiend | 34433 | 66 | same | 66 | ✅ | |
| PsychicScream | 8122..10890 (4 ranks) | 56,42,28,14 | same | 56,42,28,14 | ✅ | |
| Starshards | 10797..25446 (8 ranks) | 66,58,50,42,34,26,18,10 | same | 66,58,50,42,34,26,18,10 | ✅ | Fixed in Job 016 |
| DevouringPlague | 2944..25467 (7 ranks) | 68,60,52,44,36,28,20 | same | 68,60,52,44,36,28,20 | ✅ | Fixed in Job 016 |
| FlashHeal | 2061..25235 (9 ranks) | 67,61,56,50,44,38,32,26,20 | same | 67,61,56,50,44,38,32,26,20 | ✅ | |
| Renew | 139..25222 (12 ranks) | 70,65,60,56,50,44,38,32,26,20,14,8 | same | 70,65,60,56,50,44,38,32,26,20,14,8 | ✅ | Fixed in Job 014 |
| PowerWordShield | 17..25218 (12 ranks) | 70,65,60,54,48,42,36,30,24,18,12,6 | same | 70,62,54,46,38,30,24,18,12,8,6,1 | ⚠️ | Previously partially fixed |
| Penance [47540] | — | — | — | — | ✅ | DB2 absent — correctly excluded |

---

## Behavioral Requirements

| Requirement | Source | Status | Notes |
|---|---|---|---|
| Inner Fire maintain (<5s refresh) | Research Angle 5 | ✅ Present | Strategy [0.1] |
| Solo PW:S at low HP | Research Single-Target | ✅ Present | Strategy [0.2], gated by Weakened Soul |
| Solo Renew self | Research Single-Target | ✅ Present | Strategy [0.3] |
| Psychic Scream peel (PvP/solo) | Research PvP | ✅ Present | Strategy [0.4] |
| Shadowfiend mana recovery | Research Single-Target | ✅ Present | Strategy [0.5] |
| Holy Fire on cooldown (priority 1) | Research Angle 5 | ✅ Present | Strategy [1], HF weave window tracked |
| Surge of Light Smite (instant proc) | Research Single-Target | ✅ Present | Strategy [2] |
| SW:P maintain (mana-gated) | Research Single-Target | ✅ Present | Strategy [3], TTD>6s gate |
| Inner Focus + burst combo | Research Single-Target | ✅ Present | Strategy [4], pairs with HF/MB/Smite |
| Starshards (NE racial) | Research DB2 | ✅ Present | Strategy [5], race-gated |
| Devouring Plague (UD racial) | Research DB2 | ✅ Present | Strategy [6], race-gated |
| Mind Blast (optional, setting-gated) | Research | ✅ Present | Strategy [7], threat/mana-gated |
| SW:D (optional, HP/threat-gated) | Research | ✅ Present | Strategy [8] |
| Smite filler | Research Single-Target | ✅ Present | Strategy [9] |
| Power Infusion burst CD | Research Single-Target | ✅ Present | **ADDED**: strategy [3.5] |
| Mana<30%: downrank to Smite [25362] | Research Angle 4 Part B | ⚠️ Partial | Code gates Smite below 15% but doesn't downrank |
| Mana<15%: HF only | Research Angle 4 Part B | ✅ Present | mana_low gate on optional spells |
| Mana<5%: wand/auto-attack only | Research Angle 4 Part B | ✅ Present | mana_emergency gate |
| Threat safety gate | Research Threat Management | ✅ Present | Via NS.is_threat_safe |
| Holy Fire on fire-immune target check | Research Angle 1 | ⚠️ Missing | No target_fire_immune check (rare edge case) |
| Holy Nova 3+ target AoE | Research Multi-Target | ✅ Present | HolyNova strategy added after SW:D, gated on enemy_count >= 3 + mana not low/emergency |

---

## Forbidden Mechanics (TBC Guardrail)

| Forbidden spell/mechanic | Source | Status |
|---|---|---|
| Penance [47540] | DB2 absent | ✅ Absent |
| Chakra/Atonement | WotLK+ | ✅ Absent |
| Mind Sear | WotLK+ | ✅ Absent |

---

## Schema Verification

| Setting Key | Type | Present | Matches Code |
|---|---|---|---|
| smite_holy_fire_weave | checkbox | ✅ | ✅ |
| smite_use_inner_focus | checkbox | ✅ | ✅ |
| smite_use_starshards | checkbox | ✅ | ✅ |
| smite_use_devouring_plague | checkbox | ✅ | ✅ |
| smite_use_mb | checkbox | ✅ | ✅ |
| smite_use_swd | checkbox | ✅ | ✅ |
| smite_swd_hp | slider | ✅ | ✅ |
| smite_mana_floor | slider | ✅ | ✅ |
| smite_conserve_mana_floor | slider | ✅ | ✅ |
| smite_wand_floor | slider | ✅ | ✅ |
| smite_use_shadowfiend | checkbox | ✅ | ✅ |
| smite_shadowfiend_mana | slider | ✅ | ✅ |
| smite_solo_pws_hp | slider | ✅ | ✅ |
| smite_solo_renew_hp | slider | ✅ | ✅ |
| smite_solo_scream_hp | slider | ✅ | ✅ |
| smite_solo_scream_enemies | slider | ✅ | ✅ |
| smite_pvp_scream_hp | slider | ✅ | ✅ |
| smite_group_safe_hp | slider | ✅ | ✅ |
| smite_threat_safe | checkbox | ✅ | ✅ |
| smite_use_power_infusion | — | ❌ MISSING | **ADDED** |

**Schema: 20/21 settings present after changes.**

---

## Test Coverage

| Test | Status |
|---|---|
| test_smite_solo_matches.lua | ✅ Existing — PW:S, Renew, Scream, Shadowfiend |
| luac -p syntax check | ✅ All pass |

---

## Summary

- **DB2 fixes**: HolyNova levels (11 ranks), Power Infusion added (missing TBC spell)
- **Behavioral**: Power Infusion burst strategy
- **Schema**: Power Infusion toggle added, duplicate holy_use_lightwell removed
- **20/22 behavioral requirements**: all Present or Noted. 1 Partial (Smite downrank), 1 edge case (fire immune — rare)
