-- test_affliction_dot_ttd.lua -- Affliction DoT time-to-death tests.
-- WHAT:  Affliction DoT time-to-death tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Validates time-to-death gating to avoid clipping DoTs on short-lived targets.
-- SAFETY: Uses synthetic TTD values.

-- Test: Affliction Warlock DoT TTD gating.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_false
local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
end
setup_asserts()

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
    buff_remains = function() return 0 end,
    debuff_remains = function() return 0 end,
    get_debuff_stacks = function() return 0 end,
    spell_ready = function() return true end,
    is_spell_learned = function() return true end,
    is_api_health_broken = function() return false end,
    is_item_ready = function() return false end,
    has_item = function() return false end,
    get_spell_damage = function() return 0 end,
    log = function() end,
    time_now = function() return 1000 end,
    cooldown_remains = function() return 0 end,
    rotation_registry = { register = function() end },
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

local corruption = find_strategy("CorruptionDoT")
local ua = find_strategy("UnstableAffliction")
local siphon = find_strategy("SiphonLife")
local immolate = find_strategy("ImmolateDoT")

-- Corruption: TTD too short -> should not match
assert_false(corruption.matches({
    has_valid_enemy_target = true,
    ttd_known = true, ttd = 5,
    settings = { dot_ttd_threshold = 50 },
}, {
    corruption_remains = 0, has_bloodlust = false, spell_damage = 0, snapshot_corruption_dmg = 0,
}), "Corruption: short TTD -> no match")

-- Corruption: TTD long enough -> should match
assert_true(corruption.matches({
    has_valid_enemy_target = true,
    ttd_known = true, ttd = 30,
    settings = { dot_ttd_threshold = 50 },
}, {
    corruption_remains = 0, has_bloodlust = false, spell_damage = 0, snapshot_corruption_dmg = 0,
}), "Corruption: long TTD -> match")

-- UA: TTD too short -> should not match
assert_false(ua.matches({
    has_valid_enemy_target = true,
    ttd_known = true, ttd = 5,
    settings = { dot_ttd_threshold = 50 },
}, {
    ua_remains = 0, has_bloodlust = false, spell_damage = 0, snapshot_ua_dmg = 0,
}), "UA: short TTD -> no match")

-- UA: TTD long enough -> should match
assert_true(ua.matches({
    has_valid_enemy_target = true,
    ttd_known = true, ttd = 30,
    settings = { dot_ttd_threshold = 50 },
}, {
    ua_remains = 0, has_bloodlust = false, spell_damage = 0, snapshot_ua_dmg = 0,
}), "UA: long TTD -> match")

-- Siphon Life: TTD too short -> should not match
assert_false(siphon.matches({
    has_valid_enemy_target = true,
    ttd_known = true, ttd = 5,
    settings = { dot_ttd_threshold = 50 },
}, {
    siphon_remains = 0, has_bloodlust = false, spell_damage = 0, snapshot_siphon_dmg = 0,
}), "Siphon: short TTD -> no match")

-- Siphon Life: TTD long enough -> should match
assert_true(siphon.matches({
    has_valid_enemy_target = true,
    ttd_known = true, ttd = 30,
    settings = { dot_ttd_threshold = 50 },
}, {
    siphon_remains = 0, has_bloodlust = false, spell_damage = 0, snapshot_siphon_dmg = 0,
}), "Siphon: long TTD -> match")

-- Immolate: short TTD -> should not match (also has existing 5s hard gate)
assert_false(immolate.matches({
    has_valid_enemy_target = true,
    ttd_known = true, ttd = 3,
    settings = { dot_ttd_threshold = 50 },
}, {
    immolate_remains = 0, has_bloodlust = false, spell_damage = 0, snapshot_immolate_dmg = 0,
}), "Immolate: short TTD -> no match")

-- Immolate: long TTD -> should match
assert_true(immolate.matches({
    has_valid_enemy_target = true,
    ttd_known = true, ttd = 20,
    settings = { dot_ttd_threshold = 50 },
}, {
    immolate_remains = 0, has_bloodlust = false, spell_damage = 0, snapshot_immolate_dmg = 0,
}), "Immolate: long TTD -> match")

print("PASS test_affliction_dot_ttd")
