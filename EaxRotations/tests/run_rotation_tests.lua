local root = "EaxRotations"
local mode = "normal"

if arg then
    for i = 1, #arg do
        if arg[i] == "-v" or arg[i] == "--verbose" then
            mode = "verbose"
        elseif arg[i] == "-q" or arg[i] == "--quiet" then
            mode = "quiet"
        elseif arg[i] ~= "" then
            root = arg[i]
        end
    end
end

local tests = {
    "test_try_cast_izi_primary.lua",
    "test_pre_heal_cooldown_gate.lua",

    -- Dispatcher + loader regressions
    "test_dispatcher_role_mode.lua",
    "test_class_loader_fail_closed.lua",

    -- New feature tests (FrostByte parity)
    "test_shadow_silence_interrupt.lua",
    "test_arms_healthstone.lua",
    "test_hunter_bm_melee_aoe_trinket.lua",

    -- Arms warrior tests
    "test_arms_custom_matches.lua",
    "test_arms_hamstring_tactician.lua",
    "test_arms_rage_gating.lua",

    -- Hunter tests
    "test_hunter_aspect_matches.lua",

    -- Priest tests
    "test_priest_holy_custom_matches.lua",

    -- Druid tests
    "test_balance_custom_matches.lua",
    "test_bear_custom_matches.lua",
    "test_cat_custom_matches.lua",
    "test_druid_caster_custom_matches.lua",

    -- Core/shared infrastructure tests
    "test_aura_probe_sylvanas.lua",
    "test_trinket_manager.lua",
    "test_spell_resolver_cache.lua",
    "test_tbc_consumable_data.lua",
    "test_cooldown_registry.lua",
    "test_runtime_compat_aliases.lua",
    "test_archive_self_buff_aliases.lua",
    "test_expansion_helpers.lua",    "test_execute_phase.lua",
    "test_melee_combat_math.lua",
    "test_spell_rank_fallback.lua",
    "test_spell_id_table_regressions.lua",
    "test_ooc_manager.lua",
    "test_racial_manager.lua",
    "test_racial_autocast.lua",
    "test_interrupt_manager.lua",
    "test_interrupt_manager_school_lock.lua",
    "test_burst_logic_integration.lua",
    "test_force_command_activation.lua",
    "test_mage_tbc_corrections.lua",
    "test_api_lint.lua",
    "test_rotation_static_compliance.lua",
    "test_rotation_strategy_compliance.lua",
    "test_vec2_api_lint.lua",
    "test_fire_scorch_maintenance.lua",
    "test_frost_shatter_combo.lua",
    "test_ele_shock_gating.lua",
    "test_swing_timer_helpers.lua",
    "test_gear_helpers.lua",
    "test_dot_refresh.lua",
    "test_dot_refresh_integration.lua",
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
    "test_threat_drop_party_gate.lua",

    -- Paladin
    "test_paladin_tbc_seals.lua",

    -- Mage
    "test_arcane_custom_matches.lua",
    "test_fire_custom_matches.lua",
    "test_frost_custom_matches.lua",

    -- Warlock
    "test_demonology_custom_matches.lua",
    "test_affliction_custom_matches.lua",

    -- Discipline
    "test_discipline_custom_matches.lua",

    -- Fury
    "test_fury_custom_matches.lua",

    -- Kebab
    "test_kebab_general_use_matches.lua",
    "test_mf_tick_tracking.lua",

    -- Cat snapshot
    "test_cat_snapshot_upgrade.lua",

    -- Rogue
    "test_combat_custom_matches.lua",

    -- FrostByte gap coverage tests
    "test_balance_faerie_fire.lua",
    "test_balance_war_stomp.lua",
    "test_destruction_shadowburn.lua",
    "test_destruction_mana_gem.lua",
    "test_affliction_life_tap.lua",
    "test_elemental_weapon_buffs.lua",
    "test_restoration_healing_way.lua",
    "test_survival_concussive_misdirection.lua",
    "test_fury_health_potion.lua",
    "test_holy_priest_feature_gaps.lua",
    "test_discipline_feature_gaps.lua",
    "test_protection_feature_gaps.lua",
    "test_arena_priority.lua",
    "test_benchmark.lua",
    "test_burst_window.lua",
    "test_dispatcher_tick.lua",
    "test_dr_tracker.lua",

    -- TTD fallback chain (build_context)
    "test_ema_ttd_fallback.lua",

    -- reset_api_health integration tests
    "test_reset_api_health_aspect_manager.lua",
}

local function quote(path)
    return '"' .. tostring(path):gsub('"', '\\"') .. '"'
end

local function read_command(command)
    local pipe = io.popen(command .. " 2>&1")
    if not pipe then return "", false end
    local output = pipe:read("*a") or ""
    local _, _, code = pipe:close()
    local ok = (code == nil or code == 0)
    -- Fallback: scan output for failure markers if exit code is unreliable
    if ok then
        local lower = output:lower()
        if lower:match("^%s*%[?%s*fail")
            or lower:match("^lua:%s")
            or lower:find("assertion failed", 1, true)
            or lower:find("stack traceback", 1, true)
        then
            local lines = 0
            for _ in output:gmatch("[^\r\n]+") do lines = lines + 1 end
            if lines > 3 or output:find("assertion failed", 1, true) then ok = false end
        end
    end
    return output, ok
end

local function file_exists(path)
    local f = io.open(path, "rb")
    if not f then return false end
    f:close()
    return true
end

local function first_failure_line(output)
    for line in output:gmatch("[^\r\n]+") do
        local lower = line:lower()
        if lower:match("^%s*%[?%s*fail")
            or lower:match("^lua:%s")
            or lower:find("assertion failed", 1, true)
            or lower:find("stack traceback", 1, true)
        then
            return line
        end
    end
    return nil
end

local lua_bin = os.getenv("LUA") or "lua"
local passed, failed = 0, 0
local failed_names = {}

if mode ~= "quiet" then
    print("=============================================================================")
    print("  EAX Rotation Feature Tests")
    print("  Root:  " .. root)
    print("  Files: " .. tostring(#tests) .. " suites")
    print("=============================================================================")
    print("")
end

for i = 1, #tests do
    local file = tests[i]
    local path = root .. "/tests/" .. file
    if not file_exists(path) then
        failed = failed + 1
        failed_names[#failed_names + 1] = file .. " (missing)"
        if mode ~= "quiet" then print("  [ MISSING ] " .. file) end
    else
        local output, ok = read_command(lua_bin .. " " .. quote(path))
        if mode == "verbose" then
            print("=== " .. file .. " ===")
            io.write(output)
            if output:sub(-1) ~= "\n" then print("") end
        end

        if ok then
            passed = passed + 1
            if mode ~= "quiet" then print(string.format("  [ PASS ] %-32s ok", file)) end
        else
            failed = failed + 1
            failed_names[#failed_names + 1] = file
            if mode ~= "quiet" then
                print(string.format("  [ FAIL ] %-32s %s", file, first_failure_line(output) or "failed"))
            end
        end
    end
end

print("")
print("=============================================================================")
print("  RESULTS")
print("=============================================================================")
print(string.format("  Total:  %3d suites", #tests))
print(string.format("  Passed: %3d", passed))
print(string.format("  Failed: %3d", failed))

if #failed_names > 0 then
    print("  Failed suites:")
    for i = 1, #failed_names do print("    - " .. failed_names[i]) end
end

print("=============================================================================")

if failed > 0 then os.exit(1) end
