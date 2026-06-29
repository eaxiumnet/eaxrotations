-- healer_deficit_sylvanas.lua -- predictive healing-deficit tracker per heal target
-- WHAT:  track per-party-member incoming-damage vs incoming-heal gap
-- WHEN:  any healer combat
-- WHY:   centralizes triage so healers spec only the deficit list
-- SAFETY: bounded party scan (<=5); nil-guard on buff/debuff lookups

-- Predictive Healing Deficit Tracker (EaxRotations)
-- What: Estimates future health deficit by tracking per-unit HP samples and
--       projecting damage intake over a configurable horizon.
-- When: Called from build_healing_entries and healer specs every tick.
-- Why:  Stops healers from casting on targets whose incoming damage will be
--       covered by existing HoTs/shields, or from overhealing with big casts.
-- Safety: All math is nil-guarded; disabled pass-through when off.
-- Decision: Uses simple delta-rate instead of linear regression because
--           healers need responsiveness, not long-term trend smoothing.

local _G = _G
local NS = _G.EaxRotations
if not NS then return end

local math_max = math.max
local math_min = math.min
local type = type
local pairs = pairs
local tostring = tostring

local M = {}
NS.HealerDeficit = M

-- Per-unit HP history: keyed by unit GUID string.
-- _samples[guid] = { n = count, { t = timestamp, hp = hp_percent }, ... }
local _samples = {}
local _last_sample_time = {}
local _unit_guid_cache = {}

local DEFAULT_SAMPLE_INTERVAL = 0.5   -- seconds between HP samples
local DEFAULT_WINDOW = 4.0            -- seconds of history to keep
local DEFAULT_HORIZON = 2.0           -- seconds to project forward
local DEFAULT_SAFETY_PCT = 5.0        -- extra % max HP safety margin
local DEFAULT_MIN_RATE = 1.0          -- min HP% loss per second to trust
local DEFAULT_MAX_DEFICIT_MULT = 1.5  -- cap predicted deficit at 1.5x current
local STALE_TTL = 30.0                -- purge units not seen in 30s
local _last_prune_stale_time = 0      -- throttle global stale prune to once per second

-- Conservative TBC average heal sizes (base + moderate +heal, no crit).
-- Used by gate_spell_overheal when the caller doesn't know the exact rank.
local HEAL_SIZE_TBC = {
    GreaterHeal    = 3500,  -- ~2400 base + 1.0 coeff * 1000 +heal
    FlashHeal      = 1500,  -- ~1100 base + 0.43 coeff * 1000 +heal
    ChainHeal      = 1200,  -- ~520 base + 0.71 coeff * 1000 first target
    PrayerOfHealing=  700,  -- ~410 base + 0.241 coeff * 1000 per target
    BindingHeal    = 1800,  -- ~1050 base + 0.5 coeff * 1500 +heal (both targets)
    HealingWave    = 2500,  -- ~1600 base + 0.857 coeff * 1000 +heal
    LesserHealingWave = 1000, -- ~800 base + 0.428 coeff * 500 +heal
    -- Paladin TBC heals
    HolyLight      = 3000,  -- ~2100 base + 0.857 coeff * 1000 +heal (rank 11)
    FlashOfLight   = 1200,  -- ~800 base + 0.43 coeff * 1000 +heal (rank 7)
    HolyShock      =  900,  -- ~600 base + 0.43 coeff * 700 +heal (rank 7)
    -- Druid TBC heals
    HealingTouch   = 3000,  -- ~2000 base + 1.0 coeff * 1000 +heal (rank 12)
    Regrowth       = 1500,  -- ~1000 base + 1.0 coeff * 500 +heal (rank 8)
    -- AoE heals
    CircleOfHealing=  600,  -- ~400 base + 0.241 coeff * 800 +heal per target
}

-- ---------------------------------------------------------------------------
-- Internal helpers
-- ---------------------------------------------------------------------------

local function unit_guid(unit)
    if not unit then return nil end
    local guid = _unit_guid_cache[unit]
    if guid then return guid end
    local ok, value = pcall(function()
        local fn = unit.get_guid or unit.guid or unit.GetGUID
        if type(fn) == "function" then return fn(unit) end
        return unit.guid or unit.id or tostring(unit)
    end)
    if ok and value then
        guid = tostring(value)
        _unit_guid_cache[unit] = guid
        return guid
    end
    -- Fallback: use tostring of the object itself
    guid = tostring(unit)
    _unit_guid_cache[unit] = guid
    return guid
end

local function get_hp_percent(unit)
    if not unit then return nil end
    local pct = NS.unit_health_pct and NS.unit_health_pct(unit)
    if type(pct) == "number" then
        -- Clamp to valid range to avoid garbage from broken APIs
        if pct < 0 then pct = 0 end
        if pct > 100 then pct = 100 end
        return pct
    end
    return nil
end

local function prune_stale(now, ttl)
    ttl = ttl or STALE_TTL
    for guid, last in pairs(_last_sample_time) do
        if (now - last) > ttl then
            _samples[guid] = nil
            _last_sample_time[guid] = nil
        end
    end
end

local function prune_old_samples(guid, now, window)
    local hist = _samples[guid]
    if not hist then return end
    local cutoff = now - window
    local write_i = 1
    for i = 1, hist.n do
        local s = hist[i]
        if s and s.t >= cutoff then
            if write_i ~= i then
                hist[write_i] = s
                hist[i] = nil
            end
            write_i = write_i + 1
        else
            hist[i] = nil
        end
    end
    hist.n = write_i - 1
    if hist.n == 0 then
        _samples[guid] = nil
        _last_sample_time[guid] = nil
    end
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

--- Samples the unit's current HP% if the throttle interval has elapsed.
--@param unit   game_object  The friendly unit to track.
--@param now    number       Current time in seconds (NS.time_now()).
--@param settings table|nil  Optional settings override.
function M.update(unit, now, settings)
    if not unit then return end
    local guid = unit_guid(unit)
    if not guid then return end

    settings = settings or (NS.settings or {})
    if settings.healer_predict_enabled == false then return end

    local interval = (settings.healer_predict_sample_interval and settings.healer_predict_sample_interval / 10) or DEFAULT_SAMPLE_INTERVAL

    local last = _last_sample_time[guid]
    if last and (now - last) < interval then return end

    local hp = get_hp_percent(unit)
    if not hp then return end

    local hist = _samples[guid]
    if not hist then
        hist = { n = 0 }
        _samples[guid] = hist
    end

    -- Deduplicate identical consecutive samples to reduce noise
    local last_sample = hist[hist.n]
    if last_sample and last_sample.hp == hp then
        -- Advance timestamp so rate calculation uses the correct window
        last_sample.t = now
        _last_sample_time[guid] = now
        -- Still prune so stale samples don't accumulate while HP stays flat
        local window = settings.healer_predict_window or DEFAULT_WINDOW
        prune_old_samples(guid, now, window)
        return
    end

    hist.n = hist.n + 1
    hist[hist.n] = { t = now, hp = hp }
    _last_sample_time[guid] = now

    local window = settings.healer_predict_window or DEFAULT_WINDOW
    prune_old_samples(guid, now, window)
    -- Throttle global stale prune to ~1 Hz to avoid O(N^2) in large raids.
    if now - _last_prune_stale_time >= 1.0 then
        prune_stale(now)
        _last_prune_stale_time = now
    end
end

--- Computes the health-loss rate (% per second) for a unit over the recent window.
-- Returns nil when there are insufficient samples or the rate is too low.
--@param unit     game_object
--@param settings table|nil
--@return number|nil rate  HP% loss per second (positive = losing health).
function M.get_damage_rate(unit, settings)
    if not unit then return nil end
    local guid = unit_guid(unit)
    if not guid then return nil end

    local hist = _samples[guid]
    if not hist or hist.n < 2 then return nil end

    local first = hist[1]
    local last = hist[hist.n]
    local dt = last.t - first.t
    if dt <= 0 then return nil end

    local dhp = first.hp - last.hp  -- positive = health dropped
    local rate = dhp / dt

    settings = settings or (NS.settings or {})
    local min_rate = settings.healer_predict_min_rate or DEFAULT_MIN_RATE
    if rate < min_rate then return nil end

    return rate
end

--- Returns the predicted effective deficit after `horizon_seconds`.
-- This is: current_deficit + predicted_damage_over_horizon + safety_margin.
--@param unit            game_object
--@param horizon_seconds number   Seconds to look ahead (e.g. cast time).
--@param settings        table|nil
--@return number predicted_deficit  Absolute HP missing at horizon, >= 0.
function M.predicted_deficit(unit, horizon_seconds, settings)
    if not unit then return 0 end
    horizon_seconds = type(horizon_seconds) == "number" and horizon_seconds or DEFAULT_HORIZON
    if horizon_seconds <= 0 then horizon_seconds = DEFAULT_HORIZON end

    -- IZI SDK fast path: use engine-provided incoming damage when available
    local izi_incoming = 0
    do
        local ok, val = pcall(function()
            if type(unit.get_incoming_damage) == "function" then
                return unit:get_incoming_damage(horizon_seconds)
            end
            return nil
        end)
        if ok and type(val) == "number" and val > 0 then
            izi_incoming = val
        end
    end

    -- Baseline deficit from engine APIs (current missing HP minus known heals/shields)
    local base_deficit = 0
    local hp = 0
    local max_hp = 0
    local incoming = 0
    local absorbs = 0
    do
        local ok, val = pcall(function()
            local fn = unit.get_health
            return type(fn) == "function" and fn(unit) or 0
        end)
        if ok and type(val) == "number" then hp = val end
    end
    do
        local ok, val = pcall(function()
            local fn = unit.get_max_health
            return type(fn) == "function" and fn(unit) or 0
        end)
        if ok and type(val) == "number" and val > 0 then max_hp = val end
    end
    if max_hp <= 0 then max_hp = hp end
    do
        local ok, val = pcall(function()
            local fn = unit.get_incoming_heals
            return type(fn) == "function" and fn(unit) or 0
        end)
        if ok and type(val) == "number" then incoming = val end
    end
    do
        local ok, val = pcall(function()
            local fn = unit.get_total_shield
            return type(fn) == "function" and fn(unit) or 0
        end)
        if ok and type(val) == "number" then absorbs = val end
    end
    -- Fallback/enhancement: predicted incoming heals from party cast scanning
    if incoming <= 0 and NS.IncomingHeals and NS.IncomingHeals.get then
        local ok2, pred = pcall(NS.IncomingHeals.get, unit)
        if ok2 and type(pred) == "number" and pred > 0 then
            incoming = pred
        end
    end
    base_deficit = math_max(0, max_hp - hp - incoming - absorbs)

    settings = settings or (NS.settings or {})
    if settings.healer_predict_enabled == false then return base_deficit end

    -- Determine max HP once for conversion and cap
    local max_hp_for_math = max_hp  -- already computed for base_deficit
    if max_hp_for_math <= 0 then
        local ok, max_hp_val = pcall(function()
            local fn = unit.get_max_health
            if type(fn) == "function" then return fn(unit) end
            return 1
        end)
        if ok and type(max_hp_val) == "number" and max_hp_val > 0 then
            max_hp_for_math = max_hp_val
        else
            max_hp_for_math = 1
        end
    end

    -- Add predicted damage: prefer IZI SDK incoming damage, fall back to manual rate
    local predicted_extra = 0
    if izi_incoming > 0 then
        predicted_extra = izi_incoming
    else
        local rate = M.get_damage_rate(unit, settings)
        if rate then
            -- rate is in % per second; convert to absolute HP
            local hp_per_pct = max_hp_for_math / 100
            predicted_extra = rate * horizon_seconds * hp_per_pct
        end
    end

    -- Cap predicted extra so we don't claim infinite deficit
    do
        local mult = (settings.healer_predict_max_mult and settings.healer_predict_max_mult / 10) or DEFAULT_MAX_DEFICIT_MULT
        local cap = base_deficit * mult + (max_hp_for_math * 0.5)  -- generous ceiling
        if predicted_extra > cap then predicted_extra = cap end
    end

    -- Safety margin (% of max HP converted to absolute)
    local safety_pct = settings.healer_predict_safety_pct or DEFAULT_SAFETY_PCT
    local safety_abs = max_hp_for_math * (safety_pct / 100)

    return math_max(0, base_deficit + predicted_extra + safety_abs)
end

--- Convenience gate: returns true if the named spell would overheal on `unit`.
-- Looks up a conservative TBC average heal size and defers to heal_would_overheal.
--@param spell_key string   Key from HEAL_SIZE_TBC (e.g. "GreaterHeal", "ChainHeal").
--@param unit      game_object
--@param cast_time number   Seconds until heal lands.
--@param settings  table|nil
--@return boolean would_overheal
function M.gate_spell_overheal(spell_key, unit, cast_time, settings)
    if not unit then return false end
    settings = settings or (NS.settings or {})
    if settings.healer_predict_enabled == false then return false end
    local size = spell_key and HEAL_SIZE_TBC[spell_key]
    if not size then return false end
    return M.heal_would_overheal(unit, size, cast_time, settings)
end

--- Returns true if casting a heal of `heal_size` on `unit` would result in overhealing.
-- Accounts for current HP, known incoming heals/shields, and predicted damage during cast.
--@param unit      game_object
--@param heal_size number   Expected heal amount (absolute HP).
--@param cast_time number   Seconds until heal lands.
--@param settings  table|nil
--@return boolean would_overheal
function M.heal_would_overheal(unit, heal_size, cast_time, settings)
    if not unit or type(heal_size) ~= "number" or heal_size <= 0 then return true end
    cast_time = type(cast_time) == "number" and cast_time or DEFAULT_HORIZON

    settings = settings or (NS.settings or {})
    if settings.healer_predict_enabled == false then
        -- Simple check: would heal push above max?
        local max_hp = 1
        local current_hp = 0
        do
            local ok, val = pcall(function()
                local fn = unit.get_max_health
                return type(fn) == "function" and fn(unit) or 1
            end)
            if ok and type(val) == "number" and val > 0 then max_hp = val end
        end
        do
            local ok, val = pcall(function()
                local fn = unit.get_health
                return type(fn) == "function" and fn(unit) or 0
            end)
            if ok and type(val) == "number" then current_hp = val end
        end
        return (current_hp + heal_size) > max_hp
    end

    local predicted_missing = M.predicted_deficit(unit, cast_time, settings)
    -- predicted_missing is absolute missing HP at cast landing time
    -- If heal_size > predicted_missing, some portion is waste
    local overheal = heal_size - predicted_missing
    if overheal <= 0 then return false end

    -- Allow a small tolerance (5% of heal) so rounding doesn't block legitimate heals
    local tolerance = heal_size * 0.05
    return overheal > tolerance
end

--- Clears all tracked history (e.g. on zone change or /reload).
function M.clear()
    for k in pairs(_samples) do _samples[k] = nil end
    for k in pairs(_last_sample_time) do _last_sample_time[k] = nil end
    for k in pairs(_unit_guid_cache) do _unit_guid_cache[k] = nil end
    _last_prune_stale_time = 0
end

NS.log("HealerDeficit module loaded")
return M
