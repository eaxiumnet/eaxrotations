-- protection_wotlk.lua — Paladin Protection rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Protection paladin.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.PaladinSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    AvengersShield = define("AvengersShield", 48827, "AvengersShield"),
    HammerOfTheRighteous = define("HammerOfTheRighteous", 53595, "HammerOfTheRighteous"),
    ShieldOfRighteousness = define("ShieldOfRighteousness", 53600, "ShieldOfRighteousness"),
    Consecration = define("Consecration", { 48819, 27173, 20924, 20923, 20922, 20116, 26573 }, "Consecration"),
    Judgement = define("Judgement", { 20271, 53407, 53408 }, "Judgement"),
}

local CONSECRATION_DEBUFF = { 48819, 27173, 20924, 20923, 20922, 20116, 26573 }

local protection_state = {
    hp = 100,
    target_hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    consecration_remains = 0,
}

local function build_state(context)
    local state = spec_kit.safe_state(protection_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.mana_pct = (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.consecration_remains = (target and NS.debuff_remains and NS.debuff_remains(target, CONSECRATION_DEBUFF)) or 0
    return state
end

local function avengers_shield_matches(context, state)
    return true
end

local function hammer_of_the_righteous_matches(context, state)
    return true
end

local function shield_of_righteousness_matches(context, state)
    return true
end

local function consecration_matches(context, state)
    return state.consecration_remains < 3 and state.mana_pct >= 25
end

local function judgement_matches(context, state)
    return true
end

local strategies = {
    { name = "AvengersShield", matches = avengers_shield_matches, execute = function(ctx) return ACTION.AvengersShield and ACTION.AvengersShield:cast_safe(ctx.target) end },
    { name = "HammerOfTheRighteous", matches = hammer_of_the_righteous_matches, execute = function(ctx) return ACTION.HammerOfTheRighteous and ACTION.HammerOfTheRighteous:cast_safe(ctx.target) end },
    { name = "ShieldOfRighteousness", matches = shield_of_righteousness_matches, execute = function(ctx) return ACTION.ShieldOfRighteousness and ACTION.ShieldOfRighteousness:cast_safe(ctx.target) end },
    { name = "Consecration", matches = consecration_matches, execute = function(ctx) return ACTION.Consecration and ACTION.Consecration:cast_safe(ctx.target) end },
    { name = "Judgement", matches = judgement_matches, execute = function(ctx) return ACTION.Judgement and ACTION.Judgement:cast_safe(ctx.target) end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("protection", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state }
