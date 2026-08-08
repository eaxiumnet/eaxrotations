-- caster_vanilla.lua — Druid Caster rotation for Vanilla/Classic Anniversary (1.15.x).
-- WHAT:  caster DPS/heal hybrid (Moonfire, Starfire, Wrath, self-heals, OOC buffs).
-- WHEN:  combat or pre-combat, when NS.is_vanilla() is true.
-- WHY:  expansion-aware loader selects _vanilla suffix for Classic Era.
-- SAFETY: nil-guards via spec_kit.safe_state (Pattern 14); no on_update allocs.

local NS = rawget(_G, "EaxRotations")
if not NS then return nil end
local spec_kit = require("shared/spec_kit_sylvanas")
local leveling_helpers = require("shared/leveling_helpers_sylvanas")
local potion_helper = require("shared/potion_helper_sylvanas")
local SPELLS = NS.DruidSpells or {}
local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    Barkskin       = define("Barkskin",       { 22812 }, "Barkskin"),
    FaerieFire     = define("FaerieFire",     { 9907, 9749, 778, 770 }, "FaerieFire"),
    Innervate      = define("Innervate",      { 29166 }, "Innervate"),
    Moonfire       = define("Moonfire",       { 9835, 9834, 9833, 8929, 8928, 8927, 8926, 8925, 8924, 8921 }, "Moonfire"),
    Starfire       = define("Starfire",       { 9876, 9875, 8951, 8950, 8949, 2912 }, "Starfire"),
    Wrath          = define("Wrath",          { 9912, 8905, 6780, 5180, 5179, 5178, 5177, 5176 }, "Wrath"),
    InsectSwarm    = define("InsectSwarm",    { 24977, 24976, 24975, 24974, 5570 }, "InsectSwarm"),
    HealingTouch   = define("HealingTouch",   { 9889, 9888, 9758, 8903, 6778, 5189, 5188, 5187, 5186, 5185 }, "HealingTouch"),
    Rejuvenation   = define("Rejuvenation",   { 9841, 9840, 9839, 8910, 3627, 2091, 2090, 1430, 1058, 774 }, "Rejuvenation"),
    MarkOfTheWild  = define("MarkOfTheWild",  { 9885, 9884, 8907, 5234, 6756, 5232, 1126 }, "MarkOfTheWild"),
    Thorns         = define("Thorns",         { 9910, 9756, 8914, 1075, 782, 467 }, "Thorns"),
}

local MOONFIRE_DEBUFF = { 9835, 9834, 9833, 8929, 8928, 8927, 8926, 8925, 8924, 8921 }
local FAERIE_FIRE_DEBUFF = { 9907, 9749, 778, 770 }
local INSECT_SWARM_DEBUFF = { 24977, 24976, 24975, 24974, 5570 }
local THORNS_BUFF = { 9910, 9756, 8914, 1075, 782, 467 }
local MOTW_BUFF = { 9885, 9884, 8907, 5234, 6756, 5232, 1126, 21850, 21849 }
local REJUV_BUFF = { 9841, 9840, 9839, 8910, 3627, 2091, 2090, 1430, 1058, 774 }

local CASTER_SCHEMA = {
    moonfire_remains = 0,
    ff_remains = 0,
    insect_remains = 0,
    innervate_ready = false,
    in_combat = false,
    mana_pct = 100,
    hp_pct = 100,
    target_hp = 100,
}

local caster_state = {
    moonfire_remains = 0,
    ff_remains = 0,
    insect_remains = 0,
    innervate_ready = false,
    has_motw = false,
    has_rejuv = false,
    has_thorns = false,
    level = 60,
    in_combat = false,
    mana_pct = 100,
    hp_pct = 100,
    target_hp = 100,
    target_casting = false,
}

local function build_state(context)
    local target = context.target
    local me = context.me or NS.GetPlayer()
    caster_state.moonfire_remains = target and NS.debuff_remains and NS.debuff_remains(target, MOONFIRE_DEBUFF) or 0
    caster_state.ff_remains = target and NS.debuff_remains and NS.debuff_remains(target, FAERIE_FIRE_DEBUFF) or 0
    caster_state.insect_remains = target and NS.debuff_remains and NS.debuff_remains(target, INSECT_SWARM_DEBUFF) or 0
    caster_state.has_motw = me and NS.buff_up and NS.buff_up(me, MOTW_BUFF) or false
    caster_state.has_rejuv = me and NS.buff_up and NS.buff_up(me, REJUV_BUFF) or false
    caster_state.has_thorns = me and NS.has_player_buff and NS.has_player_buff(THORNS_BUFF) or false
    caster_state.level = context.level or context.player_level or 60
    caster_state.in_combat = context.in_combat or false
    caster_state.mana_pct = context.mana_pct or (NS.mana_pct and NS.mana_pct(me)) or 100
    caster_state.hp_pct = context.hp or context.hp_pct or (me and NS.unit_health_pct and NS.unit_health_pct(me)) or 100
    caster_state.target_hp = context.target_hp or 100
    caster_state.target_casting = target and target.is_casting and target:is_casting() or false
    caster_state.innervate_ready = NS.spell_ready and NS.spell_ready(ACTION.Innervate, NS.PLAYER_UNIT, { skip_range = true }) or false
    return spec_kit.safe_state(caster_state, CASTER_SCHEMA)
end

local function explicit_caster_selected(context)
    return context and (
        spec_kit.setting(context, "playstyle", "auto") == "caster"
        or spec_kit.setting(context, "active_playstyle", "") == "caster"
    )
end

local function caster_context_allowed(context)
    if not context then return false end
    if context.is_solo == true or context.is_leveling == true then return true end
    if context.is_pvp == true or context.is_arena == true or context.is_battleground == true then
        return explicit_caster_selected(context)
    end
    local raid_aware = spec_kit.setting_bool(context, "druid_caster_raid_aware_utility", true)
    if raid_aware and context.is_raid == true then
        return explicit_caster_selected(context)
    end
    if context.is_group == true then return true end
    return true
end

local function barkskin_matches_fn(context, state)
    if not caster_context_allowed(context) then return false end
    if (state.hp_pct or context.hp or 100) > 55 then return false end
    return NS.spell_ready(ACTION.Barkskin, NS.PLAYER_UNIT, { skip_range = true })
end

local function healing_touch_matches_fn(context, state)
    if not caster_context_allowed(context) then return false end
    if context.is_moving then return false end
    if (state.hp_pct or 100) > 40 then return false end
    if (state.mana_pct or 100) < 15 then return false end
    return NS.spell_ready(ACTION.HealingTouch, NS.PLAYER_UNIT, { skip_range = true })
end

local function rejuvenation_matches_fn(context, state)
    if not caster_context_allowed(context) then return false end
    if (state.hp_pct or 100) > 70 then return false end
    if state.has_rejuv then return false end
    return NS.spell_ready(ACTION.Rejuvenation, NS.PLAYER_UNIT, { skip_range = true })
end

local function thorns_matches_fn(context, state)
    if not caster_context_allowed(context) then return false end
    if context.in_combat then return false end
    if state.has_thorns then return false end
    if NS.has_player_buff and NS.has_player_buff(THORNS_BUFF) then return false end
    return NS.spell_ready(ACTION.Thorns, NS.PLAYER_UNIT, { skip_range = true })
end

local function motw_matches_fn(context, state)
    if not caster_context_allowed(context) then return false end
    if context.in_combat then return false end
    if state.has_motw then return false end
    return NS.spell_ready(ACTION.MarkOfTheWild, NS.PLAYER_UNIT, { skip_range = true })
end

local function innervate_matches_fn(context, state)
    if NS.should_use_long_cd and not NS.should_use_long_cd(context, 360) then return false end
    if not caster_context_allowed(context) then return false end
    if not context.in_combat then return false end
    if (context.mana_pct or state.mana_pct or 100) > 30 then return false end
    return state.innervate_ready
end

local function faerie_fire_matches_fn(context, state)
    if not caster_context_allowed(context) then return false end
    if not context.target then return false end
    if (context.target_armor or 0) <= 0 and not leveling_helpers.is_low_level(state.level) then return false end
    if (state.ff_remains or 0) > 4 then return false end
    return NS.spell_ready(ACTION.FaerieFire, context.target)
end

local function moonfire_matches_fn(context, state)
    if not caster_context_allowed(context) then return false end
    if not context.target then return false end
    if (state.moonfire_remains or 0) > 3 then return false end
    return NS.spell_ready(ACTION.Moonfire, context.target)
end

local function insect_swarm_matches_fn(context, state)
    if not caster_context_allowed(context) then return false end
    if not context.target then return false end
    if (state.level or 60) < 20 then return false end
    if (state.insect_remains or 0) > 3 then return false end
    return NS.spell_ready(ACTION.InsectSwarm, context.target)
end

local function starfire_matches_fn(context, state)
    if not caster_context_allowed(context) then return false end
    if context.is_moving then return false end
    if not context.target then return false end
    if (state.level or 60) < 20 then return false end
    if (state.mana_pct or 100) < 20 then return false end
    return NS.spell_ready(ACTION.Starfire, context.target)
end

local function wrath_matches_fn(context, state)
    if not caster_context_allowed(context) then return false end
    if context.is_moving then return false end
    return NS.spell_ready(ACTION.Wrath, context.target)
end

local function mana_potion_matches_fn(context, state)
    if not context.in_combat then return false end
    if (state.mana_pct or 100) > 22 then return false end
    if not potion_helper or not potion_helper.try_use_potion then return false end
    return true
end

local function health_potion_matches_fn(context, state)
    if not context.in_combat then return false end
    if (state.hp_pct or 100) > 35 then return false end
    if not potion_helper or not potion_helper.try_use_potion then return false end
    return true
end

local strategies = {
    { name = "Barkskin",
      matches = barkskin_matches_fn,
      execute = function() return NS.try_cast(ACTION.Barkskin, NS.PLAYER_UNIT, "[CASTER] Barkskin") end },
    { name = "HealingTouch",
      matches = healing_touch_matches_fn,
      execute = function() return NS.try_cast(ACTION.HealingTouch, NS.PLAYER_UNIT, "[CASTER] Healing Touch") end },
    { name = "Rejuvenation",
      matches = rejuvenation_matches_fn,
      execute = function() return NS.try_cast(ACTION.Rejuvenation, NS.PLAYER_UNIT, "[CASTER] Rejuvenation") end },
    { name = "HealthPotion",
      matches = health_potion_matches_fn,
      execute = function(context)
          return potion_helper.try_use_potion(context, potion_helper.HEALTH_POTION_IDS or {}) == true
      end },
    { name = "ManaPotion",
      matches = mana_potion_matches_fn,
      execute = function(context)
          return potion_helper.try_use_potion(context, potion_helper.MANA_POTION_IDS or {}) == true
      end },
    { name = "MarkOfTheWild",
      matches = motw_matches_fn,
      execute = function() return NS.try_cast(ACTION.MarkOfTheWild, NS.PLAYER_UNIT, "[CASTER] Mark of the Wild") end },
    { name = "Thorns",
      matches = thorns_matches_fn,
      execute = function() return NS.try_cast(ACTION.Thorns, NS.PLAYER_UNIT, "[CASTER] Thorns") end },
    { name = "Innervate",
      matches = innervate_matches_fn,
      execute = function() return NS.try_cast(ACTION.Innervate, NS.PLAYER_UNIT, "[CASTER] Innervate") end },
    { name = "FaerieFire",
      matches = faerie_fire_matches_fn,
      execute = function(context) return NS.try_cast(ACTION.FaerieFire, context.target, "[CASTER] Faerie Fire") end },
    { name = "Moonfire",
      matches = moonfire_matches_fn,
      execute = function(context) return NS.try_cast(ACTION.Moonfire, context.target, "[CASTER] Moonfire") end },
    { name = "InsectSwarm",
      matches = insect_swarm_matches_fn,
      execute = function(context) return NS.try_cast(ACTION.InsectSwarm, context.target, "[CASTER] Insect Swarm") end },
    { name = "Starfire", spell = ACTION.Starfire, not_moving = true, min_mana = 20,
      matches = starfire_matches_fn,
      execute = function(context) return NS.try_cast(ACTION.Starfire, context.target, "[CASTER] Starfire") end },
    { name = "Wrath", spell = ACTION.Wrath, not_moving = true, min_mana = 10,
      matches = wrath_matches_fn,
      execute = function(context) return NS.try_cast(ACTION.Wrath, context.target, "[CASTER] Wrath") end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("caster", strategies, { get_state = build_state })
end
return { strategies = strategies, build_state = build_state }
