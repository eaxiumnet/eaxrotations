-- resto_wotlk.lua — Druid Restoration rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Restoration druid.
-- WHEN:  combat with valid friendly target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl      = require("shared/strategy_dsl_sylvanas")
local SPELLS = NS.DruidSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    Rejuvenation = define("Rejuvenation", { 48441, 26982, 26981, 25299, 9841, 9840, 9839, 8910, 3627, 2091, 2090, 1430, 1058, 774 }, "Rejuvenation"),
    WildGrowth = define("WildGrowth", 48438, "WildGrowth"),
    Regrowth = define("Regrowth", { 48443, 26980, 9858, 9857, 9856, 9750, 8941, 8940, 8939, 8938, 8936 }, "Regrowth"),
    Swiftmend = define("Swiftmend", 18562, "Swiftmend"),
    Lifebloom = define("Lifebloom", { 48451, 33763 }, "Lifebloom"),
}

local REJUVENATION_BUFF = { 26982, 26981, 25299, 9841, 9840, 9839, 8910, 3627, 2091, 2090, 1430, 1058, 774 }
local REGROWTH_BUFF = { 26980, 9858, 9857, 9856, 9750, 8941, 8940, 8939, 8938, 8936 }
local LIFEBLOOM_BUFF = { 33763 }

local resto_state = {
    hp = 100,
    target_hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    rejuvenation_remains = 0,
    regrowth_remains = 0,
    lifebloom_remains = 0,
}

local function build_state(context)
    local state = spec_kit.safe_state(resto_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.mana_pct = (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.rejuvenation_remains = (target and NS.buff_remains and NS.buff_remains(target, REJUVENATION_BUFF)) or 0
    state.regrowth_remains = (target and NS.buff_remains and NS.buff_remains(target, REGROWTH_BUFF)) or 0
    state.lifebloom_remains = (target and NS.buff_remains and NS.buff_remains(target, LIFEBLOOM_BUFF)) or 0
    return state
end

local DSL_DEFS = {
    {
        name = "WildGrowth",
        conditions = {
            { type = "state", field = "enemy_count", op = ">=", value = 2 },
            { type = "state", field = "mana_pct", op = ">=", value = 25 },
        },
        action = { type = "cast", spell = ACTION.WildGrowth, target = "target" },
    },
    {
        name = "Swiftmend",
        conditions = {
            { type = "state", field = "target_hp", op = "<", value = 50 },
            { type = "custom", fn = function(context, state)
                return (state.rejuvenation_remains or 0) > 0 or (state.regrowth_remains or 0) > 0
            end },
        },
        action = { type = "cast", spell = ACTION.Swiftmend, target = "target" },
    },
    {
        name = "Lifebloom",
        conditions = {
            { type = "state", field = "lifebloom_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.Lifebloom, target = "target" },
    },
    {
        name = "Rejuvenation",
        conditions = {
            { type = "state", field = "rejuvenation_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.Rejuvenation, target = "target" },
    },
    {
        name = "Regrowth",
        conditions = {
            { type = "state", field = "regrowth_remains", op = "<", value = 3 },
            { type = "state", field = "target_hp", op = "<", value = 70 },
            { type = "state", field = "mana_pct", op = ">=", value = 25 },
        },
        action = { type = "cast", spell = ACTION.Regrowth, target = "target" },
    },
}

local strategies = {
    { name = "WildGrowth" },
    { name = "Swiftmend" },
    { name = "Lifebloom" },
    { name = "Rejuvenation" },
    { name = "Regrowth" },
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
    NS.rotation_registry:register("resto", strategies, { get_state = build_state })
end
if NS.log then NS.log("Druid resto rotation registered") end

return { strategies = strategies, build_state = build_state }
