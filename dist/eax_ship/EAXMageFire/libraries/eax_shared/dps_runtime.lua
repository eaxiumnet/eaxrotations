local combat_context = require("eax_shared/combat_context")

local dps_runtime = {}

local function load_health_prediction()
    local ok, module = pcall(require, "health_prediction")
    if ok then
        return module
    end

    local __eax_src = debug.getinfo(1, "S").source:gsub("^@", "")
local __eax_root = __eax_src:match("^(.*[\\/])libraries[\\/]") or (__eax_src:match("^(.*[\\/])") or "")
local chunk = loadfile(__eax_root .. ".api/common/modules/health_prediction.lua")
    if type(chunk) == "function" then
        local chunk_ok, fallback = pcall(chunk)
        if chunk_ok then
            return fallback
        end
    end

    return nil
end

local function clamp01(value)
    local n = tonumber(value) or 0
    if n < 0 then
        return 0
    end
    if n > 1 then
        return 1
    end
    return n
end

function dps_runtime.build_snapshot(me, target, encounter_manager, ttd_tracker)
    local snapshot = combat_context.build(me, target, nil, {
        health_prediction = load_health_prediction(),
        encounter_manager = encounter_manager,
    })

    snapshot.target = snapshot.target or {}
    snapshot.target.time_to_die_s = 30

    if ttd_tracker and ttd_tracker.get and target and target.is_valid and target:is_valid() and not target:is_dead() then
        local ok, value = pcall(function()
            return ttd_tracker.get(target)
        end)
        if ok and tonumber(value) then
            snapshot.target.time_to_die_s = tonumber(value)
        end
    end

    snapshot.encounter = snapshot.encounter or {}
    snapshot.encounter.dangerous_control_window = snapshot.encounter.interrupt_priority == true
        and (snapshot.target.is_casting == true or snapshot.target.is_channeling == true)
    snapshot.party = snapshot.party or {}
    snapshot.party.group_collapse_risk = clamp01(snapshot.party.group_collapse_risk)

    return snapshot
end

return dps_runtime
