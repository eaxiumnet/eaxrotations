local izi = require("common/izi_sdk")

local M = {}

local _last_idle_log = 0
local _idle_reason = nil
local _idle_reason_count = 0

local function log_idle(reason)
    if reason == _idle_reason then
        _idle_reason_count = _idle_reason_count + 1
    else
        _idle_reason = reason
        _idle_reason_count = 1
    end
    local now = izi.now()
    if now - _last_idle_log > 2 then
        _last_idle_log = now
        if _idle_reason_count > 5 then
            izi.print("[Eax2] idle: " .. tostring(_idle_reason) .. " (x" .. _idle_reason_count .. ")")
        end
    end
end

local function safe_bool(fn, ...)
    if type(fn) ~= "function" then return false end
    local ok, result = pcall(fn, ...)
    return ok and result == true
end

local function safe_table(fn, ...)
    if type(fn) ~= "function" then return {} end
    local ok, result = pcall(fn, ...)
    return ok and type(result) == "table" and result or {}
end

local _last_error_time = 0

local function log_error(msg)
    local now = izi.now()
    if now - _last_error_time > 3 then
        _last_error_time = now
        izi.print(msg)
    end
end

function M.run(spec)
    local me = izi.me()
    if not me then
        log_idle("no_player")
        return false
    end
    if not safe_bool(me.is_alive, me) then
        log_idle("dead")
        return false
    end
    if safe_bool(me.is_cc, me, 500) then
        log_idle("cc")
        return false
    end

    local target = izi.target()
    if target and not safe_bool(target.is_valid_enemy, target) then
        target = nil
    end

    local enemies = safe_table(izi.enemies, 40)

    if type(spec.tick) == "function" then
        local ok, casted = pcall(spec.tick, me, target, enemies)
        if not ok then
            log_error("[Eax2] spec error: " .. tostring(casted))
            return false
        end
        if casted then
            _idle_reason = nil
            _idle_reason_count = 0
            return true
        end
    end

    log_idle("no_action")
    return false
end

return M
