# Priest Holy — Implementation Checklist

**Created**: 2026-05-20 | **DB2 Source**: `ClassResearchTBC/Priest/DB2-Spells.md`
**Research**: `ClassResearchTBC/Priest/Holy/Research.md`

---

## DB2 Spell Verification

| Spell | DB2 IDs | DB2 Levels | Code IDs | Code Levels | Match | Notes |
|---|---|---|---|---|---|---|
| CircleOfHealing | 34866,34865,34864,34863,34861 | 70,65,60,56,50 | 34866,34865,34864,34863,34861 | 70,65,60,56,50 | ✅ | |
| FlashHeal | 25235,25233,10917,10916,10915,9474,9473,9472,2061 | 67,61,56,50,44,38,32,26,20 | 25235,25233,10917,10916,10915,9474,9473,9472,2061 | 67,61,56,50,44,38,32,26,20 | ✅ | |
| GreaterHeal | 25213,25210,25314,10965,10964,10963,2060 | 68,63,60,58,52,46,40 | 25213,25210,25314,10965,10964,10963,2060 | 68,63,60,58,52,46,40 | ✅ | |
| PrayerOfHealing | 25308,25316,10961,10960,996,596 | 68,60,60,50,40,30 | 25308,25316,10961,10960,996,596 | 68,60,60,50,40,30 | ✅ | 10961(60) fixed from 54 |
| PrayerOfMending | 33076 | 68 | 33076 | 68 | ✅ | |
| Renew | 25222,25221,25315,10929,10928,10927,6078,6077,6076,6075,6074,139 | 70,65,60,56,50,44,38,32,26,20,14,8 | 25222,25221,25315,10929,10928,10927,6078,6077,6076,6075,6074,139 | 70,65,60,56,50,44,38,32,26,20,14,8 | ✅ | |
| InnerFocus | 14751 | 40 | 14751 | 40 | ✅ | |
| DispelMagic | 988,527 | 54,30 | 988,527 | 54,30 | ✅ | |
| DesperatePrayer | 25437,19243,19242,19241,19240,19238,19236,13908 | 66,58,50,42,34,26,18,10 | 25437,19243,19242,19241,19240,19238,19236,13908 | 66,58,50,42,34,26,18,10 | ✅ | Expanded from 1 to 8 ranks |
| HolyFire | 25384,15261,15267,15266,15265,15264,15263,15262,14914 | 66,60,54,48,42,36,30,24,20 | 25384,15261,15267,15266,15265,15264,15263,15262,14914 | 66,60,54,48,42,36,30,24,20 | ✅ | Added missing 15261(60) |
| Smite | 25364,25363,10934,10933,6060,1004,984,598,591,585 | 69,61,54,46,38,30,22,14,6,1 | 25364,25363,10934,10933,6060,1004,984,598,591,585 | 69,61,54,46,38,30,22,14,6,1 | ✅ | |
| BindingHeal | 32546 | 64 | 32546 | 64 | ✅ | |
| Lightwell | 28275,27871,27870,724 | 70,60,50,40 | 28275,27871,27870,724 | 70,60,50,40 | ✅ | |
| Shadowfiend | 34433 | 66 | 34433 | 66 | ✅ | |
| AbolishDisease | 552 | 32 | 552 | 32 | ✅ | |
| CureDisease | 528 | 14 | 528 | 14 | ✅ | |
| PowerWordShield | 25218,25217,10901,10900,10899,10898,6066,6065,3747,600,592,17 | 70,62,54,46,38,30,24,18,12,8,6,1 | 25218,25217,10901,10900,10899,10898,6066,6065,3747,600,592,17 | 70,62,54,46,38,30,24,18,12,8,6,1 | ✅ | |
| HolyNova | 25331,25329,27805,... | 70,64,58,... | 25331,25329,27805,... | 70,64,58,... | ✅ | |

---

## Behavioral Requirements

| # | Requirement | Source | Status | Evidence |
|---|---|---|---|---|
| 1 | Guardian Spirit [47788] absent — not implemented | Research.md Angle 1 | ✅ N/A | Spell not in DB2; correctly absent from code |
| 2 | Emergency PWS for lethal ally window | Research.md Priority 1 | ✅ Present | holy_sylvanas.lua: EmergencyPWS strategy |
| 3 | Emergency Flash Heal triage | Research.md Priority 4 | ✅ Present | holy_sylvanas.lua: EmergencyFlashHeal strategy |
| 4 | Prayer of Mending on CD | Research.md Priority 2 | ✅ Present | holy_sylvanas.lua: PrayerOfMending strategy |
| 5 | Circle of Healing for 3+ injured | Research.md Priority 3 | ✅ Present | holy_sylvanas.lua: CircleOfHealing strategy (aoe_count gate) |
| 6 | Binding Heal when self also injured | Research.md Priority 1 | ✅ Present | holy_sylvanas.lua: BindingHeal strategy |
| 7 | Prayer of Healing for 3+ subgroup injured | Research.md Priority 7 | ✅ Present | holy_sylvanas.lua: PrayerOfHealing strategy (subgroup_damaged_count) |
| 8 | Greater Heal for efficient planned healing | Research.md Priority 5 | ✅ Present | holy_sylvanas.lua: GreaterHeal strategy (with pushback gate) |
| 9 | Flash Heal for fast triage | Research.md Priority 4 | ✅ Present | holy_sylvanas.lua: FlashHeal strategy |
| 10 | Renew maintenance with < 3s refresh | Research.md Angle 5 | ✅ Present | holy_sylvanas.lua: RenewTank/RenewSpread with `renew_remains > 3` gate |
| 11 | Inner Focus on expensive heals | Research.md Cooldowns | ✅ Present | holy_sylvanas.lua: InnerFocus strategy |
| 12 | Clearcasting (Holy Concentration) Greater Heal | Research.md Talents | ✅ Present | holy_sylvanas.lua: ClearcastingGreaterHeal strategy |
| 13 | Dispel Magic (dangerous magic debuffs) | Research.md Utility | ✅ Present | holy_sylvanas.lua: DispelMagic strategy |
| 14 | Cure Disease on diseased allies | Research.md Utility | ✅ Present | holy_sylvanas.lua: CureDisease strategy |
| 15 | Abolish Disease preventive on tanks | Research.md Utility | ✅ Present | holy_sylvanas.lua: AbolishDisease strategy |
| 16 | Desperate Prayer self-heal emergency | Research.md Angle 1 | ✅ Present | holy_sylvanas.lua: DesperatePrayer strategy |
| 17 | Lightwell when raid lead wants it | Research.md Angle 1 | ✅ Present | holy_sylvanas.lua: Lightwell strategy (3+ injured gate) |
| 18 | Shadowfiend mana regen when low | Research.md Resource | ✅ Present | holy_sylvanas.lua: Shadowfiend strategy (mana_pct < 30% gate) |
| 19 | Mana < 30%: drop Greater Heal, Flash Heal + Renew only | Research.md Angle 4 Part B | ✅ Present | holy_sylvanas.lua: GreaterHeal `holy_gh_mana_floor` (default 30) |
| 20 | Mana < 15%: Renew only, all direct heals forbidden | Research.md Angle 4 Part B | ✅ Present | holy_sylvanas.lua: FlashHeal `holy_fh_mana_floor` (default 15) |
| 21 | Mana < 5%: wand/auto-attack only | Research.md Angle 4 Part B | ✅ Present | holy_sylvanas.lua: ManaBelow5Wand strategy |
| 22 | Downrank Greater Heal when conserving | Research.md Angle 4 Part D | ✅ Present | cast_best_heal_rank with GREATER_HEAL_RANKS |
| 23 | Surge of Light Smite proc usage | Research.md Talents | ✅ Present | holy_sylvanas.lua: SurgeOfLightSmite strategy |
| 24 | Idle DPS (SW:P/Holy Fire/Smite) when group safe | Research.md | ✅ Present | holy_sylvanas.lua: IdleSWP/IdleHolyFire/IdleSmite strategies |
| 25 | Pre-pull Prayer of Mending + Renew | Research.md | ✅ Present | holy_sylvanas.lua: out-of-combat prepull_pom/prepull_renew gates |
| 26 | Fade on aggro (FrostByte) | Research.md Threat | ✅ Present | holy_sylvanas.lua: Fade strategy |
| 27 | Healthstone below HP threshold (FrostByte) | Research.md Consumables | ✅ Present | holy_sylvanas.lua: Healthstone strategy |
| 28 | StopCast for higher-priority target (FrostByte) | Research.md | ✅ Present | holy_sylvanas.lua: StopCast strategy |
| 29 | PreHeal tank when predictable damage incoming (FrostByte) | Research.md | ✅ Present | holy_sylvanas.lua: PreHeal strategy |
| 30 | Encounter reactions for Karazhan (FrostByte) | Research.md Angle 2 | ✅ Present | holy_sylvanas.lua: EncounterReactions strategy |
| 31 | Mounted bail-out safety (FrostByte) | Research.md | ✅ Present | holy_sylvanas.lua: MountedProtection + build_holy_state early return |
| 32 | Party dispel mana floor gate | Research.md Resource | ✅ Present | holy_sylvanas.lua: dispel strategies with `party_dispel_mana_floor` |

## Forbidden Mechanics Verification

| Mechanic | Spell ID | Status |
|---|---|---|
| Guardian Spirit | 47788 | ✅ Absent (WotLK spell) |
| Chakra | - | ✅ Absent (Cata spell) |
| Serendipity | - | ✅ Absent (WotLK spell) |
| Holy Words | - | ✅ Absent (Cata spell) |
| Mind Sear | 48045 | ✅ Absent (WotLK spell) |
| Divine Hymn | 64843 | ✅ Absent (WotLK spell) |

## Schema Key Verification

| Key | In Schema | In Code | Match |
|---|---|---|---|
| holy_use_lightwell | ✅ | ✅ | ✅ Added during this job |

## API Validation

| API Call | File | Verified |
|---|---|---|
| try_cast | core_sylvanas.lua (import) | ✅ |
| spell_exists | core_sylvanas.lua (import) | ✅ |
| spell_ready | core_sylvanas.lua (import) | ✅ |
| debuff_remains | core_sylvanas.lua (import) | ✅ |
| health_pct | core_sylvanas.lua (import) | ✅ |
| player_control_locked | core_sylvanas.lua (import) | ✅ |
| has_player_buff | core_sylvanas.lua (import) | ✅ |
| Healing.scan_healing_targets | healing_sylvanas.lua | ✅ |
| Healing.count_subgroup_below_hp | healing_sylvanas.lua | ✅ |

---

## Validation

- ✅ `luac -p` passes on class_sylvanas.lua, holy_sylvanas.lua, schema_sylvanas.lua
- ✅ Code review cleared with schema key fix applied
- ✅ 32/32 behavioral requirements Present or N/A
- ✅ All forbidden mechanics absent

## Changes Summary

| File | Changes |
|---|---|
| class_sylvanas.lua | DesperatePrayer (1→8 ranks), HolyFire (added 15261), PrayerOfHealing (10961 level 54→60) |
| holy_sylvanas.lua | Lightwell, Shadowfiend, DispelMagic, CureDisease, AbolishDisease, ManaBelow5Wand strategies |
| schema_sylvanas.lua | Added holy_use_lightwell setting to Holy tab |
