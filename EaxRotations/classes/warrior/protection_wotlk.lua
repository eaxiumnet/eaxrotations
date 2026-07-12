-- protection_wotlk.lua — Warrior Protection rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Protection warrior.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.WarriorSpells or {}
local CONSTANTS = NS.WarriorConstants or {}
local STANCE = CONSTANTS.STANCE or { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 }

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    ShieldSlam = define("ShieldSlam", { 30356, 25258, 23925, 23924, 23923, 23922 }, "ShieldSlam"),
    Revenge = define("Revenge", { 30357, 25269, 25288, 11601, 11600, 7379, 6574, 6572 }, "Revenge"),
    Devastate = define("Devastate", { 30022, 30016, 20243 }, "Devastate"),
    HeroicStrike = define("HeroicStrike", { 47497, 30324, 29707, 25286, 11567, 11566, 11565, 11564, 1608, 285, 284, 78 }, "HeroicStrike"),
    ThunderClap = define("ThunderClap", { 47502, 25264, 11581, 11580, 8205, 8204, 8198, 6343 }, "ThunderClap"),
    ShieldBlock = define("ShieldBlock", 2565, "ShieldBlock"),
}

local THUNDER_CLAP_DEBUFF = { 47502, 25264, 11581, 11580, 8205, 8204, 8198, 6343 }

local protection_state = {
    rage = 0,
    hp = 100,
    target_hp = 100,
    enemy_count = 1,
    in_combat = false,
    tclap_remains = 0,
    shield_block_ready = false,
}

local function build_state(context)
    local state = spec_kit.safe_state(protection_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.rage = (me and me.get_rage and me:get_rage()) or 0
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.tclap_remains = (target and NS.debuff_remains and NS.debuff_remains(target, THUNDER_CLAP_DEBUFF)) or 0
    state.shield_block_ready = (ACTION.ShieldBlock and ACTION.ShieldBlock.cooldown_remaining and ACTION.ShieldBlock:cooldown_remaining() <= 0) or false
    return state
end

local function shield_block_matches(context, state)
    return state.shield_block_ready
end

local function shield_slam_matches(context, state)
    return state.rage >= 20
end

local function revenge_matches(context, state)
    return state.rage >= 5
end

local function thunder_clap_matches(context, state)
    return state.tclap_remains < 3 and state.rage >= 20
end

local function devastate_matches(context, state)
    return state.rage >= 15
end

local function heroic_strike_matches(context, state)
    return state.rage >= 60
end

local strategies = {
    { name = "ShieldBlock", matches = shield_block_matches, execute = function(ctx) return ACTION.ShieldBlock and ACTION.ShieldBlock:cast_safe() end },
    { name = "ShieldSlam", matches = shield_slam_matches, execute = function(ctx) return ACTION.ShieldSlam and ACTION.ShieldSlam:cast_safe(ctx.target) end },
    { name = "Revenge", matches = revenge_matches, execute = function(ctx) return ACTION.Revenge and ACTION.Revenge:cast_safe(ctx.target) end },
    { name = "ThunderClap", matches = thunder_clap_matches, execute = function(ctx) return ACTION.ThunderClap and ACTION.ThunderClap:cast_safe(ctx.target) end },
    { name = "Devastate", matches = devastate_matches, execute = function(ctx) return ACTION.Devastate and ACTION.Devastate:cast_safe(ctx.target) end },
    { name = "HeroicStrike", matches = heroic_strike_matches, execute = function(ctx) return ACTION.HeroicStrike and ACTION.HeroicStrike:cast_safe(ctx.target) end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("protection", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state }
