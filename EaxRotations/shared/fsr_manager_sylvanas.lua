-- fsr_manager_sylvanas.lua — Five-Second Rule mana regeneration tracker for TBC Anniversary (2.5.5).
-- WHAT:  Tracks last cast time and provides FSR-aware pause helper (should_pause_for_fsr) using spec_kit settings.
-- WHEN:  Used by healer specs in build_state + strategy matches (post-emergency, pre-filler).
-- WHY:   TBC healers lose ~80% spirit regen inside 5s window; intentional pause extends mana 15-30% when delta>0.
-- SAFETY: pcall spec_kit; all state/settings reads nil-guarded via fallbacks (Pattern 14); time via NS.time_now.
-- DECISION: central source for pause logic; fsr_max_pause_seconds (0=full) replaces hard >2s gate; dead downrank helpers untouched.

local NS = _G.EaxRotations
if not NS then return nil end

-- spec_kit for settings accessors (Pattern 8/16); optional pcall for test isolation
local spec_kit = nil
local _ok, sk = pcall(require, "shared/spec_kit_sylvanas")
if _ok and sk then spec_kit = sk end

local M = {}

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------
local _last_cast_time = 0
local _last_cast_mana_cost = 0
local _fsr_window = 5.0  -- seconds

-- ---------------------------------------------------------------------------
-- API Caching (Pattern 2)
-- ---------------------------------------------------------------------------
local _time_now = NS.time_now or function() return os.clock() end
local _core_spell_book = _G.core and _G.core.spell_book
local _get_base_regen = nil
local _get_casting_regen = nil

-- Lazy-load API to avoid startup dependency issues
local function ensure_api()
  -- always re-resolve from table (supports test mocks that override slots after first call; prod funcs stable)
  if not _core_spell_book then return false end
  local ok1, br = pcall(function() return _core_spell_book.get_base_power_regen end)
  local ok2, cr = pcall(function() return _core_spell_book.get_casting_power_regen end)
  if ok1 and br then _get_base_regen = br end
  if ok2 and cr then _get_casting_regen = cr end
  return _get_base_regen ~= nil
end

-- ---------------------------------------------------------------------------
-- Core Functions
-- ---------------------------------------------------------------------------

function M.on_cast(spell_id, mana_cost)
  _last_cast_time = _time_now()
  if mana_cost and mana_cost > 0 then
    _last_cast_mana_cost = mana_cost
  end
end

function M.is_inside_fsr()
  local elapsed = _time_now() - _last_cast_time
  return elapsed < _fsr_window
end

function M.seconds_until_fsr()
  local remaining = _fsr_window - (_time_now() - _last_cast_time)
  return remaining > 0 and remaining or 0
end

function M.get_regen_delta()
  if not ensure_api() then return 0 end
  local ok1, base = pcall(_get_base_regen)
  local ok2, casting = pcall(_get_casting_regen)
  if ok1 and ok2 and type(base) == "number" and type(casting) == "number" then
    return (base - casting) * 5  -- per-tick delta over 5 seconds
  end
  return 0
end

-- Should we pause casting to let FSR tick?
-- @param state table with: mana_pct, lowest_hp_pct, in_combat, fsr_*
-- @param context table with .settings (or via spec_kit)
-- @return boolean, reason_string
function M.should_pause_for_fsr(state, context)
  if not state then return false, "no state" end

  -- settings via spec_kit if present (preferred); fallbacks preserve old behavior
  local enabled = true
  if spec_kit and spec_kit.setting_bool then
    enabled = spec_kit.setting_bool(context, "fsr_enabled", true)
  else
    local s = context and context.settings
    if s and s.fsr_enabled ~= nil then enabled = s.fsr_enabled ~= false end
  end
  if not enabled then return false, "fsr disabled" end

  local mana_pct = state.mana_pct or 100
  local lowest_hp = state.lowest_hp_pct or 100
  local in_combat = state.in_combat or false

  if not in_combat then return false, "not in combat" end

  local mana_threshold = 35
  if spec_kit and spec_kit.setting_number then
    mana_threshold = spec_kit.setting_number(context, "fsr_mana_threshold", 35)
  else
    local s = context and context.settings
    if s and type(s.fsr_mana_threshold) == "number" then mana_threshold = s.fsr_mana_threshold end
  end
  if mana_pct > mana_threshold then return false, "mana above threshold" end

  local emergency = 40
  if spec_kit and spec_kit.setting_number then
    emergency = spec_kit.setting_number(context, "fsr_emergency_hp", 40)
  else
    local s = context and context.settings
    if s and type(s.fsr_emergency_hp) == "number" then emergency = s.fsr_emergency_hp end
  end
  if lowest_hp <= emergency then return false, "emergency heal needed" end

  if not M.is_inside_fsr() then return false, "already outside FSR" end

  local regen_delta = M.get_regen_delta()
  if regen_delta <= 0 then return false, "no regen delta" end

  -- fsr_seconds guard: if fsr_max_pause_seconds > 0, only pause if remaining <= max (0 = full window)
  local max_pause = 0
  if spec_kit and spec_kit.setting_number then
    max_pause = spec_kit.setting_number(context, "fsr_max_pause_seconds", 0)
  else
    local s = context and context.settings
    if s and type(s.fsr_max_pause_seconds) == "number" then max_pause = s.fsr_max_pause_seconds end
  end
  local fsr_remaining = M.seconds_until_fsr()
  if max_pause > 0 and fsr_remaining > max_pause then
    return false, "exceeds max pause window"
  end

  return true, "pause for FSR regen: " .. string.format("%.0f", regen_delta)
end

-- Exposed helper (for specs / tests / future consumers)
function M.is_fsr_pause_enabled(context)
  if spec_kit and spec_kit.setting_bool then
    return spec_kit.setting_bool(context, "fsr_enabled", true)
  end
  local s = context and context.settings
  if s and s.fsr_enabled ~= nil then return s.fsr_enabled ~= false end
  return true
end

-- Calculate the "regen opportunity cost" of casting a spell
-- Returns how much mana we lose by staying inside FSR
function M.get_cast_opportunity_cost(cast_time)
  cast_time = cast_time or 2.5
  if not M.is_inside_fsr() then
    -- Casting will put us inside FSR, cost = lost base regen for (cast_time + 5s)
    local delta = M.get_regen_delta()
    return delta * ((cast_time + _fsr_window) / 5)
  end
  -- Already inside FSR, additional cost is just the cast time extension
  local delta = M.get_regen_delta()
  return delta * (cast_time / 5)
end

-- ---------------------------------------------------------------------------
-- Downranking Recommendation
-- ---------------------------------------------------------------------------

-- Recommend a lower spell rank when mana is low and FSR is active
-- @param ranks table of {spell_id, label, mana_cost, base_heal}
-- @param target_deficit number - HP deficit of target
-- @param state table with mana_pct
-- @return best_rank_entry or nil
function M.choose_downrank(ranks, target_deficit, state)
  if not ranks or #ranks == 0 then return nil end
  if not state then return ranks[#ranks] end  -- Default to lowest rank

  local mana_pct = state.mana_pct or 100
  if mana_pct > 30 then return nil end  -- No downranking above 30%

  -- Find the cheapest rank that covers the deficit
  for i = 1, #ranks do
    local rank = ranks[i]
    if rank.base_heal and rank.base_heal >= target_deficit then
      return rank
    end
  end

  -- If nothing covers deficit, return the lowest rank anyway
  return ranks[1]
end

-- ---------------------------------------------------------------------------
-- Export
-- ---------------------------------------------------------------------------
NS.FsrManager = M
return M
