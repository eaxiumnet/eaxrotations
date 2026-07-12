-- resto_wotlk.lua — Druid Restoration rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Restoration druid.
-- WHEN:  combat with valid friendly target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.DruidSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    Rejuvenation = define("Rejuvenation", { 26982, 26981, 25299, 9841, 9840, 9839, 8910, 3627, 2091, 2090, 1430, 1058, 774 }, "Rejuvenation"),
    WildGrowth = define("WildGrowth", 48438, "WildGrowth"),
    Regrowth = define("Regrowth", { 26980, 9858, 9857, 9856, 9750, 8941, 8940, 8939, 8938, 8936 }, "Regrowth"),
    Swiftmend = define("Swiftmend", 18562, "Swiftmend"),
    Lifebloom = define("Lifebloom", 33763, "Lifebloom"),
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

local function wild_growth_matches(context, state)
    return state.enemy_count >= 2 and state.mana_pct >= 25
end

local function swiftmend_matches(context, state)
    return (state.rejuvenation_remains > 0 or state.regrowth_remains > 0) and state.target_hp < 50
end

local function lifebloom_matches(context, state)
    return state.lifebloom_remains < 3
end

local function rejuvenation_matches(context, state)
    return state.rejuvenation_remains < 3
end

local function regrowth_matches(context, state)
    return state.regrowth_remains < 3 and state.target_hp < 70 and state.mana_pct >= 25
end

local strategies = {
    { name = "WildGrowth", matches = wild_growth_matches, execute = function(ctx) return ACTION.WildGrowth and ACTION.WildGrowth:cast_safe(ctx.target) end },
    { name = "Swiftmend", matches = swiftmend_matches, execute = function(ctx) return ACTION.Swiftmend and ACTION.Swiftmend:cast_safe(ctx.target) end },
    { name = "Lifebloom", matches = lifebloom_matches, execute = function(ctx) return ACTION.Lifebloom and ACTION.Lifebloom:cast_safe(ctx.target) end },
    { name = "Rejuvenation", matches = rejuvenation_matches, execute = function(ctx) return ACTION.Rejuvenation and ACTION.Rejuvenation:cast_safe(ctx.target) end },
    { name = "Regrowth", matches = regrowth_matches, execute = function(ctx) return ACTION.Regrowth and ACTION.Regrowth:cast_safe(ctx.target) end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("resto", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state }
