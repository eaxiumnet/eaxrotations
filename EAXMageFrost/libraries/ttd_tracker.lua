-- ttd_tracker.lua
-- Time-to-die tracker stub.
-- Provides safe fallback values so rotation logic degrades gracefully
-- (spells that check TTD will always see a large value and never skip).

local ttd_tracker = {}

local _data = {}

--- Update TTD estimate for a unit (call each rotation tick).
---@param unit userdata
function ttd_tracker.update(unit)
    if not unit then return end
    local ok, guid = pcall(function() return unit:get_guid() end)
    if not ok or not guid then return end
    local ok2, hp = pcall(function() return unit:get_health_percentage() end)
    if not ok2 then return end
    local now = core and core.time and core.time() or 0
    if not _data[guid] then
        _data[guid] = { hp = hp, time = now, ttd = 9999 }
        return
    end
    local d = _data[guid]
    local dt = now - d.time
    if dt > 0.5 then
        local dhp = d.hp - hp
        if dhp > 0 then
            d.ttd = (hp / dhp) * dt
        else
            d.ttd = 9999
        end
        d.hp   = hp
        d.time = now
    end
end

--- Get estimated time-to-die in seconds for a unit.
---@param unit userdata
---@return number seconds (9999 if unknown)
function ttd_tracker.get(unit)
    if not unit then return 9999 end
    local ok, guid = pcall(function() return unit:get_guid() end)
    if not ok or not guid then return 9999 end
    return (_data[guid] and _data[guid].ttd) or 9999
end

--- Clear stale entries (optional housekeeping).
function ttd_tracker.reset()
    _data = {}
end

return ttd_tracker
