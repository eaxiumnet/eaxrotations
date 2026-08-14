-- leveling_wotlk.lua — Druid leveling rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for druid leveling in WotLK (caster + feral fallback).
-- WHEN:  combat with valid enemy target.
-- WHY:   simple DoT/caster rotation with emergency heals and feral finishers.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); declarative DSL strategies; no on_update() allocs.
-- DECISION: mana comes from context.mana_pct / NS.mana_pct(me), combo from
--         context.combo_points (main_sylvanas:795/878) — the mock-only
--         me:get_mana_percentage()/me:get_combo_points() reads made the mana
--         gates inert and CP 0 live (W3.1 audit). Insect Swarm / Faerie Fire
--         gained debuff-remains refresh gates (they were re-cast every GCD,
--         preempting Starfire/Wrath); Rake/Rip debuff tables include the
--         WotLK max ranks (48574/49800); Shred is behind-gated; Rip spends at
--         5 CP; Entangling Roots skips beast/undead targets.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl      = require("shared/strategy_dsl_sylvanas")

-- Plain define_action: file-local WotLK rank lists must win over the
-- TBC-capped DruidSpells class table (precedent: mage/fire_wotlk.lua:20).
local define = spec_kit.define_action

local ACTION = {
    Moonfire = define("Moonfire", { 48463, 26988, 26987, 9835, 9834, 9833, 8929, 8928, 8927, 8926, 8925, 8924, 8921 }, "Moonfire"),
    Wrath = define("Wrath", { 48461, 26985, 26984, 9912, 8905, 6780, 5180, 5179, 5178, 5177, 5176 }, "Wrath"),
    Starfire = define("Starfire", { 48465, 26986, 25298, 9876, 9875, 8951, 8950, 8949, 2912 }, "Starfire"),
    InsectSwarm = define("InsectSwarm", { 48468, 27013, 24977, 24976, 24975, 24974, 5570 }, "InsectSwarm"),
    EntanglingRoots = define("EntanglingRoots", { 26989, 9853, 9852, 5196, 5195, 1062, 339 }, "EntanglingRoots"),
    Regrowth = define("Regrowth", { 48443, 26980, 9858, 9857, 9856, 9750, 8941, 8940, 8939, 8938, 8936 }, "Regrowth"),
    Rejuvenation = define("Rejuvenation", { 48441, 26982, 26981, 25299, 9841, 9840, 9839, 8910, 3627, 2091, 2090, 1430, 1058, 774 }, "Rejuvenation"),
    HealingTouch = define("HealingTouch", { 48378, 26979, 26978, 25297, 9889, 9888, 9758, 8903, 6778, 5189, 5188, 5187, 5186, 5185 }, "HealingTouch"),
    MarkOfTheWild = define("MarkOfTheWild", { 26990, 9885, 9884, 8907, 5234, 6756, 5232, 1126 }, "MarkOfTheWild"),
    Thorns = define("Thorns", { 26992, 9910, 9756, 8914, 1075, 782, 467 }, "Thorns"),
    FaerieFire = define("FaerieFire", { 26993, 9907, 9749, 778, 770 }, "FaerieFire"),
    MangleCat = define("MangleCat", { 48566, 33983, 33982, 33876 }, "MangleCat"),
    Rake = define("Rake", { 48574, 27003, 9904, 1824, 1823, 1822 }, "Rake"),
    Rip = define("Rip", { 49800, 27008, 9896, 9894, 9752, 9493, 9492, 1079 }, "Rip"),
    FerociousBite = define("FerociousBite", { 48576, 24248, 31018, 22829, 22828, 22827, 22568 }, "FerociousBite"),
    Claw = define("Claw", { 48570, 27000, 9850, 9849, 5201, 3029, 1082 }, "Claw"),
    Shred = define("Shred", { 48572, 27002, 27001, 9830, 9829, 8992, 6800, 5221 }, "Shred"),
    MangleBear = define("MangleBear", { 48564, 33987, 33986, 33878 }, "MangleBear"),
    Swipe = define("SwipeBear", { 48562, 26997, 9908, 9754, 769, 780, 779 }, "SwipeBear"),
    Lacerate = define("Lacerate", { 48568, 33745 }, "Lacerate"),
    -- Feral form shifting (verified in client DBC: Cat 768, Dire Bear 9634).
    CatForm = define("CatForm", { 768 }, "CatForm"),
    DireBearForm = define("DireBearForm", { 9634, 5487 }, "DireBearForm"),
}

-- Max-rank-first debuff tables: WotLK DoT auras are the WotLK spell ids
-- (48463 Moonfire / 48468 Insect Swarm / 48574 Rake / 49800 Rip) — the
-- TBC-only tables read 0 at max rank and the refresh gates re-cast every GCD
-- (systemic injection #3; the leveling InsectSwarm/FaerieFire spam was a
-- W3.1 audit must-fix).
local MOONFIRE_DEBUFF = { 48463, 26988, 26987, 9835, 9834, 9833, 8929, 8928, 8927, 8926, 8925, 8924, 8921 }
local INSECT_SWARM_DEBUFF = { 48468, 27013, 24977, 24976, 24975, 24974, 5570 }
local FAERIE_FIRE_DEBUFF = { 26993, 9907, 9749, 778, 770 }
local RAKE_DEBUFF = { 48574, 27003, 9904, 1824, 1823, 1822 }
local RIP_DEBUFF = { 49800, 27008, 9896, 9894, 9752, 9493, 9492, 1079 }
local MARK_OF_THE_WILD_BUFF = { 26990, 9885, 9884, 8907, 5234, 6756, 5232, 1126, 21850, 21849 }
local THORNS_BUFF = { 26992, 9910, 9756, 8914, 1075, 782, 467 }

-- Entangling Roots is broken on beasts (1) and undead (6) targets — cast it
-- on anything else (numeric creature-type convention, see protection DEMON_OR_UNDEAD).
local ROOT_IMMUNE_TYPES = { [1] = true, [6] = true }

local druid_state = {
    hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    moonfire_remains = 0,
    insect_swarm_remains = 0,
    faerie_fire_remains = 0,
    rake_remains = 0,
    rip_remains = 0,
    combo_points = 0,
    is_behind = false,
    form = "caster",
}

local function build_state(context)
    local state = spec_kit.safe_state(druid_state)
    local me = (context and context.me) or NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or (context and context.hp) or 100
    state.mana_pct = (context and context.mana_pct)
        or (NS.mana_pct and me and NS.mana_pct(me))
        or 100
    state.enemy_count = (context and (context.enemies_count or context.enemy_count)) or 1
    state.in_combat = (context and context.in_combat) or false
    state.moonfire_remains = (target and NS.debuff_remains and NS.debuff_remains(target, MOONFIRE_DEBUFF)) or 0
    state.insect_swarm_remains = (target and NS.debuff_remains and NS.debuff_remains(target, INSECT_SWARM_DEBUFF)) or 0
    state.faerie_fire_remains = (target and NS.debuff_remains and NS.debuff_remains(target, FAERIE_FIRE_DEBUFF)) or 0
    state.rake_remains = (target and NS.debuff_remains and NS.debuff_remains(target, RAKE_DEBUFF)) or 0
    state.rip_remains = (target and NS.debuff_remains and NS.debuff_remains(target, RIP_DEBUFF)) or 0
    state.combo_points = (context and context.combo_points)
        or (me and me.get_power and me:get_power(NS.POWER_COMBO))
        or 0
    if context and context.is_behind ~= nil then
        state.is_behind = context.is_behind == true
    elseif NS.is_behind_target and target then
        state.is_behind = NS.is_behind_target(target) == true
    else
        state.is_behind = false
    end
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
                local me = (context and context.me) or NS.me or (NS.GetPlayer and NS.GetPlayer())
                if not me then return false end
                return (not NS.buff_up(me, MARK_OF_THE_WILD_BUFF)) and true or false
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
                local me = (context and context.me) or NS.me or (NS.GetPlayer and NS.GetPlayer())
                if not me then return false end
                return (not NS.buff_up(me, THORNS_BUFF)) and true or false
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
            { type = "custom", fn = function(context, state)
                -- Beasts and undead are immune to Entangling Roots — a failed
                -- cast is a wasted GCD (W3.1 audit nit).
                local target = context and context.target
                if not target or not target.get_creature_type then return true end
                local ok, ct = pcall(target.get_creature_type, target)
                if not ok then return true end
                return ROOT_IMMUNE_TYPES[ct] ~= true
            end },
        },
        action = { type = "cast", spell = ACTION.EntanglingRoots, target = "target" },
    },
    {
        name = "Rip",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "form", op = "==", value = "cat" },
            -- 5-CP spend (W3.1 audit nit: 4 CP produced a weak Rip when a
            -- single extra builder was available).
            { type = "state", field = "combo_points", op = ">=", value = 5 },
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
            -- Shred requires being behind the target; without the gate every
            -- Claw-adjacent GCD was a failed attempt (W3.1 audit nit).
            { type = "state", field = "is_behind", op = "truthy" },
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
            -- Refresh gate (W3.1 audit): without remains tracking InsectSwarm
            -- re-cast every GCD, preempting the Starfire/Wrath fillers.
            { type = "state", field = "insect_swarm_remains", op = "<", value = 3 },
            { type = "state", field = "mana_pct", op = ">=", value = 15 },
        },
        action = { type = "cast", spell = ACTION.InsectSwarm, target = "target" },
    },
    {
        name = "FaerieFire",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            -- Refresh gate (W3.1 audit): same every-GCD re-cast defect.
            { type = "state", field = "faerie_fire_remains", op = "<", value = 3 },
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
