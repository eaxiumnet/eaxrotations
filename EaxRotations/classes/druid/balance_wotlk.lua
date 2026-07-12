-- balance_wotlk.lua — Druid Balance rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Balance druid.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.DruidSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    MoonkinForm = define("MoonkinForm", 24858, "MoonkinForm"),
    InsectSwarm = define("InsectSwarm", { 27013, 24977, 24976, 24975, 24974, 5570 }, "InsectSwarm"),
    Moonfire = define("Moonfire", { 26988, 26987, 9835, 9834, 9833, 8929, 8928, 8927, 8926, 8925, 8924, 8921 }, "Moonfire"),
    Starfall = define("Starfall", 48505, "Starfall"),
    Wrath = define("Wrath", { 26985, 26984, 9912, 8905, 6780, 5180, 5179, 5178, 5177, 5176 }, "Wrath"),
    Starfire = define("Starfire", { 26986, 25298, 9876, 9875, 8951, 8950, 8949, 2912 }, "Starfire"),
}

local MOONKIN_FORM_BUFF = { 24858 }
local INSECT_SWARM_DEBUFF = { 27013, 24977, 24976, 24975, 24974, 5570 }
local MOONFIRE_DEBUFF = { 26988, 26987, 9835, 9834, 9833, 8929, 8928, 8927, 8926, 8925, 8924, 8921 }

local balance_state = {
    hp = 100,
    target_hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    moonkin_up = false,
    insect_swarm_remains = 0,
    moonfire_remains = 0,
    eclipse_proc = false,
}

local function build_state(context)
    local state = spec_kit.safe_state(balance_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.mana_pct = (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.moonkin_up = (me and NS.buff_up and NS.buff_up(me, MOONKIN_FORM_BUFF)) or false
    state.insect_swarm_remains = (target and NS.debuff_remains and NS.debuff_remains(target, INSECT_SWARM_DEBUFF)) or 0
    state.moonfire_remains = (target and NS.debuff_remains and NS.debuff_remains(target, MOONFIRE_DEBUFF)) or 0
    state.eclipse_proc = (me and NS.buff_up and (NS.buff_up(me, { 48517 }) or NS.buff_up(me, { 48518 }))) or false
    return state
end

local function moonkin_form_matches(context, state)
    return not state.moonkin_up
end

local function insect_swarm_matches(context, state)
    return state.insect_swarm_remains < 3
end

local function moonfire_matches(context, state)
    return state.moonfire_remains < 3
end

local function starfall_matches(context, state)
    return state.enemy_count >= 2
end

local function wrath_matches(context, state)
    return state.mana_pct >= 15
end

local function starfire_matches(context, state)
    return state.mana_pct >= 15
end

local strategies = {
    { name = "MoonkinForm", matches = moonkin_form_matches, execute = function(ctx) return ACTION.MoonkinForm and ACTION.MoonkinForm:cast_safe() end },
    { name = "Starfall", matches = starfall_matches, execute = function(ctx) return ACTION.Starfall and ACTION.Starfall:cast_safe(ctx.target) end },
    { name = "InsectSwarm", matches = insect_swarm_matches, execute = function(ctx) return ACTION.InsectSwarm and ACTION.InsectSwarm:cast_safe(ctx.target) end },
    { name = "Moonfire", matches = moonfire_matches, execute = function(ctx) return ACTION.Moonfire and ACTION.Moonfire:cast_safe(ctx.target) end },
    { name = "Wrath", matches = wrath_matches, execute = function(ctx) return ACTION.Wrath and ACTION.Wrath:cast_safe(ctx.target) end },
    { name = "Starfire", matches = starfire_matches, execute = function(ctx) return ACTION.Starfire and ACTION.Starfire:cast_safe(ctx.target) end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("balance", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state }
