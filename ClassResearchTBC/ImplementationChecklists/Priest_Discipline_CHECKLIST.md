# Priest Discipline Implementation Checklist

## DB2 Spell Verification (class_sylvanas.lua)

| # | Spell | Status | Issue |
|---|-------|--------|-------|
| 1 | InnerFire | ❌ FIXED | 8 levels for 7 IDs; all levels wrong. DB2: {69,60,50,40,30,20,12} |
| 2 | Fade | ❌ FIXED | levels {66,60,50,40,30,20,8}, not {70,60,50,40,30,20,14} |
| 3 | PowerWordFortitude | ❌ FIXED | levels {70,60,48,36,24,12,1}, not {70,60,50,40,30,20} |
| 4 | Renew | ❌ FIXED | 11 levels for 12 IDs; DB2: {70,65,60,56,50,44,38,32,26,20,14,8} |
| 5 | PrayerOfHealing | ❌ FIXED | levels {68,60,54,50,40,30}, not {70,62,54,46,38,30} |
| 6 | PsychicScream | ❌ FIXED | levels {56,42,28,14}, not {64,56,48,14} |
| 7 | Smite | ❌ FIXED | levels {69,61,54,46,38,30,22,14,6,1}, not {70,62,52,44,36,28,22,16,10,6} |
| 8 | ShackleUndead | ❌ FIXED | levels {60,40,20}, not {60,50,24} |
| 9 | FearWard | ❌ FIXED | level {20}, not {26} |
| 10 | CircleOfHealing | ❌ FIXED | levels {70,65,60,56,50}, not {70,64,56,50,40} |
| 11 | DivineSpirit | ❌ FIXED | Added — was missing entirely |
| 12 | MassDispel | ❌ FIXED | Added — was missing entirely |
| 13 | PrayerOfFortitude | ❌ FIXED | Added — was missing entirely |
| 14 | ManaBurn | ❌ FIXED | Added — was missing entirely |
| 15 | Lightwell | ❌ FIXED | Added missing ranks {70,60,50} (had only {40}) |
| 16 | GreaterHeal | ✅ OK | IDs and levels match DB2 |
| 17 | FlashHeal | ✅ OK | IDs and levels match DB2 |
| 18 | PowerWordShield | ✅ OK | IDs and levels match DB2 |
| 19 | HolyFire | ✅ OK | IDs and levels match DB2 |
| 20 | ShadowWordPain | ✅ OK | IDs and levels match DB2 |
| 21 | BindingHeal | ✅ OK | Matches DB2 |
| 22 | ShadowWordDeath | ✅ OK | Matches DB2 |
| 23 | MindBlast | ✅ OK | Matches DB2 |
| 24 | MindFlay | ✅ OK | Matches DB2 |
| 25 | VampiricTouch | ✅ OK | Matches DB2 |
| 26 | HolyNova | ✅ OK | Matches DB2 |
| 27 | Starshards | ✅ OK | Matches DB2 |
| 28 | DevouringPlague | ✅ OK | Matches DB2 |
| 29 | Shadowfiend | ✅ OK | Matches DB2 |
| 30 | DesperatePrayer | ✅ OK | Single rank racial; correct |
| 31 | Shadowform | ✅ OK | Matches DB2 |
| 32 | Silence | ✅ OK | Matches DB2 |
| 33 | AbolishDisease | ✅ OK | Matches DB2 |
| 34 | CureDisease | ✅ OK | Matches DB2 |
| 35 | InnerFocus | ✅ OK | Matches DB2 |
| 36 | DispelMagic | ✅ OK | Matches DB2 |
| 37 | VampiricEmbrace | ✅ OK | Matches DB2 |

## Behavioral Verification (discipline_sylvanas.lua)

| # | Requirement | Status | Notes |
|---|-------------|--------|-------|
| 1 | Weakened Soul [6788] check before PW:S | ✅ Present | `s.lowest.has_weakened_soul` gate in emergency_pws_matches |
| 2 | Pain Suppression on tank during burst | ✅ Present | Gated on tank HP threshold |
| 3 | Power Infusion target picker | ⚠️ Partial | Self-cast only; Research.md calls for DPS picker (known INTENTIONAL CHOICE) |
| 4 | Inner Focus with expensive heals | ✅ Present | Gates on tank HP and group damaged count |
| 5 | Greater Heal downranking | ✅ Present | Rank 7(>30% mana), 5(15-30%), 4(<15%) |
| 6 | Flash Heal for spot healing | ✅ Present | Below discipline_flash_hp threshold |
| 7 | Prayer of Mending on tank | ✅ Present | On cooldown, in combat |
| 8 | Renew maintenance | ✅ Present | Tank and lowest target |
| 9 | Binding Heal when both need healing | ✅ Present | Self < 70%, target < 50% |
| 10 | Circle of Healing | ✅ Present | 3+ damaged group members |
| 11 | Prayer of Healing subgroup count | ✅ Present | subgroup_damaged_count, 4+ |
| 12 | Mana floor: conserve at <30% | ❌ FIXED | Added mana floor gate to PW:S and Flash Heal |
| 13 | Mana floor: shield only at <15% | ❌ FIXED | Added CONSUME_MANA_FLOOR = 15 |
| 14 | Mana floor: wand at <5% | ⚠️ N/A | Handled by leveling module |
| 15 | Inner Fire maintenance | ✅ Present | Buff check + action |
| 16 | Fear Ward maintenance | ✅ Present | Buff check + action |
| 17 | PW:Fortitude maintenance | ✅ Present | Buff check (but table had wrong Prayer IDs) |
| 18 | Divine Spirit maintenance | ❌ FIXED | Added action + match + strategy |
| 19 | Prayer of Fortitude | ❌ FIXED | Added action + match + strategy |
| 20 | Dispel Magic | ✅ Present | dispel_magic_matches |
| 21 | DPS when idle | ✅ Present | Gated on discipline_dps_when_idle + group stability |
| 22 | Pushback detection for GH | ✅ Present | _check_pushback function |
| 23 | StopCast mid-cast cancel | ✅ Present | stop_cast_matches FrostByte feature |
| 24 | PreHeal tank damage | ✅ Present | pre_heal_matches FrostByte feature |
| 25 | Fade on aggro | ✅ Present | fade_matches FrostByte feature |
| 26 | Healthstone auto-use | ✅ Present | healthstone_matches FrostByte feature |
| 27 | Penance [47540] absent | ✅ Absent | WotLK spell, correctly excluded |
| 28 | Rapture [47535] absent | ✅ Absent | WotLK spell, correctly excluded |
| 29 | Pain Suppression [44416] rank 2 gating | ✅ Present | Uses 33206 (rank 1), 44416 is passive rank |

## Schema Verification (schema_sylvanas.lua)

| # | Setting | Status | Notes |
|---|---------|--------|-------|
| 1 | Discipline tab | ❌ FIXED | Added new "Discipline" tab with all spec settings |
| 2 | discipline_pws_hp | ❌ FIXED | Added |
| 3 | discipline_flash_hp | ❌ FIXED | Added |
| 4 | discipline_greater_heal_hp | ❌ FIXED | Added |
| 5 | discipline_renew_hp | ❌ FIXED | Added |
| 6 | discipline_pain_suppression_hp | ❌ FIXED | Added |
| 7 | discipline_use_power_infusion | ❌ FIXED | Added |
| 8 | discipline_pi_safety_hp | ❌ FIXED | Added |
| 9 | discipline_use_inner_focus | ❌ FIXED | Added |
| 10 | discipline_if_hp | ❌ FIXED | Added |
| 11 | discipline_dps_when_idle | ❌ FIXED | Added |
| 12 | discipline_dps_mana_floor | ❌ FIXED | Added |
| 13 | discipline_idle_hp | ❌ FIXED | Added |
| 14 | discipline_aoe_hp | ❌ FIXED | Added |
| 15 | discipline_healthstone_hp | ❌ FIXED | Added |

---

## Run Results (2026-05-20 — 2nd pass, behavioral fixes)

**2 files changed** (6 behavioral fixes + schema tab):

| File | Changes |
|---|---|
| `discipline_sylvanas.lua` | Mana floor gates: PW:S (removed — shield should cast at any mana), Flash Heal (stop at <15%), Greater Heal (stop at <30%). DivineSpirit + PrayerOfFortitude strategies. Fixed `unit_mana_pct` nil guard. Fixed DivineSpirit match (removed copy-paste has_inner_fire check). |
| `schema_sylvanas.lua` | Added "Discipline" tab with 5 sections (Healing Priority, Cooldowns, AoE, DPS When Idle, Self Survival) — 15 settings total. |

- ✅ `luac -p` passes | ✅ Code review addressed (3 bugs fixed: PW:S gate removed, GH 30% floor added, DivineSpirit match fixed) |
- 27/29 behavioral requirements Present, 1 Partial (PI target picker — known INTENTIONAL CHOICE), 1 N/A (wand at <5% — leveling module)
---

## Run Results (2026-05-20 — 1st pass, DB2 fixes)

**3 files changed** (15 DB2 fixes + 3 behavioral fixes + schema tab):

- ✅ `luac -p` passes | ✅ Tests pass | ✅ Code review addressed
