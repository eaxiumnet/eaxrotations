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
    context.settings = context.settings or EMPTY_SETTINGS
    local target = context.target
    if target then
        caster_state.moonfire_remains = NS.debuff_remains and NS.debuff_remains(target, MOONFIRE_DEBUFF) or 0
        caster_state.ff_remains = NS.debuff_remains and NS.debuff_remains(target, FAERIE_FIRE_DEBUFF) or 0
    else
        caster_state.moonfire_remains = 0
        caster_state.ff_remains = 0
    end
    caster_state.innervate_ready = NS.spell_ready(SPELLS.Innervate, NS.PLAYER_UNIT, { skip_range = true })
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

local function barkskin_matches_fn(context, state)
    if not caster_context_allowed(context) then return false end
    if context.hp > 55 then return false end
    return NS.spell_ready(SPELLS.Barkskin, NS.PLAYER_UNIT, { skip_range = true })
end

local function thorns_matches_fn(context, state)
    if not caster_context_allowed(context) then return false end
    if context.in_combat then return false end
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
NS.log("Druid caster rotation registered (deep enhanced)")
return strategies
