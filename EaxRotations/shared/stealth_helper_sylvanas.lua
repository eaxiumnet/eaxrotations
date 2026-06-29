-- stealth_helper_sylvanas.lua -- centralized stealth detection across rogue + druid-cat specs.
-- WHAT:   centralized stealth detection across rogue + druid-cat specs
-- WHEN:   any spec that relies on stealth openers (Rogue, Feral)
-- WHY:    single source of stealth detection + opener sequencing
-- SAFETY: OPENER_BUFF check nil-guarded; no side-effects
-- DECISION: consumed by specs via require(); no on_update side-effects.

-- EaxRotations/shared/stealth_helper_sylvanas.lua
-- Shared stealth helper for Rogue (Stealth) and Druid (Prowl) specs.
-- TBC Classic Anniversary (3.3.5 client).
--
-- Public API:
--   M.try(context)        -> boolean   (cast or queue via NS.try_cast)
--   M.is_stealthed()      -> boolean   (checks all stealth buff IDs)
--   M.SPELLS              -> { STEALTH, PROWL, SHADOWMELD }

local _G = _G
local NS = _G.EaxRotations
if not NS then return nil end

local M = {}

-- TBC Classic Anniversary spell IDs (TBC cast IDs).
-- Buff IDs differ from cast IDs: Stealth has 4 ranks, Prowl/Shadowmeld are single-rank.
M.SPELLS = {
    STEALTH    = 1784,   -- Rogue Stealth (cast)
    PROWL      = 5215,   -- Druid Prowl (cast; requires Caster Form, enters Cat Form)
    SHADOWMELD = 20580,  -- Night Elf racial (cast; TBC ID, matches racial_manager)
}

-- Buff ID tables — must include all rank variants (Stealth has 4 ranks).
M.STEALTH_BUFF_IDS     = { 1787, 1786, 1785, 1784 }
M.PROWL_BUFF_IDS       = { 9913, 6783, 5215 }
M.SHADOWMELD_BUFF_IDS  = { 20580 }

-- All stealth buff IDs in one table for the public is_stealthed() check.
M.STEALTHED_BUFF_IDS = {}
for _, id in ipairs(M.STEALTH_BUFF_IDS)    do M.STEALTHED_BUFF_IDS[#M.STEALTHED_BUFF_IDS+1] = id end
for _, id in ipairs(M.PROWL_BUFF_IDS)      do M.STEALTHED_BUFF_IDS[#M.STEALTHED_BUFF_IDS+1] = id end
for _, id in ipairs(M.SHADOWMELD_BUFF_IDS) do M.STEALTHED_BUFF_IDS[#M.STEALTHED_BUFF_IDS+1] = id end

-- Names for the queue label (NS.try_cast reason).
M.SPELL_NAMES = {
    [M.SPELLS.STEALTH]    = "Stealth",
    [M.SPELLS.PROWL]      = "Prowl",
    [M.SPELLS.SHADOWMELD] = "Shadowmeld",
}

-- Default thresholds (linear yards — get_distance returns linear).
local DEFAULT_MAX_YD = 20
local DEFAULT_MIN_YD = 5

-- Pick the best stealth the local player has learned.
-- Order: Stealth (Rogue) > Prowl (Druid) > Shadowmeld (Night Elf fallback).
local function resolve_spell_id()
    if NS.is_spell_learned and NS.is_spell_learned(M.SPELLS.STEALTH)    then return M.SPELLS.STEALTH    end
    if NS.is_spell_learned and NS.is_spell_learned(M.SPELLS.PROWL)      then return M.SPELLS.PROWL      end
    if NS.is_spell_learned and NS.is_spell_learned(M.SPELLS.SHADOWMELD) then return M.SPELLS.SHADOWMELD end
    return nil
end

--- True if the player is in any form of stealth.
function M.is_stealthed()
    if not NS.has_player_buff then return false end
    return NS.has_player_buff(M.STEALTHED_BUFF_IDS) == true
end

--- True if the player is in stealth for their class.
--- Uses Rogue Stealth buff IDs for "rogue", Druid Prowl buff IDs for "druid".
--- @param class string  "rogue" or "druid"
function M.is_stealthed_for_class(class)
    local ids = class == "druid" and M.PROWL_BUFF_IDS or M.STEALTH_BUFF_IDS
    return NS.has_player_buff and NS.has_player_buff(ids) == true or false
end

--- Try to cast Stealth / Prowl / Shadowmeld.
--- Reads max/min distance from context.settings (never captured at load time).
--- @param context table  EaxRotations context with .me, .target, .settings
--- @return boolean  true if cast succeeded or was queued this tick
function M.try(context)
    context = context or {}
    local me = context.me or (NS.GetPlayer and NS.GetPlayer())
    if not me or not me:is_alive() then return false end

    -- Settings read: never captured at load time (CLAUDE.md META rule).
    local s = context.settings or {}
    if s.stealth_enabled == false then return false end
    local max_yd = tonumber(s.stealth_max_yd) or DEFAULT_MAX_YD
    local min_yd = tonumber(s.stealth_min_yd) or DEFAULT_MIN_YD

    -- Already stealthed -> skip (checks all rank buff IDs).
    if M.is_stealthed() then return false end

    -- In combat -> skip (user requirement: "not in combat").
    if me:is_in_combat() then return false end

    -- Resolve which stealth the player has.
    local id = resolve_spell_id()
    if not id then return false end

    -- Broken-API guard: prevents crash loops on private servers with bad aura API
    -- (matches the pattern in combat_sylvanas.lua:230 and assassination_sylvanas.lua:63).
    if NS.broken_api_throttled and NS.broken_api_throttled(id, 3.0) then return false end

    -- Target selection: prefer context.target, fall back to NS.GetBestEnemyTarget.
    -- NS.GetBestEnemyTarget(range) returns the closest hostile in `range` yards.
    local enemy = context.target
    if not enemy or not (NS.is_hostile_unit and NS.is_hostile_unit(me, enemy)) then
        enemy = NS.GetBestEnemyTarget and NS.GetBestEnemyTarget(max_yd)
    end
    if not enemy then return false end

    -- Linear distance check (get_distance returns linear yards, not squared).
    local dist = me:get_distance(enemy)
    if dist < min_yd then return false end   -- too close - already detected
    if dist > max_yd then return false end   -- out of pull range

    -- Get the spell object via the canonical NS.spell_action(id, label) factory.
    local spell = NS.spell_action and NS.spell_action(id, M.SPELL_NAMES[id])
    if not spell then return false end

    -- Project casting path: NS.try_cast runs the central cast guard
    -- (cooldown, resource, range, anti-flicker, min_interval, reagent, immunity,
    -- form, spell queue dedup). skip_range = true for self-casts.
    -- Druid Prowl from Bear Form will be rejected by the form-check guard
    -- and return false cleanly - no manual form-cancel needed.
    return NS.try_cast(spell, me, "[Stealth] " .. M.SPELL_NAMES[id], {
        skip_range = true,
    }) == true
end

if NS then
    NS.Stealth = M
end

return M
