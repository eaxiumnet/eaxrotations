-- Regression: when Sylvanas spell-known APIs return false for every rank,
-- rich spell actions should fall back to the best rank allowed by player level.

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

assert_eq(NS.get_spell_id(ranked), 200, "level 62 fallback should choose the level 60 rank")
assert_eq(NS.get_spell_id({ 300, 200, 100 }), 100, "unannotated fallback should choose the safest low rank")

print("PASS test_spell_rank_fallback")
