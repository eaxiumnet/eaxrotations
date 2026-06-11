-- Regression: when Sylvanas spell-known APIs return false for every rank,
-- rich spell actions should return nil (PS build fallback removed in v2.1.x).
-- On live TBC the spell_book APIs work, so the level-based fallback path
-- (fallback_spell_id) was removed.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;" .. package.path

local function assert_eq(a, b, label)
    if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end
end

local player = {
    is_alive = function() return true end,
    is_valid = function() return true end,
    get_level = function() return 62 end,
    get_effective_level = function() return 62 end,
    get_power = function() return 1000 end,
}

_G.core = {
    time = function() return 0 end,
    game_time = function() return 0 end,
    log = function() end,
    log_warning = function() end,
    log_error = function() end,
    object_manager = {
        get_local_player = function() return player end,
        get_visible_objects = function() return {} end,
    },
    spell_book = {
        is_spell_learned = function() return false end,
        is_spell_known = function() return false end,
        has_spell = function() return false end,
        get_global_cooldown = function() return 0 end,
        get_spell_cooldown = function() return 0 end,
        get_spell_cooldown_information = function() return { enabled = false } end,
        get_spell_costs = function() return {} end,
        is_spell_in_range = function() return true end,
    },
    input = {},
}

package.loaded.core_sylvanas = nil
_G.EaxRotations = nil
local NS = require("core_sylvanas")

local ranked = NS.spell_action({
    name = "Ranked Test Spell",
    ids = { 300, 200, 100 },
    levels = { 70, 60, 1 },
})

-- Level-based fallback removed: on live retail, is_spell_learned determines spell IDs.
-- get_spell_id returns nil when no IDs are confirmed learned (the test doesn't mock the API).
assert_eq(NS.get_spell_id(ranked), nil, "no mock API — get_spell_id returns nil when none confirmed learned")
assert_eq(NS.get_spell_id({ 300, 200, 100 }), nil, "no mock API — get_spell_id returns nil when none confirmed learned")

print("PASS test_spell_rank_fallback")
