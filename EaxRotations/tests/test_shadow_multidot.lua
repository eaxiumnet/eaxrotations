-- test_shadow_multidot.lua -- Shadow multi-dotting tests.
-- WHAT:  Shadow multi-dotting tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Protects against regressions in rotation logic and state handling.
-- SAFETY: Pure unit tests with mocked API context.

-- Test: Shadow Priest Multi-DoT engine.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_false
local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
end
setup_asserts()

-- Mock NS
_G.EaxRotations = {
    PriestSpells = {
        ShadowWordPain = 25368,
        VampiricTouch = 34917,
        MindBlast = 8092,
        ShadowWordDeath = 32379,
        Shadowform = 15473,
        InnerFire = 588,
        InnerFocus = 14751,
        MindFlay = 15407,
        PsychicScream = 8122,
        DispelMagic = 528,
        ShackleUndead = 9484,
        DevouringPlague = 2944,
        FlashHeal = 2061,
        PowerWordShield = 17,
        PowerWordFortitude = 1243,
        VampiricEmbrace = 15286,
        Shadowfiend = 34433,
        Shadowform = 15473,
        Berserking = 26297,
        BloodFury = 33697,
        ArcaneTorrent = 28730,
        Starshards = 10797,
        HolyNova = 15237,
    },
    action_matches = function() return true end,
    action_execute = function() return true end,
    spell_ready = function(spell, target, opts) return true end,
    spell_exists = function(spell) return true end,
    debuff_remains = function(target, ids) return 0 end,
    debuff_up = function(target, ids)
        -- Simulate: target "enemy_a" has SW:P, target "enemy_b" has VT
        if target and target._has_swp then return true end
        if target and target._has_vt then return true end
        return false
    end,
    buff_up = function() return false end,
    log = function() end,
    time_now = function() return 100 end,
    rotation_registry = { register = function() end },
    GetPlayer = function() return {} end,
    GetTarget = function() return nil end,
    GetEnemiesInRange = function(range)
        return {
            { _has_swp = true, _has_vt = false },
            { _has_swp = false, _has_vt = true },
            { _has_swp = false, _has_vt = false },
        }
    end,
    unit_mana_pct = function() return 80 end,
    unit_health_pct = function() return 100 end,
    get_debuff_stacks = function() return 5 end,
    is_threat_safe = function() return true end,
}

local _ok, mod = pcall(require, "shared/mf_tick_compute_sylvanas")
if not _ok or not mod then
    package.loaded["shared/mf_tick_compute_sylvanas"] = {
        compute_channel_state = function() return false, 0 end,
        should_clip_mf = function() return false end,
    }
end
package.loaded["shared/offensive_dispel_sylvanas"] = {}
package.loaded["shared/dot_ttd_gating_sylvanas"] = {
    should_skip_dot = function() return false end,
    should_skip_dot_from_context = function() return false end,
    DOT_DURATIONS = { vampiric_touch = 15, shadow_word_pain = 18 },
}

-- Drive tracker path (PR2): provide ActiveFightTracker before shadow load so its pcall captures it.
-- Tracker find_undotted will be preferred in _find and build_state scan.
package.loaded["shared/active_fight_tracker_sylvanas"] = {
    find_undotted_target = function(context, debuff_ids, range)
        -- Simulate: return an undotted enemy from the GetEnemies mock (third one lacks dots)
        local enemies = _G.EaxRotations.GetEnemiesInRange and _G.EaxRotations.GetEnemiesInRange(range or 30) or {}
        for _, e in ipairs(enemies) do
            local has = false
            local ok, h = pcall(function() return _G.EaxRotations.debuff_up(e, debuff_ids) end)
            if ok then has = h end
            if not has then return e end
        end
        return nil
    end,
    get_active_fights = function(range)
        return _G.EaxRotations.GetEnemiesInRange and _G.EaxRotations.GetEnemiesInRange(range or 30) or {}
    end,
    count = function() return 3 end,
}

local result = dofile("EaxRotations/classes/priest/shadow_sylvanas.lua")
local strategies = result.strategies or result
assert_true(strategies, "strategies should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    return nil
end

local multidot_swp = find_strategy("MultiDotSWP")
local multidot_vt = find_strategy("MultiDotVT")
assert_true(multidot_swp ~= nil, "MultiDotSWP strategy should exist")
assert_true(multidot_vt ~= nil, "MultiDotVT strategy should exist")

-- Mode Off -> should not match
assert_false(multidot_swp.matches({ in_combat = true, target_hp_pct = 100, settings = {} },
    { swp_known = true, multidot_mode = 1, enemy_count = 3, dotted_swp_count = 0, enemies_missing_swp = 2, swp_remaining = 0, mana_emergency = false }), "mode Off -> no match")

-- Mode On, missing enemies, no SW:P on target -> should match
assert_true(multidot_swp.matches({ in_combat = true, target_hp_pct = 100, settings = {} },
    { swp_known = true, multidot_mode = 3, enemy_count = 3, dotted_swp_count = 0, enemies_missing_swp = 2, swp_remaining = 0, mana_emergency = false }), "mode On + missing -> match")

-- Target HP <= 30% -> should not match (HP lives on the state arg at runtime, set by build_state)
assert_false(multidot_swp.matches({ in_combat = true, settings = {} },
    { swp_known = true, multidot_mode = 3, enemy_count = 3, dotted_swp_count = 0, enemies_missing_swp = 2, swp_remaining = 0, mana_emergency = false, target_hp_pct = 25 }), "low HP target -> no match")

-- Max targets reached -> should not match
assert_false(multidot_swp.matches({ in_combat = true, target_hp_pct = 100, settings = {} },
    { swp_known = true, multidot_mode = 3, enemy_count = 3, dotted_swp_count = 3, multidot_max = 3, enemies_missing_swp = 2, swp_remaining = 0, mana_emergency = false }), "max targets -> no match")

-- OOC -> should not match
assert_false(multidot_swp.matches({ in_combat = false, target_hp_pct = 100, settings = {} },
    { swp_known = true, multidot_mode = 3, enemy_count = 3, dotted_swp_count = 0, enemies_missing_swp = 2, swp_remaining = 0, mana_emergency = false }), "OOC -> no match")

-- Mana emergency -> should not match
assert_false(multidot_swp.matches({ in_combat = true, target_hp_pct = 100, settings = {} },
    { swp_known = true, multidot_mode = 3, enemy_count = 3, dotted_swp_count = 0, enemies_missing_swp = 2, swp_remaining = 0, mana_emergency = true }), "mana emergency -> no match")

-- VT multidot moving -> should not match
assert_false(multidot_vt.matches({ in_combat = true, target_hp_pct = 100, is_moving = true, settings = {} },
    { vampiric_touch_known = true, multidot_mode = 3, enemy_count = 3, dotted_vt_count = 0, enemies_missing_vt = 2, vt_remaining = 0, mana_emergency = false }), "moving VT -> no match")

-- VT multidot valid -> should match
assert_true(multidot_vt.matches({ in_combat = true, target_hp_pct = 100, is_moving = false, settings = {} },
    { vampiric_touch_known = true, multidot_mode = 3, enemy_count = 3, dotted_vt_count = 0, enemies_missing_vt = 2, vt_remaining = 0, mana_emergency = false }), "VT valid -> match")

-- Tracker-driven cases (PR2): since tracker mock is active, these exercise find_undotted + get_active in _find/build_state
-- (dotted counts from state still used for max gate; tracker supplies the undotted candidate)
assert_true(multidot_swp.matches({ in_combat = true, target_hp_pct = 100, settings = {} },
    { swp_known = true, multidot_mode = 3, enemy_count = 3, dotted_swp_count = 0, multidot_max = 3, enemies_missing_swp = 2, swp_remaining = 0, mana_emergency = false }), "tracker path SWP -> match")
assert_true(multidot_vt.matches({ in_combat = true, target_hp_pct = 100, is_moving = false, settings = {} },
    { vampiric_touch_known = true, multidot_mode = 3, enemy_count = 3, dotted_vt_count = 0, multidot_max = 3, enemies_missing_vt = 2, vt_remaining = 0, mana_emergency = false }), "tracker path VT -> match")

print("PASS test_shadow_multidot")
