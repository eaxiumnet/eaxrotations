-- leveling_wotlk.lua — Druid leveling rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for druid leveling in WotLK (caster + feral fallback).
-- WHEN:  combat with valid enemy target.
-- WHY:   simple DoT/caster rotation with emergency heals and feral finishers.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
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

local function mark_of_the_wild_matches(context, state)
    return not state.in_combat and (NS.buff_up and not NS.buff_up(NS.me, MARK_OF_THE_WILD_BUFF))
end

local function thorns_matches(context, state)
    return not state.in_combat and (NS.buff_up and not NS.buff_up(NS.me, THORNS_BUFF))
end

local function rejuvenation_matches(context, state)
    return state.in_combat and state.hp < 50 and state.mana_pct >= 20
end

local function healing_touch_matches(context, state)
    return state.in_combat and state.hp < 30 and state.mana_pct >= 25
end

-- Feral shifting is opt-in (caster is the default leveling playstyle). When the
-- bear setting is on it wins over cat; once shifted, the existing form-gated
-- strategies (Mangle/Rake/Shred vs Lacerate/Swipe) take over.
local function shift_bear_matches(context, state)
    if not spec_kit.setting_bool(context, "druid_leveling_bear", false) then return false end
    return state.in_combat and state.form ~= "bear"
end

local function shift_cat_matches(context, state)
    if spec_kit.setting_bool(context, "druid_leveling_bear", false) then return false end
    if not spec_kit.setting_bool(context, "druid_leveling_feral", false) then return false end
    return state.in_combat and state.form ~= "cat"
end

local function entangling_roots_matches(context, state)
    return state.in_combat and state.hp < 40 and state.enemy_count >= 2 and state.mana_pct >= 15
end

local function moonfire_matches(context, state)
    return state.in_combat and state.moonfire_remains < 3 and state.mana_pct >= 15
end

local function insect_swarm_matches(context, state)
    return state.in_combat and state.mana_pct >= 15
end

local function faerie_fire_matches(context, state)
    return state.in_combat and state.mana_pct >= 10
end

local function starfire_matches(context, state)
    return state.in_combat and state.mana_pct >= 15
end

local function wrath_matches(context, state)
    return state.in_combat and state.mana_pct >= 10
end

local function rake_matches(context, state)
    return state.in_combat and state.form == "cat" and state.rake_remains < 3
end

local function rip_matches(context, state)
    return state.in_combat and state.form == "cat" and state.combo_points >= 4 and state.rip_remains < 3
end

local function ferocious_bite_matches(context, state)
    return state.in_combat and state.form == "cat" and state.combo_points >= 4
end

local function shred_matches(context, state)
    return state.in_combat and state.form == "cat" and state.combo_points < 5
end

local function claw_matches(context, state)
    return state.in_combat and state.form == "cat" and state.combo_points < 5
end

local function mangle_cat_matches(context, state)
    return state.in_combat and state.form == "cat" and state.combo_points < 5
end

local function mangle_bear_matches(context, state)
    return state.in_combat and state.form == "bear"
end

local function swipe_matches(context, state)
    return state.in_combat and state.form == "bear" and state.enemy_count >= 2
end

local function lacerate_matches(context, state)
    return state.in_combat and state.form == "bear"
end

local strategies = {
    { name = "MarkOfTheWild", matches = mark_of_the_wild_matches, execute = function(ctx) return ACTION.MarkOfTheWild and ACTION.MarkOfTheWild:cast_safe() end },
    { name = "Thorns", matches = thorns_matches, execute = function(ctx) return ACTION.Thorns and ACTION.Thorns:cast_safe() end },
    { name = "Rejuvenation", matches = rejuvenation_matches, execute = function(ctx) return ACTION.Rejuvenation and ACTION.Rejuvenation:cast_safe() end },
    { name = "HealingTouch", matches = healing_touch_matches, execute = function(ctx) return ACTION.HealingTouch and ACTION.HealingTouch:cast_safe() end },
    { name = "DireBearForm", matches = shift_bear_matches, execute = function(ctx) return ACTION.DireBearForm and ACTION.DireBearForm:cast_safe() end },
    { name = "CatForm", matches = shift_cat_matches, execute = function(ctx) return ACTION.CatForm and ACTION.CatForm:cast_safe() end },
    { name = "EntanglingRoots", matches = entangling_roots_matches, execute = function(ctx) return ACTION.EntanglingRoots and ACTION.EntanglingRoots:cast_safe(ctx.target) end },
    { name = "Rip", matches = rip_matches, execute = function(ctx) return ACTION.Rip and ACTION.Rip:cast_safe(ctx.target) end },
    { name = "FerociousBite", matches = ferocious_bite_matches, execute = function(ctx) return ACTION.FerociousBite and ACTION.FerociousBite:cast_safe(ctx.target) end },
    { name = "Rake", matches = rake_matches, execute = function(ctx) return ACTION.Rake and ACTION.Rake:cast_safe(ctx.target) end },
    { name = "MangleCat", matches = mangle_cat_matches, execute = function(ctx) return ACTION.MangleCat and ACTION.MangleCat:cast_safe(ctx.target) end },
    { name = "Shred", matches = shred_matches, execute = function(ctx) return ACTION.Shred and ACTION.Shred:cast_safe(ctx.target) end },
    { name = "Claw", matches = claw_matches, execute = function(ctx) return ACTION.Claw and ACTION.Claw:cast_safe(ctx.target) end },
    { name = "Swipe", matches = swipe_matches, execute = function(ctx) return ACTION.Swipe and ACTION.Swipe:cast_safe(ctx.target) end },
    { name = "Lacerate", matches = lacerate_matches, execute = function(ctx) return ACTION.Lacerate and ACTION.Lacerate:cast_safe(ctx.target) end },
    { name = "MangleBear", matches = mangle_bear_matches, execute = function(ctx) return ACTION.MangleBear and ACTION.MangleBear:cast_safe(ctx.target) end },
    { name = "Moonfire", matches = moonfire_matches, execute = function(ctx) return ACTION.Moonfire and ACTION.Moonfire:cast_safe(ctx.target) end },
    { name = "InsectSwarm", matches = insect_swarm_matches, execute = function(ctx) return ACTION.InsectSwarm and ACTION.InsectSwarm:cast_safe(ctx.target) end },
    { name = "FaerieFire", matches = faerie_fire_matches, execute = function(ctx) return ACTION.FaerieFire and ACTION.FaerieFire:cast_safe(ctx.target) end },
    { name = "Starfire", matches = starfire_matches, execute = function(ctx) return ACTION.Starfire and ACTION.Starfire:cast_safe(ctx.target) end },
    { name = "Wrath", matches = wrath_matches, execute = function(ctx) return ACTION.Wrath and ACTION.Wrath:cast_safe(ctx.target) end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("leveling", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state }
