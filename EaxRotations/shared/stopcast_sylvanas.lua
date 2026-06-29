-- stopcast_sylvanas.lua -- Cancels a direct heal cast when the target's HP recovers above threshold.
-- WHAT:   Cancels a direct heal cast when the target's HP recovers above threshold
-- WHEN:   Any healing spec casting a direct heal with cast time > 1.0s.
-- WHY:    has this; EAX needs parity. A Greater Heal landing on a target
-- SAFETY: All API calls nil-guarded; disabled pass-through when off or when
-- DECISION: smart Stop-Cast Engine; cancel heal channel when target recovers enough.

--  during the cast, preventing massive overheal waste.
--  that was topped off by a HoT tick = ~40% overheal.
--   target data is unavailable. Uses engine cancel API (cancel_spells).
-- Decision: Standalone module so all 5 healer specs can consume it uniformly.

local _G = _G
local NS = _G.EaxRotations
if not NS then return end

local type = type
local math_max = math.max
local math_min = math.min

local M = {}
NS.StopCast = M

-- ---------------------------------------------------------------------------
-- Configuration defaults (overridden by context.settings)
-- ---------------------------------------------------------------------------
local DEFAULT_ENABLED = true
local DEFAULT_THRESHOLD = 95  -- Cancel if target would be above 95% after heal
local DEFAULT_CHECK_25 = true  -- Check at 25% cast progress
local DEFAULT_CHECK_50 = true  -- Check at 50% cast progress
local DEFAULT_CHECK_75 = true  -- Check at 75% cast progress
local DEFAULT_MIN_CAST_TIME = 1.0 -- Only monitor casts >= 1.0s

-- ---------------------------------------------------------------------------
-- Internal state
-- ---------------------------------------------------------------------------
local _last_casting = false
local _cast_start_time = 0
local _cast_target = nil
local _cast_target_guid = nil
local _cast_spell_id = nil
local _cast_expected_heal = 0
local _cast_total_time = 0
local _last_cancel_time = 0
local CANCEL_COOLDOWN = 1.0  -- 1s between cancels to prevent spam

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function safe_number(v, fallback)
 fallback = fallback or 0
 return type(v) == "number" and v or fallback
end

local function unit_hp_pct(unit)
 if not unit then return nil end
 local ok, pct = pcall(function()
  if unit.get_health_percentage then return unit:get_health_percentage() end
  if NS.unit_health_pct then return NS.unit_health_pct(unit) end
  return nil
 end)
 if ok and type(pct) == "number" then return pct end
 return nil
end

local function unit_max_hp(unit)
 if not unit then return 0 end
 local ok, val = pcall(function()
  if unit.get_max_health then return unit:get_max_health() end
  return 0
 end)
 if ok and type(val) == "number" then return val end
 return 0
end

local function unit_guid(unit)
 if not unit then return nil end
 local ok, guid = pcall(function()
  if unit.get_guid then return unit:get_guid() end
  if unit.guid then return unit.guid end
  return tostring(unit)
 end)
 if ok and guid then return tostring(guid) end
 return nil
end

local function is_player_casting(me)
 if not me then return false end
 local ok, casting = pcall(function()
  if me.is_casting then return me:is_casting() end
  return false
 end)
 return ok and casting == true
end

local function get_cast_info(me)
 if not me then return nil end
 local ok, info = pcall(function()
  if me.get_cast_info then return me:get_cast_info() end
  return nil
 end)
 if ok and type(info) == "table" then return info end
 return nil
end

local function cancel_cast()
 if NS.cancel_spells then
  local ok = pcall(NS.cancel_spells)
  return ok
 end
 return false
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

--- Update the stop-cast tracker. Call every frame from healer specs.
-- @param me   game_object Local player
-- @param settings table|nil Context settings (stopcast_enabled, stopcast_threshold, etc.)
-- @return boolean true if a cast was canceled this frame
function M.update(me, settings)
 settings = settings or (NS.settings or {})

 local enabled = settings.stopcast_enabled
 if enabled == nil then enabled = DEFAULT_ENABLED end
 if not enabled then
  _last_casting = false
  return false
 end

 local now = NS.time_now and NS.time_now() or 0
 if (now - _last_cancel_time) < CANCEL_COOLDOWN then
  return false
 end

 local is_casting = is_player_casting(me)

 -- Cast started this frame
 if is_casting and not _last_casting then
  local info = get_cast_info(me)
  if info then
   _cast_start_time = now
   _cast_total_time = safe_number(info.cast_time, 0)
   _cast_spell_id = info.spell_id
   _cast_target = info.target
   _cast_target_guid = unit_guid(info.target)
   _cast_expected_heal = safe_number(info.expected_heal, 0)
  end
 end

 _last_casting = is_casting

 -- Not casting or cast is too short to bother
 if not is_casting or _cast_total_time < DEFAULT_MIN_CAST_TIME then
  return false
 end

 -- Determine cast progress (0.0 - 1.0)
 local elapsed = now - _cast_start_time
 local progress = _cast_total_time > 0 and (elapsed / _cast_total_time) or 0
 progress = math_min(1.0, math_max(0.0, progress))

 -- Check if we should evaluate at this progress checkpoint
 local check_25 = settings.stopcast_check_25
 if check_25 == nil then check_25 = DEFAULT_CHECK_25 end
 local check_50 = settings.stopcast_check_50
 if check_50 == nil then check_50 = DEFAULT_CHECK_50 end
 local check_75 = settings.stopcast_check_75
 if check_75 == nil then check_75 = DEFAULT_CHECK_75 end

 local should_check = false
 if check_25 and progress >= 0.25 and progress < 0.30 then should_check = true end
 if check_50 and progress >= 0.50 and progress < 0.55 then should_check = true end
 if check_75 and progress >= 0.75 and progress < 0.80 then should_check = true end

 if not should_check then
  return false
 end

 -- Target may have changed (e.g., via click-casting); use current target if available
 local target = _cast_target
 if not target and me then
  local ok, t = pcall(function()
   if me.get_target then return me:get_target() end
   return nil
  end)
  if ok then target = t end
 end

 if not target then
  return false
 end

 local target_hp = unit_hp_pct(target)
 if not target_hp then
  return false
 end

 local threshold = safe_number(settings.stopcast_threshold, DEFAULT_THRESHOLD)

 -- If target is already above threshold, cancel immediately
 if target_hp >= threshold then
  _last_cancel_time = now
  cancel_cast()
  if NS.log then
   NS.log(string.format("[StopCast] Cancelled %s at %.0f%% progress: target %.0f%% > threshold %.0f%%",
    tostring(_cast_spell_id or "?"), progress * 100, target_hp, threshold))
  end
  return true
 end

 -- Estimate post-heal HP: current HP% + (expected_heal / max_hp * 100)
 local max_hp = unit_max_hp(target)
 if max_hp > 0 and _cast_expected_heal > 0 then
  local heal_pct = (_cast_expected_heal / max_hp) * 100
  local projected_hp = target_hp + heal_pct
  if projected_hp >= threshold then
   _last_cancel_time = now
   cancel_cast()
   if NS.log then
    NS.log(string.format("[StopCast] Cancelled %s at %.0f%% progress: projected %.0f%% (%.0f%% + %.1f%% heal) > threshold %.0f%%",
     tostring(_cast_spell_id or "?"), progress * 100, projected_hp, target_hp, heal_pct, threshold))
   end
   return true
  end
 end

 return false
end

--- Reset internal state (e.g. on zone change or /reload).
function M.reset()
 _last_casting = false
 _cast_start_time = 0
 _cast_target = nil
 _cast_target_guid = nil
 _cast_spell_id = nil
 _cast_expected_heal = 0
 _cast_total_time = 0
 _last_cancel_time = 0
end

--- Check if stop-cast is enabled for the given settings.
function M.is_enabled(settings)
 settings = settings or (NS.settings or {})
 local enabled = settings.stopcast_enabled
 if enabled == nil then enabled = DEFAULT_ENABLED end
 return enabled
end

if NS.log then NS.log("StopCast module loaded") end
return M
