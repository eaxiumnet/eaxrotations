-- Hunter shot timing state.
-- Delegates to HunterCore for unified timing with 500ms auto-shot buffer.

local NS = _G.EaxRotations
if not NS then return nil end

local HunterCore = NS.HunterCore

local M = {}

function M.record_auto_shot()
    if HunterCore then HunterCore.record_auto_shot() end

function M.record_manual_shot()
    -- legacy no-op (HunterCore handles all timing)
end

function M.set_weapon_speed_seconds(speed)
    -- legacy no-op (HunterCore auto-detects weapon speed)
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
    -- legacy no-op
end

NS.HunterClipTracker = M
return M
