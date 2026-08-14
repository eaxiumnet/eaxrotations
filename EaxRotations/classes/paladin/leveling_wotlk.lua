-- leveling_wotlk.lua — Paladin leveling rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for paladin leveling: seal upkeep (SoV → SoC →
--          SoR full rank ladder), Blessing of Might / Devotion Aura OOC upkeep,
--          Judgement, Hammer of Wrath execute, Divine Storm / Consecration AoE,
--          Crusader Strike.
-- WHEN:  combat with valid enemy target.
-- WHY:   simple seal/judgement rotation for leveling; the SoR action ladder
--         { 25742, 21084 } + matching buff list close the low-level never-zone
--         (21084 = rank 1, learnable at level 1) and the 60+ buff-mismatch
--         (25742 = the rank a 60+ cast applies).
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); declarative DSL strategies; no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

-- Hit-volume AoE gates (install if core not loaded, e.g. unit tests)
do
    local _ok_aoe, AoeHV = pcall(require, "shared/aoe_hit_volume_sylvanas")
    if _ok_aoe and AoeHV and AoeHV.install then AoeHV.install(NS) end
end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl      = require("shared/strategy_dsl_sylvanas")

-- Plain define_action (NOT define_action_for_class): the WotLK client loads the
-- TBC class_sylvanas.lua into NS.<Class>Spells, so the class-first resolver would
-- shadow these WotLK rank ladders with TBC-era rank lists.
local define = spec_kit.define_action

local ACTION = {
    SealOfCommand = define("SealOfCommand", { 27170, 20920, 20919, 20918, 20915, 20375 }, "SealOfCommand"),
    SealOfVengeance = define("SealOfVengeance", 31801, "SealOfVengeance"),
    -- Full SoR ladder: 25742 (60+ cast applies this buff) + 21084 (rank 1,
    -- learnable at level 1). First-known-wins resolution picks the right rank.
    SealOfRighteousness = define("SealOfRighteousness", { 25742, 21084 }, "SealOfRighteousness"),
    BlessingOfMight = define("BlessingOfMight", { 48932, 48931, 27140, 25291, 19838, 19837, 19836, 19835, 19834, 19740 }, "BlessingOfMight"),
    DevotionAura = define("DevotionAura", { 48942, 48941, 27149, 10293, 10292, 10291, 10290, 643, 465 }, "DevotionAura"),
    Judgement = define("Judgement", { 20271, 53407, 53408 }, "Judgement"),
    CrusaderStrike = define("CrusaderStrike", 35395, "CrusaderStrike"),
    DivineStorm = define("DivineStorm", 53385, "DivineStorm"),
    Consecration = define("Consecration", { 48819, 27173, 20924, 20923, 20922, 20116, 26573 }, "Consecration"),
    HammerOfWrath = define("HammerOfWrath", { 48806, 27180, 24239, 24274, 24275 }, "HammerOfWrath"),
}

local SEAL_OF_COMMAND_BUFF = { 27170, 20920, 20919, 20918, 20915, 20375 }
local SEAL_OF_VENGEANCE_BUFF = { 31801 }
-- Buff list must mirror the action ladder: a 60+ cast applies 25742, a low-level
-- cast applies 21084 — checking only one id leaves the seal perpetually "down".
local SEAL_OF_RIGHTEOUSNESS_BUFF = { 25742, 21084 }
local BLESSING_OF_MIGHT_BUFF = { 48932, 48931, 27140, 25291, 19838, 19837, 19836, 19835, 19834, 19740 }
local DEVOTION_AURA_BUFF = { 48942, 48941, 27149, 10293, 10292, 10291, 10290, 643, 465 }

local paladin_state = {
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
    -- context.mana_pct is dispatcher-set (main_sylvanas.lua:795); me:mana_pct()
    -- is the IZI SDK unit method. me:get_mana_percentage() is mock-only (W3.4).
    state.mana_pct = (context and context.mana_pct)
        or (me and me.mana_pct and me:mana_pct())
        or (NS.unit_mana_pct and NS.unit_mana_pct(me))
        or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and (context.enemies_count or context.enemy_count)) or 1
    state.in_combat = (context and context.in_combat) or false
    state.seal_up = (me and NS.buff_up and (NS.buff_up(me, SEAL_OF_COMMAND_BUFF) or NS.buff_up(me, SEAL_OF_VENGEANCE_BUFF) or NS.buff_up(me, SEAL_OF_RIGHTEOUSNESS_BUFF))) or false
    state.might_up = (me and NS.buff_up and NS.buff_up(me, BLESSING_OF_MIGHT_BUFF)) or false
    state.aura_up = (me and NS.buff_up and NS.buff_up(me, DEVOTION_AURA_BUFF)) or false
    return state
end

local DSL_DEFS = {
    -- Keep a seal up in and out of combat. The SoR ladder { 25742, 21084 }
    -- covers the 1-19 dead zone (21084 = rank 1, learnable at level 1) through
    -- 60+ (25742), and SEAL_OF_RIGHTEOUSNESS_BUFF mirrors both ids so the seal
    -- registers as up after EITHER rank is cast.
    {
        name = "Seal",
        conditions = {
            { type = "state", field = "seal_up", op = "falsy" },
            { type = "state", field = "mana_pct", op = ">=", value = 5 },
        },
        action = { type = "custom", fn = function(context, state)
            if NS.try_cast(ACTION.SealOfVengeance, nil, "SealOfVengeance") == true then return true end
            if NS.try_cast(ACTION.SealOfCommand, nil, "SealOfCommand") == true then return true end
            return NS.try_cast(ACTION.SealOfRighteousness, nil, "SealOfRighteousness") == true
        end },
    },
    {
        name = "BlessingOfMight",
        conditions = {
            { type = "state", field = "in_combat", op = "falsy" },
            { type = "state", field = "might_up", op = "falsy" },
            { type = "state", field = "mana_pct", op = ">=", value = 5 },
        },
        action = { type = "cast", spell = ACTION.BlessingOfMight, target = "self" },
    },
    {
        name = "DevotionAura",
        conditions = {
            { type = "state", field = "in_combat", op = "falsy" },
            { type = "state", field = "aura_up", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.DevotionAura, target = "self" },
    },
    {
        name = "Judgement",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 10 },
        },
        action = { type = "cast", spell = ACTION.Judgement, target = "target" },
    },
    {
        name = "HammerOfWrath",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "target_hp", op = "<", value = 20 },
            { type = "state", field = "mana_pct", op = ">=", value = 10 },
        },
        action = { type = "cast", spell = ACTION.HammerOfWrath, target = "target" },
    },
    {
        name = "DivineStorm",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
            { type = "custom", fn = function(context, state)
                if not NS.aoe_self_meets then return false end
                local radius = (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_8) or 8
                return NS.aoe_self_meets(2, radius, context, state) and true or false
            end },
        },
        action = { type = "cast", spell = ACTION.DivineStorm, target = "target" },
    },
    {
        name = "Consecration",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 25 },
            { type = "custom", fn = function(context, state)
                if not NS.aoe_self_meets then return false end
                local radius = (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_8) or 8
                return NS.aoe_self_meets(2, radius, context, state) and true or false
            end },
        },
        action = { type = "cast", spell = ACTION.Consecration, target = "target" },
    },
    {
        name = "CrusaderStrike",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 10 },
        },
        action = { type = "cast", spell = ACTION.CrusaderStrike, target = "target" },
    },
}

-- Priority order (compiled in place from DSL_DEFS below).
local strategies = {
    { name = "Seal" },
    { name = "BlessingOfMight" },
    { name = "DevotionAura" },
    { name = "Judgement" },
    { name = "HammerOfWrath" },
    { name = "DivineStorm" },
    { name = "Consecration" },
    { name = "CrusaderStrike" },
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
    NS.rotation_registry:register("leveling", strategies, { get_state = build_state })
end

if NS.log then NS.log("Paladin leveling rotation registered") end

return { strategies = strategies, build_state = build_state }
