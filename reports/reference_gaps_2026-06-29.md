# Reference Gap Report
**Date**: 2026-06-29 10:39
**Reference**: `tbc-main` (78 files)
**EAX**: `EaxRotations` (420 files)

## Feature Gaps (75)
Features in reference but **not** in EAX:

- [ ] `auto_abolish_disease`
- [ ] `auto_attack_spell_id`
- [ ] `auto_dispel_magic`
- [ ] `auto_powershift`
- [ ] `auto_ps`
- [ ] `auto_remove_poison`
- [ ] `auto_shot_spell_ids`
- [ ] `auto_shot_spell_names`
- [ ] `auto_sync_cds`
- [ ] `auto_tab_execute`
- [ ] `enable_aoe`
- [ ] `enable_tab_targeting`
- [ ] `use_arcane_intellect`
- [ ] `use_auto_bandage`
- [ ] `use_auto_charge`
- [ ] `use_auto_freedom`
- [ ] `use_auto_tab`
- [ ] `use_auto_tremor`
- [ ] `use_barkskin`
- [ ] `use_bash_interrupt`
- [ ] `use_berserker_rage`
- [ ] `use_bestial_wrath`
- [ ] `use_bite_execute`
- [ ] `use_bite_trick`
- [ ] `use_bloodrage`
- [ ] `use_challenging_roar`
- [ ] `use_cloak_of_shadows`
- [ ] `use_counterspell`
- [ ] `use_cure_disease`
- [ ] `use_cure_poison`
- [ ] `use_dark_rune`
- [ ] `use_divine_spirit`
- [ ] `use_enrage`
- [ ] `use_evasion`
- [ ] `use_fade`
- [ ] `use_fear_ward`
- [ ] `use_feign_death`
- [ ] `use_feint`
- [ ] `use_fel_armor`
- [ ] `use_force_of_nature`
- [ ] `use_fortitude`
- [ ] `use_frenzied_regen`
- [ ] `use_fresh_mana`
- [ ] `use_goblin_sapper`
- [ ] `use_growl`
- [ ] `use_haste_potion`
- [ ] `use_inner_fire`
- [ ] `use_innervate_self`
- [ ] `use_kick`
- [ ] `use_loc_breaker`
- [ ] `use_mana_rune`
- [ ] `use_mangle_builder`
- [ ] `use_mangle_opener`
- [ ] `use_mangle_trick`
- [ ] `use_motw`
- [ ] `use_ooc`
- [ ] `use_opener`
- [ ] `use_priority_interrupt`
- [ ] `use_racial`
- [ ] `use_rake_trick`
- [ ] `use_retaliation`
- [ ] `use_sappers`
- [ ] `use_scorpid_sting`
- [ ] `use_serpent_sting`
- [ ] `use_shadow_protection`
- [ ] `use_shiv`
- [ ] `use_soulshatter`
- [ ] `use_spell_reflection`
- [ ] `use_super_sapper`
- [ ] `use_target_focus_behind`
- [ ] `use_thistle_tea`
- [ ] `use_thorns`
- [ ] `use_tigers_fury`
- [ ] `use_vanish_emergency`
- [ ] `use_wing_clip`

## Shared Features (25)
- ✅ `auto_attack`
- ✅ `auto_burst`
- ✅ `auto_remove_curse`
- ✅ `auto_shout`
- ✅ `use_arcane`
- ✅ `use_avenging_wrath`
- ✅ `use_cleanse`
- ✅ `use_desperate_prayer`
- ✅ `use_evocation`
- ✅ `use_expose_armor`
- ✅ `use_hammer_of_justice`
- ✅ `use_healing_potion`
- ✅ `use_healthstone`
- ✅ `use_hl`
- ✅ `use_ice_barrier`
- ✅ `use_interrupt`
- ✅ `use_mana_gem`
- ✅ `use_mana_potion`
- ✅ `use_multi_for_catchup`
- ✅ `use_purge`
- ✅ `use_rapid_fire`
- ✅ `use_readiness`
- ✅ `use_seal_of_wisdom_low_mana`
- ✅ `use_shadowfiend`
- ✅ `use_viper_sting_pve`

## Large Reference Files Missing in EAX
- `tbc-main\rotation\tmw-template.lua` — **6466 lines**
- `tbc-main\rotation\source\aio\warrior\middleware.lua` — **1519 lines**
- `tbc-main\rotation\source\aio\dashboard.lua` — **1428 lines**
- `tbc-main\rotation\source\aio\hunter\cliptracker.lua` — **1360 lines**
- `tbc-main\rotation\source\aio\warrior\schema.lua` — **1191 lines**
- `tbc-main\rotation\source\aio\druid\bear.lua` — **1145 lines**
- `tbc-main\rotation\source\aio\core.lua` — **1130 lines**
- `tbc-main\rotation\source\aio\druid\cat.lua` — **1097 lines**
- `tbc-main\rotation\source\aio\hunter\adaptive.lua` — **949 lines**
- `tbc-main\rotation\source\aio\shaman\enhancement.lua` — **854 lines**
- `tbc-main\rotation\source\aio\druid\class.lua` — **812 lines**
- `tbc-main\docs\api\Player.lua` — **766 lines**
- `tbc-main\rotation\source\aio\warrior\protection.lua` — **761 lines**
- `tbc-main\rotation\source\aio\paladin\protection.lua` — **708 lines**
- `tbc-main\rotation\source\aio\hunter\rotation.lua` — **692 lines**
- `tbc-main\docs\api\Unit.lua` — **676 lines**
- `tbc-main\rotation\source\aio\hunter\meleeweave.lua` — **675 lines**
- `tbc-main\rotation\source\aio\priest\shadow.lua` — **608 lines**
- `tbc-main\rotation\source\aio\shaman\middleware.lua` — **591 lines**
- `tbc-main\rotation\source\aio\paladin\retribution.lua` — **583 lines**
- `tbc-main\docs\api\Globals.lua` — **548 lines**
- `tbc-main\rotation\source\aio\warrior\arms.lua` — **534 lines**
- `tbc-main\rotation\source\aio\paladin\holy.lua` — **528 lines**
- `tbc-main\rotation\source\aio\warrior\fury.lua` — **518 lines**

## Healthstone Coverage
Reference classes with healthstone: 9
 - `tbc-main\rotation\source\aio\druid\middleware.lua`
 - `tbc-main\rotation\source\aio\hunter\middleware.lua`
 - `tbc-main\rotation\source\aio\mage\middleware.lua`
 - `tbc-main\rotation\source\aio\paladin\middleware.lua`
 - `tbc-main\rotation\source\aio\priest\middleware.lua`
 - `tbc-main\rotation\source\aio\rogue\middleware.lua`
 - `tbc-main\rotation\source\aio\shaman\middleware.lua`
 - `tbc-main\rotation\source\aio\warlock\middleware.lua`
 - `tbc-main\rotation\source\aio\warrior\middleware.lua`

EAX classes with healthstone: 13
 - `classes\druid\middleware_sylvanas.lua`
 - `classes\hunter\middleware_sylvanas.lua`
 - `classes\mage\middleware_sylvanas.lua`
 - `classes\priest\discipline_sylvanas.lua`
 - `classes\priest\discipline_vanilla.lua`
 - `classes\priest\holy_sylvanas.lua`
 - `classes\priest\holy_vanilla.lua`
 - `classes\priest\shadow_sylvanas.lua`
 - `classes\warlock\affliction_sylvanas.lua`
 - `classes\warlock\demonology_sylvanas.lua`
 - `classes\warlock\destruction_sylvanas.lua`
 - `classes\warlock\middleware_sylvanas.lua`
 - `shared\consumable_manager_sylvanas.lua`

## Stance/Powershift Coverage
Reference files with stance/powershift: 2
 - `tbc-main\rotation\source\aio\druid\cat.lua`
 - `tbc-main\rotation\source\aio\warrior\middleware.lua`

EAX files with stance/powershift: 1
 - `classes\warrior\middleware_sylvanas.lua`
