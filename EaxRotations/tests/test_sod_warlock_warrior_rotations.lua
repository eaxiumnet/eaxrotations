-- test_sod_warlock_warrior_rotations.lua -- SoD Warlock/Warrior role contracts.
-- WHAT: validates source-ordered DPS/tank strategies and class registration.
-- WHEN: run with deterministic action, readiness, and registry mocks.
-- WHY: locks phase/rune, pet, stance, and rage safety before shipping products.
-- SAFETY: malformed runtime inputs must fail closed without throwing.
-- DECISION: exercise production role modules through their public strategy/build_state contract.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;?.lua;" .. package.path

local function assert_eq(actual, expected, label)
    if actual ~= expected then
        error((label or "assert_eq") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected), 2)
    end
end

local registry = { playstyles = {} }
function registry:register(name, strategies, options)
    self.playstyles[name] = strategies
    self.options = self.options or {}
    self.options[name] = options
end

local cast_log = {}
_G.EaxRotations = {
    is_sod = function() return true end,
    rotation_registry = registry,
    spell_action = function(ids, label)
        local id = type(ids) == "table" and (ids[1] or ids.ids and ids.ids[1]) or ids
        return { _meta = { id = id, label = label } }
    end,
    spell_ready = function() return true end,
    try_cast = function(action, target, reason, options)
        cast_log[#cast_log + 1] = { action = action, target = target, reason = reason, options = options }
        return true
    end,
}

local function load_role(path)
    package.loaded[path] = nil
    local role = require(path)
    assert_eq(type(role), "table", path .. " loads")
    return role
end

local function strategy(role, name)
    for _, candidate in ipairs(role.strategies) do
        if candidate.name == name then return candidate end
    end
    error("missing strategy " .. name, 2)
end

local function assert_execute(role, name, context, expected_id, expected_target)
    local selected = strategy(role, name)
    local state = role.build_state(context)
    local before = #cast_log
    assert_eq(selected.execute(context, state), true, name .. " execute result")
    assert_eq(#cast_log, before + 1, name .. " cast count")
    local call = cast_log[#cast_log]
    assert_eq(call.action._meta.id, expected_id, name .. " action ID")
    assert_eq(call.target, expected_target, name .. " target")
end

local target = {}
local me = {}
local warlock_dps = load_role("classes/warlock/dps_sod")
local warlock_tank = load_role("classes/warlock/tank_sod")
local warrior_dps = load_role("classes/warrior/dps_warrior_sod")
local warrior_tank = load_role("classes/warrior/tank_warrior_sod")

local warlock_base = {
    is_sod = true, sod_phase = 8, in_combat = true, target = target, me = me,
    mana_pct = 90, target_hp_pct = 100, curse_remains = 0,
    immolate_remains = 0, corruption_remains = 0,
    pet = {}, pet_alive = true, pet_hp_pct = 100,
    sod_runes = { [403629] = true, [412758] = true },
}
assert_eq(strategy(warlock_dps, "CurseOfRecklessness").matches(
    warlock_base, warlock_dps.build_state(warlock_base)), true,
    "Warlock DPS opens with the pinned curse")
assert_execute(warlock_dps, "CurseOfRecklessness", warlock_base, 7658, target)

local warlock_execute = {
    is_sod = true, sod_phase = 8, in_combat = true, target = target,
    mana_pct = 80, target_hp_pct = 15, curse_remains = 20, immolate_remains = 10,
    corruption_remains = 10, pet = {}, pet_alive = true, sod_runes = {},
}
assert_eq(strategy(warlock_dps, "Shadowburn").matches(
    warlock_execute, warlock_dps.build_state(warlock_execute)), true,
    "Warlock DPS uses execute Shadowburn")
assert_execute(warlock_dps, "Shadowburn", warlock_execute, 29341, target)

local warlock_life_tap = {
    is_sod = true, sod_phase = 8, in_combat = true, target = target,
    mana_pct = 10, hp_pct = 80, moving = false, target_hp_pct = 100,
    curse_remains = 20, immolate_remains = 10, corruption_remains = 10,
    pet = {}, pet_alive = true, sod_runes = {},
}
assert_eq(strategy(warlock_dps, "LifeTap").matches(
    warlock_life_tap, warlock_dps.build_state(warlock_life_tap)), true,
    "Warlock DPS sustains mana only above the health floor")
local warlock_low_health = {
    is_sod = true, sod_phase = 8, in_combat = true, target = target,
    mana_pct = 10, hp_pct = 20, moving = false,
}
assert_eq(strategy(warlock_dps, "LifeTap").matches(
    warlock_low_health, warlock_dps.build_state(warlock_low_health)), false,
    "Warlock Life Tap protects low health")
assert_eq(strategy(warlock_dps, "HealthFunnel").matches(
    { is_sod = true, sod_phase = 8, in_combat = true, target = target,
        pet = {}, pet_alive = false, pet_hp_pct = 20 },
    warlock_dps.build_state({ is_sod = true, sod_phase = 8, in_combat = true,
        target = target, pet = {}, pet_alive = false, pet_hp_pct = 20 })), false,
    "Warlock Health Funnel requires a live pet")
assert_eq(strategy(warlock_dps, "Incinerate").matches(
    { is_sod = true, sod_phase = 1, in_combat = true, target = target, sod_runes = { [999999] = true } },
    warlock_dps.build_state({ is_sod = true, sod_phase = 1, in_combat = true,
        target = target, sod_runes = { [999999] = true } })), false,
    "Warlock Incinerate requires its rune (known rune table without it closes)")

local warlock_tank_meta = {
    is_sod = true, sod_phase = 8, in_combat = true, target = target, me = me,
    mana_pct = 80, pet = {}, pet_alive = true, metamorphosis_active = false,
    sod_runes = { [403789] = true },
}
assert_eq(strategy(warlock_tank, "Metamorphosis").matches(
    warlock_tank_meta, warlock_tank.build_state(warlock_tank_meta)), true,
    "Warlock tank enables Metamorphosis")
assert_execute(warlock_tank, "Metamorphosis", warlock_tank_meta, 403789, me)
local warlock_tank_cleave = {
    is_sod = true, sod_phase = 8, in_combat = true, target = target,
    enemy_count = 3, pet = {}, pet_alive = true, metamorphosis_active = true,
    shadow_cleave_remains = 0, sod_runes = { [403789] = true },
}
assert_eq(strategy(warlock_tank, "ShadowCleave").matches(
    warlock_tank_cleave, warlock_tank.build_state(warlock_tank_cleave)), true,
    "Warlock tank uses Shadow Cleave in Metamorphosis")
assert_eq(strategy(warlock_tank, "HealthFunnel").matches(
    { is_sod = true, sod_phase = 8, in_combat = true, target = target,
        pet = {}, pet_alive = false, pet_hp_pct = 10, metamorphosis_active = true,
        sod_runes = { [403789] = true } },
    warlock_tank.build_state({ is_sod = true, sod_phase = 8, in_combat = true,
        target = target, pet = {}, pet_alive = false, pet_hp_pct = 10,
        metamorphosis_active = true, sod_runes = { [403789] = true } })), false,
    "Warlock tank Health Funnel fails closed without pet")

local warrior_dps_base = {
    is_sod = true, sod_phase = 8, in_combat = true, target = target,
    stance = "berserker", rage = 30, target_hp_pct = 15, enemy_count = 1,
    sod_runes = {},
}
assert_eq(strategy(warrior_dps, "Execute").matches(
    warrior_dps_base, warrior_dps.build_state(warrior_dps_base)), true,
    "Warrior DPS executes with rage and target health")
assert_execute(warrior_dps, "Execute", warrior_dps_base, 20660, target)
assert_eq(strategy(warrior_dps, "Execute").matches(
    { is_sod = true, sod_phase = 8, in_combat = true, target = target,
        stance = "defensive", rage = 50, target_hp_pct = 15 },
    warrior_dps.build_state(warrior_dps_base)), false,
    "Warrior DPS does not attack from the tank stance")
local warrior_quick_strike = {
    is_sod = true, sod_phase = 8, in_combat = true, target = target,
    stance = "berserker", rage = 60, target_hp_pct = 80, enemy_count = 1,
    sod_runes = { [429765] = true },
}
assert_eq(strategy(warrior_dps, "QuickStrike").matches(
    warrior_quick_strike, warrior_dps.build_state(warrior_quick_strike)), true,
    "Warrior Quick Strike respects its rune and rage floor")
local warrior_low_rage = {
    is_sod = true, sod_phase = 8, in_combat = true, target = target,
    stance = "berserker", rage = 10, sod_runes = { [429765] = true },
}
assert_eq(strategy(warrior_dps, "QuickStrike").matches(
    warrior_low_rage, warrior_dps.build_state(warrior_low_rage)), false,
    "Warrior Quick Strike fails closed at low rage")

local warrior_tank_base = {
    is_sod = true, sod_phase = 8, in_combat = true, target = target,
    stance = "defensive", rage = 50, enemy_count = 2, hp_pct = 80,
    sod_runes = { [440488] = true },
}
assert_eq(strategy(warrior_tank, "Shockwave").matches(
    warrior_tank_base, warrior_tank.build_state(warrior_tank_base)), true,
    "Warrior tank uses Shockwave for multiple targets")
assert_execute(warrior_tank, "Shockwave", warrior_tank_base, 440488, target)
local warrior_tank_low_rage = {
    is_sod = true, sod_phase = 8, in_combat = true, target = target,
    stance = "defensive", rage = 10, enemy_count = 1,
}
assert_eq(strategy(warrior_tank, "ShieldSlam").matches(
    warrior_tank_low_rage, warrior_tank.build_state(warrior_tank_low_rage)), false,
    "Warrior Shield Slam respects rage safety")
assert_eq(strategy(warrior_tank, "ShieldSlam").matches(
    { is_sod = true, sod_phase = "phase-8", in_combat = true, target = target,
        stance = "defensive", rage = 60, sod_runes = { [426978] = true } },
    warrior_tank.build_state(warrior_tank_base)), false,
    "Warrior tank rejects stale phase input")

for _, role in ipairs({ warlock_dps, warlock_tank, warrior_dps, warrior_tank }) do
    local ok = pcall(function()
        for _, candidate in ipairs(role.strategies) do
            candidate.matches(nil, role.build_state(nil))
        end
    end)
    assert_eq(ok, true, "nil context is non-throwing")
end

local original_require = require
local requested = {}
local class_id = 9
require = function(path)
    if path == "shared/class_loader_sylvanas" then
        return {
            get_enums = function() return { class_id = { WARLOCK = 9, WARRIOR = 1 } } end,
            create_loader = function() return function() end end,
            create_expansion_loader = function()
                return function(name)
                    requested[#requested + 1] = name
                    return true
                end
            end,
            sod_playstyles = function(class)
                return class == "warlock"
                    and { { name = "sod_warlock_dps" }, { name = "sod_warlock_tank" } }
                    or { { name = "sod_warrior_dps" }, { name = "sod_warrior_tank" } }
            end,
            load_sod_specs = function(class)
                local names = class == "warlock" and { "sod_warlock_dps", "sod_warlock_tank" }
                    or { "sod_warrior_dps", "sod_warrior_tank" }
                for _, name in ipairs(names) do requested[#requested + 1] = name end
                return #names
            end,
        }
    end
    if path == "shared/spell_id_table_sylvanas" then return { resolve = function() return nil end } end
    return original_require(path)
end
_G.EaxRotations.GetPlayer = function() return { get_class = function() return class_id end } end
_G.EaxRotations.rotation_registry.set_class_config = function(_, config)
    _G.EaxRotations.last_class_config = config
end
assert(loadfile("EaxRotations/classes/warlock/class_sylvanas.lua"))()
assert_eq(table.concat(requested, ","), "sod_warlock_dps,sod_warlock_tank", "Warlock SoD role paths")
assert_eq(_G.EaxRotations.last_class_config.playstyles[#_G.EaxRotations.last_class_config.playstyles].name,
    "sod_warlock_tank", "Warlock tank playstyle")
requested = {}
class_id = 1
assert(loadfile("EaxRotations/classes/warrior/class_sylvanas.lua"))()
assert_eq(table.concat(requested, ","), "sod_warrior_dps,sod_warrior_tank", "Warrior SoD role paths")
assert_eq(_G.EaxRotations.last_class_config.playstyles[#_G.EaxRotations.last_class_config.playstyles].name,
    "sod_warrior_tank", "Warrior tank playstyle")
require = original_require

print("PASS test_sod_warlock_warrior_rotations (four source-backed role products)")
