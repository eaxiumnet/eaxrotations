-- ============================================================================
-- Shared Helper: Missile Tracker
-- What:   Tracks in-flight spell projectiles using core.object_manager.get_all_missiles().
-- When:   Any rotation or spec file that needs to detect incoming CC projectiles
--         for pre-immune / pre-trinket decision-making.
-- Why:    Projectiles travel while their caster is locked in cast animation.
--         Detecting a Polymorph or Fear in-flight gives the rotation a window
--         to pre-pop a defensive trinket or pre-cast an immunity before impact.
-- Safety: All API calls pcall-wrapped. If the missiles API is nil or unavailable,
--         all functions return safe defaults (false / 0 / empty table).
-- Decision:
--   - Module is read-only / status-only — it reports what's inbound.
--   - Spec files consume these values via build_state() / context injection.
--   - Does NOT trigger defensives directly (spec files own that choice).
-- ============================================================================

local M = {}
local _G = _G
local NS = _G.EaxRotations

-- ============================================================================
-- Cache API at module load (Pattern 2: API caching)
-- ============================================================================

local _get_all_missiles = type(core) == "table"
    and type(core.object_manager) == "table"
    and type(core.object_manager.get_all_missiles) == "function"
    and core.object_manager.get_all_missiles
    or nil

local _get_local_player = (NS and NS.GetPlayer)
    or (type(core) == "table"
        and type(core.object_manager) == "table"
        and type(core.object_manager.get_local_player) == "function"
        and core.object_manager.get_local_player)
    or nil

local _time_now = (NS and NS.time_now) or function() return 0 end

-- ============================================================================
-- CC Spell ID Set
-- ============================================================================
-- Known Crowd Control spell IDs for TBC Classic (Wrath client).
-- These are spells whose projectiles the tracker should flag.
-- Polymorph, Fear, Seduction, Mind Control, Hibernate, etc.
-- ============================================================================

local CC_SPELL_IDS = {
    [118]    = true,  -- Polymorph (Mage)
    [12826]  = true,  -- Polymorph (Rank 2)
    [12827]  = true,  -- Polymorph (Rank 3)
    [28272]  = true,  -- Polymorph (Rank 4)
    [5782]   = true,  -- Fear (Warlock)
    [6213]   = true,  -- Fear (Rank 2)
    [6215]   = true,  -- Fear (Rank 3)
    [6358]   = true,  -- Seduction (Warlock Succubus)
    [605]    = true,  -- Mind Control (Priest)
    [10911]  = true,  -- Mind Control (Rank 2)
    [10912]  = true,  -- Mind Control (Rank 3)
    [2637]   = true,  -- Hibernate (Druid)
    [18657]  = true,  -- Hibernate (Rank 2)
    [18658]  = true,  -- Hibernate (Rank 3)
    [2094]   = true,  -- Blind (Rogue)
    [6770]   = true,  -- Sap (Rogue)
    [2070]   = true,  -- Sap (Rank 2)
    [11297]  = true,  -- Sap (Rank 3)
    [51724]  = true,  -- Sap (Rank 4 — Wrath-era, valid on TBC anniversary client)
    [1499]   = true,  -- Freezing Trap (Hunter)
    [20066]  = true,  -- Repentance (Paladin)
    [10326]  = true,  -- Turn Evil (Priest)
    [710]    = true,  -- Banish (Warlock)
    [6789]   = true,  -- Death Coil (Warlock)
    [17928]  = true,  -- Death Coil (Rank 2)
    [8122]   = true,  -- Psychic Scream (Priest)
    [8124]   = true,  -- Psychic Scream (Rank 2)
    [10888]  = true,  -- Psychic Scream (Rank 3)
    [10890]  = true,  -- Psychic Scream (Rank 4)
    [1513]   = true,  -- Scare Beast (Hunter)
    [14326]  = true,  -- Scare Beast (Rank 2)
    [5246]   = true,  -- Intimidating Shout (Warrior)
    [20511]  = true,  -- Intimidating Shout (Rank 2)
    [5484]   = true,  -- Howl of Terror (Warlock)
    [17928]  = true,  -- Howl of Terror (Rank 2)
    [3355]   = true,  -- Freezing Trap Effect (Rank 1)
    [19905]  = true,  -- Freezing Trap Effect (Rank 2)
    [19386]  = true,  -- Wyvern Sting (Hunter)
    [24132]  = true,  -- Wyvern Sting (Rank 2)
    [24133]  = true,  -- Wyvern Sting (Rank 3)
    [31661]  = true,  -- Dragon's Breath (Mage)
    [33042]  = true,  -- Dragon's Breath (Rank 2)
    [34243]  = true,  -- Dragon's Breath (Rank 3)
}

-- ============================================================================
-- Static table for reuse (Pattern 4)
-- ============================================================================

local _result_t = { n = 0 }

-- ============================================================================
-- Helpers
-- ============================================================================

--- Safely get a unit's GUID, returning nil on failure.
---@param unit game_object|nil
---@return string|nil
local function get_unit_guid(unit)
    if not unit then return nil end
    if type(unit) == "string" then return unit end
    local ok, guid = pcall(function() return unit:get_guid() end)
    if ok and type(guid) == "string" then return guid end
    return nil
end

--- Get the local player GUID, cached per call.
---@return string|nil
local function get_local_player_guid()
    if not _get_local_player then return nil end
    local ok, player = pcall(_get_local_player)
    if not ok or type(player) ~= "table" then return nil end
    return get_unit_guid(player)
end

--- Fetch all in-flight missiles safely.
---@return table|nil  Array of missile objects, or nil on failure.
local function get_missiles()
    if not _get_all_missiles then return nil end
    local ok, missiles = pcall(_get_all_missiles)
    if not ok or type(missiles) ~= "table" then return nil end
    return missiles
end

--- Check if a spell ID is a known CC spell.
---@param spell_id number
---@return boolean
local function is_cc_spell(spell_id)
    return CC_SPELL_IDS[spell_id] == true
end

--- Get the GUID of a missile's target safely.
---@param missile table
---@return string|nil
local function missile_target_guid(missile)
    if type(missile) ~= "table" then return nil end
    local target = missile.target
    if not target then return nil end
    return get_unit_guid(target)
end

--- Check if a missile is targeting a given GUID.
---@param missile table
---@param target_guid string
---@return boolean
local function is_targeting(missile, target_guid)
    local guid = missile_target_guid(missile)
    if not guid then return false end
    return guid == target_guid
end

-- ============================================================================
-- Public API
-- ============================================================================

--- Returns true if a CC projectile is currently targeting the local player.
---@return boolean
function M.incoming_cc()
    local missiles = get_missiles()
    if not missiles then return false end

    local player_guid = get_local_player_guid()
    if not player_guid then return false end

    for i = 1, #missiles do
        local m = missiles[i]
        if type(m) == "table" and is_targeting(m, player_guid) then
            local spell_id = m.spell_id
            if type(spell_id) == "number" and is_cc_spell(spell_id) then
                return true
            end
        end
    end

    return false
end

--- Returns the total count of in-flight missiles.
---@return number
function M.missile_count()
    local missiles = get_missiles()
    if not missiles then return 0 end
    return #missiles
end

--- Returns an array of missiles targeting the given unit.
---@param unit game_object|string  Unit object or GUID string.
---@return table  Array of missile tables (empty if none).
function M.missiles_targeting(unit)
    _result_t.n = 0

    local missiles = get_missiles()
    if not missiles then return _result_t end

    local target_guid = get_unit_guid(unit)
    if not target_guid then return _result_t end

    for i = 1, #missiles do
        local m = missiles[i]
        if type(m) == "table" and is_targeting(m, target_guid) then
            local idx = _result_t.n + 1
            _result_t[idx] = m
            _result_t.n = idx
        end
    end

    return _result_t
end

-- ============================================================================
-- NS Registration
-- ============================================================================

if NS then
    NS.MissileTracker = M
end

return M
