-- hit_cap_tracker_sylvanas.lua — Hit cap / expertise / haste awareness for TBC DPS.
-- WHAT:  Provides hit-cap thresholds and haste-breakpoint data for all TBC DPS specs.
-- WHEN:  Used by DPS specs to gate abilities or recommend gear priorities.
-- WHY:   TBC hit cap is 9% (142 rating) for melee vs +3 bosses, 16% for casters;
--        expertise reduces dodge/parry; haste breakpoints affect dot ticks.
-- SAFETY: All lookups nil-guarded; returns conservative defaults if no data.
-- DECISION: Static tables per spec (TBC values are fixed), not dynamic API queries.

local NS = _G.EaxRotations
if not NS then return nil end

local M = {}

-- ---------------------------------------------------------------------------
-- TBC Hit / Expertise / Haste Constants (vs boss-level target, +3 levels)
-- ---------------------------------------------------------------------------

-- Hit rating conversion: 15.77 rating = 1% hit (at level 70)
local HIT_RATING_PER_PCT = 15.77

-- Expertise rating conversion: 3.94 rating = 1 expertise = -0.25% dodge/parry
local EXPERTISE_RATING_PER_PT = 3.94

-- Haste rating conversion: 15.77 rating = 1% haste
local HASTE_RATING_PER_PCT = 15.77

-- Hit caps by class/spec role
local HIT_CAPS = {
  -- Melee / physical DPS
  warrior_melee  = { pct = 9,  rating = 142 }, -- dual-wield penalty handled separately
  rogue_melee    = { pct = 9,  rating = 142 },
  hunter_ranged  = { pct = 9,  rating = 142 }, -- ranged uses same table
  paladin_melee  = { pct = 9,  rating = 142 },
  shaman_melee   = { pct = 9,  rating = 142 },
  druid_feral    = { pct = 9,  rating = 142 },
  -- Caster DPS
  mage_caster    = { pct = 16, rating = 202 }, -- 16% vs +3 level
  warlock_caster = { pct = 16, rating = 202 },
  priest_caster  = { pct = 16, rating = 202 },
  druid_balance  = { pct = 16, rating = 202 },
  shaman_caster  = { pct = 16, rating = 202 },
  paladin_caster = { pct = 16, rating = 202 },
}

-- Expertise soft cap (removes dodge from boss front): 26 expertise = 6.5%
local EXPERTISE_SOFT_CAP = { expertise = 26, rating = math.floor(26 * EXPERTISE_RATING_PER_PT) }

-- Expertise hard cap (removes parry from boss front): 56 expertise = 14%
local EXPERTISE_HARD_CAP = { expertise = 56, rating = math.floor(56 * EXPERTISE_RATING_PER_PT) }

-- Haste breakpoints (snapshot for TBC — minimal breakpoints compared to Wrath)
-- TBC has very few meaningful haste breakpoints; most specs just stack haste.
local HASTE_SNAPSHOTS = {
  -- Priest Shadow: VT + SW:P dot tick intervals scale linearly; no hard breakpoints.
  -- Mage Fire: Living Bomb (if available) and Pyroblast cast time reductions.
  -- Warlock Affliction: UA + Corruption + Siphon Life tick intervals.
  -- Generally in TBC haste is linear; breakpoints only matter for "one extra tick"
  -- which is rare at TBC gear levels. We return nil to indicate "stack freely".
}

-- ---------------------------------------------------------------------------
-- Core API
-- ---------------------------------------------------------------------------

-- Get hit cap info for a spec key (e.g., "warrior_melee")
function M.get_hit_cap(spec_key)
  local cap = HIT_CAPS[spec_key]
  if not cap then return nil end
  return {
    pct_needed    = cap.pct,
    rating_needed = cap.rating,
    rating_per_pct = HIT_RATING_PER_PCT,
  }
end

-- Get expertise cap info
function M.get_expertise_cap()
  return {
    soft_expertise  = EXPERTISE_SOFT_CAP.expertise,
    soft_rating     = EXPERTISE_SOFT_CAP.rating,
    hard_expertise  = EXPERTISE_HARD_CAP.expertise,
    hard_rating     = EXPERTISE_HARD_CAP.rating,
    rating_per_pt   = EXPERTISE_RATING_PER_PT,
  }
end

-- Check if current hit rating meets cap (placeholder — real impl needs gear API)
-- @param spec_key string — e.g., "warrior_melee"
-- @param current_hit_rating number — from gear inspection or cached value
function M.is_hit_capped(spec_key, current_hit_rating)
  local cap = M.get_hit_cap(spec_key)
  if not cap or not current_hit_rating then return false end
  return current_hit_rating >= cap.rating_needed
end

-- Check if current expertise meets soft cap
function M.is_expertise_soft_capped(current_expertise_rating)
  if not current_expertise_rating then return false end
  return current_expertise_rating >= EXPERTISE_SOFT_CAP.rating
end

-- Recommend ability gating based on hit cap (for specs that want to skip "missable" CDs when uncapped)
-- @return boolean — true = caution warranted, false = hit cap likely met
function M.should_caution_missable(spec_key, current_hit_rating)
  if not spec_key then return false end
  local cap = M.get_hit_cap(spec_key)
  if not cap then return false end
  if not current_hit_rating then
    -- No data available → conservative: assume capped to avoid nagging
    return false
  end
  -- If significantly below cap (>30 rating deficit), suggest caution
  local deficit = cap.rating_needed - current_hit_rating
  return deficit > 30
end

-- Return a human-readable summary for logging / debug
function M.summary(spec_key, current_hit_rating, current_expertise_rating)
  local cap = M.get_hit_cap(spec_key)
  local expertise = M.get_expertise_cap()
  local parts = {}
  if cap then
    local status = (current_hit_rating and current_hit_rating >= cap.rating_needed) and "MET" or "NEEDED"
    parts[#parts+1] = string.format("Hit: %d/%d rating (%s)", current_hit_rating or 0, cap.rating_needed, status)
  else
    parts[#parts+1] = "Hit: unknown spec"
  end
  if expertise then
    local status = (current_expertise_rating and current_expertise_rating >= expertise.soft_rating) and "SOFT-MET" or "NEEDED"
    parts[#parts+1] = string.format("Expertise: %d/%d rating (%s)", current_expertise_rating or 0, expertise.soft_rating, status)
  end
  return table.concat(parts, " | ")
end

-- ---------------------------------------------------------------------------
-- Export
-- ---------------------------------------------------------------------------
NS.HitCapTracker = M
return M
