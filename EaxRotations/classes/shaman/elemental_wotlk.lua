-- elemental_wotlk.lua — Shaman Elemental rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Elemental shaman.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl      = require("shared/strategy_dsl_sylvanas")
local SPELLS = NS.ShamanSpells or {}

local define = spec_kit.define_action

local ACTION = {
    Bloodlust = define("Bloodlust", 2825, "Bloodlust"),
    FireElemental = define("FireElemental", 2894, "FireElemental"),
    ElementalMastery = define("ElementalMastery", 16166, "ElementalMastery"),
    TotemOfWrath = define("TotemOfWrath", 57722, "TotemOfWrath"),
    SearingTotem = define("SearingTotem", 58704, "SearingTotem"),
    FlameShock = define("FlameShock", 49233, "FlameShock"),
    ChainLightning = define("ChainLightning", 49271, "ChainLightning"),
    LavaBurst = define("LavaBurst", 60043, "LavaBurst"),
    LightningBolt = define("LightningBolt", 49238, "LightningBolt"),
    Thunderstorm = define("Thunderstorm", 59159, "Thunderstorm"),
    -- Baseline shaman interrupt (3.3.5): Earth Shock interrupts spellcasting;
    -- Wind Shear only arrives in Cataclysm. Not in the wowsims elemental APL,
    -- so it sits outside the pinned order (first, like the rogue Kick template).
    EarthShock = define("EarthShock", 49231, "EarthShock"),
}

local FLAME_SHOCK_DEBUFF = { 49233, 25457, 29228, 10448, 10447, 8053, 8052, 8050 }
local FIRE_ELEMENTAL_BUFF = { 2894 }
local TOTEM_OF_WRATH_BUFF = { 57722 }
local SEARING_TOTEM_DEBUFF = { 58704 }

local elemental_state = {
    hp = 100,
    target_hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    target_is_casting = false,
    flame_shock_remains = 0,
    bloodlust_ready = false,
    fire_elemental_ready = false,
    elemental_mastery_ready = false,
    fire_elemental_active = false,
    totem_of_wrath_up = false,
    searing_totem_up = false,
}

local function build_state(context)
    local state = spec_kit.safe_state(elemental_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.mana_pct = (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.target_is_casting = (target and target.is_casting and target:is_casting()) or false
    state.flame_shock_remains = (target and NS.debuff_remains and NS.debuff_remains(target, FLAME_SHOCK_DEBUFF)) or 0
    state.bloodlust_ready = (context and context.bloodlust_ready) or false
    state.fire_elemental_ready = (context and context.fire_elemental_ready) or false
    state.elemental_mastery_ready = (context and context.elemental_mastery_ready) or false
    if context and context.fire_elemental_active ~= nil then
        state.fire_elemental_active = context.fire_elemental_active
    else
        state.fire_elemental_active = (me and NS.buff_up and NS.buff_up(me, FIRE_ELEMENTAL_BUFF)) or false
    end
    if context and context.totem_of_wrath_up ~= nil then
        state.totem_of_wrath_up = context.totem_of_wrath_up
    else
        state.totem_of_wrath_up = (me and NS.buff_up and NS.buff_up(me, TOTEM_OF_WRATH_BUFF)) or false
    end
    if context and context.searing_totem_up ~= nil then
        state.searing_totem_up = context.searing_totem_up
    else
        state.searing_totem_up = (target and NS.debuff_up and NS.debuff_up(target, SEARING_TOTEM_DEBUFF)) or false
    end
    return state
end

local DSL_DEFS = {
    {
        name = "EarthShock",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "target_is_casting", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.EarthShock, target = "target" },
    },
    {
        name = "Bloodlust",
        conditions = {
            { type = "state", field = "bloodlust_ready", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.Bloodlust, target = "self" },
    },
    {
        name = "FireElemental",
        conditions = {
            { type = "state", field = "fire_elemental_ready", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.FireElemental, target = "self" },
    },
    {
        name = "ElementalMastery",
        conditions = {
            { type = "state", field = "elemental_mastery_ready", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.ElementalMastery, target = "self" },
    },
    {
        name = "TotemOfWrath",
        conditions = {
            { type = "state", field = "in_combat", op = "falsy" },
            { type = "state", field = "totem_of_wrath_up", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.TotemOfWrath, target = "self" },
    },
    {
        name = "SearingTotem",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "fire_elemental_active", op = "falsy" },
            { type = "state", field = "searing_totem_up", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.SearingTotem, target = "self" },
    },
    {
        name = "FlameShock",
        conditions = {
            { type = "state", field = "flame_shock_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.FlameShock, target = "target" },
    },
    {
        name = "LavaBurst",
        conditions = {
            { type = "state", field = "flame_shock_remains", op = ">=", value = 1 },
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
        },
        action = { type = "cast", spell = ACTION.LavaBurst, target = "target" },
    },
    {
        name = "ChainLightning",
        conditions = {
            { type = "state", field = "enemy_count", op = ">=", value = 2 },
            { type = "state", field = "mana_pct", op = ">=", value = 25 },
        },
        action = { type = "cast", spell = ACTION.ChainLightning, target = "target" },
    },
    {
        name = "Thunderstorm",
        conditions = {
            { type = "state", field = "mana_pct", op = "<", value = 50 },
        },
        action = { type = "cast", spell = ACTION.Thunderstorm, target = "self" },
    },
    {
        name = "LightningBolt",
        conditions = {
            { type = "state", field = "mana_pct", op = ">=", value = 15 },
        },
        action = { type = "cast", spell = ACTION.LightningBolt, target = "target" },
    },
}

local strategies = {
    { name = "EarthShock" },
    { name = "Bloodlust" },
    { name = "FireElemental" },
    { name = "ElementalMastery" },
    { name = "TotemOfWrath" },
    { name = "SearingTotem" },
    { name = "FlameShock" },
    { name = "LavaBurst" },
    { name = "ChainLightning" },
    { name = "LightningBolt" },
    { name = "Thunderstorm" },
}

for i = 1, #strategies do
    for j = 1, #DSL_DEFS do
        if strategies[i].name == DSL_DEFS[j].name then
            strategies[i] = dsl.compile_strategy(DSL_DEFS[j], { get_state = build_state })
            break
        end
    end
end

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("elemental", strategies, { get_state = build_state })
end
if NS.log then NS.log("Shaman elemental rotation registered") end

return { strategies = strategies, build_state = build_state }
