-- anti_fake_manager.lua
-- PvP anti-fake interrupt logic

local anti_fake_manager = {}

-- Cache APIs
local _core_time = core.time
local _math_random = math.random

-- Constants
local FAKE_CAST_THRESHOLD_MS = 300  -- Canceled faster than this = fake
local SUCCESSIVE_FAKE_COUNT = 2     -- After 2 fakes, be more cautious
local RANDOM_DELAY_MIN_MS = 100     -- Min random delay
local RANDOM_DELAY_MAX_MS = 400     -- Max random delay

-- Track cast history per target
local cast_history = {}

function anti_fake_manager.is_likely_fake(target)
    if not target or not target:is_valid() then return false end
    local guid = target:get_guid()
    if not guid then return false end
    
    local history = cast_history[guid]
    if not history then return false end
    
    -- If they've faked twice recently, be cautious
    if history.fake_count >= SUCCESSIVE_FAKE_COUNT then
        local cast_time = target:get_cast_time() or 0
        if cast_time < FAKE_CAST_THRESHOLD_MS then
            return true  -- Probably another fake
        end
    end
    return false
end

function anti_fake_manager.get_interrupt_delay(target, is_pvp)
    if not is_pvp then return 0 end  -- No delay in PvE
    
    -- Random delay between 100-400ms for PvP
    return _math_random(RANDOM_DELAY_MIN_MS, RANDOM_DELAY_MAX_MS) / 1000  -- Convert to seconds
end

function anti_fake_manager.record_cast_start(target)
    if not target or not target:is_valid() then return end
    local guid = target:get_guid()
    if not guid then return end
    
    cast_history[guid] = cast_history[guid] or { fake_count = 0 }
    cast_history[guid].cast_start_time = _core_time()
    cast_history[guid].was_interrupted = false
end

function anti_fake_manager.record_cast_end(target, was_interrupted)
    if not target or not target:is_valid() then return end
    local guid = target:get_guid()
    if not guid then return end
    
    local history = cast_history[guid]
    if not history then return end
    
    local cast_duration = (_core_time() - (history.cast_start_time or 0)) * 1000
    
    if was_interrupted then
        history.fake_count = 0  -- We got it, reset
        history.was_interrupted = true
    else
        -- Cast ended without our interrupt - was it a fake?
        if cast_duration < FAKE_CAST_THRESHOLD_MS and not history.was_interrupted then
            history.fake_count = (history.fake_count or 0) + 1
        end
    end
end

return anti_fake_manager
