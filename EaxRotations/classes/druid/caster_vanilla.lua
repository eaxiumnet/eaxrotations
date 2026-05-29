-- Druid Caster priority list (Vanilla).
-- Simple caster rotation for solo/leveling content.
-- Stripped of TBC-only spell IDs.

local _G_E = rawget(_G, "EaxRotations")
if not _G_E then return nil end
local SPELLS = _G_E.DruidSpells or {}

local MOONFIRE_DEBUFF = { 9835, 9834, 9833, 8929, 8928, 8927, 8926, 8925, 8924, 8921 }
local FAERIE_FIRE_DEBUFF = { 9907, 9749, 778, 770 }
local THORNS_BUFF = { 9910, 9756, 8914, 1075, 782, 467 }
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
    local me = context.me or _G_E.GetPlayer()
    local skip_aura = _G_E.broken_api_throttled and _G_E.broken_api_throttled(22812, 3.0) or false
    if not skip_aura then
        caster_state.moonfire_remains = target and _G_E.debuff_remains and _G_E.debuff_remains(target, MOONFIRE_DEBUFF) or 0
        caster_state.ff_remains = target and _G_E.debuff_remains and _G_E.debuff_remains(target, FAERIE_FIRE_DEBUFF) or 0
    end
    caster_state.in_combat = context.in_combat or false
    caster_state.mana_pct = context.mana_pct or (me and _G_E.unit_mana_pct and _G_E.unit_mana_pct(me)) or 100
    caster_state.hp_pct = context.hp or (me and _G_E.unit_health_pct and _G_E.unit_health_pct(me)) or 100
    caster_state.target_hp = context.target_hp or 100
    caster_state.innervate_ready = _G_E.spell_ready and _G_E.spell_ready(SPELLS.Innervate, _G_E.PLAYER_UNIT, { skip_range = true }) or false
    return caster_state
end

-- ============================================================================
-- Matches functions
-- ============================================================================

local function explicit_caster_selected(context)
    local settings = context and context.settings or EMPTY_SETTINGS
    return context and (
        context.active_playstyle == "caster"
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
    if state.ff_remains > 4 then return false end
    return _G_E.spell_ready(SPELLS.FaerieFire, context.target)
end

local function moonfire_matches_fn(context, state)
    if not caster_context_allowed(context) then return false end
    if not context.target then return false end
    if state.moonfire_remains > 3 then return false end
    return _G_E.spell_ready(SPELLS.Moonfire, context.target)
end

local function wrath_matches_fn(context, state)
    if not caster_context_allowed(context) then return false end
    if context.is_moving then return false end
    return _G_E.spell_ready(SPELLS.Wrath, context.target)
end

local function innervate_matches_fn(context, state)
    if not caster_context_allowed(context) then return false end
    if not context.in_combat then return false end
    if (context.mana_pct or 100) > 30 then return false end
    return state.innervate_ready
end

local function barkskin_matches_fn(context, state)
    if not caster_context_allowed(context) then return false end
    if (context.hp or 100) > 55 then return false end
    return _G_E.spell_ready(SPELLS.Barkskin, _G_E.PLAYER_UNIT, { skip_range = true })
end

local function thorns_matches_fn(context, state)
    if not caster_context_allowed(context) then return false end
    if context.in_combat then return false end
    if _G_E.has_player_buff and _G_E.has_player_buff(THORNS_BUFF) then return false end
    return _G_E.spell_ready(SPELLS.Thorns, _G_E.PLAYER_UNIT, { skip_range = true })
end

-- ============================================================================
-- Strategies
-- ============================================================================

local strategies = {
    { name = "Barkskin",
      matches = barkskin_matches_fn,
      execute = function() return _G_E.try_cast(SPELLS.Barkskin, _G_E.PLAYER_UNIT, "[CASTER] Barkskin") end },
    { name = "Thorns",
      matches = thorns_matches_fn,
      execute = function() return _G_E.try_cast(SPELLS.Thorns, _G_E.PLAYER_UNIT, "[CASTER] Thorns") end },
    { name = "Innervate",
      matches = innervate_matches_fn,
      execute = function() return _G_E.try_cast(SPELLS.Innervate, _G_E.PLAYER_UNIT, "[CASTER] Innervate") end },
    { name = "FaerieFire",
      matches = faerie_fire_matches_fn,
      execute = function(context) return _G_E.try_cast(SPELLS.FaerieFire, context.target, "[CASTER] Faerie Fire") end },
    { name = "Moonfire",
      matches = moonfire_matches_fn,
      execute = function(context) return _G_E.try_cast(SPELLS.Moonfire, context.target, "[CASTER] Moonfire") end },
    { name = "Wrath", spell = SPELLS.Wrath, not_moving = true, min_mana = 10,
      matches = wrath_matches_fn,
      execute = function(context) return _G_E.try_cast(SPELLS.Wrath, context.target, "[CASTER] Wrath") end },
}

_G_E.rotation_registry:register("caster", strategies, { get_state = build_state })
_G_E.log("Druid caster rotation registered (vanilla)")
return strategies
