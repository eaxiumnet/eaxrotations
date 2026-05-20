# Shaman Elemental — Implementation Checklist

**Created**: 2026-05-20 | **DB2 Source**: `ClassResearchTBC/Shaman/DB2-Spells.md`
**Research**: `ClassResearchTBC/Shaman/Elemental/Research.md`

---

## DB2 Spell Verification

| Spell | DB2 IDs | DB2 Levels | Code IDs | Code Levels | Match | Notes |
|---|---|---|---|---|---|---|
| LightningBolt | 25449..403 (12 ranks) | 67,62,56,50,44,38,32,26,20,14,8,1 | same | 70,62,54,46,38,30,22,14,8,4,1(11 levels) | ❌ | **FIXED**: 12 levels→{67,62,56,50,44,38,32,26,20,14,8,1} |
| ChainLightning | 25442..421 (6 ranks) | 70,63,56,48,40,32 | same | 70,62,52,44,36,28 | ❌ | **FIXED**: →{70,63,56,48,40,32} |
| EarthShock | 25454..8042 (8 ranks) | 69,60,48,36,24,14,8,4 | same | 70,62,52,44,36,28,22,14 | ❌ | **FIXED**: →{69,60,48,36,24,14,8,4} |
| FlameShock | 25457..8050 (7 ranks) | 70,60,52,40,28,18,10 | same | 70,64,56,48,40,30,22 | ❌ | **FIXED**: →{70,60,52,40,28,18,10} |
| FrostShock | 25464..8056 (5 ranks) | 68,58,46,34,20 | same | 70,62,52,44,36 | ❌ | **FIXED**: →{68,58,46,34,20} |
| LightningShield | 25472..324 (9 ranks) | 70,63,56,48,40,32,24,16,8 | same | 70,62,52,44,36,28,20,14,1 | ❌ | **FIXED**: →{70,63,56,48,40,32,24,16,8} |
| WaterShield | 33736,24398,23575 | 69,62,50 | 33736,24398,23575 | 66,60,50 | ❌ | **FIXED**: →{69,62,50} |
| Purge | 8012,370 | 32,12 | 8012,370 | 58,22 | ❌ | **FIXED**: →{32,12} |
| ChainHeal | 25423..1064 (5 ranks) | 68,61,54,46,40 | same | 70,62,52,44,40 | ❌ | **FIXED**: →{68,61,54,46,40} |
| ManaTideTotem | 16190 | 40 | 16190 | 60 | ❌ | **FIXED**: →40 |
| Bloodlust | 2825 | 70 | 2825 | 68 | ❌ | **FIXED**: →70 |
| EarthbindTotem | 2484 | 6 | 2484 | 26 | ❌ | **FIXED**: →6 |
| ManaSpringTotem | 25570..5675 (5 ranks) | 65,56,46,36,26 | same | 70,60,50,40,30 | ❌ | **FIXED**: →{65,56,46,36,26} |
| TotemicCall | 36936 | 30 | 36936 | 1 | ❌ | **FIXED**: →30 |
| ElementalMastery | 16166 | talent(lvl1) | 16166 | 50 | ✅ | Talent, level in table is irrelevant |
| TotemOfWrath | 30706 | 50 | 30706 | 50 | ✅ | |
| WrathOfAirTotem | 3738 | 64 | 3738 | 64 | ✅ | |
| FireNovaTotem | 25547..1535 (7 ranks) | 70,61,52,42,32,22,12 | same | same | ✅ | |
| MagmaTotem | 25552..8190 (5 ranks) | 65,56,46,36,26 | same | same | ✅ | |

---

## Behavioral Requirements

| Requirement | Source | Status | Notes |
|---|---|---|---|
| Lightning Bolt filler (max rank) | Research Single-Target | ✅ Present | Strategy LightningBolt |
| Lightning Bolt downrank at mana < 30% | Research Angle 4 | ✅ Present | Uses SPELLS.LightningBoltLowerRank (25448) |
| Chain Lightning at 3+ targets | Research Multi-Target | ✅ Present | Configurable via elemental_cl_min_targets |
| Chain Lightning skip when mana_conserve | Research Angle 4 | ✅ Present | state.mana_conserve gate |
| Chain Lightning skip when CC unsafe | Research | ✅ Present | cc_safe gate |
| Chain Lightning skip when threat > 80% | Research Threat | ✅ Present | threat_pct > 80 gate |
| Flame Shock refresh at < 1s remaining | Research Angle 5 | ✅ Present | remains > 1 check |
| Earth Shock interrupt (target casting) | Research | ✅ Present | EarthShock strategy checks is_casting |
| Earth Shock filler (moving, no reserve) | Research | ✅ Present | EarthShockMoving strategy |
| Earth Shock reserve for interrupts | Research | ✅ Present | elemental_interrupt_reserve setting |
| Elemental Mastery burst (with burst window) | Research Cooldowns | ✅ Present | ElementalMastery strategy |
| Nature's Swiftness burst | Research Cooldowns | ✅ Present | NaturesSwiftness strategy |
| Bloodlust burst (combat, burst window) | Research Cooldowns | ✅ Present | Bloodlust strategy |
| Totem of Wrath maintain (OOC) | Research | ✅ Present | TotemOfWrath strategy |
| Wrath of Air Totem maintain (OOC) | Research | ✅ Present | WrathOfAirTotem strategy |
| Mana Spring Totem maintain (OOC) | Research | ✅ Present | ManaSpringTotem strategy |
| Fire Nova Totem AoE (4+ targets) | Research Multi-Target | ✅ Present | FireNovaTotem strategy |
| Magma Totem AoE (4+ targets) | Research Multi-Target | ✅ Present | MagmaTotem strategy |
| Lightning Shield buff maintain | Research | ✅ Present | LightningShield strategy |
| Water Shield at low mana | Research Resource Mgmt | ✅ Present | WaterShield strategy |
| Mana Tide Totem at mana < 30% | Research Resource Mgmt | ✅ Present | ManaTideTotem strategy |
| Healing Wave self-heal at low HP | Research Utility | ✅ Present | HealingWave strategy |
| Ghost Wolf OOC movement | Research Utility | ✅ Present | GhostWolf strategy |
| Tremor Totem anti-fear | Research PvP | ✅ Present | TremorTotem strategy |
| Earthbind Totem PvP slow | Research PvP | ✅ Present | EarthbindTotem strategy |
| Chain Heal group emergency | Research Utility | ✅ Present | ChainHeal strategy |
| Flametongue Weapon (OOC) | Research | ✅ Present | FlametongueWeapon strategy |
| Windfury Weapon (OOC) | Research | ✅ Present | WindfuryWeapon strategy |
| Rockbiter Weapon (OOC) | Research | ✅ Present | RockbiterWeapon strategy |
| Totemic Call (combat moving) | Research | ✅ Present | TotemicCall strategy |
| Frost Shock moving PvP | Research PvP | ✅ Present | FrostShockMoving strategy |
| Mana < 5%: auto-attack/wand only | Research Angle 4 Part B | ✅ Fixed | ManaEmergencyWand strategy added at position 1 |
| Totem range check (pre-place at 20-25y) | Research Angle 5 | ⚠️ Blocked | Requires engine-level totem range API or runtime measurement; not safe to hard-code range without live Sylvanas test |

---

## Forbidden Mechanics (TBC Guardrail)

| Forbidden spell/mechanic | Source | Status |
|---|---|---|
| Lava Burst | WotLK+ | ✅ Absent |
| Thunderstorm | WotLK+ | ✅ Absent |
| Hex | WotLK+ | ✅ Absent |
| Wind Shear | WotLK+ | ✅ Absent |

---

## Schema Verification

| Setting Key | Type | Present | Notes |
|---|---|---|---|
| elemental_cl_min_targets | slider | ✅ | |
| elemental_cl_cluster_radius | slider | ✅ | |
| elemental_aoe_threshold | slider | ✅ | |
| elemental_mana_low_pct | slider | ✅ | default 30 |
| elemental_mana_conserve_pct | slider | ✅ | default 15 |
| elemental_mana_emergency_pct | slider | ✅ | default 5 |
| elemental_use_elemental_mastery | checkbox | ✅ | |
| elemental_use_natures_swiftness | checkbox | ✅ | |
| elemental_manage_totems | checkbox | ✅ | |
| elemental_use_totem_of_wrath | checkbox | ✅ | |
| elemental_use_fire_nova_aoe | checkbox | ✅ | |
| elemental_use_magma_aoe | checkbox | ✅ | |
| elemental_lightning_shield | checkbox | ✅ | |
| elemental_water_shield_mana | slider | ✅ | |
| elemental_self_heal_hp | slider | ✅ | |
| elemental_interrupt_reserve | checkbox | ✅ | |

---

## Test Coverage

| Test | Status |
|---|---|
| test_elemental_weapon_buffs.lua | ✅ Existing |
| luac -p syntax check | ✅ All pass |

---

## Summary

- **DB2 fixes**: 13 spell level corrections in class_sylvanas.lua
- **Behavioral**: Mana < 5% auto-attack strategy added
- **Schema**: Already comprehensive — no changes needed
- **DB2 fixes**: 13 spell level corrections in class_sylvanas.lua
- **Behavioral**: Mana < 5% auto-attack strategy added (position 1), mana_emergency gates added to LightningShield, WaterShield, TremorTotem, EarthbindTotem, ManaTideTotem
- **Schema**: Already comprehensive — no changes needed
- **Review pass 2**: Moved ManaEmergencyWand to strategy position 1 (gates all others at <5% mana); added mana_emergency short-circuits to 5 early strategies
- **32/33 behavioral requirements**: Present. 1 Blocked (totem range — requires engine-level totem range API)
- ✅ luac -p passes (both passes) | ✅ Code review cleared (both passes)
