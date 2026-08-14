-- test_sod_rogue_shaman_rotations.lua -- Source-priority coverage for Task 6 SoD roles.
-- WHAT: validates Rogue DPS/tank and Shaman elemental/enhancement/warden/restoration priorities.
-- WHEN: run standalone or from the rotation suite after the shared SoD runtime contract tests.
-- WHY: locks the pinned wowsims/sod role actions into executable production modules.
-- SAFETY: deterministic registry/cast mocks; no live game API or external state.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;?.lua;" .. package.path

local function assert_eq(actual, expected, label)
    if actual ~= expected then
        error((label or "assert_eq") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected), 2)
    end
end

local registry = { playstyles = {} }
local cast_log = {}
function registry:register(name, strategies, options)
    self.playstyles[name] = strategies
    self.options = self.options or {}
    self.options[name] = options
end

_G.EaxRotations = {
    is_sod = function() return true end,
    RogueSpells = {},
    ShamanSpells = {},
    rotation_registry = registry,
    spell_action = function(ids, label)
        if type(ids) == "table" and ids.ids then
            local meta = ids
            return { _meta = { id = meta.ids[1], label = meta.name } }
        end
        local id = type(ids) == "table" and ids[1] or ids
        return { _meta = { id = id, label = label } }
    end,
    try_cast = function(action, target, reason, options)
        cast_log[#cast_log + 1] = { action = action, target = target, reason = reason, options = options }
        return true
    end,
}

local function load_role(path)
    package.loaded[path] = nil
    local result = require(path)
    assert_eq(type(result), "table", path .. " loads")
    return result
end

local function strategy(role, name)
    for _, candidate in ipairs(role.strategies) do
        if candidate.name == name then return candidate end
    end
    error("missing strategy " .. name, 2)
end

local function first_match(role, context)
    local state = role.build_state(context)
    for _, candidate in ipairs(role.strategies) do
        if candidate.matches(context, state) then return candidate.name end
    end
    return nil
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

local rogue = load_role("classes/rogue/combat_sod")
local rogue_tank = load_role("classes/rogue/tank_sod")
local elemental = load_role("classes/shaman/elemental_sod")
local enhancement = load_role("classes/shaman/enhancement_sod")
local warden = load_role("classes/shaman/warden_sod")
local restoration = load_role("classes/shaman/restoration_sod")

local rogue_context = {
    is_sod = true, sod_phase = 8, target = {}, enemy_count = 1,
    combo_points = 5, energy = 80, poison_stacks = 5, target_poisoned = true,
    snd_remains = 10, crimson_tempest_remains = 0,
    sod_runes = { [399963] = true, [399956] = true, [412096] = true },
}
assert_eq(strategy(rogue, "Envenom").matches(rogue_context, rogue.build_state(rogue_context)), true,
    "Rogue DPS spends five points with poison")
assert_eq(strategy(rogue, "Mutilate").matches(rogue_context, rogue.build_state(rogue_context)), false,
    "Rogue DPS does not build at five points")
assert_execute(rogue, "Envenom", rogue_context, 399963, rogue_context.target)

local rogue_mutilate_context = {
    is_sod = true, sod_phase = 8, target = {}, combo_points = 4, energy = 80,
    sod_runes = { [399956] = true },
}
assert_eq(strategy(rogue, "Mutilate").matches(
    rogue_mutilate_context, rogue.build_state(rogue_mutilate_context)), false,
    "Mutilate stops at three combo points in the pinned phase-6 APL")

local rogue_saber_context = {
    is_sod = true, sod_phase = 8, target = {}, combo_points = 3, energy = 40,
    sod_runes = { [424785] = true },
}
assert_eq(strategy(rogue, "SaberSlash").matches(
    rogue_saber_context, rogue.build_state(rogue_saber_context)), false,
    "Saber Slash waits for energy at three combo points")

local tank_context = {
    is_sod = true, sod_phase = 8, target = {}, combo_points = 4, energy = 60,
    blade_dance_remains = 0, target_poisoned = true, poison_stacks = 4,
    sod_runes = { [400014] = true, [400012] = true, [424919] = true },
}
assert_eq(strategy(rogue_tank, "BladeDance").matches(tank_context, rogue_tank.build_state(tank_context)), true,
    "Rogue tank maintains Blade Dance before builders")
assert_execute(rogue_tank, "BladeDance", tank_context, 400012, tank_context.target)

local elemental_context = {
    is_sod = true, sod_phase = 8, target = {}, mana_pct = 90, enemy_count = 1,
    flame_shock_remains = 8, sod_runes = { [408490] = true },
}
assert_eq(strategy(elemental, "LavaBurst").matches(elemental_context, elemental.build_state(elemental_context)), true,
    "Elemental casts Lava Burst into Flame Shock")
assert_execute(elemental, "LavaBurst", elemental_context, 408490, elemental_context.target)

local elemental_spirit_context = {
    is_sod = true, sod_phase = 8, target = {}, in_combat = true,
    sod_runes = { [440580] = true },
}
assert_eq(strategy(elemental, "FeralSpirit").matches(
    elemental_spirit_context, elemental.build_state(elemental_spirit_context)), true,
    "Elemental exposes the pinned Feral Spirit cooldown")

local elemental_aoe_context = {
    is_sod = true, sod_phase = 8, target = {}, mana_pct = 90, enemy_count = 2,
    flame_shock_remains = 8, sod_runes = { [408490] = true },
}
assert_eq(first_match(elemental, elemental_aoe_context), "ChainLightning",
    "Elemental prefers Chain Lightning before Lava Burst in the pinned AoE priority")

local enhancement_context = {
    is_sod = true, sod_phase = 8, target = {}, mana_pct = 90, enemy_count = 1,
    maelstrom_stacks = 5, sod_runes = { [408498] = true },
}
assert_eq(strategy(enhancement, "MaelstromLightningBolt").matches(
    enhancement_context, enhancement.build_state(enhancement_context)), true,
    "Enhancement consumes five Maelstrom stacks")
assert_execute(enhancement, "MaelstromLightningBolt", enhancement_context, 15208, enhancement_context.target)

local enhancement_lava_context = {
    is_sod = true, sod_phase = 8, target = {}, in_combat = true,
    auto_swing_remains = 2.5, offhand_imbue = "flametongue",
    sod_runes = { [408490] = true, [408507] = true },
}
assert_eq(strategy(enhancement, "LavaBurst").matches(
    enhancement_lava_context, enhancement.build_state(enhancement_lava_context)), true,
    "Enhancement casts Lava Burst only inside the safe swing window")
local enhancement_imbue_free = {
    is_sod = true, sod_phase = 8, target = {}, in_combat = true,
    sod_runes = { [408507] = true },
}
assert_eq(strategy(enhancement, "LavaLash").matches(
    enhancement_imbue_free, enhancement.build_state(enhancement_imbue_free)), true,
    "Enhancement Lava Lash fires on rune availability alone (W4.2: offhand imbue gate removed)")
local enhancement_no_rune = {
    is_sod = true, sod_phase = 8, target = {}, in_combat = true,
    sod_runes = { [408490] = true }, -- LavaBurst rune, NOT LavaLash's 408507
}
assert_eq(strategy(enhancement, "LavaLash").matches(
    enhancement_no_rune, enhancement.build_state(enhancement_no_rune)), false,
    "Enhancement Lava Lash gated on its own rune")

local warden_context = {
    is_sod = true, sod_phase = 8, target = {}, mana_pct = 90, enemy_count = 5,
    mainhand_imbue = "rockbiter", sod_runes = { [408531] = true, [425339] = true },
}
assert_eq(strategy(warden, "MoltenBlast").matches(warden_context, warden.build_state(warden_context)), true,
    "Warden uses Molten Blast for five targets")
assert_execute(warden, "MoltenBlast", warden_context, 425339, warden_context.target)

local heal_target = {}
local restoration_context = {
    is_sod = true, sod_phase = 8, target = {}, mana_pct = 80,
    lowest = { unit = heal_target, hp = 55 }, injured_count = 3,
    riptide_remains = 0, sod_runes = { [408521] = true, [415236] = true },
}
assert_eq(strategy(restoration, "Riptide").matches(
    restoration_context, restoration.build_state(restoration_context)), true,
    "Restoration stabilizes the lowest target with Riptide")
assert_eq(strategy(restoration, "HealingRain").matches(
    restoration_context, restoration.build_state(restoration_context)), true,
    "Restoration exposes Healing Rain for clustered damage")
assert_execute(restoration, "Riptide", restoration_context, 408521, heal_target)

assert_eq(registry.playstyles.tank, rogue_tank.strategies, "Rogue tank registration")
assert_eq(registry.playstyles.warden, warden.strategies, "Shaman warden registration")

local original_require = require
local requested = {}
local player_class = 4
_G.EaxRotations.GetPlayer = function()
    return { get_class = function() return player_class end }
end
_G.EaxRotations.rotation_registry.set_class_config = function(_, config)
    _G.EaxRotations.last_class_config = config
end
require = function(path)
    if path == "shared/class_loader_sylvanas" then
        return {
            get_enums = function() return { class_id = { ROGUE = 4, SHAMAN = 7 } } end,
            create_loader = function() return function() return true end end,
            create_expansion_loader = function()
                return function(name)
                    requested[#requested + 1] = name
                    return true
                end
            end,
            sod_playstyles = function(class)
                return class == "rogue"
                    and { { name = "sod_rogue_combat" }, { name = "sod_rogue_tank" } }
                    or { { name = "sod_shaman_elemental" }, { name = "sod_shaman_enhancement" },
                        { name = "sod_shaman_warden" }, { name = "sod_shaman_restoration" } }
            end,
            load_sod_specs = function(class)
                local names = class == "rogue" and { "sod_rogue_combat", "sod_rogue_tank" }
                    or { "sod_shaman_elemental", "sod_shaman_enhancement", "sod_shaman_warden", "sod_shaman_restoration" }
                for _, name in ipairs(names) do requested[#requested + 1] = name end
                return #names
            end,
        }
    end
    return original_require(path)
end
assert(loadfile("EaxRotations/classes/rogue/class_sylvanas.lua"))()
assert_eq(table.concat(requested, ","), "sod_rogue_combat,sod_rogue_tank", "Rogue SoD class role paths")
assert_eq(_G.EaxRotations.last_class_config.playstyles[2].name, "sod_rogue_tank", "Rogue SoD tank playstyle")

requested = {}
player_class = 7
assert(loadfile("EaxRotations/classes/shaman/class_sylvanas.lua"))()
assert_eq(table.concat(requested, ","), "sod_shaman_elemental,sod_shaman_enhancement,sod_shaman_warden,sod_shaman_restoration",
    "Shaman SoD class role paths")
assert_eq(_G.EaxRotations.last_class_config.playstyles[3].name, "sod_shaman_warden", "Shaman SoD warden playstyle")
require = original_require

print("PASS test_sod_rogue_shaman_rotations (six source-backed role products)")
