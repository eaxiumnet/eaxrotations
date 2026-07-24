-- leveling_wotlk.lua — Druid leveling rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for druid leveling in WotLK (caster + feral fallback).
-- WHEN:  combat with valid enemy target.
-- WHY:   simple DoT/caster rotation with emergency heals and feral finishers.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); declarative DSL strategies; no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl      = require("shared/strategy_dsl_sylvanas")
local SPELLS = NS.DruidSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    Moonfire = define("Moonfire", { 48463, 26988, 26987, 9835, 9834, 9833, 8929, 8928, 8927, 8926, 8925, 8924, 8921 }, "Moonfire"),
    Wrath = define("Wrath", { 48461, 26985, 26984, 9912, 8905, 6780, 5180, 5179, 5178, 5177, 5176 }, "Wrath"),
    Starfire = define("Starfire", { 48465, 26986, 25298, 9876, 9875, 8951, 8950, 8949, 2912 }, "Starfire"),
    InsectSwarm = define("InsectSwarm", { 27013, 24977, 24976, 24975, 24974, 5570 }, "InsectSwarm"),
    EntanglingRoots = define("EntanglingRoots", { 26989, 9853, 9852, 5196, 5195, 1062, 339 }, "EntanglingRoots"),
    Regrowth = define("Regrowth", { 26980, 9858, 9857, 9856, 9750, 8941, 8940, 8939, 8938, 8936 }, "Regrowth"),
    Rejuvenation = define("Rejuvenation", { 48441, 26982, 26981, 25299, 9841, 9840, 9839, 8910, 3627, 2091, 2090, 1430, 1058, 774 }, "Rejuvenation"),
    HealingTouch = define("HealingTouch", { 26979, 26978, 25297, 9889, 9888, 9758, 8903, 6778, 5189, 5188, 5187, 5186, 5185 }, "HealingTouch"),
    MarkOfTheWild = define("MarkOfTheWild", { 26990, 9885, 9884, 8907, 5234, 6756, 5232, 1126 }, "MarkOfTheWild"),
    Thorns = define("Thorns", { 26992, 9910, 9756, 8914, 1075, 782, 467 }, "Thorns"),
    FaerieFire = define("FaerieFire", { 26993, 9907, 9749, 778, 770 }, "FaerieFire"),
    MangleCat = define("MangleCat", { 33983, 33982, 33876 }, "MangleCat"),
    Rake = define("Rake", { 27003, 9904, 1824, 1823, 1822 }, "Rake"),
    Rip = define("Rip", { 27008, 9896, 9894, 9752, 9493, 9492, 1079 }, "Rip"),
    FerociousBite = define("FerociousBite", { 24248, 31018, 22829, 22828, 22827, 22568 }, "FerociousBite"),
    Claw = define("Claw", { 27000, 9850, 9849, 5201, 3029, 1082 }, "Claw"),
    Shred = define("Shred", { 27002, 27001, 9830, 9829, 8992, 6800, 5221 }, "Shred"),
    MangleBear = define("MangleBear", { 33987, 33986, 33878 }, "MangleBear"),
    Swipe = define("SwipeBear", { 26997, 9908, 9754, 769, 780, 779 }, "SwipeBear"),
    Lacerate = define("Lacerate", { 33745 }, "Lacerate"),
    -- Feral form shifting (verified in client DBC: Cat 768, Dire Bear 9634).
    CatForm = define("CatForm", { 768 }, "CatForm"),
    DireBearForm = define("DireBearForm", { 9634, 5487 }, "DireBearForm"),
}

local MOONFIRE_DEBUFF = { 48463, 26988, 26987, 9835, 9834, 9833, 8929, 8928, 8927, 8926, 8925, 8924, 8921 }
local RAKE_DEBUFF = { 27003, 9904, 1824, 1823, 1822 }
local RIP_DEBUFF = { 27008, 9896, 9894, 9752, 9493, 9492, 1079 }
local MARK_OF_THE_WILD_BUFF = { 26990, 9885, 9884, 8907, 5234, 6756, 5232, 1126, 21850, 21849 }
local THORNS_BUFF = { 26992, 9910, 9756, 8914, 1075, 782, 467 }

local druid_state = {
    hp = 100,
    target_hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    moonfire_remains = 0,
    rake_remains = 0,
    rip_remains = 0,
    combo_points = 0,
    form = "caster",
}

local function build_state(context)
    local state = spec_kit.safe_state(druid_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.mana_pct = (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and (context.enemies_count or context.enemy_count)) or 1
    state.in_combat = (context and context.in_combat) or false
    state.moonfire_remains = (target and NS.debuff_remains and NS.debuff_remains(target, MOONFIRE_DEBUFF)) or 0
    state.rake_remains = (target and NS.debuff_remains and NS.debuff_remains(target, RAKE_DEBUFF)) or 0
    state.rip_remains = (target and NS.debuff_remains and NS.debuff_remains(target, RIP_DEBUFF)) or 0
    state.combo_points = (context and context.combo_points) or (me and me.get_combo_points and me:get_combo_points()) or 0
    if context and context.form then
        state.form = context.form
    elseif NS.has_form then
        local ok, form = pcall(NS.has_form, "cat")
        if ok and form then
            state.form = "cat"
        else
            ok, form = pcall(NS.has_form, "bear")
            if ok and form then
                state.form = "bear"
            else
                state.form = "caster"
            end
        end
    else
        state.form = "caster"
    end
    return state
end

local DSL_DEFS = {
    {
        name = "MarkOfTheWild",
        conditions = {
            { type = "state", field = "in_combat", op = "falsy" },
            { type = "custom", fn = function(context, state)
                if not NS.buff_up then return false end
                return (not NS.buff_up(NS.me, MARK_OF_THE_WILD_BUFF)) and true or false
            end },
        },
        action = { type = "cast", spell = ACTION.MarkOfTheWild, target = "self" },
    },
    {
        name = "Thorns",
        conditions = {
            { type = "state", field = "in_combat", op = "falsy" },
            { type = "custom", fn = function(context, state)
                if not NS.buff_up then return false end
                return (not NS.buff_up(NS.me, THORNS_BUFF)) and true or false
            end },
        },
        action = { type = "cast", spell = ACTION.Thorns, target = "self" },
    },
    {
        name = "Rejuvenation",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "hp", op = "<", value = 50 },
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
        },
        action = { type = "cast", spell = ACTION.Rejuvenation, target = "self" },
    },
    {
        name = "HealingTouch",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "hp", op = "<", value = 30 },
            { type = "state", field = "mana_pct", op = ">=", value = 25 },
        },
        action = { type = "cast", spell = ACTION.HealingTouch, target = "self" },
    },
    -- Feral shifting is opt-in (caster is the default leveling playstyle). When the
    -- bear setting is on it wins over cat; once shifted, the existing form-gated
    -- strategies (Mangle/Rake/Shred vs Lacerate/Swipe) take over.
    {
        name = "DireBearForm",
        conditions = {
            { type = "custom", fn = function(context, state) return spec_kit.setting_bool(context, "druid_leveling_bear", false) == true end },
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "form", op = "!=", value = "bear" },
        },
        action = { type = "cast", spell = ACTION.DireBearForm, target = "self" },
    },
    {
        name = "CatForm",
        conditions = {
            { type = "custom", fn = function(context, state) return spec_kit.setting_bool(context, "druid_leveling_bear", false) == false end },
            { type = "custom", fn = function(context, state) return spec_kit.setting_bool(context, "druid_leveling_feral", false) == true end },
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "form", op = "!=", value = "cat" },
        },
        action = { type = "cast", spell = ACTION.CatForm, target = "self" },
    },
    {
        name = "EntanglingRoots",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "hp", op = "<", value = 40 },
            { type = "state", field = "enemy_count", op = ">=", value = 2 },
            { type = "state", field = "mana_pct", op = ">=", value = 15 },
        },
        action = { type = "cast", spell = ACTION.EntanglingRoots, target = "target" },
    },
    {
        name = "Rip",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "form", op = "==", value = "cat" },
            { type = "state", field = "combo_points", op = ">=", value = 4 },
            { type = "state", field = "rip_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.Rip, target = "target" },
    },
    {
        name = "FerociousBite",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "form", op = "==", value = "cat" },
            { type = "state", field = "combo_points", op = ">=", value = 4 },
        },
        action = { type = "cast", spell = ACTION.FerociousBite, target = "target" },
    },
    {
        name = "Rake",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "form", op = "==", value = "cat" },
            { type = "state", field = "rake_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.Rake, target = "target" },
    },
    {
        name = "MangleCat",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "form", op = "==", value = "cat" },
            { type = "state", field = "combo_points", op = "<", value = 5 },
        },
        action = { type = "cast", spell = ACTION.MangleCat, target = "target" },
    },
    {
        name = "Shred",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "form", op = "==", value = "cat" },
            { type = "state", field = "combo_points", op = "<", value = 5 },
        },
        action = { type = "cast", spell = ACTION.Shred, target = "target" },
    },
    {
        name = "Claw",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "form", op = "==", value = "cat" },
            { type = "state", field = "combo_points", op = "<", value = 5 },
        },
        action = { type = "cast", spell = ACTION.Claw, target = "target" },
    },
    {
        name = "Swipe",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "form", op = "==", value = "bear" },
            { type = "state", field = "enemy_count", op = ">=", value = 2 },
        },
        action = { type = "cast", spell = ACTION.Swipe, target = "target" },
    },
    {
        name = "Lacerate",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "form", op = "==", value = "bear" },
        },
        action = { type = "cast", spell = ACTION.Lacerate, target = "target" },
    },
    {
        name = "MangleBear",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "form", op = "==", value = "bear" },
        },
        action = { type = "cast", spell = ACTION.MangleBear, target = "target" },
    },
    {
        name = "Moonfire",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "moonfire_remains", op = "<", value = 3 },
            { type = "state", field = "mana_pct", op = ">=", value = 15 },
        },
        action = { type = "cast", spell = ACTION.Moonfire, target = "target" },
    },
    {
        name = "InsectSwarm",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 15 },
        },
        action = { type = "cast", spell = ACTION.InsectSwarm, target = "target" },
    },
    {
        name = "FaerieFire",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 10 },
        },
        action = { type = "cast", spell = ACTION.FaerieFire, target = "target" },
    },
    {
        name = "Starfire",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 15 },
        },
        action = { type = "cast", spell = ACTION.Starfire, target = "target" },
    },
    {
        name = "Wrath",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 10 },
        },
        action = { type = "cast", spell = ACTION.Wrath, target = "target" },
    },
}

-- Priority order (compiled in place from DSL_DEFS below).
local strategies = {
    { name = "MarkOfTheWild" },
    { name = "Thorns" },
    { name = "Rejuvenation" },
    { name = "HealingTouch" },
    { name = "DireBearForm" },
    { name = "CatForm" },
    { name = "EntanglingRoots" },
    { name = "Rip" },
    { name = "FerociousBite" },
    { name = "Rake" },
    { name = "MangleCat" },
    { name = "Shred" },
    { name = "Claw" },
    { name = "Swipe" },
    { name = "Lacerate" },
    { name = "MangleBear" },
    { name = "Moonfire" },
    { name = "InsectSwarm" },
    { name = "FaerieFire" },
    { name = "Starfire" },
    { name = "Wrath" },
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

if NS.log then NS.log("Druid leveling rotation registered") end

return { strategies = strategies, build_state = build_state }
