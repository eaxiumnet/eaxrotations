-- hot_tick_tracker_sylvanas.lua -- predict next HoT tick per aura; expose tick-time delta.
-- WHAT:   predict next HoT tick per aura; expose tick-time delta
-- WHEN:   any healer combat
-- WHY:    prevents refreshing HoTs mid-tick (which wipes incoming tick)
-- SAFETY: bounded aura list; throttled recompute
-- DECISION: pure helper consumed via require() by specs; no on_update side-effects.

-- Generic heal-over-time tick progress computation for TBC/Classic.
-- Tracks buff-based HOTs (Renew, Rejuvenation, Regrowth, Lifebloom) by
-- monitoring buff presence via NS.buff_remains and computing tick state.
--
--   local hot = NS.HotTickTracker
--   local state = hot.get(unit, "Renew")
--   -- state = { active=true, remaining=8.5, ticks_elapsed=2, ticks_total=5,
--   --           next_tick_in=1.5, next_tick_progress=0.5 }
--
-- Usage in dashboard or healer specs:
--   local hots = hot.get_all(me)
--   for _, st in ipairs(hots) do
--       print(st.hot_key, st.next_tick_in)
--   end

local _G = _G
local NS = _G.EaxRotations
if not NS then return end

local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local type = type
local pairs = pairs
local ipairs = ipairs

local M = {}
NS.HotTickTracker = M

-- ---------------------------------------------------------------------------
-- HOT registry: TBC/Classic spell IDs, tick intervals, and base durations
-- ---------------------------------------------------------------------------

local HOT_REGISTRY = {
    -- Priest: Renew — 15s duration, 3s tick interval, 5 ticks total
    Renew = {
        spell_ids = {139, 6074, 6075, 6076, 6077, 6078, 10927, 10928, 10929, 25315, 25221, 25222},
        tick_interval = 3.0,
        base_duration = 15.0,
    },
    -- Druid: Rejuvenation — 12s base duration (+3s with Imp. Rejuv), 3s tick, 5 ticks
    -- Use 15s as max expected duration so talented Rejuvs don't break apply_time estimation.
    Rejuvenation = {
        spell_ids = {774, 1058, 1430, 2090, 2091, 3627, 8910, 9839, 9840, 9841, 25299, 26981, 26982},
        tick_interval = 3.0,
        base_duration = 15.0,
    },
    -- Druid: Regrowth — 21s HoT duration, 3s tick, 7 ticks
    Regrowth = {
        spell_ids = {8936, 8938, 8939, 8940, 8941, 9750, 9856, 9857, 9858, 26980},
        tick_interval = 3.0,
        base_duration = 21.0,
    },
    -- Druid: Lifebloom — 7s duration, 1s tick, 7 ticks + bloom at expiration
    Lifebloom = {
        spell_ids = {33763},
        tick_interval = 1.0,
        base_duration = 7.0,
        has_bloom = true,
    },
}

-- ---------------------------------------------------------------------------
-- Internal state: per-unit HOT tracking
-- ---------------------------------------------------------------------------

-- _state[guid][hot_key] = { apply_time = number, last_remains = number,
--                            last_seen = number, refreshed_at = number|nil }
local _state = {}

-- Prune entries for units not seen in a while (party/raid members leaving, etc.)
local _last_prune = 0
local PRUNE_INTERVAL = 30.0
local PRUNE_AGE = 300.0  -- 5 minutes

local function now_s()
    if NS.time_now then
        return NS.time_now()
    end
    local core = _G.core
    if core and core.time then
        return core.time()
    end
    return 0
end

local function unit_guid(unit)
    if not unit then return nil end
    local ok, value = pcall(function()
        local fn = unit.get_guid or unit.guid or unit.GetGUID
        if type(fn) == "function" then return fn(unit) end
        return unit.guid or unit.id or tostring(unit)
    end)
    if ok and value then return tostring(value) end
    return tostring(unit)
end

local function get_buff_remains(unit, spell_ids)
    if not unit or not spell_ids then return 0 end
    local max_rem = 0
    for _, id in ipairs(spell_ids) do
        local rem = 0
        if NS.buff_remains then
            rem = NS.buff_remains(unit, id) or 0
        end
        if type(rem) == "number" and rem > max_rem then
            max_rem = rem
        end
    end
    return max_rem
end

local function prune_stale_state()
    local now = now_s()
    if now - _last_prune < PRUNE_INTERVAL then return end
    _last_prune = now
    for guid, unit_state in pairs(_state) do
        for hot_key, st in pairs(unit_state) do
            if type(st.last_seen) == "number" and (now - st.last_seen) >= PRUNE_AGE then
                unit_state[hot_key] = nil
            end
        end
        -- Remove empty unit entries
        local any_left = false
        for _ in pairs(unit_state) do
            any_left = true
            break
        end
        if not any_left then
            _state[guid] = nil
        end
    end
end

-- ---------------------------------------------------------------------------
-- Core computation
-- ---------------------------------------------------------------------------

--- Compute HOT tick state for a single HOT on a unit.
-- @param unit     game_object
-- @param hot_key  string  Key from HOT_REGISTRY (e.g. "Renew")
-- @return table|nil  State table or nil if HOT not active.
function M.get(unit, hot_key)
    if not unit or not hot_key then return nil end
    local config = HOT_REGISTRY[hot_key]
    if not config then return nil end

    prune_stale_state()

    local now = now_s()
    local guid = unit_guid(unit)
    if not guid then return nil end

    local remains = get_buff_remains(unit, config.spell_ids)
    if remains <= 0 then
        -- HOT faded — clear state
        local unit_state = _state[guid]
        if unit_state then
            unit_state[hot_key] = nil
        end
        return nil
    end

    -- Initialize or update tracking state
    local unit_state = _state[guid]
    if not unit_state then
        unit_state = {}
        _state[guid] = unit_state
    end

    local st = unit_state[hot_key]
    if not st then
        -- Newly detected HOT — conservative apply_time = now.
        -- Using base_duration to back-calculate apply_time is inaccurate when talents
        -- modify duration (e.g. Improved Rejuvenation). Starting from now makes
        -- ticks_elapsed accurate going forward; next_tick_in is at most one
        -- tick_interval off initially and self-corrects quickly.
        st = {
            apply_time = now,
            last_remains = remains,
            last_seen = now,
        }
        unit_state[hot_key] = st
    else
        -- Detect refresh: remaining increased significantly
        if remains > st.last_remains + 1.0 then
            st.apply_time = now - (config.base_duration - remains)
        end
        st.last_remains = remains
        st.last_seen = now
    end

    -- Compute elapsed and tick state
    local elapsed = now - st.apply_time
    if elapsed < 0 then elapsed = 0 end

    local tick_interval = config.tick_interval
    local ticks_elapsed = math_floor(elapsed / tick_interval)
    local next_tick_in = tick_interval - (elapsed % tick_interval)
    if next_tick_in <= 0 then next_tick_in = tick_interval end

    local total_duration = config.base_duration
    local ticks_total = math_floor(total_duration / tick_interval)

    -- For Lifebloom, the bloom is the "final tick" at expiration
    local bloom_in = nil
    local bloom_progress = nil
    if config.has_bloom then
        bloom_in = remains
        bloom_progress = math_min(1, math_max(0, elapsed / total_duration))
    end

    return {
        active = true,
        remaining = remains,
        elapsed = elapsed,
        ticks_elapsed = ticks_elapsed,
        ticks_total = ticks_total,
        next_tick_in = next_tick_in,
        next_tick_progress = 1.0 - (next_tick_in / tick_interval),
        bloom_in = bloom_in,
        bloom_progress = bloom_progress,
        hot_key = hot_key,
    }
end

--- Returns all active HOT states on `unit`.
-- @param unit game_object
-- @return table  Array of state tables.
function M.get_all(unit)
    if not unit then return {} end
    local out = {}
    local count = 0
    for hot_key in pairs(HOT_REGISTRY) do
        local st = M.get(unit, hot_key)
        if st then
            count = count + 1
            out[count] = st
        end
    end
    return out
end

--- Returns true if the specified HOT is active on `unit`.
-- @param unit    game_object
-- @param hot_key string
-- @return boolean
function M.is_active(unit, hot_key)
    local st = M.get(unit, hot_key)
    return st ~= nil
end

--- Returns seconds until next tick, or nil if HOT not active.
-- @param unit    game_object
-- @param hot_key string
-- @return number|nil
function M.next_tick_in(unit, hot_key)
    local st = M.get(unit, hot_key)
    return st and st.next_tick_in or nil
end

--- Returns seconds until bloom, or nil if HOT has no bloom mechanic.
-- @param unit    game_object
-- @param hot_key string
-- @return number|nil
function M.bloom_in(unit, hot_key)
    local st = M.get(unit, hot_key)
    return st and st.bloom_in or nil
end

--- Clears all internal state (call on zone change or /reload).
function M.clear()
    for k in pairs(_state) do _state[k] = nil end
end

NS.log("HotTickTracker module loaded")
return M
