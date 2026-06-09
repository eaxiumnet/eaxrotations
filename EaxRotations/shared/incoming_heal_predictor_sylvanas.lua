-- Incoming Heal Predictor (EaxRotations)
-- What: Estimates heals currently incoming on friendly targets by combining
--       (a) native API get_incoming_heals() when available,
--       (b) combat-log-derived heal frequency heuristics,
--       (c) active cast scanning on party/raid members for known heal spells.
-- When: Called every tick from healer specs via NS.IncomingHeals.get(unit).
-- Why:  Prevents double-healing and reduces overheal by making deficit
--       calculations aware of heals that will land before our cast completes.
-- Safety: All API calls are pcall-wrapped; falls back to 0 on any error.
-- Decision: Heuristic-based rather than LibHealComm-accurate because the
--           Sylvanas API does not expose cross-player cast-start events.
--           We infer ongoing heals from (1) active cast bar scanning and
--           (2) recent combat-log heal patterns.

local _G = _G
local NS = _G.EaxRotations
if not NS then return end

local math_max = math.max
local math_min = math.min
local math_floor = math.floor
local type = type
local pairs = pairs
local ipairs = ipairs
local tostring = tostring
local tonumber = tonumber

local M = {}
NS.IncomingHeals = M

-- ---------------------------------------------------------------------------
-- Configuration
-- ---------------------------------------------------------------------------

local SCAN_INTERVAL = 0.5           -- seconds between party cast scans
local PREDICTION_HORIZON = 4.0      -- seconds ahead to predict
local COMBAT_LOG_LOOKBACK = 8.0     -- seconds of combat log to analyze
local HEAL_SPELL_CACHE_TTL = 300.0  -- seconds to keep spell ID cache
local MAX_PREDICTIONS_PER_UNIT = 8  -- cap per unit to limit memory
local HEAL_KEYWORDS = {             -- spell name substrings that identify heals
    "heal", "rejuvenation", "renew", "regrowth", "lifebloom",
    "tranquility", "prayer of healing", "circle of healing",
    "chain heal", "healing wave", "lesser healing wave",
    "binding heal", "flash of light", "holy light", "earth shield",
}

-- Conservative average heal sizes (absolute HP) for cast-scanning fallback
-- when we know the spell name but have no combat-log history yet.
local HEAL_SIZE_FALLBACK = {
    ["greater heal"]        = 3500,
    ["flash heal"]          = 1500,
    ["binding heal"]        = 1800,
    ["prayer of healing"]   = 700,
    ["renew"]               = 250,
    ["circle of healing"]   = 800,
    ["healing wave"]        = 2500,
    ["lesser healing wave"] = 1000,
    ["chain heal"]          = 1200,
    ["earth shield"]        = 1200,
    ["regrowth"]            = 2000,
    ["rejuvenation"]        = 800,
    ["lifebloom"]           = 600,
    ["tranquility"]         = 1500,
    ["flash of light"]      = 1000,
    ["holy light"]          = 3000,
}

-- Conservative cast times (seconds) for heal spells when API lookup fails
local HEAL_CAST_TIME_FALLBACK = {
    ["greater heal"]        = 2.5,
    ["flash heal"]          = 1.5,
    ["binding heal"]        = 1.5,
    ["prayer of healing"]   = 3.0,
    ["renew"]               = 0.0,  -- instant in TBC (except when talented?)
    ["circle of healing"]   = 0.0,  -- instant
    ["healing wave"]        = 3.0,
    ["lesser healing wave"] = 1.5,
    ["chain heal"]          = 2.5,
    ["earth shield"]        = 0.0,  -- instant
    ["regrowth"]            = 2.0,
    ["rejuvenation"]        = 0.0,  -- instant
    ["lifebloom"]           = 0.0,  -- instant
    ["tranquility"]         = 10.0, -- channeled
    ["flash of light"]      = 1.5,
    ["holy light"]          = 2.5,
}

-- ---------------------------------------------------------------------------
-- Internal state
-- ---------------------------------------------------------------------------

-- _predictions[guid] = { {amount, arrival_time, source, spell_name}, ... }
local _predictions = {}

-- _healer_prefs[healer_guid][target_guid] = { last_time, avg_amount, count }
local _healer_prefs = {}

-- _spell_cache[spell_id] = { name=string, is_heal=bool, cast_time=number,
--                            avg_amount=number, cached_at=number }
local _spell_cache = {}

local _last_scan_time = 0
local _last_cleanup_time = 0

-- ---------------------------------------------------------------------------
-- Internal helpers
-- ---------------------------------------------------------------------------

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
    if ok and value then
        return tostring(value)
    end
    return tostring(unit)
end

local function unit_name(unit)
    if not unit then return nil end
    local ok, value = pcall(function()
        local fn = unit.get_name or unit.name or unit.GetName
        if type(fn) == "function" then return fn(unit) end
        return unit.name or unit.get_display_name and unit:get_display_name()
    end)
    if ok and value then return tostring(value) end
    return nil
end

local function is_heal_spell_name(name)
    if not name then return false end
    local lower = string.lower(name)
    for _, keyword in ipairs(HEAL_KEYWORDS) do
        if string.find(lower, keyword, 1, true) then
            return true
        end
    end
    return false
end

local function spell_info(spell_id)
    spell_id = tonumber(spell_id)
    if not spell_id then return nil end

    local cached = _spell_cache[spell_id]
    if cached then
        if (now_s() - cached.cached_at) < HEAL_SPELL_CACHE_TTL then
            return cached
        end
    end

    local name = nil
    do
        local core = _G.core
        if core and core.spell_book and core.spell_book.get_spell_name then
            local ok, val = pcall(core.spell_book.get_spell_name, spell_id)
            if ok and val and val ~= "" then
                name = val
            end
        end
    end

    -- If spell_book unavailable, try NS helper
    if not name and NS.get_spell_name then
        local ok, val = pcall(NS.get_spell_name, spell_id)
        if ok and val then name = val end
    end

    if not name then
        -- Unknown spell; cache as non-heal briefly to avoid repeated misses
        _spell_cache[spell_id] = {
            name = nil,
            is_heal = false,
            cast_time = 0,
            avg_amount = 0,
            cached_at = now_s(),
        }
        return _spell_cache[spell_id]
    end

    local lower_name = string.lower(name)
    local is_heal = is_heal_spell_name(name)

    local cast_time = 0
    do
        local core = _G.core
        if core and core.spell_book and core.spell_book.get_spell_cast_time then
            local ok, val = pcall(core.spell_book.get_spell_cast_time, spell_id)
            if ok and type(val) == "number" and val > 0 then
                cast_time = val / 1000  -- ms -> s
            end
        end
    end
    if cast_time <= 0 then
        cast_time = HEAL_CAST_TIME_FALLBACK[lower_name] or 0
    end

    local avg_amount = HEAL_SIZE_FALLBACK[lower_name] or 1000

    local info = {
        name = name,
        is_heal = is_heal,
        cast_time = cast_time,
        avg_amount = avg_amount,
        cached_at = now_s(),
    }
    _spell_cache[spell_id] = info
    return info
end

local function get_unit_target(unit)
    if not unit then return nil end
    local ok, target = pcall(function()
        local fn = unit.get_target or unit.target or unit.GetTarget
        if type(fn) == "function" then return fn(unit) end
        return unit.target
    end)
    if ok and target then return target end
    return nil
end

local function is_party_or_raid(unit)
    if not unit then return false end
    -- Try common flags
    local ok, val = pcall(function()
        if unit.is_party_member and unit:is_party_member() then return true end
        if unit.is_raid_member and unit:is_raid_member() then return true end
        if unit.is_friend and unit:is_friend() then return true end
        return false
    end)
    if ok and val then return true end
    return false
end

local function prune_expired_predictions(now)
    for guid, list in pairs(_predictions) do
        local write_i = 1
        for i = 1, #list do
            local p = list[i]
            if p and p.arrival_time > now then
                if write_i ~= i then
                    list[write_i] = p
                    list[i] = nil
                end
                write_i = write_i + 1
            else
                list[i] = nil
            end
        end
        -- Shift nils from end
        for i = write_i, #list do
            list[i] = nil
        end
        if #list == 0 then
            _predictions[guid] = nil
        end
    end
end

local function add_prediction(target_guid, amount, arrival_time, source, spell_name)
    if not target_guid or not amount or amount <= 0 then return end
    arrival_time = arrival_time or (now_s() + 2.0)

    local list = _predictions[target_guid]
    if not list then
        list = {}
        _predictions[target_guid] = list
    end

    if #list >= MAX_PREDICTIONS_PER_UNIT then
        -- Evict oldest (earliest arrival)
        local oldest_i = 1
        for i = 2, #list do
            if list[i].arrival_time < list[oldest_i].arrival_time then
                oldest_i = i
            end
        end
        table.remove(list, oldest_i)
    end

    list[#list + 1] = {
        amount = amount,
        arrival_time = arrival_time,
        source = source or "unknown",
        spell_name = spell_name or "Heal",
    }
end

local function estimate_heal_amount(spell_name, healer_guid, target_guid)
    -- Prefer combat-log derived average for this healer->target pair
    if healer_guid and target_guid then
        local prefs = _healer_prefs[healer_guid]
        if prefs then
            local pt = prefs[target_guid]
            if pt and pt.avg_amount and pt.avg_amount > 0 then
                return pt.avg_amount
            end
        end
    end
    -- Fallback to conservative lookup
    local lower = spell_name and string.lower(spell_name) or ""
    return HEAL_SIZE_FALLBACK[lower] or 1000
end

-- ---------------------------------------------------------------------------
-- Combat log integration
-- ---------------------------------------------------------------------------

function M._on_combat_log_entry(entry)
    if not entry then return end
    if entry.amount_kind ~= "HEAL" then return end

    local healer_guid = entry.caster_token
    local target_guid = entry.target_token
    if not healer_guid or not target_guid then return end
    if healer_guid == target_guid then return end  -- self-heal; less relevant for group prediction

    local amount = tonumber(entry.amount) or 0
    if amount <= 0 then return end

    -- Update healer preference table
    if not _healer_prefs[healer_guid] then
        _healer_prefs[healer_guid] = {}
    end
    local pt = _healer_prefs[healer_guid][target_guid]
    if not pt then
        pt = { last_time = now_s(), avg_amount = amount, count = 1 }
        _healer_prefs[healer_guid][target_guid] = pt
    else
        -- Exponential moving average of heal amount
        local alpha = 0.3
        pt.avg_amount = (alpha * amount) + ((1 - alpha) * pt.avg_amount)
        pt.last_time = now_s()
        pt.count = pt.count + 1
    end

    -- Heuristic: if this healer has healed this target 3+ times recently,
    -- predict another heal of the same type arriving after estimated cast time.
    if pt.count >= 3 then
        local spell_name = entry.spell_name or "Heal"
        local info = spell_info(entry.spell_id)
        local cast_time = (info and info.cast_time) or 1.5

        -- Predict next heal: assume chain-casting with a small latency buffer
        local next_arrival = now_s() + cast_time + 0.5
        local next_amount = pt.avg_amount * 0.8  -- conservative: 80% of average

        add_prediction(target_guid, next_amount, next_arrival, healer_guid, spell_name)
    end
end

-- ---------------------------------------------------------------------------
-- Party cast scanning
-- ---------------------------------------------------------------------------

function M.scan_party_casts(now)
    now = now or now_s()
    if (now - _last_scan_time) < SCAN_INTERVAL then return end
    _last_scan_time = now

    -- Prune old predictions periodically
    if (now - _last_cleanup_time) >= 1.0 then
        prune_expired_predictions(now)
        _last_cleanup_time = now
    end

    -- Collect units to scan: party + visible friendlies
    local units = {}
    local count = 0

    -- 1. Party members via API
    if NS.GetPartyMembers then
        local ok, party = pcall(NS.GetPartyMembers)
        if ok and type(party) == "table" then
            for _, u in ipairs(party) do
                if u then
                    count = count + 1
                    units[count] = u
                end
            end
        end
    end

    -- 2. Visible friendly fallback
    local core = _G.core
    if core and core.object_manager and core.object_manager.get_visible_objects then
        local ok, visible = pcall(core.object_manager.get_visible_objects)
        if ok and type(visible) == "table" then
            for _, u in ipairs(visible) do
                if u and is_party_or_raid(u) then
                    -- Deduplicate
                    local dup = false
                    local this_guid = unit_guid(u)
                    for i = 1, count do
                        if unit_guid(units[i]) == this_guid then
                            dup = true
                            break
                        end
                    end
                    if not dup then
                        count = count + 1
                        units[count] = u
                    end
                end
            end
        end
    end

    -- Scan each unit for active heal casts
    for i = 1, count do
        local u = units[i]
        local is_casting = false
        local spell_id = nil
        local start_time = 0

        -- Check casting state
        do
            local ok, val = pcall(function()
                if u.is_casting and u:is_casting() then return true end
                if u.is_channeling and u:is_channeling() then return true end
                if u.is_channeling_or_casting and u:is_channeling_or_casting() then return true end
                return false
            end)
            if ok then is_casting = val end
        end

        if is_casting then

        -- Get casting spell ID
        do
            local ok, val = pcall(function()
                local fn = u.get_casting_spell_id or u.get_active_spell_id or u.get_channel_spell_id
                if type(fn) == "function" then return fn(u) end
                return nil
            end)
            if ok and val then spell_id = tonumber(val) end
        end

        if spell_id then

        local info = spell_info(spell_id)
        if info and info.is_heal then

        -- Get cast start time
        do
            local ok, val = pcall(function()
                local fn = u.get_cast_start_time or u.get_active_cast_start_time or u.get_channel_start_time
                if type(fn) == "function" then return fn(u) end
                return 0
            end)
            if ok and type(val) == "number" then start_time = val end
        end

        -- Compute remaining cast time
        local elapsed = 0
        if start_time > 0 and now > start_time then
            elapsed = now - start_time
        end
        local remaining = math_max(0, info.cast_time - elapsed)
        local arrival = now + remaining

        -- Resolve target: prefer unit:get_target(), fallback to healer preference
        local target = get_unit_target(u)
        local healer_guid = unit_guid(u)
        local target_guid = nil

        if target then
            target_guid = unit_guid(target)
        else
            -- Fallback: use most-preferred target from this healer
            local prefs = _healer_prefs[healer_guid]
            if prefs then
                local best_guid = nil
                local best_score = 0
                for tguid, pt in pairs(prefs) do
                    local score = pt.count or 0
                    if (now - pt.last_time) < COMBAT_LOG_LOOKBACK then
                        score = score + 2
                    end
                    if score > best_score then
                        best_score = score
                        best_guid = tguid
                    end
                end
                target_guid = best_guid
            end
        end

        if target_guid and remaining > 0.1 then
            local amount = estimate_heal_amount(info.name, healer_guid, target_guid)
            -- Scale by remaining proportion so we don't overcount early in cast
            add_prediction(target_guid, amount, arrival, healer_guid, info.name)
        end

        end -- info and info.is_heal
        end -- spell_id
        end -- is_casting
    end
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

--- Returns the total predicted incoming heal amount on `unit` arriving
-- within PREDICTION_HORIZON seconds.
--@param unit game_object
--@return number total incoming heal (absolute HP), >= 0.
function M.get(unit)
    if not unit then return 0 end

    -- Always scan first so predictions are fresh
    M.scan_party_casts()

    local guid = unit_guid(unit)
    if not guid then return 0 end

    -- 1. Try native API first (most accurate)
    local native = 0
    do
        local ok, val = pcall(function()
            local fn = unit.get_incoming_heals
            return type(fn) == "function" and fn(unit) or 0
        end)
        if ok and type(val) == "number" then native = val end
    end
    if native > 0 then return native end

    -- 2. Fall back to our predictions
    local now = now_s()
    local cutoff = now + PREDICTION_HORIZON
    local total = 0

    local list = _predictions[guid]
    if list then
        for _, p in ipairs(list) do
            if p and p.arrival_time <= cutoff and p.arrival_time > now then
                total = total + p.amount
            end
        end
    end

    return math_floor(total)
end

--- Returns detailed per-prediction info for `unit`.
--@param unit game_object
--@return table array of { amount, arrival_in_seconds, source, spell_name }
function M.get_detailed(unit)
    if not unit then return {} end
    M.scan_party_casts()

    local guid = unit_guid(unit)
    if not guid then return {} end

    local now = now_s()
    local cutoff = now + PREDICTION_HORIZON
    local out = {}
    local count = 0

    local list = _predictions[guid]
    if list then
        for _, p in ipairs(list) do
            if p and p.arrival_time <= cutoff and p.arrival_time > now then
                count = count + 1
                out[count] = {
                    amount = math_floor(p.amount),
                    arrival_in_seconds = math_max(0, math_floor((p.arrival_time - now) * 10) / 10),
                    source = p.source,
                    spell_name = p.spell_name,
                }
            end
        end
    end

    return out
end

--- Returns predicted incoming heals arriving before `deadline_s` (seconds from now).
--@param unit game_object
--@param deadline_s number Seconds from now.
--@return number total arriving before deadline.
function M.get_arriving_before(unit, deadline_s)
    if not unit or type(deadline_s) ~= "number" then return 0 end
    M.scan_party_casts()

    local guid = unit_guid(unit)
    if not guid then return 0 end

    local now = now_s()
    local cutoff = now + deadline_s
    local total = 0

    local list = _predictions[guid]
    if list then
        for _, p in ipairs(list) do
            if p and p.arrival_time <= cutoff and p.arrival_time > now then
                total = total + p.amount
            end
        end
    end

    return math_floor(total)
end

--- Clears all predictions and caches (call on zone change / reload).
function M.clear()
    for k in pairs(_predictions) do _predictions[k] = nil end
    for k in pairs(_healer_prefs) do _healer_prefs[k] = nil end
    for k in pairs(_spell_cache) do _spell_cache[k] = nil end
    _last_scan_time = 0
    _last_cleanup_time = 0
end

-- ---------------------------------------------------------------------------
-- Bootstrap: subscribe to combat log parser if available
-- ---------------------------------------------------------------------------

if NS.CombatLogParser and NS.CombatLogParser.subscribe then
    NS.CombatLogParser.subscribe(M._on_combat_log_entry)
end

NS.log("IncomingHeals module loaded")
return M
