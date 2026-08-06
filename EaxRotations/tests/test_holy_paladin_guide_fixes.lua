-- test_holy_paladin_guide_fixes.lua -- TBC Holy Paladin guide contracts.
-- WHAT:  Verifies efficient FoL ranks, emergency HL/HS gates, target safety, and no group AoE.
-- WHEN:  During the rotation test suite.
-- SAFETY: Pure strategy tests with mocked Sylvanas APIs and no live game state.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local cast_calls = {}
local overheal = false
local previous_ns = _G.EaxRotations
local module_names = {
    "classes/paladin/healing_sylvanas",
    "shared/fsr_manager_sylvanas",
    "shared/potion_helper_sylvanas",
    "shared/tbc_data_sylvanas",
    "shared/health_pred_helper_sylvanas",
    "shared/strategy_dsl_sylvanas",
}
local previous_modules = {}
for i = 1, #module_names do previous_modules[i] = package.loaded[module_names[i]] end

local NS = {
    PaladinSpells = {},
    PLAYER_UNIT = { _player = true },
    GetPlayer = function() return NS.PLAYER_UNIT end,
    spell_ready = function() return true end,
    try_cast = function(spell, target, reason)
        cast_calls[#cast_calls + 1] = { spell = spell, target = target, reason = reason }
        return true
    end,
    gate_overheal = function() return overheal end,
    buff_up = function() return false end,
    debuff_up = function() return false end,
    debuff_remains = function() return 0 end,
    buff_remains = function() return 0 end,
    has_player_buff = function() return false end,
    is_item_ready = function() return false end,
    get_friendly_target_entry = function() return nil end,
    time_now = function() return 0 end,
    log = function() end,
    rotation_registry = { register = function() end },
}
_G.EaxRotations = NS

package.loaded["classes/paladin/healing_sylvanas"] = {
    scan_healing_targets = function() return {}, 0 end,
    get_tank_target = function() return nil end,
    get_lowest_hp_target = function() return nil end,
}
package.loaded["shared/fsr_manager_sylvanas"] = {
    is_inside_fsr = function() return false end,
    seconds_until_fsr = function() return 0 end,
    get_regen_delta = function() return 0 end,
    should_pause_for_fsr = function() return false end,
}
package.loaded["shared/potion_helper_sylvanas"] = {
    MANA_POTION_IDS = {},
    try_use_potion = function() return false end,
}
package.loaded["shared/tbc_data_sylvanas"] = { ITEMS = { potions = {} } }
package.loaded["shared/health_pred_helper_sylvanas"] = nil
package.loaded["shared/strategy_dsl_sylvanas"] = nil

local holy = dofile("EaxRotations/classes/paladin/holy_sylvanas.lua")
local strategies = holy.strategies

local function find(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("missing strategy: " .. name, 2)
end

local function context(mana, extra)
    local value = {
        in_combat = true,
        is_group = true,
        is_solo = false,
        is_leveling = false,
        is_moving = false,
        mana_pct = mana,
        settings = {},
        has_valid_enemy_target = false,
        me = NS.PLAYER_UNIT,
    }
    for key, item in pairs(extra or {}) do value[key] = item end
    return value
end

local function state(entry, mana)
    return {
        lowest = entry,
        tank = entry,
        mana_pct = mana,
        moving = false,
        has_lights_grace = false,
        lights_grace_remains = 0,
        has_divine_favor = false,
        has_forbearance = false,
        has_divine_illumination = false,
        heavy_healing = false,
        has_seal_wisdom = false,
        has_seal_light = false,
        has_seal_righteousness = false,
        enemy_count = 0,
    }
end

local function entry(hp, extra)
    local value = { unit = {}, effective_hp = hp, deficit = 0 }
    for key, item in pairs(extra or {}) do value[key] = item end
    return value
end

local function last_cast()
    return cast_calls[#cast_calls]
end

local smart_heal = find("SmartHeal")
local lay_on_hands = find("LayOnHandsLastResort")
local holy_shock = find("HolyShock")
local holy_light = find("HolyLightEmergency")
local flash = find("FlashOfLightEfficientTopoff")
local consecration = find("ConsecrationSoloAoE")

cast_calls = {}
overheal = false
local target = entry(80)
local normal_state = state(target, 100)
assert(smart_heal.matches(context(100), normal_state), "R7 throughput should match")
assert(smart_heal.execute(context(100), normal_state), "R7 throughput should cast")
assert(last_cast().spell == 27137, "normal FoL should use TBC R7: " .. tostring(last_cast().spell))

cast_calls = {}
local conserve_state = state(target, 10)
assert(smart_heal.matches(context(10), conserve_state), "R6 conserve should match")
assert(smart_heal.execute(context(10), conserve_state), "R6 conserve should cast")
assert(last_cast().spell == 19943, "low-mana FoL should use TBC R6")

assert(not smart_heal.matches(context(4), state(target, 4)), "SmartHeal should stop below mana floor")
assert(not flash.matches(context(4), state(target, 4)), "FoL topoff should stop below mana floor")

local low_mana_emergency = entry(50)
local low_mana_emergency_state = state(low_mana_emergency, 4)
assert(not lay_on_hands.matches(context(4), low_mana_emergency_state),
    "50% HP target should be above the 12% Lay on Hands emergency range")
assert(smart_heal.matches(context(4), low_mana_emergency_state),
    "injured target above Lay on Hands range needs a sub-5% mana emergency heal")
cast_calls = {}
assert(smart_heal.execute(context(4), low_mana_emergency_state), "sub-5% mana emergency heal should cast")
assert(last_cast().spell == 19943, "sub-5% mana emergency heal should use Flash of Light R6")
assert(not smart_heal.matches(context(4), state(entry(50, { hostile = true }), 4)),
    "sub-5% mana emergency heal should reject hostile targets")
overheal = true
assert(not smart_heal.matches(context(4), state(entry(50), 4)),
    "sub-5% mana emergency heal should honor the overheal gate")
overheal = false

assert(holy_shock.matches(context(100, { is_moving = true }), state(entry(80), 100)),
    "Holy Shock should be an instant fallback for an injured moving ally")
assert(not holy_shock.matches(context(4, { is_moving = true }), state(entry(80), 4)),
    "moving Holy Shock should respect the mana floor")
assert(not holy_shock.matches(context(100, { is_moving = true }), state(entry(80, { hostile = true }), 100)),
    "moving Holy Shock should reject hostile targets")
assert(holy_shock.matches(context(50), state(entry(35), 50)), "Holy Shock should match emergency HP")
overheal = true
assert(not holy_shock.matches(context(50), state(entry(35), 50)), "Holy Shock should honor overheal gate")
overheal = false

assert(not holy_light.matches(context(20), state(entry(40), 20)), "Holy Light emergency should respect mana floor")
local critical = entry(20)
local critical_state = state(critical, 100)
assert(holy_light.matches(context(100), critical_state), "critical target should use Holy Light emergency")
cast_calls = {}
assert(holy_light.execute(context(100), critical_state), "critical Holy Light should cast")
assert(last_cast().spell == 27136, "critical Holy Light should use TBC max rank")
assert(not holy_light.matches(context(100), state(entry(20, { hostile = true }), 100)),
    "heals must reject explicitly hostile targets")
assert(not holy_light.matches(context(100), state(entry(20, { is_valid = false }), 100)),
    "heals must reject explicitly invalid targets")

assert(not consecration.matches(context(100, { has_valid_enemy_target = true, target = {}, enemy_count = 3 }),
    state(entry(90), 100)), "group healing must not cast Consecration AoE")
for i = 1, #strategies do
    assert(strategies[i].name ~= "HolyRadiance" and strategies[i].name ~= "LightOfDawn",
        "Holy Paladin must not invent non-TBC AoE healing")
end

print("PASS test_holy_paladin_guide_fixes")
for i = 1, #module_names do package.loaded[module_names[i]] = previous_modules[i] end
_G.EaxRotations = previous_ns
