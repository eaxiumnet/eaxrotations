-- caster_sylvanas.lua -- Druid Caster (leveling/solo) rotation for TBC Anniversary (2.5.5).
-- WHAT:  priority-list strategies for caster DPS (Moonfire, Wrath, Faerie Fire).
-- WHEN:  combat with valid enemy target (leveling/solo/raid/PvP context gates).
-- WHY:   mirrors SimulationCraft / wowsims APL with TBC-era mechanics (Moonfire + Insect Swarm multidot, Starfire filler, per balance APL).
-- SAFETY: Pattern 14 eliminated via spec_kit.safe_state(); no manual nil-guards; no on_update() allocs.

-- Druid Caster priority list.

local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.DruidSpells or {}
local spec_kit = require("shared/spec_kit_sylvanas")
local dsl = require("shared/strategy_dsl_sylvanas")

-- Centralized spell resolver via spec_kit (rank IDs from class_sylvanas.lua).
local define = spec_kit.define_action_for_class(SPELLS)
local ACTION = {
    Barkskin    = define("Barkskin",    { 22812 }, "Barkskin"),
    FaerieFire  = define("FaerieFire",  { 26993, 9907, 9749, 778, 770 }, "FaerieFire"),
    Innervate   = define("Innervate",   { 29166 }, "Innervate"),
    Moonfire    = define("Moonfire",    { 26988, 26987, 9835, 9834, 9833, 8929, 8928, 8927, 8926, 8925, 8924, 8921 }, "Moonfire"),
    Thorns      = define("Thorns",      { 26992, 9910, 9756, 8914, 1075, 782, 467 }, "Thorns"),
    Wrath       = define("Wrath",       { 26985, 26984, 9912, 8905, 6780, 5180, 5179, 5178, 5177, 5176 }, "Wrath"),
}

local MOONFIRE_DEBUFF = { 26988, 26987, 9835, 9834, 9833, 8929, 8928, 8927, 8926, 8925, 8924, 8921 }
local FAERIE_FIRE_DEBUFF = { 26993, 9907, 9749, 778, 770 }
local THORNS_BUFF = { 26992, 9910, 9756, 8914, 1075, 782, 467 }

-- Schema for safe_state (Pattern 14 nil-guard elimination).
local CASTER_SCHEMA = {
    moonfire_remains = 0,
    ff_remains = 0,
    innervate_ready = false,
    in_combat = false,
    is_group = false,
    mana_pct = 100,
    hp_pct = 100,
    target_hp = 100,
}

-- ============================================================================
-- State builder
-- ============================================================================
local caster_state = {
    moonfire_remains = 0,
    ff_remains = 0,
    innervate_ready = false,
}

local function build_state(context)
    local target = context.target
    local me = context.me or NS.GetPlayer()
    caster_state.moonfire_remains = target and NS.debuff_remains and NS.debuff_remains(target, MOONFIRE_DEBUFF) or 0
    caster_state.ff_remains = target and NS.debuff_remains and NS.debuff_remains(target, FAERIE_FIRE_DEBUFF) or 0
    caster_state.in_combat = context.in_combat or false
    caster_state.is_group = context.is_group or false
    caster_state.mana_pct = context.mana_pct or (NS.mana_pct and NS.mana_pct(me)) or 100
    caster_state.hp_pct = context.hp or (me and NS.unit_health_pct and NS.unit_health_pct(me)) or 100
    caster_state.target_hp = context.target_hp or 100
    caster_state.innervate_ready = NS.spell_ready and NS.spell_ready(ACTION.Innervate, NS.PLAYER_UNIT, { skip_range = true }) or false
    return spec_kit.safe_state(caster_state, CASTER_SCHEMA)
end

-- ============================================================================
-- Helper functions
-- ============================================================================

local function explicit_caster_selected(context)
    return context and (
        spec_kit.setting(context, "playstyle", "auto") == "caster"
        or spec_kit.setting(context, "active_playstyle", "auto") == "caster"
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
    return true
end

-- ============================================================================
-- Declarative Strategy DSL definitions
-- ============================================================================
-- These replace the imperative match/execute pairs.  Complex conditions that
-- are awkward to express declaratively are kept in `custom` nodes.
local DSL_DEFS = {
    {
        name = "Barkskin",
        conditions = {
            { type = "custom", fn = function(context, state)
                if not caster_context_allowed(context) then return false end
                if (context.hp or 100) > 55 then return false end
                return true
            end },
            { type = "spell_ready", spell = ACTION.Barkskin, target = "self", opts = { skip_range = true } },
        },
        action = { type = "cast", spell = ACTION.Barkskin, target = "self", label = "[CASTER] Barkskin", opts = { skip_range = true } },
    },
    {
        name = "Thorns",
        conditions = {
            { type = "custom", fn = function(context, state)
                if not caster_context_allowed(context) then return false end
                if not spec_kit.setting_bool(context, "use_self_buffs", true) then return false end
                if context.in_combat then return false end
                if NS.buff_would_downgrade and NS.buff_would_downgrade(context.me or NS.PLAYER_UNIT, THORNS_BUFF, ACTION.Thorns) then
                    return false
                end
                if NS.has_player_buff and NS.has_player_buff(THORNS_BUFF) then return false end
                return true
            end },
            { type = "spell_ready", spell = ACTION.Thorns, target = "self", opts = { skip_range = true } },
        },
        action = { type = "cast", spell = ACTION.Thorns, target = "self", label = "[CASTER] Thorns", opts = { skip_range = true } },
    },
    {
        name = "Innervate",
        conditions = {
            { type = "custom", fn = function(context, state)
                if not caster_context_allowed(context) then return false end
                if not context.in_combat then return false end
                if (context.mana_pct or 100) > 30 then return false end
                return true
            end },
            { type = "state", field = "innervate_ready", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.Innervate, target = "self", label = "[CASTER] Innervate", opts = { skip_range = true } },
    },
    {
        name = "FaerieFire",
        conditions = {
            { type = "custom", fn = function(context, state)
                if not caster_context_allowed(context) then return false end
                if not context.target then return false end
                if (context.target_armor or 0) <= 0 then return false end
                if (state.ff_remains or 0) > 4 then return false end
                return true
            end },
            { type = "spell_ready", spell = ACTION.FaerieFire },
        },
        action = { type = "custom", fn = function(context, state)
            return NS.try_cast and NS.try_cast(ACTION.FaerieFire, context.target, "[CASTER] Faerie Fire")
        end },
    },
    {
        name = "Moonfire",
        conditions = {
            { type = "custom", fn = function(context, state)
                if not caster_context_allowed(context) then return false end
                if not context.target then return false end
                if (state.moonfire_remains or 0) > 3 then return false end
                return true
            end },
            { type = "spell_ready", spell = ACTION.Moonfire },
        },
        action = { type = "custom", fn = function(context, state)
            return NS.try_cast and NS.try_cast(ACTION.Moonfire, context.target, "[CASTER] Moonfire")
        end },
    },
    {
        name = "Wrath",
        conditions = {
            { type = "custom", fn = function(context, state)
                if not caster_context_allowed(context) then return false end
                if context.is_moving then return false end
                return true
            end },
            { type = "spell_ready", spell = ACTION.Wrath },
        },
        action = { type = "custom", fn = function(context, state)
            return NS.try_cast and NS.try_cast(ACTION.Wrath, context.target, "[CASTER] Wrath")
        end },
    },
}

-- ============================================================================
-- Strategies
-- ============================================================================

local strategies = {
    { name = "Barkskin" },
    { name = "Thorns" },
    { name = "Innervate" },
    { name = "FaerieFire" },
    { name = "Moonfire" },
    { name = "Wrath", not_moving = true, min_mana = 10 },
}

-- Name-based substitution preserves the existing priority order.
for i = 1, #strategies do
    for j = 1, #DSL_DEFS do
        if strategies[i].name == DSL_DEFS[j].name then
            strategies[i] = dsl.compile_strategy(DSL_DEFS[j], { get_state = build_state })
            break
        end
    end
end

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("caster", strategies, { get_state = build_state })
end
if NS.log then NS.log("Druid caster rotation registered") end
return { strategies = strategies, build_state = build_state }
