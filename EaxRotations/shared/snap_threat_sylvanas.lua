-- snap_threat_sylvanas.lua — Fire immediate threat ability on combat entry.
-- WHAT:  Detects the first frame of combat and queues a high-threat opener.
-- WHEN:  Prot Paladin, Prot Warrior (and any tank spec that opts in).
-- WHY:   Establishes threat before DPS opens up, preventing early aggro loss.
-- SAFETY: 3s cooldown after snap to prevent spam; gated by setting; nil-guarded
-- DECISION: snap Judgement/Shield Slam on combat entry for Prot Pally/Warrior.
--         API access. Only fires when actually entering combat (not already in).
-- Decision: Shared module because both Prot Pally and Prot Warrior need it,
--           and future tank specs (Bear, Prot DK) can reuse the same hook.

local _G = _G
local NS = _G.EaxRotations
if not NS then return end

local type = type
local pcall = pcall
local tostring = tostring

local M = {}
NS.SnapThreat = M

-- ---------------------------------------------------------------------------
-- Defaults
-- ---------------------------------------------------------------------------
local DEFAULT_ENABLED = true
local DEFAULT_COOLDOWN = 3.0       -- Seconds between snap attempts
local DEFAULT_WINDOW = 2.0         -- Combat-start window in seconds

-- ---------------------------------------------------------------------------
-- Internal state
-- ---------------------------------------------------------------------------
local _was_in_combat = false
local _last_snap_time = 0
local _snap_fired_this_combat = false

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function safe_number(v, fallback)
    fallback = fallback or 0
    return type(v) == "number" and v or fallback
end

local function is_in_combat(me)
    if not me then return false end
    local ok, combat = pcall(function()
        if me.is_in_combat then return me:is_in_combat() end
        return false
    end)
    return ok and combat == true
end

local function can_cast(spell_id, target)
    if not spell_id then return false end
    if NS.spell_ready then
        local ok, ready = pcall(NS.spell_ready, spell_id, target)
        if ok and ready then return true end
    end
    return false
end

local function try_cast(spell_id, target, label)
    if not spell_id then return false end
    if NS.try_cast then
        local ok, result = pcall(NS.try_cast, spell_id, target, label)
        return ok and result
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

--- Call every frame. Returns the spell ID to cast for snap threat, or nil.
-- @param me         game_object  Local player
-- @param target     game_object  Current target
-- @param settings   table|nil    Context settings (snap_threat_enabled)
-- @param opener_map table        { spell_id = number, fallback_id = number|nil }
-- @return number|nil  spell_id to cast, or nil if no snap needed
function M.check(me, target, settings, opener_map)
    settings = settings or (NS.settings or {})

    local enabled = settings.snap_threat_enabled
    if enabled == nil then enabled = DEFAULT_ENABLED end
    if not enabled then return nil end

    local now = NS.time_now and NS.time_now() or 0
    if (now - _last_snap_time) < DEFAULT_COOLDOWN then
        return nil
    end

    local in_combat = is_in_combat(me)

    -- Combat just started
    if in_combat and not _was_in_combat then
        _snap_fired_this_combat = false
    end

    _was_in_combat = in_combat

    if not in_combat then
        return nil
    end

    if _snap_fired_this_combat then
        return nil
    end

    if not opener_map or type(opener_map) ~= "table" then
        return nil
    end

    local primary = opener_map.spell_id
    local fallback = opener_map.fallback_id

    if primary and can_cast(primary, target) then
        _snap_fired_this_combat = true
        _last_snap_time = now
        if NS.log then
            NS.log(string.format("[SnapThreat] Firing opener %s on combat start", tostring(primary)))
        end
        return primary
    end

    if fallback and can_cast(fallback, target) then
        _snap_fired_this_combat = true
        _last_snap_time = now
        if NS.log then
            NS.log(string.format("[SnapThreat] Firing fallback opener %s on combat start", tostring(fallback)))
        end
        return fallback
    end

    return nil
end

--- Reset internal state (e.g. on zone change or /reload).
function M.reset()
    _was_in_combat = false
    _last_snap_time = 0
    _snap_fired_this_combat = false
end

--- Manual override to mark snap as fired (e.g. when another opener was used).
function M.mark_fired()
    _snap_fired_this_combat = true
end

-- module initialized
return M
