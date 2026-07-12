-- frost_wotlk.lua — Mage Frost rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Frost mage.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.MageSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    Frostbolt = define("Frostbolt", { 27072, 27071, 25304, 10181, 10180, 10179, 10177, 10176, 10175, 116, 205 }, "Frostbolt"),
    FrostfireBolt = define("FrostfireBolt", 44614, "FrostfireBolt"),
    IceLance = define("IceLance", 30455, "IceLance"),
    DeepFreeze = define("DeepFreeze", 44572, "DeepFreeze"),
    ColdSnap = define("ColdSnap", 12472, "ColdSnap"),
}

local FROSTBOLT_DEBUFF = { 27072, 27071, 25304, 10181, 10180, 10179, 10177, 10176, 10175, 116, 205 }
local FROSTFIRE_BOLT_DEBUFF = { 44614 }
local FROST_NOVA_DEBUFF = { 122, 865, 6131, 10230 }

local frost_state = {
    hp = 100,
    target_hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    frostbolt_remains = 0,
    frostfire_remains = 0,
    target_frozen = false,
}

local function build_state(context)
    local state = spec_kit.safe_state(frost_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.mana_pct = (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.frostbolt_remains = (target and NS.debuff_remains and NS.debuff_remains(target, FROSTBOLT_DEBUFF)) or 0
    state.frostfire_remains = (target and NS.debuff_remains and NS.debuff_remains(target, FROSTFIRE_BOLT_DEBUFF)) or 0
    state.target_frozen = (target and NS.debuff_up and NS.debuff_up(target, FROST_NOVA_DEBUFF)) or false
    return state
end

local function cold_snap_matches(context, state)
    return state.hp < 50
end

local function deep_freeze_matches(context, state)
    return state.target_frozen
end

local function frostfire_bolt_matches(context, state)
    return state.frostfire_remains < 3 and state.mana_pct >= 20
end

local function ice_lance_matches(context, state)
    return state.target_frozen
end

local function frostbolt_matches(context, state)
    return state.mana_pct >= 15
end

local strategies = {
    { name = "ColdSnap", matches = cold_snap_matches, execute = function(ctx) return ACTION.ColdSnap and ACTION.ColdSnap:cast_safe() end },
    { name = "DeepFreeze", matches = deep_freeze_matches, execute = function(ctx) return ACTION.DeepFreeze and ACTION.DeepFreeze:cast_safe(ctx.target) end },
    { name = "FrostfireBolt", matches = frostfire_bolt_matches, execute = function(ctx) return ACTION.FrostfireBolt and ACTION.FrostfireBolt:cast_safe(ctx.target) end },
    { name = "IceLance", matches = ice_lance_matches, execute = function(ctx) return ACTION.IceLance and ACTION.IceLance:cast_safe(ctx.target) end },
    { name = "Frostbolt", matches = frostbolt_matches, execute = function(ctx) return ACTION.Frostbolt and ACTION.Frostbolt:cast_safe(ctx.target) end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("frost", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state }
