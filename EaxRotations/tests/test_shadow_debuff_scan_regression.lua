-- test_shadow_debuff_scan_regression.lua -- Regression test for Shadow Priest DoT spam bug.
-- WHAT:  Verifies that when buff_manager reports active Vampiric Touch and
--         Shadow Word: Pain debuffs, the Shadow rotation sees positive
--         remaining times and does not re-cast those DoTs.
-- WHEN:  During rotation test suite execution.
-- WHY:   The same buff_manager_helper bug that caused Corruption spam in
--         affliction_sylvanas.lua also affected shadow_sylvanas.lua. This
--         test guards the fix for the Shadow Priest scan path.
-- SAFETY: Pure synthetic test; no live game data required.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_false, assert_eq
local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
    assert_eq = function(a, b, label) if a ~= b then error((label or "assert_eq failed") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
end
setup_asserts()

_G.EaxRotations = {
    PriestSpells = {
        ShadowWordPain = 25368, VampiricTouch = 34917, MindBlast = 8092,
        ShadowWordDeath = 32379, Shadowform = 15473, InnerFire = 588,
        InnerFocus = 14751, MindFlay = 15407, PsychicScream = 8122,
        DispelMagic = 528, ShackleUndead = 9484, DevouringPlague = 2944,
        FlashHeal = 2061, PowerWordShield = 17, PowerWordFortitude = 1243,
        VampiricEmbrace = 15286, Shadowfiend = 34433, Berserking = 26297,
        BloodFury = 33697, ArcaneTorrent = 28730, Starshards = 10797,
        HolyNova = 15237,
    },
    action_matches = function() return true end,
    action_execute = function() return true end,
    spell_ready = function(spell, target, opts) return true end,
    spell_exists = function(spell) return true end,
    -- Fallback debuff_remains returns 0 so the test relies on the buff_manager scan.
    debuff_remains = function(target, ids) return 0 end,
    debuff_up = function() return false end,
    buff_up = function() return false end,
    log = function() end,
    time_now = function() return 100 end,
    game_time_ms = function() return 100000 end,
    cooldown_remains = function() return 0 end,
    rotation_registry = { register = function() end },
    GetPlayer = function() return {} end,
    GetTarget = function() return nil end,
    GetEnemiesInRange = function() return {} end,
    unit_mana_pct = function() return 80 end,
    unit_health_pct = function() return 100 end,
    get_debuff_stacks = function() return 5 end,
    is_threat_safe = function() return true end,
}

-- Mock the Sylvanas buff_manager so get_debuff_cache returns active VT and SW:P.
package.loaded["common/modules/buff_manager"] = {
    get_debuff_cache = function(unit, ttl_ms)
        return {
            { buff_id = 34917, remaining = 12000 }, -- Vampiric Touch, 12s
            { buff_id = 25368, remaining = 15000 }, -- Shadow Word: Pain, 15s
        }
    end,
}

package.loaded["shared/mf_tick_compute_sylvanas"] = {
    compute_channel_state = function() return false, 0 end,
    should_clip_mf = function() return false end,
}
package.loaded["shared/offensive_dispel_sylvanas"] = {
    is_breakable_cc_active = function() return false, nil end,
}
package.loaded["shared/dot_ttd_gating_sylvanas"] = {
    should_skip_dot = function() return false end,
    should_skip_dot_from_context = function() return false end,
    DOT_DURATIONS = { vampiric_touch = 15, shadow_word_pain = 18 },
}

local result = dofile("EaxRotations/classes/priest/shadow_sylvanas.lua")
local strategies = result.strategies or result
assert_true(strategies, "strategies should load")
assert_true(result.build_state, "shadow module should expose build_state")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    return nil
end

local mock_target = {
    get_guid = function() return "target-shadow-123" end,
    get_health_percentage = function() return 100 end,
}

local context = {
    now = 100,
    in_combat = true,
    target = mock_target,
    has_valid_enemy_target = true,
    is_moving = false,
    is_casting = false,
    is_channeling = false,
    ttd_known = true,
    ttd = 60,
    settings = {},
}

local state = result.build_state(context)

-- The buff_manager scan should see VT with 12s and SW:P with 15s remaining.
assert_eq(state.vt_remaining, 12, "vt_remaining should be 12.0 seconds (12000ms / 1000)")
assert_eq(state.swp_remaining, 15, "swp_remaining should be 15.0 seconds (15000ms / 1000)")

-- With active debuffs, the VT and SW:P strategies should NOT match.
local vt = find_strategy("VampiricTouch")
local swp = find_strategy("ShadowWordPain")
assert_true(vt ~= nil, "VampiricTouch strategy should exist")
assert_true(swp ~= nil, "ShadowWordPain strategy should exist")

assert_false(vt.matches(context, state), "VampiricTouch should not match when VT has 12s remaining")
assert_false(swp.matches(context, state), "ShadowWordPain should not match when SW:P has 15s remaining")

-- ============================================================================
-- Fallback path: when buff_manager cache is empty, NS.debuff_remains is used.
-- ============================================================================
local original_get_debuff_cache = package.loaded["common/modules/buff_manager"].get_debuff_cache
local original_debuff_remains = _G.EaxRotations.debuff_remains

package.loaded["common/modules/buff_manager"].get_debuff_cache = function(unit, ttl_ms)
    return {}
end

-- Provide fallback values via NS.debuff_remains so the fallback path is exercised.
_G.EaxRotations.debuff_remains = function(target, ids)
    -- ids is an array; check for VT or SW:P IDs.
    for _, id in ipairs(ids) do
        if id == 34917 then return 8 end
        if id == 25368 then return 6 end
    end
    return 0
end

context.now = 200  -- force build_state to rebuild if it caches by frame
local state2 = result.build_state(context)
assert_eq(state2.vt_remaining, 8, "vt_remaining should fall back to NS.debuff_remains (8s)")
assert_eq(state2.swp_remaining, 6, "swp_remaining should fall back to NS.debuff_remains (6s)")

assert_false(vt.matches(context, state2), "VampiricTouch should not match when fallback VT has 8s remaining")
assert_false(swp.matches(context, state2), "ShadowWordPain should not match when fallback SW:P has 6s remaining")

-- Restore original mocks for cleanliness.
package.loaded["common/modules/buff_manager"].get_debuff_cache = original_get_debuff_cache
_G.EaxRotations.debuff_remains = original_debuff_remains

print("PASS test_shadow_debuff_scan_regression")
