-- cat_wotlk.lua — Druid Feral Cat rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Feral Cat druid.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); DSL conditions replace
--         imperative match functions; no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl = require("shared/strategy_dsl_sylvanas")
local SPELLS = NS.DruidSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    FaerieFireFeral = define("FaerieFireFeral", { 27011, 17392, 17391, 17390, 16857 }, "FaerieFireFeral"),
    Ravage = define("Ravage", { 48579, 27005, 9867, 9866, 6787, 6785 }, "Ravage"),
    MangleCat = define("MangleCat", { 48566, 33983, 33982, 33876 }, "MangleCat"),
    Rake = define("Rake", { 48574, 27003, 9904, 1824, 1823, 1822 }, "Rake"),
    Rip = define("Rip", { 49800, 27008, 9896, 9894, 9752, 9493, 9492, 1079 }, "Rip"),
    SavageRoar = define("SavageRoar", 52610, "SavageRoar"),
    FerociousBite = define("FerociousBite", { 48576, 24248, 31018, 22829, 22828, 22827, 22568 }, "FerociousBite"),
    Shred = define("Shred", { 48572, 27002, 27001, 9830, 9829, 8992, 6800, 5221 }, "Shred"),
}

local RAKE_DEBUFF = { 27003, 9904, 1824, 1823, 1822 }
local RIP_DEBUFF = { 27008, 9896, 9894, 9752, 9493, 9492, 1079 }
local FAERIE_FIRE_FERAL_DEBUFF = { 27011, 17392, 17391, 17390, 16857 }
local SAVAGE_ROAR_BUFF = { 52610 }

local cat_state = {
    hp = 100,
    target_hp = 100,
    energy = 0,
    combo_points = 0,
    enemy_count = 1,
    in_combat = false,
    rake_remains = 0,
    rip_remains = 0,
    faerie_fire_remains = 0,
    savage_roar_remains = 0,
    is_stealthed = false,
    is_behind = false,
}

local function build_state(context)
    local state = spec_kit.safe_state(cat_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.energy = (me and me.get_energy and me:get_energy()) or 0
    state.combo_points = (me and me.get_combo_points and me:get_combo_points()) or 0
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.rake_remains = (target and NS.debuff_remains and NS.debuff_remains(target, RAKE_DEBUFF)) or 0
    state.rip_remains = (target and NS.debuff_remains and NS.debuff_remains(target, RIP_DEBUFF)) or 0
    state.faerie_fire_remains = (target and NS.debuff_remains and NS.debuff_remains(target, FAERIE_FIRE_FERAL_DEBUFF)) or 0
    state.savage_roar_remains = (me and NS.buff_remains and NS.buff_remains(me, SAVAGE_ROAR_BUFF)) or 0
    state.is_stealthed = (context and context.is_stealthed == true) or (me and NS.buff_up and NS.buff_up(me, { 9913, 6783, 5215 })) or false
    -- Strict behind check for Shred (spell requires being behind target)
    if context and context.is_behind ~= nil then
        state.is_behind = context.is_behind == true
    elseif NS.is_behind_target and target then
        state.is_behind = NS.is_behind_target(target) == true
    else
        state.is_behind = false
    end
    return state
end

-- -----------------------------------------------------------------------------
-- Declarative Strategy DSL definitions
-- -----------------------------------------------------------------------------
local DSL_DEFS = {
    {
        name = "FaerieFireFeral",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "faerie_fire_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.FaerieFireFeral, target = "target" },
    },
    {
        name = "Ravage",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "is_stealthed", op = "truthy" },
            { type = "state", field = "is_behind", op = "truthy" },
            { type = "state", field = "energy", op = ">=", value = 60 },
        },
        action = { type = "cast", spell = ACTION.Ravage, target = "target" },
    },
    {
        name = "SavageRoar",
        conditions = {
            { type = "state", field = "savage_roar_remains", op = "<", value = 3 },
            { type = "state", field = "combo_points", op = ">=", value = 1 },
        },
        action = { type = "cast", spell = ACTION.SavageRoar, target = "self" },
    },
    {
        name = "Rip",
        conditions = {
            { type = "state", field = "rip_remains", op = "<", value = 3 },
            { type = "state", field = "combo_points", op = ">=", value = 5 },
        },
        action = { type = "cast", spell = ACTION.Rip, target = "target" },
    },
    {
        name = "Rake",
        conditions = {
            { type = "state", field = "rake_remains", op = "<", value = 3 },
            { type = "state", field = "energy", op = ">=", value = 40 },
        },
        action = { type = "cast", spell = ACTION.Rake, target = "target" },
    },
    {
        name = "FerociousBite",
        conditions = {
            { type = "state", field = "combo_points", op = ">=", value = 5 },
            { type = "state", field = "target_hp", op = "<", value = 25 },
        },
        action = { type = "cast", spell = ACTION.FerociousBite, target = "target" },
    },
    {
        name = "MangleCat",
        conditions = {
            { type = "state", field = "energy", op = ">=", value = 45 },
        },
        action = { type = "cast", spell = ACTION.MangleCat, target = "target" },
    },
    {
        name = "Shred",
        conditions = {
            { type = "state", field = "is_behind", op = "truthy" },
            { type = "state", field = "energy", op = ">=", value = 50 },
        },
        action = { type = "cast", spell = ACTION.Shred, target = "target" },
    },
}

-- -----------------------------------------------------------------------------
-- Strategies (name-only placeholders; substituted by DSL). Priority preserved.
-- -----------------------------------------------------------------------------
local strategies = {
    { name = "FaerieFireFeral" },
    { name = "Ravage" },
    { name = "SavageRoar" },
    { name = "Rip" },
    { name = "Rake" },
    { name = "FerociousBite" },
    { name = "MangleCat" },
    { name = "Shred" },
}

-- Name-based substitution preserves the existing priority order.
for i = 1, #strategies do
    for j = 1, #DSL_DEFS do
        if strategies[i].name == DSL_DEFS[j].name then
            strategies[i] = dsl.compile_strategy(DSL_DEFS[j], { get_state = build_state })
            break
        end
    end
end

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("cat", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state }
