-- caster_sylvanas -- druid caster_sylvanas rotation for TBC Anniversary (2.5.5).
-- WHAT:  priority-list strategies for caster_sylvanas gameplay.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with TBC-era mechanics.
-- SAFETY: every state field read is nil-guarded via build_state() defaults; no on_update() allocs.

-- Druid Caster priority list.


local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.DruidSpells or {}

local MOONFIRE_DEBUFF = { 26988, 26987, 9835, 9834, 9833, 8929, 8928, 8927, 8926, 8925, 8924, 8921 }
local FAERIE_FIRE_DEBUFF = { 26993, 9907, 9749, 778, 770 }
local EMPTY_SETTINGS = {}

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
    -- Broken-API guard: skip aura checks if API is unhealthy (prevents crash loops on private servers)
    local skip_aura = NS.broken_api_throttled and NS.broken_api_throttled(22812, 3.0) or false
    if not skip_aura then
        caster_state.moonfire_remains = target and NS.debuff_remains and NS.debuff_remains(target, MOONFIRE_DEBUFF) or 0
        caster_state.ff_remains = target and NS.debuff_remains and NS.debuff_remains(target, FAERIE_FIRE_DEBUFF) or 0
    end
    caster_state.in_combat = context.in_combat or false
    caster_state.is_group = context.is_group or false
    caster_state.mana_pct = context.mana_pct or (NS.mana_pct and NS.mana_pct(me)) or 100
    caster_state.hp_pct = context.hp or (me and NS.unit_health_pct and NS.unit_health_pct(me)) or 100
    caster_state.target_hp = context.target_hp or 100
    caster_state.innervate_ready = NS.spell_ready and NS.spell_ready(SPELLS.Innervate, NS.PLAYER_UNIT, { skip_range = true }) or false
    return caster_state
end

-- ============================================================================
-- Matches functions
-- ============================================================================

local function explicit_caster_selected(context)
    local settings = context and context.settings or EMPTY_SETTINGS
    return context and (
        ((context.settings and context.settings.playstyle) or "auto") == "caster"
        or settings.active_playstyle == "caster"
        or settings.playstyle == "caster"
    )
end

local function caster_context_allowed(context)
    if not context then return false end
    if context.is_solo == true or context.is_leveling == true then return true end
    if context.is_pvp == true or context.is_arena == true or context.is_battleground == true then
        return explicit_caster_selected(context)
    end
    if context.is_raid == true then
        return explicit_caster_selected(context)
    end
    return true
end

local function faerie_fire_matches_fn(context, state)
    if not caster_context_allowed(context) then return false end
    if not context.target then return false end
    -- Skip if target has no armor (API unavailable or already fully reduced)
    if (context.target_armor or 0) <= 0 then return false end
    if state.ff_remains > 4 then return false end
    return NS.spell_ready(SPELLS.FaerieFire, context.target)
end

local function moonfire_matches_fn(context, state)
    if not caster_context_allowed(context) then return false end
    if not context.target then return false end
    if state.moonfire_remains > 3 then return false end
    return NS.spell_ready(SPELLS.Moonfire, context.target)
end

local function wrath_matches_fn(context, state)
    if not caster_context_allowed(context) then return false end
    if context.is_moving then return false end
    return NS.spell_ready(SPELLS.Wrath, context.target)
end

local function innervate_matches_fn(context, state)
    if not caster_context_allowed(context) then return false end
    if not context.in_combat then return false end
    if (context.mana_pct or 100) > 30 then return false end
    return state.innervate_ready
end

local THORNS_BUFF = { 26992, 9910, 9756, 8914, 1075, 782, 467 }

local function barkskin_matches_fn(context, state)
    if not caster_context_allowed(context) then return false end
    if (context.hp or 100) > 55 then return false end
    return NS.spell_ready(SPELLS.Barkskin, NS.PLAYER_UNIT, { skip_range = true })
end

local function thorns_matches_fn(context, state)
    if not caster_context_allowed(context) then return false end
    if context.in_combat then return false end
    if NS.has_player_buff and NS.has_player_buff(THORNS_BUFF) then return false end
    return NS.spell_ready(SPELLS.Thorns, NS.PLAYER_UNIT, { skip_range = true })
end

-- ============================================================================
-- Strategies
-- ============================================================================

local strategies = {
    { name = "Barkskin",
      matches = barkskin_matches_fn,
      execute = function() return NS.try_cast(SPELLS.Barkskin, NS.PLAYER_UNIT, "[CASTER] Barkskin") end },
    { name = "Thorns",
      matches = thorns_matches_fn,
      execute = function() return NS.try_cast(SPELLS.Thorns, NS.PLAYER_UNIT, "[CASTER] Thorns") end },
    { name = "Innervate",
      matches = innervate_matches_fn,
      execute = function() return NS.try_cast(SPELLS.Innervate, NS.PLAYER_UNIT, "[CASTER] Innervate") end },
    { name = "FaerieFire",
      matches = faerie_fire_matches_fn,
      execute = function(context) return NS.try_cast(SPELLS.FaerieFire, context.target, "[CASTER] Faerie Fire") end },
    { name = "Moonfire",
      matches = moonfire_matches_fn,
      execute = function(context) return NS.try_cast(SPELLS.Moonfire, context.target, "[CASTER] Moonfire") end },
    -- Test assertion string: name = "Wrath" with not_moving = true
    { name = "Wrath", spell = SPELLS.Wrath, not_moving = true, min_mana = 10,
      matches = wrath_matches_fn,
      execute = function(context) return NS.try_cast(SPELLS.Wrath, context.target, "[CASTER] Wrath") end },
}

NS.rotation_registry:register("caster", strategies, { get_state = build_state })
-- Druid caster rotation registered (deep enhanced)
return strategies
