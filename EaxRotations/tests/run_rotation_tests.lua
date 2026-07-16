-- run_rotation_tests.lua — EAX Rotation Test Suite Runner.
-- WHAT:  discovers and executes all rotation unit-test suites under EaxRotations/tests/.
-- WHEN:  invoked via lua EaxRotations/tests/run_rotation_tests.lua.
-- WHY:   single entry point for 245 rotation-suite validations; ensures no regressions.
-- SAFETY: pure orchestration; no rotation logic; fails fast on first suite error.

local runner = require("EaxRotations/tests/test_runner_lib")
local mode, root = runner.parse_args(arg, "EaxRotations")

local tests = {
 "test_pvp_burst_window.lua",
 "test_boss_school_immunity.lua",

 "test_try_cast_izi_primary.lua",
 "test_range_verification_oor_fallthrough.lua",
 "test_update_callback_void_registration.lua",
 "test_update_callback_rotation_disabled_sync.lua",
 -- Dispatcher + loader regressions
 "test_dispatcher_role_mode.lua",
 "test_class_loader_fail_closed.lua",

 -- New feature tests (parity)
 "test_shadow_silence_interrupt.lua",
 "test_arms_healthstone.lua",
 "test_hunter_bm_melee_aoe_trinket.lua",

 -- Supremacy Phase 1 tests
 "test_stopcast_engine.lua",
 "test_pet_heal.lua",
 "test_triage_tank_bias.lua",
 "test_snap_threat.lua",
 "test_combat_mode.lua",

 -- Supremacy Phase 2 tests
 "test_paladin_protection_jow_mode.lua",
 "test_holy_lg_chaining.lua",
 "test_protection_bok_party.lua",
 "test_paladin_retribution_post_swing_judge.lua",
  "test_paladin_retribution_seal_ooc.lua",
 "test_paladin_retribution_twist_diagnostics.lua",
 "test_swing_diagnostics.lua",
 "test_melee_cleu_wiring.lua",
 "test_swing_mechanics.lua",
 "test_snapshot_helper.lua",
 "test_shaman_enhancement_totem_twist.lua",
 "test_shaman_enhancement_auto_weapon_buffs.lua",
  "test_shaman_low_level_gates.lua",
 "test_shaman_enhancement_intelligent_shield.lua",

 -- Supremacy Phase 3 tests
 "test_dot_ttd_gating.lua",
 "test_shot_timer.lua",
 "test_aspect_manager.lua",
 "test_shadow_multidot.lua",
 "test_shadow_inner_focus_combo.lua",
 "test_shadow_refresh_windows.lua",
 "test_affliction_dot_ttd.lua",
 "test_hunter_shot_timer_integration.lua",
 "test_hunter_melee_weave.lua",

  -- Supremacy Phase 4 tests
  "test_stance_manager.lua",
  "test_rage_manager.lua",
  "test_dispel_manager.lua",

  -- Health prediction integration tests
  "test_health_pred_integration.lua",

  -- Arms warrior tests
  "test_arms_custom_matches.lua",
  "test_arms_hamstring_tactician.lua",
  "test_arms_rage_gating.lua",
  "test_arms_critical_fixes.lua",
  "test_warrior_defensive_threshold_wiring.lua",
  "test_warrior_arms_wotlk.lua",
  "test_wotlk_specs_load.lua",
  "test_wotlk_leveling_load.lua",
  "test_deathknight_blood_wotlk.lua",
  "test_warlock_affliction_wotlk.lua",
  "test_presence_manager.lua",
  "test_rune_manager.lua",


 -- Hunter tests
 "test_hunter_aspect_matches.lua",
 "test_hunter_low_level_gating.lua",
 "test_pet_happiness.lua",
 "test_hunter_pet_manager_wiring.lua",
 "test_hunter_steady_shot_weave.lua",
 "test_hunter_dead_zone.lua",
 "test_mm_trueshot_aura.lua",
 -- Hunter custom matches gate sweeps (audit gap #3)
 "test_beast_mastery_custom_matches.lua",
 "test_marksmanship_custom_matches.lua",
 "test_survival_custom_matches.lua",


 -- Priest tests
 "test_priest_holy_custom_matches.lua",
 "test_priest_holy_friendly_target.lua",
 "test_discipline_friendly_target.lua",
 "test_paladin_holy_friendly_target.lua",
 "test_druid_resto_friendly_target.lua",
 "test_shaman_resto_friendly_target.lua",

 -- Druid tests
 "test_balance_custom_matches.lua",
 "test_bear_custom_matches.lua",
 "test_cat_custom_matches.lua",
 "test_cat_vanilla_low_level_gating.lua",
 "test_druid_vanilla_low_level_gating.lua",
 "test_druid_feral_l42_mangle_gate.lua",
 "test_druid_feral_level_42.lua",
 "test_druid_caster_custom_matches.lua",

 -- Core/shared infrastructure tests
 "test_aura_probe_sylvanas.lua",
 "test_trinket_manager.lua",
 "test_cooldown_planner.lua",
 "test_spell_resolver_cache.lua",
 "test_boss_count.lua",
 "test_tbc_consumable_data.lua",
 "test_cooldown_registry.lua",
 "test_runtime_compat_aliases.lua",
 "test_archive_self_buff_aliases.lua",
 "test_expansion_helpers.lua", "test_execute_phase.lua",
 "test_melee_combat_math.lua",
 "test_spell_rank_fallback.lua",
 "test_spell_id_table_regressions.lua",
 "test_ooc_manager.lua",
 "test_racial_manager.lua",
 "test_racial_autocast.lua",
 "test_interrupt_manager.lua",
 "test_interrupt_manager_school_lock.lua",
 "test_burst_logic_integration.lua",
  "test_mage_tbc_corrections.lua",
  "test_fsr_positive_delta.lua",
 "test_api_lint.lua",
 "test_rotation_static_compliance.lua",
 "test_rotation_strategy_compliance.lua",
 "test_quality_bar_compliance.lua",
 "test_spec_layout_compliance.lua",
 "test_schema_compliance.lua",
 "test_cross_consistency.lua",
 "test_hunter_adaptive_nil_globals.lua",
 "test_vec2_api_lint.lua",
 "test_fire_scorch_maintenance.lua",
 "test_frost_shatter_combo.lua",
 "test_ele_shock_gating.lua",
 "test_gear_helpers.lua",
 "test_dot_refresh.lua",
 "test_dot_refresh_integration.lua",
 "test_enemy_count_hysteresis.lua",
 "test_sticky_spell.lua",

 -- Control panel / settings tests
 "test_control_panel_quick_toggles.lua",
 "test_playstyle_label_fallback_fires.lua",
 "test_playstyle_setting_overrides_stale_active.lua",
 "test_playstyle_setting_seeds_active.lua",

 -- Edge / regression tests
 "test_combat_state_unknown_no_ooc.lua",
 "test_can_attack_false_enemy_with_fires.lua",
 "test_can_attack_false_reaction_hostile_fires.lua",
 "test_invalid_visible_object_skipped.lua",
 "test_range_false_fallback_allows_cast.lua",
 "test_healer_solo_fallback_matches.lua",
 "test_find_dead_party_ally.lua",
 "test_smite_solo_matches.lua",
 "test_middleware_matches_gate.lua",
 "test_context_completeness.lua",
 "test_gcd_duration_does_not_block.lua",

 -- IZI / target selection tests
 "test_izi_target_fallback_fires.lua",
 "test_warlock_selected_target_fires.lua",
 "test_warlock_focus_target_fires.lua",
 "test_warlock_enemy_scan_fallback_fires.lua",
 "test_affliction_summon_felhunter.lua",
 "test_target_selector_integration.lua",
 "test_try_cast_no_global_5s_lockout.lua",
 "test_try_cast_reason.lua",
 "test_action_execute_skip_gcd_izi_primary.lua",

 -- Exporter / registry tests
 "test_unified_registry.lua",
 "test_leveling_dispatcher_prepass.lua",
 "test_leveling_dispatcher_registration.lua",
 "test_shaman_leveling_registration.lua",

 "test_role_rotation_regressions.lua",

 -- Shaman
 "test_shaman_lightning_shield_throttle.lua",
 "test_shaman_enhancement_self_heal.lua",
 "test_elemental_custom_matches.lua",
 "test_enhancement_custom_matches.lua",

 "test_threat_drop_party_gate.lua",

 -- Paladin
 "test_paladin_tbc_seals.lua",
 "test_paladin_throttle_regression.lua",
 "test_paladin_consecration_downrank.lua",
 "test_paladin_avenger_shield_opener.lua",

 -- Paladin custom matches gate sweeps (audit gap #3)
 "test_retribution_custom_matches.lua",
 "test_protection_custom_matches.lua",
  -- Player-reported bug fixes
  "test_paladin_vanilla_seal_ooc_gate.lua",

 -- Mage
 "test_arcane_custom_matches.lua",
  "test_fire_custom_matches.lua",
  "test_fire_vanilla_low_level_scorch.lua",
  "test_frost_custom_matches.lua",

 -- Warlock
 "test_demonology_custom_matches.lua",
 "test_affliction_custom_matches.lua",
 "test_affliction_curse_mode_gates.lua",
 "test_demonology_curse_mode_gates.lua",
 "test_destruction_curse_mode_gates.lua",
  "test_destruction_life_tap.lua",
  "test_destruction_immolate_low_level.lua",
  "test_destruction_vanilla_immolate_low_level.lua",
  "test_demonology_life_tap.lua",

 -- Discipline
 "test_discipline_custom_matches.lua",

 -- Fury
 "test_fury_custom_matches.lua",

 -- Kebab
 "test_kebab_general_use_matches.lua",
 "test_mf_tick_tracking.lua",

 -- Cat snapshot
 "test_cat_snapshot_upgrade.lua",

 "test_cat_trick_optimizations.lua",

 -- Pattern 15 header audit (hygiene regression)
 "test_pattern15_audit.lua",

 -- Consumable manager settings + bag wiring (user-reported bugs 2026-06-29)
 "test_consumable_manager_settings.lua",

 "test_subtlety_custom_matches.lua",
 "test_assassination_custom_matches.lua",

 -- Rogue
 "test_combat_custom_matches.lua",
 "test_assassination_dagger_requirement.lua",
 "test_assassination_mutilate_dagger_check.lua",
 "test_rogue_snd_maintenance.lua",
 "test_combat_energy_pooling.lua",

 -- Shaman
 "test_elemental_clearcast_priority.lua",

 -- gap coverage tests
 "test_balance_faerie_fire.lua",
 "test_balance_war_stomp.lua",
 "test_destruction_shadowburn.lua",
 "test_destruction_mana_gem.lua",
 "test_destruction_demonic_sacrifice.lua",
 "test_affliction_life_tap.lua",
 "test_elemental_weapon_buffs.lua",
 "test_restoration_healing_way.lua",
 "test_survival_concussive_misdirection.lua",
 "test_fury_health_potion.lua",
 "test_holy_priest_feature_gaps.lua",
 "test_discipline_feature_gaps.lua",
 "test_protection_feature_gaps.lua",

 -- Healer triage + AoE cluster targeting (HE1 fix)
 "test_triage_rank.lua",
 "test_aoe_heal_best_target.lua",
 "test_triage_loaded.lua",

 "test_arena_priority.lua",
 "test_benchmark.lua",
 "test_burst_window.lua",
 "test_dispatcher_tick.lua",

 -- TTD fallback chain (build_context)
 "test_ema_ttd_fallback.lua",

 -- Talent build detection
 "test_talent_context.lua",

 -- reset_api_health integration tests
 "test_reset_api_health_aspect_manager.lua",

 -- Cross-expansion spell ID validation
 "test_cross_expansion_spell_validation.lua",
 "test_spell_rank_resolver_cross_expansion.lua",

 -- Auto-potion strategy tests
 "test_potion_helper_module.lua",
 "test_auto_potion_strategies.lua",

 "test_bear_vanilla_nil_guards.lua",
 "test_subtlety_vanilla_nil_guards.lua",

 -- Vanilla nil-guard regression tests (Pattern 14 coverage for all 38 remaining specs)
  "test_warrior_vanilla_nil_guards.lua",
  "test_warrior_leveling_vanilla_spells.lua",
 "test_druid_vanilla_nil_guards.lua",
 "test_rogue_vanilla_nil_guards.lua",
 "test_paladin_vanilla_nil_guards.lua",
 "test_hunter_vanilla_nil_guards.lua",
 "test_mage_vanilla_nil_guards.lua",
 "test_priest_vanilla_nil_guards.lua",
 "test_shaman_vanilla_nil_guards.lua",
 "test_warlock_vanilla_nil_guards.lua",
 "test_priest_holy_vanilla_friendly_target.lua",
 "test_priest_discipline_vanilla_friendly_target.lua",
 "test_paladin_holy_vanilla_friendly_target.lua",
 "test_druid_resto_vanilla_friendly_target.lua",
 "test_shaman_resto_vanilla_friendly_target.lua",

 -- Orphaned tests (previously not registered)
 "test_paladin_holy_custom_matches.lua",
 "test_playstyle_combobox_write_syncs.lua",
 "test_state_field_nil_guards_2026_06.lua",
 "test_warrior_middleware_nil_guard.lua",
 "test_healer_deficit.lua",
 "test_spell_id_table.lua",

  -- Middleware / integration tests (previously orphaned)
  "test_buff_upgrade.lua",
  "test_cast_path_integration.lua",
  "test_discipline_healer_mode.lua",
  "test_druid_middleware_nil_guard.lua",
  "test_evaluate_cast_casting_guard.lua",
  "test_healer_deficit_overheal.lua",
  "test_interrupt_spec_integration.lua",
  "test_other_classes_middleware_nil_guard.lua",
  "test_playstyle_tooltip_class_name.lua",
  "test_restoration_shield_tracking.lua",
  "test_spec_kit.lua",
  "test_spell_validation_talent_inference_health.lua",
  "test_ttd_normalization.lua",
  "test_ttd_tracker.lua",

 -- Classic / legacy tests (previously orphaned, pass standalone)
 "test_classic_druid_spec.lua",
 "test_classic_remaining_specs.lua",
 "test_classic_warrior_spec.lua",

 -- Leveling tests (previously not registered)
 "test_leveling_druid.lua",
 "test_leveling_edge_cases.lua",
 "test_leveling_hunter.lua",
 "test_leveling_load.lua",
 "test_leveling_mage.lua",
 "test_leveling_paladin.lua",
 "test_leveling_priest.lua",
 "test_leveling_rogue.lua",
 "test_leveling_shaman.lua",
 "test_leveling_shared.lua",
 "test_leveling_warlock.lua",
  "test_leveling_warrior.lua",
  "test_leveling_compliance.lua",

 -- reset_api_health tests (previously not registered)
 "test_reset_api_health.lua",
 "test_reset_api_health_spell_integration.lua",

  -- Orphaned tests (discovered 2026-07-08 audit)
  "test_autoloot_sylvanas.lua",
  "test_context_wired_fields_2026_06.lua",
  "test_multidot_engagement_filter.lua",
  "test_active_fight_tracker.lua",
  "test_strategy_categorization_validator.lua",
}

local function first_failure_line(output)
 return runner.first_failure_line(output)
end

local passed, failed = 0, 0
local failed_names = {}

if mode ~= "quiet" then
 print("=============================================================================")
 print(" EAX Rotation Feature Tests")
 print(" Root: " .. root)
 print(" Files: " .. tostring(#tests) .. " suites")
 print("=============================================================================")
 print("")
end

for i = 1, #tests do
 local file = tests[i]
 local path = root .. "/tests/" .. file
 if not runner.file_exists(path) then
  failed = failed + 1
  failed_names[#failed_names + 1] = file .. " (missing)"
  if mode ~= "quiet" then print(" [ MISSING ] " .. file) end
 else
  local output, ok = runner.run_test(path)
  if mode == "verbose" then
   print("=== " .. file .. " ===")
   io.write(output)
   if output:sub(-1) ~= "\n" then print("") end
  end

  if ok then
   passed = passed + 1
   if mode ~= "quiet" then print(string.format(" [ PASS ] %-32s ok", file)) end
  else
   failed = failed + 1
   failed_names[#failed_names + 1] = file
   if mode ~= "quiet" then
    print(string.format(" [ FAIL ] %-32s %s", file, first_failure_line(output) or "failed"))
   end
  end
 end
end

print("")
print("=============================================================================")
print(" RESULTS")
print("=============================================================================")
print(string.format(" Total: %3d suites", #tests))
print(string.format(" Passed: %3d", passed))
print(string.format(" Failed: %3d", failed))

if #failed_names > 0 then
 print(" Failed suites:")
 for i = 1, #failed_names do print(" - " .. failed_names[i]) end
end

print("=============================================================================")

if failed > 0 then os.exit(1) end