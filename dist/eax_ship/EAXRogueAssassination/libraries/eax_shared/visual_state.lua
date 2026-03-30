local dps_meter = require("eax_shared/dps_meter")
local cooldown_tracker = require("eax_shared/cooldown_tracker")

local visual_state = {}

local function now_s_fallback()
    if core and core.time then
        local t = core.time()
        if type(t) == "number" then
            return t
        end
    end
    return os.clock()
end

local function normalize_ttd(ttd_seconds)
    if ttd_seconds == nil then
        return "--"
    end

    local n = tonumber(ttd_seconds)
    if not n or n >= 999 then
        return "--"
    end

    return n
end

function visual_state.build_snapshot(args)
    args = args or {}

    local dps_snapshot = dps_meter.get_snapshot()
    local now_s = tonumber(args.now_s) or now_s_fallback()
    local cooldown_s = cooldown_tracker.seconds_remaining(now_s)

    return {
        dps = tonumber(dps_snapshot.dps) or 0,
        hps = tonumber(dps_snapshot.hps) or 0,
        cooldown_s = tonumber(cooldown_s) or 0,
        ttd_s = normalize_ttd(args.ttd_seconds),
        tracked_auras = type(args.tracked_auras) == "table" and args.tracked_auras or {},
    }
end

return visual_state
