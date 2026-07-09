-- fsr_manager_sylvanas.lua — Five-Second Rule mana regeneration tracker.
-- WHAT:  Tracks last cast time and provides FSR-aware casting recommendations.
-- WHEN:  Used by healer specs to optimize mana efficiency.
-- WHY:   TBC healers lose ~80% of spirit regen while inside the 5-second window.
--        Intentionally pausing for FSR can extend mana pool by 15-30%.
-- SAFETY: All API calls nil-guarded; falls back to conservative estimates.
-- DECISION: Track last mana-consuming cast; recommend pause when regen value > heal urgency.

local NS = _G.EaxRotations
if not NS then return nil end

local M = {}

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------
local _last_cast_time = 0
local _last_cast_mana_cost = 0
local _fsr_window = 5.0  -- seconds

-- ---------------------------------------------------------------------------
-- API Caching
-- ---------------------------------------------------------------------------
local _time_now = NS.time_now or function() return os.clock() end
local _get_base_regen = nil
local _get_casting_regen = nil

-- Lazy-load API to avoid startup dependency issues
local function ensure_api()
  if _get_base_regen then return true end
  local ok1, br = pcall(function() return core.spell_book.get_base_power_regen end)
  local ok2, cr = pcall(function() return core.spell_book.get_casting_power_regen end)
  if ok1 and br then _get_base_regen = br end
  if ok2 and cr then _get_casting_regen = cr end
  return _get_base_regen ~= nil
end

-- ---------------------------------------------------------------------------
-- Core Functions
-- ---------------------------------------------------------------------------

function M.on_cast(spell_id, mana_cost)
  mana_cost = mana_cost or 0
  if mana_cost > 0 then
    _last_cast_time = _time_now()
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
  if ok1 and ok2 and base and casting then
    return (base - casting) * 5  -- per-tick delta over 5 seconds
  end
  return 0
end

-- Should we pause casting to let FSR tick?
-- @param state table with: mana_pct, lowest_hp_pct, emergency_hp_pct
-- @param context table with settings
-- @return boolean, reason_string
function M.should_pause_for_fsr(state, context)
  if not state then return false, "no state" end

  local mana_pct = state.mana_pct or 100
  local lowest_hp = state.lowest_hp_pct or 100
  local in_combat = state.in_combat or false

  -- Only consider FSR pauses in combat with low mana
  if not in_combat then return false, "not in combat" end
  if mana_pct > 35 then return false, "mana above 35%" end

  -- Never pause if someone is critically low
  local emergency = (context and context.settings and context.settings.fsr_emergency_hp) or 40
  if lowest_hp <= emergency then return false, "emergency heal needed" end

  -- If already outside FSR, no need to pause
  if not M.is_inside_fsr() then return false, "already outside FSR" end

  -- Calculate value of pausing for full FSR tick
  local regen_delta = M.get_regen_delta()
  if regen_delta <= 0 then return false, "no regen delta" end

  -- Only pause if we have time until next heal is needed
  local fsr_remaining = M.seconds_until_fsr()
  if fsr_remaining > 2.0 then return false, "FSR window too long" end

  return true, "pause for FSR regen: " .. string.format("%.0f", regen_delta)
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
