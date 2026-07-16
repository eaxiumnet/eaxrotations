-- leveling_wotlk.lua — Paladin leveling rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for paladin leveling in WotLK.
-- WHEN:  combat with valid enemy target.
-- WHY:   simple seal/judgement rotation for leveling.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

-- Hit-volume AoE gates (install if core not loaded, e.g. unit tests)
do
    local _ok_aoe, AoeHV = pcall(require, "shared/aoe_hit_volume_sylvanas")
    if _ok_aoe and AoeHV and AoeHV.install then AoeHV.install(NS) end
end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.PaladinSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    SealOfCommand = define("SealOfCommand", { 27170, 20920, 20919, 20918, 20915, 20375 }, "SealOfCommand"),
    SealOfVengeance = define("SealOfVengeance", 31801, "SealOfVengeance"),
    SealOfRighteousness = define("SealOfRighteousness", 21084, "SealOfRighteousness"),
    BlessingOfMight = define("BlessingOfMight", { 48932, 48931, 27140, 25291, 19838, 19837, 19836, 19835, 19834, 19740 }, "BlessingOfMight"),
    DevotionAura = define("DevotionAura", { 48942, 48941, 27149, 10293, 10292, 10291, 10290, 643, 465 }, "DevotionAura"),
    Judgement = define("Judgement", { 20271, 53407, 53408 }, "Judgement"),
    CrusaderStrike = define("CrusaderStrike", 35395, "CrusaderStrike"),
    DivineStorm = define("DivineStorm", 53385, "DivineStorm"),
    Consecration = define("Consecration", { 48819, 27173, 20924, 20923, 20922, 20116, 26573 }, "Consecration"),
    HammerOfWrath = define("HammerOfWrath", { 48807, 27180, 24239, 24274, 24275 }, "HammerOfWrath"),
}

local SEAL_OF_COMMAND_BUFF = { 27170, 20920, 20919, 20918, 20915, 20375 }
local SEAL_OF_VENGEANCE_BUFF = { 31801 }
local SEAL_OF_RIGHTEOUSNESS_BUFF = { 21084 }
local BLESSING_OF_MIGHT_BUFF = { 48932, 48931, 27140, 25291, 19838, 19837, 19836, 19835, 19834, 19740 }
local DEVOTION_AURA_BUFF = { 48942, 48941, 27149, 10293, 10292, 10291, 10290, 643, 465 }

local paladin_state = {
    hp = 100,
    target_hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    seal_up = false,
    might_up = false,
    aura_up = false,
}

local function build_state(context)
    local state = spec_kit.safe_state(paladin_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.mana_pct = (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and (context.enemies_count or context.enemy_count)) or 1
    state.in_combat = (context and context.in_combat) or false
    state.seal_up = (me and NS.buff_up and (NS.buff_up(me, SEAL_OF_COMMAND_BUFF) or NS.buff_up(me, SEAL_OF_VENGEANCE_BUFF) or NS.buff_up(me, SEAL_OF_RIGHTEOUSNESS_BUFF))) or false
    state.might_up = (me and NS.buff_up and NS.buff_up(me, BLESSING_OF_MIGHT_BUFF)) or false
    state.aura_up = (me and NS.buff_up and NS.buff_up(me, DEVOTION_AURA_BUFF)) or false
    return state
end

local function seal_matches(context, state)
    -- Keep a seal up in and out of combat. Seal of Righteousness (rank 1, level 3)
    -- covers the 1-19 dead zone before Seal of Command/Vengeance are learnable.
    return not state.seal_up and state.mana_pct >= 5
end

local function blessing_of_might_matches(context, state)
    return not state.in_combat and not state.might_up and state.mana_pct >= 5
end

local function devotion_aura_matches(context, state)
    return not state.in_combat and not state.aura_up
end

local function judgement_matches(context, state)
    return state.in_combat and state.mana_pct >= 10
end

local function crusader_strike_matches(context, state)
    return state.in_combat and state.mana_pct >= 10
end

local function divine_storm_matches(context, state)
    return state.in_combat and state.mana_pct >= 20
        and NS.aoe_self_meets and NS.aoe_self_meets(2, (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_8) or 8, context, state)
end

local function consecration_matches(context, state)
    return state.in_combat and state.mana_pct >= 25
        and NS.aoe_self_meets and NS.aoe_self_meets(2, (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_8) or 8, context, state)
end

local function hammer_of_wrath_matches(context, state)
    return state.in_combat and state.target_hp < 20 and state.mana_pct >= 10
end

local strategies = {
    { name = "Seal", matches = seal_matches, execute = function(ctx) return (ACTION.SealOfVengeance and ACTION.SealOfVengeance:cast_safe()) or (ACTION.SealOfCommand and ACTION.SealOfCommand:cast_safe()) or (ACTION.SealOfRighteousness and ACTION.SealOfRighteousness:cast_safe()) end },
    { name = "BlessingOfMight", matches = blessing_of_might_matches, execute = function(ctx) return ACTION.BlessingOfMight and ACTION.BlessingOfMight:cast_safe() end },
    { name = "DevotionAura", matches = devotion_aura_matches, execute = function(ctx) return ACTION.DevotionAura and ACTION.DevotionAura:cast_safe() end },
    { name = "Judgement", matches = judgement_matches, execute = function(ctx) return ACTION.Judgement and ACTION.Judgement:cast_safe(ctx.target) end },
    { name = "HammerOfWrath", matches = hammer_of_wrath_matches, execute = function(ctx) return ACTION.HammerOfWrath and ACTION.HammerOfWrath:cast_safe(ctx.target) end },
    { name = "DivineStorm", matches = divine_storm_matches, execute = function(ctx) return ACTION.DivineStorm and ACTION.DivineStorm:cast_safe(ctx.target) end },
    { name = "Consecration", matches = consecration_matches, execute = function(ctx) return ACTION.Consecration and ACTION.Consecration:cast_safe(ctx.target) end },
    { name = "CrusaderStrike", matches = crusader_strike_matches, execute = function(ctx) return ACTION.CrusaderStrike and ACTION.CrusaderStrike:cast_safe(ctx.target) end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("leveling", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state }
