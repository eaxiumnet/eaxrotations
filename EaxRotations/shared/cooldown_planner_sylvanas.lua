-- cooldown_planner_sylvanas.lua -- shared offensive/defensive cooldown alignment helpers.
-- WHAT:   decides when to fire on-use trinkets and major DPS cooldowns so they
--         overlap with Bloodlust/Heroism, drums, and each other.
-- WHEN:   per-tick by DPS specs before casting trinkets/major CDs.
-- WHY:    mirrors wowsims/SimC APL autocast-other-cooldowns rules that stack
--         temporary power for maximum effect.
-- SAFETY: pure helper; nil-guarded lookups; no side effects.
-- DECISION: consumed by specs and trinket_manager via require().

local NS = _G.EaxRotations
local M = {}

-- ============================================================================
-- Buff/debuff spell ID tables (TBC Classic 2.5.5)
-- ============================================================================
local BLOODLUST_BUFFS = { 2825, 32182 }            -- Shaman Bloodlust / Heroism
local DRUMS_BUFFS    = { 35475, 35476, 35477, 35478 } -- Drums of Battle/Bloodlust/War/Restoration

-- Major offensive cooldown auras / spells we can detect on the player.
-- IDs are the aura spell IDs from the TBC client DBC.
local MAJOR_OFFENSIVE_CD_IDS = {
  12042,  -- Arcane Power
  12472,  -- Icy Veins
  31884,  -- Avenging Wrath
  19574,  -- Bestial Wrath
  30823,  -- Shamanistic Rage
  16166,  -- Elemental Mastery
  10060,  -- Power Infusion
  12292,  -- Death Wish
  1719,   -- Recklessness
  12293,  -- Defensive Stance? no, skip
}

-- Defensive cooldowns and survival trinket alignment targets.
local MAJOR_DEFENSIVE_CD_IDS = {
  12975,  -- Last Stand
  871,    -- Shield Wall
  498,    -- Divine Protection
  642,    -- Divine Shield (bubble)
  22812,  -- Barkskin
  22842,  -- Frenzied Regeneration
}

local EMPTY_SETTINGS = {}

-- ============================================================================
-- Helpers
-- ============================================================================
local function me_or_context(context)
  if not context then return nil end
  return context.me or (NS and NS.GetPlayer and NS.GetPlayer()) or nil
end

local function setting(settings, key, default)
  if settings and settings[key] ~= nil then return settings[key] end
  if NS and NS.get_setting then return NS.get_setting(key, default) end
  return default
end

local function buff_up(unit, ids)
  if not unit then return false end
  if NS and NS.buff_up then return NS.buff_up(unit, ids) end
  local fn = unit.buff_up
  if type(fn) == "function" then
    local ok, result = pcall(fn, unit, ids)
    return ok and result or false
  end
  return false
end

local function debuff_up(unit, ids)
  if not unit then return false end
  if NS and NS.debuff_up then return NS.debuff_up(unit, ids) end
  local fn = unit.debuff_up
  if type(fn) == "function" then
    local ok, result = pcall(fn, unit, ids)
    return ok and result or false
  end
  return false
end

-- ============================================================================
-- Public API
-- ============================================================================

--- Returns true if Bloodlust, Heroism, or any TBC drum buff is active.
function M.is_external_haste_active(context)
  local me = me_or_context(context)
  if not me then return false end
  return buff_up(me, BLOODLUST_BUFFS) or buff_up(me, DRUMS_BUFFS)
end

--- Returns true if a recognized offensive cooldown buff is active on the player.
function M.is_major_offensive_cd_active(context)
  local me = me_or_context(context)
  if not me then return false end
  return buff_up(me, MAJOR_OFFENSIVE_CD_IDS)
end

--- Returns true if a recognized defensive cooldown is active (for survival trinket alignment).
function M.is_major_defensive_cd_active(context)
  local me = me_or_context(context)
  if not me then return false end
  return buff_up(me, MAJOR_DEFENSIVE_CD_IDS)
end

--- The canonical "fire offensive trinket/CD now?" gate.
-- Returns true in these cases:
--   1. context.should_burst is explicitly true
--   2. an external haste (Bloodlust/Drums) or major CD is already active
--   3. burst_on_bloodlust is enabled and BL/Drums was not seen, but we've waited
--      long enough (timeout) or the target is about to die (TTD <= 15s)
--   4. user explicitly disables alignment (trinket_align_with_cds = false)
function M.should_fire_offensive(context)
  local settings = context and context.settings or EMPTY_SETTINGS
  if context and context.should_burst then return true end

  -- Explicit disable allows legacy "fire on CD" behavior.
  if setting(settings, "trinket_align_with_cds", true) == false then return true end

  -- Always stack with real power windows.
  if M.is_external_haste_active(context) then return true end
  if M.is_major_offensive_cd_active(context) then return true end

  -- Timeout fallback to avoid holding CDs forever on fights without BL/Shaman.
  local combat_time = context and context.combat_time or 0
  local ttd = context and context.ttd or 999
  if combat_time >= 45 or ttd <= 15 then return true end

  -- If the user configured burst_on_bloodlust, respect that they still want to
  -- wait for BL unless timeout; otherwise default to fire so trinkets don't rot.
  local wait_for_bl = setting(settings, "burst_on_bloodlust", false)
  if not wait_for_bl then return true end

  return false
end

--- Defensive trinket/CD alignment.
-- Fires immediately when HP is below threshold unless a defensive CD is already
-- active (avoid overlapping redundancy).
function M.should_fire_defensive(context)
  local hp = context and (context.hp or 100) or 100
  local threshold = (context and context.settings and context.settings.trinket_defensive_hp) or 40
  if hp >= threshold then return false end
  if M.is_major_defensive_cd_active(context) then return false end
  return true
end

--- Returns true if a major offensive cooldown is about to come off cooldown soon.
-- Use to decide whether to hold a trinket for a few seconds.
-- @param context           rotation context
-- @param cd_spell_id       spell ID of the CD to wait for
-- @param max_wait_sec      maximum seconds to hold (default 10)
function M.is_major_cd_imminent(context, cd_spell_id, max_wait_sec)
  max_wait_sec = max_wait_sec or 10
  if not cd_spell_id then return false end
  local me = me_or_context(context)
  if not me then return false end
  local remains = 0
  if NS and NS.cooldown_remains then
    remains = NS.cooldown_remains(cd_spell_id)
  elseif NS and NS.spell_ready then
    if NS.spell_ready(cd_spell_id, me, { skip_range = true }) then return true end
  end
  if type(remains) ~= "number" then remains = 0 end
  return remains > 0 and remains <= max_wait_sec
end

if NS then
  NS.CooldownPlanner = M
  NS.cooldown_planner = M
end

return M
