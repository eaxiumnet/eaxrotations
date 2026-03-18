-- ttd_tracker.lua
-- Rolling time-to-death estimator based on HP loss rate over a sliding window.
-- Designed for use in execute-phase logic (Drain Soul, Execute, Ferocious Bite).

local ttd_tracker = {}

local WINDOW_S   = 10   -- sample window in seconds
local MIN_LOSS   = 0.001 -- minimum HP loss rate before TTD is considered valid

-- Per-target sample tables, keyed by target object pointer (approximated by tostring)
local _samples = {}

local function target_key(target)
    return tostring(target)
end

-- Call this every update tick while a target is alive.
function ttd_tracker.update(target)
    if not target or not target:is_valid() or target:is_dead() then
        return
    end
    local key = target_key(target)
    local now = core.time()
    local hp  = target:get_health() / math.max(target:get_max_health(), 1)

    if not _samples[key] then _samples[key] = {} end
    local s = _samples[key]
    s[#s + 1] = { t = now, hp = hp }

    -- Prune old samples
    while s[1] and (now - s[1].t) > WINDOW_S do
        table.remove(s, 1)
    end
end

-- Returns estimated seconds until target dies.
-- Returns 999 if insufficient data or target is regenerating.
function ttd_tracker.get(target)
    if not target or not target:is_valid() then return 999 end
    local key = target_key(target)
    local s   = _samples[key]
    if not s or #s < 2 then return 999 end

    local oldest = s[1]
    local newest = s[#s]
    local elapsed = newest.t - oldest.t
    if elapsed <= 0 then return 999 end

    local hp_loss = oldest.hp - newest.hp
    if hp_loss < MIN_LOSS then return 999 end  -- healing or no change

    local rate = hp_loss / elapsed   -- HP% per second
    return newest.hp / rate
end

-- Returns true if TTD < threshold_s (useful for execute phase checks).
function ttd_tracker.is_dying(target, threshold_s)
    return ttd_tracker.get(target) < (threshold_s or 20)
end

-- Clear data for a target (call on target death or switch).
function ttd_tracker.reset(target)
    if target then
        _samples[target_key(target)] = nil
    else
        _samples = {}
    end
end

return ttd_tracker
