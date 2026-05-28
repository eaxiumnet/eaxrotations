-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "classes/druid/caster_sylvanas.lua"
local __eax_version = "1.1.1"
local __eax_modified = "2026-05-27"
local __eax_change = "File version stamp for runtime load verification"
local __eax_versions = rawget(_G, "EaxRotationsFileVersions") or {}
_G.EaxRotationsFileVersions = __eax_versions
__eax_versions[__eax_file] = { version = __eax_version, modified = __eax_modified, change = __eax_change }
local __eax_core = rawget(_G, "core")
if type(__eax_core) == "table" and type(__eax_core.log) == "function" then
    pcall(__eax_core.log, "[EaxRotations] Loaded " .. __eax_file .. " v" .. __eax_version)
end
local __eax_ns = rawget(_G, "EaxRotations")
if type(__eax_ns) == "table" then __eax_ns.file_versions = __eax_versions end
-- Druid Caster priority list.

-- ============================================================================
-- What: TBC Druid caster-form priority list for Moonfire, Wrath, Starfire, and Innervate
-- When: Evaluated every tick via main_sylvanas.lua dispatcher
-- Why: Separate caster-form list keeps off-form utility and damage decisions readable
-- Safety: Nil-guarded settings; NS.* wrappers; safe fallbacks for missing spell data
-- ============================================================================

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
        caster_state.faerie_remains = target and NS.debuff_remains and NS.debuff_remains(target, FAERIE_FIRE_DEBUFF) or 0
    end
    caster_state.in_combat = context.in_combat or false
    caster_state.mana_pct = context.mana_pct or (me and NS.unit_mana_pct and NS.unit_mana_pct(me)) or 100
    caster_state.hp_pct = context.hp or (me and NS.unit_health_pct and NS.unit_health_pct(me)) or 100
    caster_state.target_hp = context.target_hp or 100
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

local THORNS_BUFF = { 26992, 9910, 9756, 8914, 1075, 782, 467 }

local function barkskin_matches_fn(context, state)
    if not caster_context_allowed(context) then return false end
    if context.hp > 55 then return false end
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
NS.log("Druid caster rotation registered (deep enhanced)")
return strategies
