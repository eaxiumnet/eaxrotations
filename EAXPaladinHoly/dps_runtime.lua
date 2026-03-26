local combat_context = require("combat_context")

local dps_runtime = {}
local _health_prediction_module = nil
local _health_prediction_loaded = false
local _last_snapshot_tick = nil
local _last_snapshot_me = nil
local _last_snapshot_target = nil
local _last_snapshot_me_guid = nil
local _last_snapshot_target_guid = nil
local _last_snapshot = nil

local function load_health_prediction()
    if _health_prediction_loaded then return _health_prediction_module end
    _health_prediction_loaded = true
    local ok, module = pcall(require, "health_prediction")
    if ok then _health_prediction_module = module
        return module
    end

    local chunk = loadfile(".api/common/modules/health_prediction.lua")
    if type(chunk) == "function" then
        local chunk_ok, fallback = pcall(chunk)
        if chunk_ok then _health_prediction_module = fallback
            return fallback
        end
    end

    return nil
end

local function unit_guid(unit)
    if type(unit) ~= "table" or type(unit.get_guid) ~= "function" then return nil end
    local ok, guid = pcall(function() return unit:get_guid() end)
    if ok and guid ~= nil then return tostring(guid) end
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
    local now_s = (core and core.time and core.time()) or 0
    local me_guid = unit_guid(me)
    local target_guid = unit_guid(target)
    if _last_snapshot ~= nil and _last_snapshot_tick == now_s and _last_snapshot_me == me and _last_snapshot_target == target and _last_snapshot_me_guid == me_guid and _last_snapshot_target_guid == target_guid then return _last_snapshot end
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

    _last_snapshot_tick = now_s
    _last_snapshot_me = me
    _last_snapshot_target = target
    _last_snapshot_me_guid = me_guid
    _last_snapshot_target_guid = target_guid
    _last_snapshot = snapshot

    return snapshot
end

return dps_runtime
