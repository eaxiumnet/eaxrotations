-- ============================================================================
-- Shared Helper: DR Tracker (Diminishing Returns)
-- ============================================================================
-- Readability notes:
--   What: tracks Diminishing Returns per target GUID and DR category for TBC Arena.
--   When: PvP situations where CC duration reduction and immunity matter.
--   Why: accurate DR state enables smarter CC chains and avoids wasted casts.
--   Safety: uses spell cast callbacks, validates GUIDs, expires old entries.

local M = {}
local _G = _G
local NS = _G.EaxRotations

local EMPTY = {}

local function now()
    return NS and NS.time_now and NS.time_now() or 0
end

-- TBC DR Categories (18 second reset timer)
local DR_CATEGORIES = {
    STUN = "stun",
    FEAR = "fear",
    ROOT = "root",
    INCAPACITATE = "incapacitate",
    DISORIENT = "disorient",
    SILENCE = "silence",
    CYCLONE = "cyclone",
}

-- Spell ID to DR Category mapping (TBC only, patch 2.4.3)
-- Covers major CC spells across all classes
local SPELL_TO_CATEGORY = {
    -- Stuns (1.0 -> 0.5 -> 0.25 -> 0)
    [5211] = DR_CATEGORIES.STUN,    -- Bash (Rank 1)
    [6798] = DR_CATEGORIES.STUN,    -- Bash (Rank 2)
    [8983] = DR_CATEGORIES.STUN,    -- Bash (Rank 3)
    [408] = DR_CATEGORIES.STUN,     -- Kidney Shot (Rank 1)
    [8643] = DR_CATEGORIES.STUN,     -- Kidney Shot (Rank 2)
    -- Gouge (Incapacitate, not Stun)
    [1776] = DR_CATEGORIES.INCAPACITATE,    -- Gouge (Rank 1)
    [1777] = DR_CATEGORIES.INCAPACITATE,    -- Gouge (Rank 2)
    [8629] = DR_CATEGORIES.INCAPACITATE,    -- Gouge (Rank 3)
    [11285] = DR_CATEGORIES.INCAPACITATE,   -- Gouge (Rank 4)
    [11286] = DR_CATEGORIES.INCAPACITATE,   -- Gouge (Rank 5)
    [853] = DR_CATEGORIES.STUN,     -- Hammer of Justice (Rank 1)
    [5588] = DR_CATEGORIES.STUN,    -- Hammer of Justice (Rank 2)
    [5589] = DR_CATEGORIES.STUN,    -- Hammer of Justice (Rank 3)
    [10308] = DR_CATEGORIES.STUN,   -- Hammer of Justice (Rank 4)
    [1833] = DR_CATEGORIES.STUN,    -- Cheap Shot
    [9005] = DR_CATEGORIES.STUN,    -- Pounce (Rank 1)
    [9823] = DR_CATEGORIES.STUN,    -- Pounce (Rank 2)
    [9827] = DR_CATEGORIES.STUN,    -- Pounce (Rank 3)
    [27006] = DR_CATEGORIES.STUN,   -- Pounce (Rank 4)
    [12809] = DR_CATEGORIES.STUN,   -- Concussion Blow
    [100] = DR_CATEGORIES.STUN,     -- Charge
    [5530] = DR_CATEGORIES.STUN,    -- Mace Specialization Stun
    [19577] = DR_CATEGORIES.STUN,   -- Intimidation
    [7922] = DR_CATEGORIES.STUN,    -- Charge Stun
    [20615] = DR_CATEGORIES.STUN,   -- Intercept Stun (Rank 1)
    [20616] = DR_CATEGORIES.STUN,   -- Intercept Stun (Rank 2)
    [25274] = DR_CATEGORIES.STUN,    -- Intercept Stun (Rank 3)
    [25275] = DR_CATEGORIES.STUN,    -- Intercept Stun (Rank 4)
    [25272] = DR_CATEGORIES.STUN,   -- Intercept Stun (Rank 5)
    
    -- Fear (1.0 -> 0.5 -> 0.25 -> 0)
    [5782] = DR_CATEGORIES.FEAR,    -- Fear (Rank 1)
    [6213] = DR_CATEGORIES.FEAR,    -- Fear (Rank 2)
    [6215] = DR_CATEGORIES.FEAR,    -- Fear (Rank 3)
    [8122] = DR_CATEGORIES.FEAR,    -- Psychic Scream (Rank 1)
    [8124] = DR_CATEGORIES.FEAR,    -- Psychic Scream (Rank 2)
    [10888] = DR_CATEGORIES.FEAR,   -- Psychic Scream (Rank 3)
    [10890] = DR_CATEGORIES.FEAR,   -- Psychic Scream (Rank 4)
    [5246] = DR_CATEGORIES.FEAR,    -- Intimidating Shout
    [17108] = DR_CATEGORIES.FEAR,   -- Intimidating Shout (cower)
    [17276] = DR_CATEGORIES.FEAR,   -- Intimidating Shout (cower)
    [17277] = DR_CATEGORIES.FEAR,   -- Intimidating Shout (cower)
    [17278] = DR_CATEGORIES.FEAR,   -- Intimidating Shout (cower)
    
    -- Roots (1.0 -> 0.5 -> 0.25 -> 0)
    [339] = DR_CATEGORIES.ROOT,      -- Entangling Roots (Rank 1)
    [1062] = DR_CATEGORIES.ROOT,     -- Entangling Roots (Rank 2)
    [5195] = DR_CATEGORIES.ROOT,     -- Entangling Roots (Rank 3)
    [5196] = DR_CATEGORIES.ROOT,     -- Entangling Roots (Rank 4)
    [9852] = DR_CATEGORIES.ROOT,     -- Entangling Roots (Rank 5)
    [9853] = DR_CATEGORIES.ROOT,     -- Entangling Roots (Rank 6)
    [26989] = DR_CATEGORIES.ROOT,    -- Entangling Roots (Rank 7)
    [122] = DR_CATEGORIES.ROOT,      -- Frost Nova (Rank 1)
    [865] = DR_CATEGORIES.ROOT,      -- Frost Nova (Rank 2)
    [6131] = DR_CATEGORIES.ROOT,     -- Frost Nova (Rank 3)
    [10230] = DR_CATEGORIES.ROOT,    -- Frost Nova (Rank 4)
    [27088] = DR_CATEGORIES.ROOT,    -- Frost Nova (Rank 5)
    [27868] = DR_CATEGORIES.ROOT,    -- Frost Nova (Rank 6)
    
    -- Incapacitate (1.0 -> 0.5 -> 0.25 -> 0) - shares with disorient
    [6770] = DR_CATEGORIES.INCAPACITATE, -- Sap (Rank 1)
    [2070] = DR_CATEGORIES.INCAPACITATE, -- Sap (Rank 2)
    [11297] = DR_CATEGORIES.INCAPACITATE, -- Sap (Rank 3)
    [118] = DR_CATEGORIES.INCAPACITATE,   -- Polymorph (Rank 1)
    [12824] = DR_CATEGORIES.INCAPACITATE, -- Polymorph (Rank 2)
    [12825] = DR_CATEGORIES.INCAPACITATE, -- Polymorph (Rank 3)
    [12826] = DR_CATEGORIES.INCAPACITATE, -- Polymorph (Rank 4)
    [28272] = DR_CATEGORIES.INCAPACITATE, -- Polymorph: Pig
    [28271] = DR_CATEGORIES.INCAPACITATE, -- Polymorph: Turtle
    [20066] = DR_CATEGORIES.INCAPACITATE, -- Repentance
    [19503] = DR_CATEGORIES.INCAPACITATE, -- Scatter Shot
    [2094] = DR_CATEGORIES.INCAPACITATE, -- Blind (shares with incapacitate in TBC)
    
    -- Silence (0.5 -> 0.25 -> 0, 2 DRs only, but we track normally)
    [2139] = DR_CATEGORIES.SILENCE,   -- Counterspell
    [15487] = DR_CATEGORIES.SILENCE,  -- Silence (Priest)
    [34490] = DR_CATEGORIES.SILENCE,  -- Silencing Shot
    [19647] = DR_CATEGORIES.SILENCE,  -- Spell Lock (Felhunter)
    [18469] = DR_CATEGORIES.SILENCE,  -- Counterspell - Silenced (Improved)
    
    -- Cyclone (shares DR only with itself)
    [33786] = DR_CATEGORIES.CYCLONE,  -- Cyclone
}

-- DR State storage: {[guid] = {[category] = {count = 1-3, expires_at = timestamp, last_spell_id = id}}}
local dr_state = {}

local DR_RESET_DURATION = 18.0  -- 18 second DR reset timer

-- Get unit GUID safely
local function get_unit_guid(unit)
    if not unit then return nil end
    if type(unit) == "string" then return unit end
    local ok, guid = pcall(function() return unit:get_guid() end)
    if ok and type(guid) == "string" then return guid end
    return nil
end

-- Record a CC spell application on a target
-- Called from spell cast callback when we observe a CC being applied
function M.record_dr_application(target, spell_id)
    if not spell_id then return end
    
    local category = SPELL_TO_CATEGORY[spell_id]
    if not category then return end  -- Not a DR-tracked spell
    
    local guid = get_unit_guid(target)
    if not guid then return end
    
    local t = now()
    local entry = dr_state[guid]
    if not entry then
        entry = {}
        dr_state[guid] = entry
    end
    
    local cat_entry = entry[category]
    if not cat_entry then
        cat_entry = {count = 0, expires_at = 0, last_spell_id = nil}
        entry[category] = cat_entry
    end
    
    -- Check if previous DR has expired (reset)
    if t > cat_entry.expires_at then
        cat_entry.count = 0
    end
    
    -- Increment count (cap at 3+)
    cat_entry.count = math.min(cat_entry.count + 1, 3)
    cat_entry.expires_at = t + DR_RESET_DURATION
    cat_entry.last_spell_id = spell_id
end

-- Get raw DR state table for a unit/category
-- Returns {count = N, expires_at = T, last_spell_id = ID} or nil
function M.get_dr_state(unit_or_guid, category)
    if not unit_or_guid then return nil end
    local guid = get_unit_guid(unit_or_guid)
    if not guid then return nil end
    
    local entry = dr_state[guid]
    if not entry then return nil end
    
    local cat_entry = entry[category]
    if not cat_entry then return nil end
    
    -- Check expiry
    local t = now()
    if t > cat_entry.expires_at then
        entry[category] = nil
        return nil
    end
    
    return cat_entry
end

-- Get the current DR multiplier for a spell cast on a target
-- Returns: 1.0 (full), 0.5 (half), 0.25 (quarter), 0.0 (immune)
function M.get_dr_multiplier(unit_or_guid, category)
    local state = M.get_dr_state(unit_or_guid, category)
    if not state then return 1.0 end
    
    local count = state.count
    -- DR progression: 1st = 1.0, 2nd = 0.5, 3rd = 0.25, 4th+ = immune
    if count == 0 then return 1.0
    elseif count == 1 then return 0.5
    elseif count == 2 then return 0.25
    else return 0.0 end
end

-- Check if target is immune to further DRs in this category
function M.is_dr_immune(unit_or_guid, category)
    local state = M.get_dr_state(unit_or_guid, category)
    if not state then return false end
    return state.count >= 3
end

-- Get the number of DRs applied to this category (0-3+)
function M.get_dr_count(unit_or_guid, category)
    local state = M.get_dr_state(unit_or_guid, category)
    if not state then return 0 end
    return state.count
end

-- Get seconds until DR resets for this category
function M.get_dr_reset_in(unit_or_guid, category)
    local state = M.get_dr_state(unit_or_guid, category)
    if not state then return 0 end
    local t = now()
    return math.max(0, state.expires_at - t)
end

-- Clean up expired entries to prevent memory growth
function M.cleanup()
    local t = now()
    for guid, entry in pairs(dr_state) do
        local has_active = false
        for cat, cat_entry in pairs(entry) do
            if t > cat_entry.expires_at then
                entry[cat] = nil
            else
                has_active = true
            end
        end
        if not has_active then
            dr_state[guid] = nil
        end
    end
end

-- Initialize: register spell cast callback if available
function M.init()
    if not NS then return end
    
    -- Register on spell cast callback if Sylvanas exposes it
    -- Signature: function(spell_id, target, data)
    if NS.register_on_spell_cast then
        NS.register_on_spell_cast(function(spell_id, target, data)
            -- data contains additional info like caster
            if target and spell_id then
                M.record_dr_application(target, spell_id)
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

-- Manual hook for when external modules detect CC application
-- Useful when spell cast callback data is incomplete
function M.on_cc_applied(target, spell_id)
    M.record_dr_application(target, spell_id)
end

if NS then
    NS.DRTracker = M
    -- Auto-init if NS is ready
    M.init()
end

return M
