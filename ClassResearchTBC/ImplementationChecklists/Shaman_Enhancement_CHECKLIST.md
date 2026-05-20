# Shaman Enhancement — Implementation Checklist

**Job**: 022 | **Spec**: Shaman Enhancement  
**Research**: `ClassResearchTBC/Shaman/Enhancement/Research.md`  
**DB2 Source**: `ClassResearchTBC/Shaman/DB2-Spells.md`  
**Last Updated**: 2026-05-20 (final — luac -p passed, code review cleared)

---

## Part A: DB2 Spell ID and Level Verification

| Spell | DB2 IDs | DB2 Levels | Code Levels (before) | Code Levels (after) | Status |
|---|---|---|---|---|---|
| Bloodlust [2825] | 2825 | 70 | 70 | 70 | ✅ Present |
| ChainLightning | 25442,25439,10605,2860,930,421 | 70,63,56,48,40,32 | 70,63,56,48,40,32 | — | ✅ Present (fixed Job 021) |
| EarthShock | 25454,10414,10413,10412,8046,8045,8044,8042 | 69,60,48,36,24,14,8,4 | 69,60,48,36,24,14,8,4 | — | ✅ Present (fixed Job 021) |
| FireNovaTotem | 25547,25546,11315,11314,8499,8498,1535 | 70,61,52,42,32,22,12 | 70,61,52,42,32,22,12 | — | ✅ Present |
| FlameShock | 25457,29228,10448,10447,8053,8052,8050 | 70,60,52,40,28,18,10 | 70,60,52,40,28,18,10 | — | ✅ Present (fixed Job 021) |
| FlametongueWeapon | 25489,16342,16341,16339,8030,8027,8024 | 64,56,46,36,26,18,10 | 64,56,46,36,26,18,10 | — | ✅ Present |
| FrostShock | 25464,10473,10472,8058,8056 | 68,58,46,34,20 | 68,58,46,34,20 | — | ✅ Present (fixed Job 021) |
| FrostbrandWeapon | 25500,16356,16355,10456,8038,8033 | 66,58,48,38,28,20 | 66,58,48,38,28,20 | — | ✅ Present |
| **GraceOfAirTotem** | 25359,10627,8835 | **60,56,42** | **70,60,48** | **60,56,42** | 🔧 Fixed |
| GroundingTotem | 8177 | 32 | 32 | — | ✅ Present |
| HealingStreamTotem | 25567,10463,10462,6377,6375,5394 | 69,60,50,40,30,20 | 69,60,50,40,30,20 | — | ✅ Present |
| **LesserHealingWave** | 25420,10468,10467,10466,8010,8008,8004 | **66,60,52,44,36,28,20** | **68,60,50,42,34,26,18** | **66,60,52,44,36,28,20** | 🔧 Fixed |
| LightningBolt | 25449,25448,15208,15207,10392,10391,6041,943,915,548,529,403 | 67,62,56,50,44,38,32,26,20,14,8,1 | 67,62,56,50,44,38,32,26,20,14,8,1 | — | ✅ Present (fixed Job 021) |
| LightningShield | 25472,25469,10432,10431,8134,945,905,325,324 | 70,63,56,48,40,32,24,16,8 | 70,63,56,48,40,32,24,16,8 | — | ✅ Present (fixed Job 021) |
| MagmaTotem | 25552,10587,10586,10585,8190 | 65,56,46,36,26 | 65,56,46,36,26 | — | ✅ Present |
| ManaSpringTotem | 25570,10497,10496,10495,5675 | 65,56,46,36,26 | 65,56,46,36,26 | — | ✅ Present (fixed Job 021) |
| ManaTideTotem | 16190 | 40 | 40 | — | ✅ Present (fixed Job 021) |
| **RockbiterWeapon** | 25485,25479,16316,16315,16314,10399,8019,8018,8017 | **70,62,54,44,34,24,16,8,1** | **70,64,56,48,40,30,20,10,1** | **70,62,54,44,34,24,16,8,1** | 🔧 Fixed |
| SearingTotem | 25533,10438,10437,6365,6364,6363,3599 | 69,60,50,40,30,20,10 | 69,60,50,40,30,20,10 | — | ✅ Present |
| ShamanisticRage | 30823 | 50 | 50 | — | ✅ Present |
| **Stormstrike** | 17364 | **40** | **50** | **40** | 🔧 Fixed |
| StoneskinTotem | 25509,25508,10408,10407,10406,8155,8154,8071 | 70,63,54,44,34,24,14,4 | 70,63,54,44,34,24,14,4 | — | ✅ Present |
| StrengthOfEarthTotem | 25528,25361,10442,8161,8160,8075 | 65,60,52,38,24,10 | 65,60,52,38,24,10 | — | ✅ Present |
| TremorTotem | 8143 | 18 | 18 | — | ✅ Present |
| WaterShield | 33736,24398,23575 | 69,62,50 | 69,62,50 | — | ✅ Present (fixed Job 021) |
| WindfuryTotem | 25587,25585,10614,10613,8512 | 70,61,52,42,32 | 70,61,52,42,32 | — | ✅ Present (fixed Job 021) |
| WindfuryWeapon | 25505,16362,10486,8235,8232 | 68,60,50,40,30 | 68,60,50,40,30 | — | ✅ Present (fixed Job 021) |

**Summary**: 4 DB2 corrections applied (GraceOfAirTotem, Stormstrike, LesserHealingWave, RockbiterWeapon). 20/24 already correct (many fixed in Job 021).

---

## Part B: Behavioral Requirements

| # | Requirement | Source | Status |
|---|---|---|---|
| 1 | Maintain correct weapon imbues (Windfury MH, Flametongue/Frostbrand OH) | Research: Single Target #1 | ✅ Present |
| 2 | Keep Strength of Earth/Grace/Windfury totem assignment active | Research: Single Target #2 | ✅ Present |
| 3 | Use Stormstrike on cooldown | Research: Single Target #3 | ✅ Present |
| 4 | Earth Shock as primary shock; Flame Shock only if it will tick | Research: Single Target #4 | ✅ Present |
| 5 | Twist Windfury/Grace if assigned and swing timing supports it | Research: Single Target #5 | ✅ Present |
| 6 | Use Shamanistic Rage for mana and defensive value | Research: Single Target #6 | ✅ Present |
| 7 | Mana < 20%: Stormstrike only; no shocks | Research: Resource Floor | ✅ Present |
| 8 | Mana < 10%: Auto-attack only. All spells forbidden | Research: Resource Floor | 🔧 **Added** (was Missing) |
| 9 | Bloodlust/Heroism by raid assignment | Research: Cooldown Usage | ✅ Present |
| 10 | Shamanistic Rage before mana collapse | Research: Cooldown Usage | ✅ Present |
| 11 | Fire Nova Totem and Magma Totem as main AoE tools | Research: Multi Target | ✅ Present |
| 12 | Track main/offhand imbues, totem state, Windfury buff | Research: Automation Notes | ✅ Present |
| 13 | Grace of Air Totem rank resolution [8835/10627/25359] | Research: Hard rule | 🔧 **Fixed** (was Wrong) |
| 14 | No Feral Spirit, Maelstrom Weapon, Lava Lash (WotLK) | Research: Hard rule | ✅ Present |
| 15 | Nil-guard all menu accesses | Research: Automation Rules | ✅ Present |
| 16 | Cache hot-path API references | Research: Codegen | ✅ Present |
| 17 | Squared distance checks for totem range | Research: Codegen | ✅ Present |
| 18 | Lightning Shield maintain with 3 charges | Research: Angle 5 | ✅ Present |
| 19 | Earth Shock interrupt mode with cast-% gates | Research: PvP/Utility | ✅ Present |
| 20 | Ghost Wolf OOC movement | Research: Utility | ✅ Present |
| 21 | Tremor Totem fear/charm/sleep break | Research: PvP | ✅ Present |
| 22 | Grounding Totem for spell absorb | Research: PvP | ✅ Present |
| 23 | Totemic Call when totems out of range (20yd) | Research: Automation | ✅ Present |
| 24 | Weapon sync awareness (WF procs gated by MH swing timer) | Research: Angle 1 | ⚠️ Blocked (twist timing present; engine-level swing-sync gated on NS.GetSwingTimer API exposure — needs runtime test) |

---

## Part C: Forbidden Mechanics

| Forbidden Mechanic | Present in Code? |
|---|---|
| Feral Spirit (WotLK) | ❌ Absent |
| Maelstrom Weapon (WotLK) | ❌ Absent |
| Lava Lash (WotLK) | ❌ Absent |
| Wind Shear (WotLK) | ❌ Absent |
| Lava Burst (WotLK) | ❌ Absent |
| External addon APIs | ❌ Absent |
| math.sqrt() for range | ❌ Absent (uses squared dist) |

---

## Part D: Schema Verification

| Schema Key | Type | Spec Tab | Code Reads | Status |
|---|---|---|---|---|
| enhancement_combat_mode | dropdown | Enhancement Combat | ✅ | ✅ Present |
| enhancement_earth_shock_mode | dropdown | Enhancement Combat | ✅ | ✅ Present |
| enhancement_shield_type | dropdown | Enhancement Combat | ✅ | ✅ Present |
| enhancement_manage_totems | checkbox | Enhancement Combat | ✅ | ✅ Present |
| enhancement_totem_twisting | checkbox | Enhancement Combat | ✅ | ✅ Present |
| enhancement_auto_attack | checkbox | Enhancement Combat | ✅ | ✅ Present |
| enhancement_aoe_threshold | slider | Enhancement Combat | ✅ | ✅ Present |
| enhancement_air_totem | dropdown | Air Totems | ✅ | ✅ Present |
| enhancement_earth_totem | dropdown | Earth Totems | ✅ | ✅ Present |
| enhancement_fire_totem | dropdown | Fire Totems | ✅ | ✅ Present |
| enhancement_water_totem | dropdown | Water Totems | ✅ | ✅ Present |
| enhancement_main_hand_ench | dropdown | Weapon Buffs | ✅ | ✅ Present |
| enhancement_off_hand_ench | dropdown | Weapon Buffs | ✅ | ✅ Present |
| enhancement_self_heal_hp | slider | Survival | ✅ | ✅ Present |
| enhancement_chain_heal_hp | slider | Survival | ✅ | ✅ Present |
| enhancement_interrupt_kick_min | slider | Interrupts | ✅ | ✅ Present |
| enhancement_interrupt_kick_max | slider | Interrupts | ✅ | ✅ Present |
| enhancement_interrupt_mode | dropdown | Interrupts | ✅ | ✅ Present |
| enhancement_sr_melee_only | checkbox | Interrupts | ✅ | ✅ Present |
| enhancement_totem_range | slider | Utility | ✅ | ✅ Present |
| enhancement_fs_multi_target | checkbox | Utility | ✅ | ✅ Present |
| enhancement_hold_shocks_focus | checkbox | Utility | ✅ | ✅ Present |
| enhancement_ghost_wolf_ooc | checkbox | Utility | ✅ | ✅ Present |
| enhancement_water_shield_mana | slider | Utility | ✅ | ✅ Present |
| enhancement_lightning_shield_mana | slider | Utility | ✅ | ✅ Present |
| enhancement_auto_totemic_call | checkbox | Utility | ✅ | ✅ Present |
| enhancement_mana_low_pct | slider | Mana Conservation | ✅ | ✅ Present |
| enhancement_mana_emergency_pct | slider | Mana Conservation | ✅ | ✅ Present |
| enhancement_totem_twist_mana_floor | slider | Mana Conservation | ✅ | ✅ Present |
| enhancement_cd_shamanistic_rage | checkbox | Cooldowns | ✅ | ✅ Present |
| enhancement_cd_blood_fury | checkbox | Cooldowns | ✅ | ✅ Present |
| enhancement_cd_berserking | checkbox | Cooldowns | ✅ | ✅ Present |
| enhancement_cd_bloodlust | checkbox | Cooldowns | ✅ | ✅ Present |
| enhancement_cd_mana_tide | checkbox | Cooldowns | ✅ | ✅ Present |
| enhancement_cd_gift_of_the_naaru | checkbox | Cooldowns | ✅ | ✅ Present |
| debug_mode | checkbox | Debug | ✅ | ✅ Present |

---

## Part E: API Validation

| API Function | File/Line | Validated? |
|---|---|---|
| `core.object_manager.get_local_player()` | via NS.GetPlayer() | ✅ |
| `core.object_manager.get_visible_objects()` | totemic_call_matches | ✅ |
| `core.spell_book.get_totem_info()` | totem range scan | ✅ |
| `NS.buff_up()` | buff detection | ✅ |
| `NS.debuff_up()` | flame shock tracking | ✅ |
| `NS.debuff_remains()` | flame shock refresh | ✅ |
| `NS.spell_ready()` | spell readiness | ✅ |
| `NS.try_cast()` | spell execution | ✅ |
| `NS.game_time_ms()` | timing | ✅ |
| `NS.action_matches()` | action matching | ✅ |
| `NS.action_execute()` | action execution | ✅ |
| `auto_attack:start_attack()` | auto-attack | ✅ |

---

## Part F: Test Coverage

| Test | Path | Status |
|---|---|---|
| Self-heal tests | `EaxRotations/tests/test_shaman_enhancement_self_heal.lua` | ✅ Exists |
