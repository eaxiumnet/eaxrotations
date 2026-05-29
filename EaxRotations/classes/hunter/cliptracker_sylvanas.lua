-- Lightweight Hunter shot timing state.
-- Thin wrapper around shared/hunter_core_sylvanas.lua for backward compatibility.
-- All timing logic delegates to HunterCore (single source of truth).

local NS = _G.EaxRotations
if not NS then return nil end

local M = {}

-- Ensure HunterCore is loaded
local HunterCore = NS.HunterCore
if not HunterCore then
    local ok, mod = pcall(require, "shared/hunter_core_sylvanas")
    if ok and type(mod) == "table" then
        HunterCore = mod
        NS.HunterCore = HunterCore
    end
end

-- Legacy state kept for record_manual_shot / after_spell (not in HunterCore)
local _last_manual_ms = 0

local function now_ms()
    return NS.game_time_ms and NS.game_time_ms() or 0
end

function M.record_auto_shot()
    if HunterCore then HunterCore.record_auto_shot() end
end

function M.record_manual_shot()
    _last_manual_ms = now_ms()
end

function M.set_weapon_speed_seconds(speed)
    -- HunterCore auto-detects weapon speed from player object.
    -- This is a no-op for backward compatibility.
end

function M.ms_until_auto()
    if HunterCore then return HunterCore.ms_until_auto() end
    return 0
end

function M.can_cast_steady()
    if HunterCore then return HunterCore.can_cast_steady() end
    return true
end

function M.after_spell(spell_name)
    if spell_name then M.record_manual_shot() end
end

NS.HunterClipTracker = M
return M
