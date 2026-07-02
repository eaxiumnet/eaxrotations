-- swing_diagnostics_sylvanas.lua — CLEU-backed swing timer + seal confirmation + diagnostics.
-- WHAT:  Listens to COMBAT_LOG_EVENT_UNFILTERED for melee swings and seal casts,
--        providing authoritative swing timing and twist-result categorization.
-- WHEN:  Loaded at startup; registers callback if core.register_on_game_event_callback exists.
-- WHY:   Frame-polling swing timers drift under latency/haste. CLEU gives exact server timestamps.
-- SAFETY: Falls back silently if callback API is unavailable. All internal state is nil-guarded.
-- DECISION: Shared module because any melee spec (Ret, Enh, Warrior) benefits from CLEU swing data.

local _G = _G
local NS = _G.EaxRotations
if not NS then return end

local type = type
local pcall = pcall
local tonumber = tonumber
local tostring = tostring
local string_find = string.find
local math_max = math.max
local math_abs = math.abs

local M = {}
NS.SwingDiagnostics = M

-- ---------------------------------------------------------------------------
-- Defaults
-- ---------------------------------------------------------------------------
local TWIST_TRACK_WINDOW = 3.0
local SWING_LOG_CAPACITY = 20
local DIAGNOSTICS_COOLDOWN = 5.0

-- ---------------------------------------------------------------------------
-- Internal state
-- ---------------------------------------------------------------------------
local _last_swing_time = 0
local _last_swing_interval = 3.5
local _pending_twist = nil
local _last_twist_result = "NO-TWIST"
local _last_twist_result_time = 0
local _swing_log = {}
local _swing_log_head = 0
local _seal_cast_confirmed = {}
local _player_guid = nil
local _diagnostics_enabled = false
local _last_diag_log_time = 0
local _SEAL_SPELL_IDS = {}
local _registered = false

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local function safe_number(v, fallback)
    fallback = fallback or 0
    local n = tonumber(v)
    return (type(n) == "number" and n == n) and n or fallback
end

local function get_player_guid()
    if _player_guid then return _player_guid end
    local me = NS.GetPlayer and NS.GetPlayer()
    if me and me.get_guid then
        local ok, guid = pcall(me.get_guid, me)
        if ok and guid then _player_guid = guid end
    end
    return _player_guid
end

local function is_player_source(args)
    local guid = args and args[4]
    if not guid then return false end
    return guid == get_player_guid()
end

local function now_seconds()
    return (NS.time_now and NS.time_now()) or (core and core.time and core.time()) or 0
end

local function log_diagnostics(msg)
    local now = now_seconds()
    if (now - _last_diag_log_time) < DIAGNOSTICS_COOLDOWN then return end
    _last_diag_log_time = now
    if NS.log then pcall(NS.log, msg) end
end

local function push_swing_log(entry)
    _swing_log_head = _swing_log_head + 1
    if _swing_log_head > SWING_LOG_CAPACITY then _swing_log_head = 1 end
    _swing_log[_swing_log_head] = entry
end

local function categorize_twist(swing_time)
    if not _pending_twist then return "NO-TWIST" end
    local elapsed = swing_time - _pending_twist.time
    if elapsed < -0.5 then return "NO-TWIST" end
    if elapsed > TWIST_TRACK_WINDOW then
        _pending_twist = nil
        return "NO-TWIST"
    end
    local result
    if not _pending_twist.cast_confirmed then
        result = "PHANTOM"
    elseif elapsed < 0.15 then
        result = "LATE"
    else
        result = "PERFECT"
    end
    _pending_twist = nil
    return result
end


-- ---------------------------------------------------------------------------
-- CLEU Event handler
-- ---------------------------------------------------------------------------
local function on_cleu(args)
    if type(args) ~= "table" then return end
    local sub_event = args[2]
    if type(sub_event) ~= "string" then return end

    if sub_event == "SWING_DAMAGE" or sub_event == "SWING_MISSED" then
        if not is_player_source(args) then return end
        local now = now_seconds()
        local is_offhand = false
        if sub_event == "SWING_DAMAGE" then
            is_offhand = args[21] == true or args[21] == 1
        elseif sub_event == "SWING_MISSED" then
            is_offhand = args[12] == true or args[12] == 1
        end
        if is_offhand then return end

        if _last_swing_time > 0 then
            _last_swing_interval = now - _last_swing_time
        end
        _last_swing_time = now

        local result = categorize_twist(now)
        _last_twist_result = result
        _last_twist_result_time = now

        local ms_delta = 0
        if _pending_twist then
            ms_delta = math_abs(safe_number(now - _pending_twist.time, 0)) * 1000
        end

        push_swing_log({
            time = now,
            result = result,
            seal_id = _pending_twist and _pending_twist.seal_id or nil,
            ms_delta = math.floor(ms_delta + 0.5),
            interval = _last_swing_interval,
        })

        if _diagnostics_enabled and result ~= "NO-TWIST" then
            log_diagnostics(string.format(
                "[SwingDiagnostics] %s (swing %.0fms from twist attempt, interval %.2fs)",
                result, ms_delta, _last_swing_interval
            ))
        end
        return
    end

    if sub_event == "SPELL_CAST_SUCCESS" then
        if not is_player_source(args) then return end
        local spell_id = tonumber(args[12])
        if not spell_id then return end
        if _SEAL_SPELL_IDS[spell_id] then
            local cast_time = now_seconds()
            _seal_cast_confirmed[spell_id] = cast_time
            if _pending_twist and _pending_twist.seal_id == spell_id then
                _pending_twist.cast_confirmed = true
            end
        end
        return
    end

    if sub_event == "SPELL_AURA_APPLIED" then
        local dest_guid = args[8]
        if dest_guid ~= get_player_guid() then return end
        local spell_id = tonumber(args[12])
        if not spell_id then return end
        if _SEAL_SPELL_IDS[spell_id] then
            _seal_cast_confirmed[spell_id] = now_seconds()
        end
        return
    end
end

-- ---------------------------------------------------------------------------
-- Game event router
-- ---------------------------------------------------------------------------
local function on_game_event(event_name, args)
    if event_name == "COMBAT_LOG_EVENT_UNFILTERED" then
        local ok, err = pcall(on_cleu, args)
        if not ok and NS.log_warning then
            pcall(NS.log_warning, "[SwingDiagnostics] CLEU error: " .. tostring(err))
        end
    end
end

-- ---------------------------------------------------------------------------
-- Registration
-- ---------------------------------------------------------------------------
local function try_register()
    if _registered then return true end
    local fn = core and core.register_on_game_event_callback
    if type(fn) ~= "function" then return false end
    local ok, result = pcall(fn, function(event_name, args)
        on_game_event(event_name, args)
    end)
    if ok and result ~= false then
        _registered = true
        if NS.log then pcall(NS.log, "[SwingDiagnostics] CLEU listener registered") end
        return true
    end
    return false
end

local function ensure_registered()
    if _registered then return true end
    return try_register()
end



-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------
function M.register_seals(seal_ids)
    if type(seal_ids) ~= "table" then return end
    for i = 1, #seal_ids do
        local id = tonumber(seal_ids[i])
        if id then _SEAL_SPELL_IDS[id] = true end
    end
    ensure_registered()
end

function M.mark_twist_attempt(seal_id)
    ensure_registered()
    seal_id = tonumber(seal_id)
    _pending_twist = {
        time = now_seconds(),
        seal_id = seal_id,
        cast_confirmed = false,
    }
end

function M.is_seal_confirmed(seal_id, within_seconds)
    seal_id = tonumber(seal_id)
    if not seal_id then return false end
    local confirmed_time = _seal_cast_confirmed[seal_id]
    if not confirmed_time then return false end
    within_seconds = safe_number(within_seconds, 2.0)
    return (now_seconds() - confirmed_time) <= within_seconds
end

function M.get_last_swing_time()
    return (_last_swing_time > 0) and _last_swing_time or nil
end

function M.get_swing_interval()
    return (_last_swing_time > 0) and _last_swing_interval or nil
end

function M.get_swing_remains()
    if _last_swing_time <= 0 then return nil end
    local interval = _last_swing_interval
    if not interval or interval <= 0 then return nil end
    local elapsed = now_seconds() - _last_swing_time
    return math_max(0, interval - elapsed)
end

function M.get_last_twist_result()
    return _last_twist_result
end

function M.get_last_twist_result_time()
    return _last_twist_result_time
end

function M.set_diagnostics(enabled)
    _diagnostics_enabled = enabled == true
end

function M.get_swing_log(max_entries)
    max_entries = safe_number(max_entries, 10)
    local out = {}
    local count = 0
    for i = 1, max_entries do
        if i > SWING_LOG_CAPACITY then break end
        local idx = _swing_log_head - i + 1
        if idx <= 0 then idx = idx + SWING_LOG_CAPACITY end
        local entry = _swing_log[idx]
        if entry then
            count = count + 1
            out[count] = {
                time = entry.time,
                result = entry.result,
                seal_id = entry.seal_id,
                ms_delta = entry.ms_delta,
                interval = entry.interval,
            }
        end
    end
    return out
end

function M.reset()
    _last_swing_time = 0
    _last_swing_interval = 3.5
    _pending_twist = nil
    _last_twist_result = "NO-TWIST"
    _last_twist_result_time = 0
    _swing_log = {}
    _swing_log_head = 0
    _seal_cast_confirmed = {}
    _player_guid = nil
end

function M.is_active()
    return _registered
end

M.has_cleu = M.is_active

return M

