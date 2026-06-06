-- Shared Helper: PvP Trinket Tracker
-- Tracks when enemy players use their PvP trinket (Medallion of the Alliance/Horde).
-- TBC PvP trinket: spell ID 42292, 2 minute cooldown, removes CC.
-- ============================================================================
local M = {}
local _G = _G
local NS = _G.EaxRotations

local initialized = false

local PVP_TRINKET_SPELL_ID = 42292
local TRINKET_COOLDOWN = 120.0  -- 2 minutes in seconds

local function now()
    return NS and NS.time_now and NS.time_now() or 0
end

-- Get unit GUID safely
local function get_unit_guid(unit)
    if not unit then return nil end
    if type(unit) == "string" then return unit end
    local ok, guid = pcall(function() return unit:get_guid() end)
    if ok and type(guid) == "string" then return guid end
    return nil
end

-- Storage: {[guid] = timestamp_of_last_trinket_use}
local trinket_usage = {}

-- Record a PvP trinket use by a unit
function M.record_trinket_use(unit)
    local guid = get_unit_guid(unit)
    if not guid then return end
    trinket_usage[guid] = now()
end

-- Check if a unit's PvP trinket is on cooldown (used within last 120s)
-- @param unit_or_guid  unit object or GUID string
-- @return boolean  true if trinket was used within last TRINKET_COOLDOWN seconds
function M.is_on_cooldown(unit_or_guid)
    if not unit_or_guid then return false end
    local guid = get_unit_guid(unit_or_guid)
    if not guid then return false end
    local t = now()
    local last_use = trinket_usage[guid]
    if not last_use then return false end
    if (t - last_use) >= TRINKET_COOLDOWN then
        trinket_usage[guid] = nil
        return false
    end
    return true
end

-- Get seconds remaining on a unit's PvP trinket cooldown
-- @param unit_or_guid  unit object or GUID string
-- @return number  seconds until trinket is available (0 if not on cooldown)
function M.cooldown_remaining(unit_or_guid)
    if not unit_or_guid then return 0 end
    local guid = get_unit_guid(unit_or_guid)
    if not guid then return 0 end
    local t = now()
    local last_use = trinket_usage[guid]
    if not last_use then return 0 end
    local elapsed = t - last_use
    if elapsed >= TRINKET_COOLDOWN then
        trinket_usage[guid] = nil
        return 0
    end
    return TRINKET_COOLDOWN - elapsed
end

-- Get seconds since a unit last used their PvP trinket
-- @param unit_or_guid  unit object or GUID string
-- @return number  seconds since last use (0 if never tracked)
function M.time_since_use(unit_or_guid)
    if not unit_or_guid then return 0 end
    local guid = get_unit_guid(unit_or_guid)
    if not guid then return 0 end
    local last_use = trinket_usage[guid]
    if not last_use then return 0 end
    return now() - last_use
end

-- Clean up expired entries to prevent memory growth
function M.cleanup()
    local t = now()
    for guid, last_use in pairs(trinket_usage) do
        if (t - last_use) >= TRINKET_COOLDOWN then
            trinket_usage[guid] = nil
        end
    end
end

-- Initialize: register spell cast callback if available
function M.init()
    if not NS then return end
    if initialized then return end
    initialized = true

    -- Register on spell cast callback if Sylvanas exposes it
    if NS.register_on_spell_cast then
        NS.register_on_spell_cast(function(spell_id, _target, data)
            if spell_id == PVP_TRINKET_SPELL_ID and data and data.caster then
                M.record_trinket_use(data.caster)
            end
        end)
    end

    -- Periodic cleanup every 60 seconds
    if NS.register_on_update_callback then
        local last_cleanup = 0
        NS.register_on_update_callback(function()
            local t = now()
            if t - last_cleanup > 60 then
                M.cleanup()
                last_cleanup = t
            end
        end)
    end
end

if NS then
    NS.PvPTrinket = M
    -- Defer init until player is available (engine callbacks may not be ready at require() time)
    if NS.GetPlayer and NS.GetPlayer() then
        M.init()
    end
end

return M
