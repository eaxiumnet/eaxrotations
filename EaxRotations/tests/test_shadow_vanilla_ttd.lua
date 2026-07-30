package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(value, label) if not value then error(label, 2) end end
local function assert_false(value, label) if value then error(label, 2) end end

_G.EaxRotations = {
    PriestSpells = { ShadowWordPain = 589 }, PLAYER_UNIT = {},
    GetPlayer = function() return {} end,
    spell_action = function(ids) return ids[1] end,
    spell_ready = function() return true end, spell_exists = function() return true end,
    try_cast = function() return true end, buff_up = function() return false end,
    buff_remains = function() return 0 end, debuff_remains = function() return 0 end,
    debuff_up = function() return false end, get_debuff_stacks = function() return 0 end,
    has_player_buff = function() return false end, has_debuff = function() return false end,
    unit_health_pct = function() return 100 end, time_now = function() return 0 end,
    log = function() end, rotation_registry = { register = function() end },
}

package.loaded["shared/spec_kit_sylvanas"] = {
    setting = function(_, _, default) return default end,
    setting_bool = function(_, _, default) return default end,
    safe_state = function(state) return state end,
}
package.loaded["shared/potion_helper_sylvanas"] = { try_use_potion = function() return false end }
package.loaded["shared/tbc_data_sylvanas"] = { ITEMS = { potions = {} } }

local strategies = dofile("EaxRotations/classes/priest/shadow_vanilla.lua")
local function find(name)
    for i = 1, #strategies do if strategies[i].name == name then return strategies[i] end end
end

local swp = find("ShadowWordPain")
assert_true(swp ~= nil, "ShadowWordPain strategy exists")
local state = { swp_known = true, swp_remaining = 0, weaving_stacks = 5,
    mana_emergency = false, spell_damage = 0, snapshot_swp_dmg = 0 }
local context = { target = {}, has_valid_enemy_target = true, is_moving = false }
context.ttd = 9.9
assert_false(swp.matches(context, state), "SW:P is skipped below 10s target TTD")
context.ttd = 10
assert_true(swp.matches(context, state), "SW:P is allowed at 10s target TTD")
context.ttd = nil
assert_true(swp.matches(context, state), "unknown TTD preserves non-blocking fallback")

print("PASS test_shadow_vanilla_ttd")
