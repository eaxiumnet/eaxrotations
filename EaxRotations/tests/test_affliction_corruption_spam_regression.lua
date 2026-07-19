-- test_affliction_corruption_spam_regression.lua -- Regression test for Corruption spam bug.
-- WHAT:  Verifies that when buff_manager reports an active Corruption debuff,
--         the Affliction rotation sees a positive remaining time and does not
--         re-cast Corruption.
-- WHEN:  During rotation test suite execution.
-- WHY:   The bug was caused by buff_manager_helper calling the non-existent
--         "get_debuffs" method instead of the documented "get_debuff_cache",
--         which made scan_target_dots return empty and corruption_remains
--         defaulted to 0, causing CorruptionDoT to match every tick.
-- SAFETY: Pure synthetic test; no live game data required.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_false, assert_eq
local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
    assert_eq = function(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
end
setup_asserts()

-- Mock NS namespace
_G.EaxRotations = {
    WarlockSpells = {
        DeathCoil = { ids = { 27223 } },
        Soulshatter = { ids = { 29858 } },
        ShadowBolt = { ids = { 27209 } },
        Corruption = { ids = { 27216 } },
        UnstableAffliction = { ids = { 30405 } },
        SiphonLife = { ids = { 30911 } },
        CurseOfDoom = { ids = { 30910 } },
        CurseOfAgony = { ids = { 27218 } },
        Immolate = { ids = { 27215 } },
        SeedOfCorruption = { ids = { 27285 } },
        LifeTap = { ids = { 27222 } },
    },
    spell_action = function(tbl) return tbl end,
    has_player_buff = function() return false end,
    -- Fallback debuff_remains returns 0 so the test is forced to rely on the
    -- buff_manager scan path. If the helper regresses to calling a non-existent
    -- method, corruption_remains will be 0 and the test will fail.
    debuff_remains = function() return 0 end,
    buff_remains = function() return 0 end,
    get_debuff_stacks = function() return 0 end,
    spell_ready = function() return true end,
    is_spell_learned = function() return true end,
    is_api_health_broken = function() return false end,
    is_item_ready = function() return false end,
    has_item = function() return false end,
    log = function() end,
    time_now = function() return 1000 end,
    cooldown_remains = function() return 0 end,
    rotation_registry = { register = function() end },
}

-- Mock the Sylvanas buff_manager so get_debuff_cache returns an active Corruption.
package.loaded["common/modules/buff_manager"] = {
    get_debuff_cache = function(unit, ttl_ms)
        return {
            { buff_id = 27216, remaining = 14000 }, -- 14 seconds remaining
        }
    end,
}

package.loaded["shared/pet_manager_sylvanas"] = {
    set_defensive = function() end,
    set_passive = function() end,
    set_aggressive = function() end,
}
package.loaded["shared/potion_helper_sylvanas"] = {}
package.loaded["shared/tbc_data_sylvanas"] = { ITEMS = { potions = {} } }
package.loaded["shared/dot_ttd_gating_sylvanas"] = {
    should_skip_dot = function(ttd, duration, threshold)
        if not ttd or ttd <= 0 then return false end
        if not duration or duration <= 0 then return false end
        return ttd < (duration * threshold)
    end,
    DOT_DURATIONS = {
        corruption = 18,
        unstable_affliction = 18,
        siphon_life = 30,
        immolate = 15,
    },
}

local orig_pcall = _G.pcall
_G.pcall = function(fn, path, ...)
    if type(path) == "string" then
        if path:find("tbc_data_sylvanas") then return true, { ITEMS = { potions = {} } } end
        if path:find("izi_sdk") then return false, nil end
        if path:find("dot_ttd_gating_sylvanas") then return true, package.loaded["shared/dot_ttd_gating_sylvanas"] end
    end
    return orig_pcall(fn, path, ...)
end

local orig_require = _G.require
_G.require = function(path)
    if type(path) == "string" then
        if path:find("tbc_data_sylvanas") then return { ITEMS = { potions = {} } } end
        if path:find("offensive_dispel") then return {} end
        if path:find("izi_sdk") then return nil end
        if path:find("dot_ttd_gating") then return package.loaded["shared/dot_ttd_gating_sylvanas"] end
        if path:find("pet_manager") then return package.loaded["shared/pet_manager_sylvanas"] end
        if path:find("potion_helper") then return package.loaded["shared/potion_helper_sylvanas"] end
    end
    return orig_require(path)
end

local result = dofile("EaxRotations/classes/warlock/affliction_sylvanas.lua")
assert_true(result, "affliction module should load")
assert_true(result.build_state, "affliction module should expose build_state")
local strategies = result.strategies
assert_true(strategies, "strategies table should load")

_G.require = orig_require
_G.pcall = orig_pcall

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local mock_target = {
    get_guid = function() return "target-123" end,
    get_health_percentage = function() return 100 end,
}

local context = {
    now = 1000,
    target = mock_target,
    has_valid_enemy_target = true,
    in_combat = true,
    ttd_known = true,
    ttd = 30,
    settings = { dot_ttd_threshold = 50 },
}

local state = result.build_state(context)

-- The buff_manager scan should see Corruption with 14s remaining.
assert_eq(state.corruption_remains, 14, "corruption_remains should be 14.0 seconds (14000ms / 1000)")

-- With 14s remaining, the CorruptionDoT strategy should NOT match.
local corruption = find_strategy("CorruptionDoT")
local is_match = corruption.matches(context, state)
assert_false(is_match, "CorruptionDoT should not match when Corruption has 14s remaining")

-- ============================================================================
-- Fallback path: when buff_manager cache is empty, NS.debuff_remains is used.
-- ============================================================================
local original_get_debuff_cache = package.loaded["common/modules/buff_manager"].get_debuff_cache
local original_debuff_remains = _G.EaxRotations.debuff_remains

package.loaded["common/modules/buff_manager"].get_debuff_cache = function(unit, ttl_ms)
    return {}
end

_G.EaxRotations.debuff_remains = function(target, ids)
    for _, id in ipairs(ids) do
        if id == 27216 then return 9 end
    end
    return 0
end

context.now = 2000  -- force build_state to rebuild (frame-keyed dedup)
local state2 = result.build_state(context)
assert_eq(state2.corruption_remains, 9, "corruption_remains should fall back to NS.debuff_remains (9s)")
assert_false(corruption.matches(context, state2), "CorruptionDoT should not match when fallback Corruption has 9s remaining")

-- Restore original mocks for cleanliness.
package.loaded["common/modules/buff_manager"].get_debuff_cache = original_get_debuff_cache
_G.EaxRotations.debuff_remains = original_debuff_remains

print("PASS test_affliction_corruption_spam_regression")
