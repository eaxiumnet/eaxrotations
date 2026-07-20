-- test_shadow_dsl_priority.lua — Shadow Priest DSL priority + equivalence test.
-- WHAT:  verifies full strategy priority order, DSL position checks, and condition
--        equivalence for 6 DSL-converted strategies (Shadowform, VampiricTouch,
--        ShadowWordPain, MindBlast, ShadowWordDeath, InnerFire).
-- WHEN:  runs as part of the rotation test suite.
-- WHY:   regression guard for the eighth DSL adopter (first shadow priest/DoT-tracking spec).
-- SAFETY: standalone — mocks NS, spec_kit, and shared modules; no game API calls.

local _pass, _fail = 0, 0
local function assert_true(cond, msg)
    if cond then _pass = _pass + 1 else _fail = _fail + 1 print("  FAIL: " .. msg) end
end
local function assert_false(cond, msg)
    if not cond then _pass = _pass + 1 else _fail = _fail + 1 print("  FAIL: " .. msg) end
end

-- ============================================================================
-- Mock NS
-- ============================================================================
local NS = {}
_G.EaxRotations = NS

NS.PriestSpells = {
    ArcaneTorrent = 25046, Berserking = 26297, BloodFury = 33697,
    DevouringPlague = 2944, DispelMagic = 527, Fade = 586,
    FlashHeal = 2061, HolyNova = 15237, InnerFire = 588,
    InnerFocus = 14751, MindBlast = 8092, MindFlay = 15407,
    PowerWordFortitude = 1243, PowerWordShield = 17,
    PsychicScream = 8122, ShackleUndead = 9484,
    ShadowWordDeath = 32379, ShadowWordPain = 589,
    Shadowfiend = 34433, Shadowform = 15473, Starshards = 10797,
    VampiricEmbrace = 15286, VampiricTouch = 34914,
}
NS.PLAYER_UNIT = {
    get_health = function() return 100 end,
    get_health_percentage = function() return 100 end,
    is_valid = function() return true end,
    is_dead = function() return false end,
    is_casting = function() return false end,
    is_mounted = function() return false end,
    get_guid = function() return "player" end,
    get_target = function() return nil end,
}
NS.GetPlayer = function() return NS.PLAYER_UNIT end
NS.GetTarget = function() return nil end
NS.buff_up = function() return false end
NS.debuff_up = function() return false end
NS.debuff_remains = function() return 0 end
NS.spell_ready = function() return true end
NS.try_cast = function() return true end
NS.unit_mana_pct = function() return 100 end
NS.unit_health_pct = function() return 100 end
NS.time_now = function() return 0 end
NS.game_time_ms = function() return 0 end
NS.broken_api_throttled = function() return false end
NS.cooldown_remains = function() return 0 end
NS.spell_exists = function() return true end
NS.is_item_ready = function() return false end
NS.is_auto_attacking = function() return false end
NS.is_threat_safe = function() return true end
NS.is_spell_in_range = function() return true end
NS.same_unit = function() return true end
NS.unit_interruptible = function() return true end
NS.unit_creature_type = function() return nil end
NS.get_debuff_stacks = function() return 0 end
NS.GetEnemiesInRange = function() return {} end
NS.aoe_self_meets = function() return false end
NS.aoe_target_meets = function() return false end
NS.log = function() end
NS.log_warning = function() end
NS.rotation_registry = { register = function() end }
NS.OffensiveDispelDB = {
    is_breakable_cc_active = function() return false, nil end,
    is_casting_preemptive_cc = function() return false, nil end,
}

-- Mock spec_kit (uses _setting local to avoid self-reference issues)
local _setting = function(context, key, default)
    if context and context.settings and context.settings[key] ~= nil then
        return context.settings[key]
    end
    return default
end
local mock_spec_kit = {
    define_action_for_class = function(SPELLS)
        return function(field, rank_ids, label)
            if SPELLS and SPELLS[field] then return SPELLS[field] end
            return rank_ids and rank_ids[1] or field
        end
    end,
    safe_state = function(raw, schema)
        return setmetatable({}, {
            __index = function(t, k)
                if raw[k] ~= nil then return raw[k] end
                if schema and schema[k] ~= nil then return schema[k] end
                return nil
            end,
        })
    end,
    setting = _setting,
    setting_bool = function(context, key, default)
        local v = _setting(context, key, nil)
        if v == nil then return default end
        return v ~= false
    end,
    setting_number = function(context, key, default)
        local v = _setting(context, key, nil)
        if type(v) == "number" then return v end
        return default
    end,
}
package.loaded["shared/spec_kit_sylvanas"] = mock_spec_kit

-- Mock shared modules
package.loaded["shared/mf_tick_compute_sylvanas"] = {
    compute_channel_state = function() return false, 0 end,
    should_clip_mf = function() return true end,
}
package.loaded["shared/offensive_dispel_sylvanas"] = NS.OffensiveDispelDB
package.loaded["shared/dot_ttd_gating_sylvanas"] = {
    should_skip_dot = function() return false end,
    DOT_DURATIONS = { vampiric_touch = 15, shadow_word_pain = 18, devouring_plague = 24 },
}
package.loaded["shared/buff_manager_helper_sylvanas"] = {
    get_all_debuffs = function() return {} end,
}
package.loaded["shared/cooldown_planner_sylvanas"] = {
    is_major_offensive_cd_active = function() return false end,
}
package.loaded["shared/snapshot_sylvanas"] = {
    should_upgrade = function() return true end,
}
package.loaded["shared/active_fight_tracker_sylvanas"] = {
    get_active_fights = function() return {} end,
    find_undotted_target = function() return nil end,
}
package.loaded["shared/ts_helper_sylvanas"] = nil
package.loaded["shared/aoe_hit_volume_sylvanas"] = { install = function() end }

-- Load the real DSL engine and cache it so the spec file's require() picks it up
package.loaded["shared/strategy_dsl_sylvanas"] = dofile("EaxRotations/shared/strategy_dsl_sylvanas.lua")

-- Load the shadow priest spec
local shadow = dofile("EaxRotations/classes/priest/shadow_sylvanas.lua")
local strategies = shadow.strategies

-- ============================================================================
-- Priority order verification (32 strategies)
-- ============================================================================
local expected_order = {
    "PowerWordFortitude", "PreCombatPull", "Shadowform", "SWDCCBreak",
    "Shadowfiend", "VampiricTouch", "ShadowWordPain", "MovingSWP",
    "VampiricEmbrace", "DevouringPlague", "InnerFocusMindBlast", "MindBlast",
    "Starshards", "ShadowWordDeath", "MindFlay", "PsychicScream",
    "Fade", "Healthstone", "DispelMagic", "ShackleUndead",
    "SWPSpread", "VTSpread", "MultiDotSWP", "MultiDotVT",
    "InnerFire", "PowerWordShield", "FlashHeal", "HolyNovaAoE",
    "ManaEmergencyWand", "RacialBerserking", "RacialBloodFury", "RacialArcaneTorrent",
}
assert_true(#strategies == #expected_order, "strategy count matches (" .. #strategies .. " vs " .. #expected_order .. ")")
for i = 1, math.min(#strategies, #expected_order) do
    assert_true(strategies[i].name == expected_order[i],
        string.format("priority[%d] = %s (expected %s)", i, strategies[i].name or "?", expected_order[i]))
end

-- DSL position checks — verify the 6 DSL-converted strategies are at expected indices
local dsl_indices = {}
for i = 1, #strategies do dsl_indices[strategies[i].name] = i end
assert_true(dsl_indices["Shadowform"] == 3, "Shadowform at index 3")
assert_true(dsl_indices["VampiricTouch"] == 6, "VampiricTouch at index 6")
assert_true(dsl_indices["ShadowWordPain"] == 7, "ShadowWordPain at index 7")
assert_true(dsl_indices["MindBlast"] == 12, "MindBlast at index 12")
assert_true(dsl_indices["ShadowWordDeath"] == 14, "ShadowWordDeath at index 14")
assert_true(dsl_indices["InnerFire"] == 25, "InnerFire at index 25")

-- ============================================================================
-- Mock context + state helpers
-- ============================================================================
local function make_ctx(overrides)
    local ctx = {
        me = NS.PLAYER_UNIT,
        target = { is_valid = function() return true end, is_dead = function() return false end,
                   is_casting = function() return false end, get_health_percentage = function() return 100 end,
                   get_creature_type = function() return nil end, get_guid = function() return "target" end,
                   get_target = function() return NS.PLAYER_UNIT end },
        in_combat = true,
        hp = 100,
        mana_pct = 80,
        settings = { use_cooldowns = true, shadow_use_inner_fire = true, shadow_swd_cc_break = true },
        has_valid_enemy_target = true,
        is_pvp = false,
        is_moving = false,
        is_casting = false,
        is_channeling = false,
        combat_time = 50,
        ttd = 999,
        ttd_known = false,
        target_hp_pct = 100,
        target_hp = 100,
    }
    for k, v in pairs(overrides or {}) do ctx[k] = v end
    return ctx
end

local function make_state(overrides)
    local s = {
        has_shadowform = true,
        shadowform_known = true,
        vampiric_touch_known = true,
        swp_known = true,
        vt_remaining = 0,
        swp_remaining = 0,
        dp_remaining = 0,
        ve_remaining = 0,
        mb_ready = true,
        mb_cd_remains = 0,
        swd_ready = true,
        mana_pct = 80,
        mana_low = false,
        mana_emergency = false,
        threat_safe = true,
        swd_safety_hp = 80,
        has_inner_fire = false,
        inner_fire_known = true,
        mf_channeling = false,
        should_clip_mf = true,
        weaving_stacks = 5,
        spell_damage = 1000,
        snapshot_vt_dmg = 0,
        snapshot_swp_dmg = 0,
        snapshot_dp_dmg = 0,
        has_bloodlust = false,
        in_combat = true,
        enemy_count = 1,
        combat_mode = "st",
        target_hp_pct = 100,
    }
    for k, v in pairs(overrides or {}) do s[k] = v end
    return s
end

-- ============================================================================
-- Shadowform: not broken_api, no shadowform buff, spell known
-- ============================================================================
local idx_sf = 3
-- Positive: no shadowform, spell known
assert_true(strategies[idx_sf].matches(make_ctx(), make_state({ has_shadowform = false })),
    "Shadowform matches when no buff + spell known")
-- Negative: already has shadowform
assert_false(strategies[idx_sf].matches(make_ctx(), make_state({ has_shadowform = true })),
    "Shadowform skips when already has buff")
-- Negative: spell not known
assert_false(strategies[idx_sf].matches(make_ctx(), make_state({ has_shadowform = false, shadowform_known = false })),
    "Shadowform skips when spell not known")

-- ============================================================================
-- VampiricTouch: not casting/channeling, can break MF, not moving, valid target,
--                VT remaining <= threshold, not mana emergency, engaged
-- ============================================================================
local idx_vt = 6
-- Positive: all conditions met (no VT active)
assert_true(strategies[idx_vt].matches(make_ctx(), make_state()),
    "VampiricTouch matches when no VT active + in combat + not moving")
-- Negative: currently casting
assert_false(strategies[idx_vt].matches(make_ctx({ is_casting = true }), make_state()),
    "VampiricTouch skips when casting")
-- Negative: channeling Mind Flay (can't break)
assert_false(strategies[idx_vt].matches(make_ctx({ is_channeling = true }), make_state({ mf_channeling = true, should_clip_mf = false })),
    "VampiricTouch skips when channeling MF and can't clip")
-- Negative: moving
assert_false(strategies[idx_vt].matches(make_ctx({ is_moving = true }), make_state()),
    "VampiricTouch skips when moving")
-- Negative: no valid target
assert_false(strategies[idx_vt].matches(make_ctx({ has_valid_enemy_target = false }), make_state()),
    "VampiricTouch skips without valid target")
-- Negative: VT still has plenty of time
assert_false(strategies[idx_vt].matches(make_ctx(), make_state({ vt_remaining = 10 })),
    "VampiricTouch skips when VT remaining > clip threshold")
-- Negative: mana emergency
assert_false(strategies[idx_vt].matches(make_ctx(), make_state({ mana_emergency = true })),
    "VampiricTouch skips during mana emergency")
-- Negative: spell not known (leveling gate)
assert_false(strategies[idx_vt].matches(make_ctx(), make_state({ vampiric_touch_known = false })),
    "VampiricTouch skips when spell not known")

-- ============================================================================
-- ShadowWordPain: not broken_api, can break MF, valid target, not mana emergency,
--                 weaving-aware refresh, snapshot upgrade, TTD gate
-- ============================================================================
local idx_swp = 7
-- Positive: no SW:P active
assert_true(strategies[idx_swp].matches(make_ctx(), make_state({ swp_remaining = 0 })),
    "ShadowWordPain matches when no SW:P active")
-- Positive: SW:P in refresh window
assert_true(strategies[idx_swp].matches(make_ctx(), make_state({ swp_remaining = 1 })),
    "ShadowWordPain matches when SW:P in refresh window")
-- Negative: SW:P has plenty of time
assert_false(strategies[idx_swp].matches(make_ctx(), make_state({ swp_remaining = 10 })),
    "ShadowWordPain skips when SW:P remaining > window")
-- Negative: no valid target
assert_false(strategies[idx_swp].matches(make_ctx({ has_valid_enemy_target = false }), make_state()),
    "ShadowWordPain skips without valid target")
-- Negative: mana emergency
assert_false(strategies[idx_swp].matches(make_ctx(), make_state({ mana_emergency = true })),
    "ShadowWordPain skips during mana emergency")
-- Negative: channeling MF and can't clip
assert_false(strategies[idx_swp].matches(make_ctx(), make_state({ mf_channeling = true, should_clip_mf = false })),
    "ShadowWordPain skips when channeling MF and can't clip")
-- Negative: spell not known (leveling gate)
assert_false(strategies[idx_swp].matches(make_ctx(), make_state({ swp_known = false })),
    "ShadowWordPain skips when spell not known")

-- ============================================================================
-- MindBlast: not casting/channeling, can break MF, not moving, valid target,
--            spell ready, not mana low, threat safe, engaged
-- ============================================================================
local idx_mb = 12
-- Positive: all conditions met
assert_true(strategies[idx_mb].matches(make_ctx(), make_state()),
    "MindBlast matches when ready + not casting + not moving + mana ok + threat safe")
-- Negative: casting
assert_false(strategies[idx_mb].matches(make_ctx({ is_casting = true }), make_state()),
    "MindBlast skips when casting")
-- Negative: moving
assert_false(strategies[idx_mb].matches(make_ctx({ is_moving = true }), make_state()),
    "MindBlast skips when moving")
-- Negative: not ready
assert_false(strategies[idx_mb].matches(make_ctx(), make_state({ mb_ready = false })),
    "MindBlast skips when not ready")
-- Negative: mana low
assert_false(strategies[idx_mb].matches(make_ctx(), make_state({ mana_low = true })),
    "MindBlast skips when mana low")
-- Negative: threat unsafe
assert_false(strategies[idx_mb].matches(make_ctx(), make_state({ threat_safe = false })),
    "MindBlast skips when threat unsafe")
-- Negative: no valid target
assert_false(strategies[idx_mb].matches(make_ctx({ has_valid_enemy_target = false }), make_state()),
    "MindBlast skips without valid target")
-- Negative: channeling MF and can't clip
assert_false(strategies[idx_mb].matches(make_ctx(), make_state({ mf_channeling = true, should_clip_mf = false })),
    "MindBlast skips when channeling MF and can't clip")

-- ============================================================================
-- ShadowWordDeath: can break MF, valid target, spell ready, TTD gate,
--                  not mana emergency, threat safe, safety HP check, engaged
-- ============================================================================
local idx_swd = 14
-- Positive: all conditions met
assert_true(strategies[idx_swd].matches(make_ctx(), make_state()),
    "ShadowWordDeath matches when ready + threat safe + HP ok")
-- Positive: execute range (target HP <= 25%, safety floor lowered to 60)
assert_true(strategies[idx_swd].matches(make_ctx({ target_hp_pct = 20, hp = 65 }), make_state({ target_hp_pct = 20 })),
    "ShadowWordDeath matches in execute range with lowered safety floor")
-- Negative: not ready
assert_false(strategies[idx_swd].matches(make_ctx(), make_state({ swd_ready = false })),
    "ShadowWordDeath skips when not ready")
-- Negative: no valid target
assert_false(strategies[idx_swd].matches(make_ctx({ has_valid_enemy_target = false }), make_state()),
    "ShadowWordDeath skips without valid target")
-- Negative: mana emergency
assert_false(strategies[idx_swd].matches(make_ctx(), make_state({ mana_emergency = true })),
    "ShadowWordDeath skips during mana emergency")
-- Negative: threat unsafe
assert_false(strategies[idx_swd].matches(make_ctx(), make_state({ threat_safe = false })),
    "ShadowWordDeath skips when threat unsafe")
-- Negative: player HP below safety floor
assert_false(strategies[idx_swd].matches(make_ctx({ hp = 50 }), make_state()),
    "ShadowWordDeath skips when player HP below safety floor")
-- Negative: channeling MF and can't clip
assert_false(strategies[idx_swd].matches(make_ctx(), make_state({ mf_channeling = true, should_clip_mf = false })),
    "ShadowWordDeath skips when channeling MF and can't clip")

-- ============================================================================
-- InnerFire: spell known, not broken_api, no buff, setting enabled, not in combat
-- ============================================================================
local idx_if = 25
-- Positive: OOC, no inner fire, spell known, setting on
assert_true(strategies[idx_if].matches(make_ctx({ in_combat = false }), make_state()),
    "InnerFire matches when OOC + no buff + spell known + setting on")
-- Negative: already has inner fire
assert_false(strategies[idx_if].matches(make_ctx({ in_combat = false }), make_state({ has_inner_fire = true })),
    "InnerFire skips when already has buff")
-- Negative: in combat
assert_false(strategies[idx_if].matches(make_ctx({ in_combat = true }), make_state()),
    "InnerFire skips when in combat")
-- Negative: spell not known
assert_false(strategies[idx_if].matches(make_ctx({ in_combat = false }), make_state({ inner_fire_known = false })),
    "InnerFire skips when spell not known")
-- Negative: setting disabled
assert_false(strategies[idx_if].matches(make_ctx({ in_combat = false, settings = { shadow_use_inner_fire = false } }), make_state()),
    "InnerFire skips when setting disabled")

-- ============================================================================
-- Summary
-- ============================================================================
print(string.format("test_shadow_dsl_priority: %d passed, %d failed", _pass, _fail))
if _fail > 0 then
    os.exit(1)
end
print("PASS test_shadow_dsl_priority")
