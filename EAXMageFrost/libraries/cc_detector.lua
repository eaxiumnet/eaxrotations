--[[
    cc_detector.lua
    Crowd Control Detection Module for TBC Classic WoW
    
    Provides centralized detection of all crowd control debuffs
    for rotation decision-making and safety checks.
    
    Usage:
        local is_ccd, cc_type = cc_detector.is_ccd(unit)
        if is_ccd then
            -- Handle CC state
        end
--]]

-- Cache buff_manager at module load time
local buff_manager = require("common/modules/buff_manager")

-- ============================================================================
-- TBC CC SPELL DATABASE
-- ============================================================================

local TBC_CC_SPELLS = {
    -- Polymorph (Mage)
    POLYMORPH = {
        118,    -- Rank 1
        12824,  -- Rank 2
        12825,  -- Rank 3
        12826,  -- Rank 4
        28271,  -- Turtle
        28272,  -- Pig
    },
    
    -- Fear (Warlock)
    FEAR = {
        5782,   -- Rank 1
        6213,   -- Rank 2
        6215,   -- Rank 3
    },
    
    -- Psychic Scream (Priest)
    PSYCHIC_SCREAM = {
        8122,   -- Rank 1
        8124,   -- Rank 2
        10888,  -- Rank 3
        10890,  -- Rank 4
    },
    
    -- Howl of Terror (Warlock)
    HOWL_OF_TERROR = {
        5484,   -- Rank 1
        17928,  -- Rank 2
    },
    
    -- Death Coil (Warlock) - Horror effect
    HORROR = {
        6789,   -- Rank 1
        17925,  -- Rank 2
        17926,  -- Rank 3
        27223,  -- Rank 4
    },
    
    -- Sap (Rogue)
    SAP = {
        6770,   -- Rank 1
        2070,   -- Rank 2
        11297,  -- Rank 3
    },
    
    -- Gouge (Rogue)
    GOUGE = {
        1776,   -- Rank 1
        1777,   -- Rank 2
        8629,   -- Rank 3
        11285,  -- Rank 4
        11286,  -- Rank 5
    },
    
    -- Blind (Rogue)
    BLIND = {
        2094,   -- Rank 1
    },
    
    -- Cyclone (Druid)
    CYCLONE = {
        33786,  -- Rank 1
    },
    
    -- Entangling Roots (Druid)
    ROOTS = {
        339,    -- Rank 1
        1062,   -- Rank 2
        5196,   -- Rank 3
        5197,   -- Rank 4
        9852,   -- Rank 5
        9853,   -- Rank 6
        26989,  -- Rank 7
        26990,  -- Rank 8
    },
    
    -- Stun effects
    STUN = {
        -- Cheap Shot (Rogue)
        1833,
        -- Kidney Shot (Rogue)
        408,    -- Rank 1
        8643,   -- Rank 2
        -- Hammer of Justice (Paladin)
        853,    -- Rank 1
        5588,   -- Rank 2
        5589,   -- Rank 3
        10308,  -- Rank 4
        -- Bash (Druid)
        5211,   -- Rank 1
        6798,   -- Rank 2
        8983,   -- Rank 3
        -- War Stomp (Tauren)
        20549,
        -- Charge Stun (Warrior)
        7922,
        -- Concussion Blow (Warrior)
        12809,
        -- Intercept Stun (Warrior)
        20253,
        -- Intimidation (Hunter)
        19577,
        -- Shadowfury (Warlock)
        30283,  -- Rank 1
        30413,  -- Rank 2
        30414,  -- Rank 3
    },
    
    -- Silence effects
    SILENCE = {
        15487,  -- Silence (Priest)
        18469,  -- Counterspell - Silenced (Mage)
        18425,  -- Kick - Silenced (Rogue)
        24259,  -- Spell Lock (Warlock Felhunter)
        18498,  -- Shield Bash - Silenced (Warrior)
        34490,  -- Silencing Shot (Hunter)
    },
    
    -- Disarm (Warrior)
    DISARM = {
        676,    -- Rank 1
    },
    
    -- Charm effects
    CHARM = {
        -- Mind Control (Priest)
        605,    -- Rank 1
        10911,  -- Rank 2
        10912,  -- Rank 3
        -- Seduction (Warlock Succubus)
        6358,   -- Rank 1
        6359,   -- Rank 2
    },
    
    -- Sleep effects
    SLEEP = {
        -- Hibernate (Druid)
        2637,   -- Rank 1
        18657,  -- Rank 2
        18658,  -- Rank 3
        -- Wyvern Sting (Hunter)
        19386,  -- Rank 1
        24132,  -- Rank 2
        24133,  -- Rank 3
        27068,  -- Rank 4
    },
    
    -- Banish (Warlock)
    BANISH = {
        710,    -- Rank 1
        18647,  -- Rank 2
    },
    
    -- Hex (Shaman - added in TBC patch 2.3)
    HEX = {
        51514,  -- Rank 1
    },
    
    -- Freezing Trap (Hunter)
    FREEZING_TRAP = {
        3355,   -- Rank 1
        14308,  -- Rank 2
        14309,  -- Rank 3
    },
    
    -- Scatter Shot (Hunter)
    SCATTER_SHOT = {
        19503,  -- Rank 1
    },
    
    -- Shackle Undead (Priest)
    SHACKLE_UNDEAD = {
        9484,   -- Rank 1
        9485,   -- Rank 2
        10955,  -- Rank 3
    },
    
    -- Intimidating Shout (Warrior)
    INTIMIDATING_SHOUT = {
        5246,   -- Rank 1
    },
}

-- ============================================================================
-- FLATTENED LOOKUP TABLES
-- ============================================================================

-- All CC spells in one flat table for quick lookup
local ALL_CC_SPELLS = {}

-- CC type lookup by spell ID
local CC_TYPE_BY_SPELL = {}

-- Build flattened tables
for cc_type, spells in pairs(TBC_CC_SPELLS) do
    for _, spell_id in ipairs(spells) do
        ALL_CC_SPELLS[spell_id] = true
        CC_TYPE_BY_SPELL[spell_id] = cc_type
    end
end

-- ============================================================================
-- CATEGORY-SPECIFIC SPELL TABLES
-- ============================================================================

-- Stun spells only
local STUN_SPELLS = {}
for _, spell_id in ipairs(TBC_CC_SPELLS.STUN) do
    STUN_SPELLS[spell_id] = true
end

-- Silence spells only
local SILENCE_SPELLS = {}
for _, spell_id in ipairs(TBC_CC_SPELLS.SILENCE) do
    SILENCE_SPELLS[spell_id] = true
end

-- Fear spells (includes Fear, Psychic Scream, Howl of Terror, Intimidating Shout)
local FEAR_SPELLS = {}
for _, spell_id in ipairs(TBC_CC_SPELLS.FEAR) do
    FEAR_SPELLS[spell_id] = true
end
for _, spell_id in ipairs(TBC_CC_SPELLS.PSYCHIC_SCREAM) do
    FEAR_SPELLS[spell_id] = true
end
for _, spell_id in ipairs(TBC_CC_SPELLS.HOWL_OF_TERROR) do
    FEAR_SPELLS[spell_id] = true
end
for _, spell_id in ipairs(TBC_CC_SPELLS.INTIMIDATING_SHOUT) do
    FEAR_SPELLS[spell_id] = true
end

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Validate unit object
local function is_valid_unit(unit)
    if not unit then return false end
    local ok, valid = pcall(function() return unit:is_valid() end)
    return ok and valid
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

local cc_detector = {}

--[[
    Check if a unit has any crowd control debuff
    
    @param unit - Game object to check
    @return boolean - true if CC'd, false otherwise
    @return string|nil - CC type if found, nil otherwise
--]]
function cc_detector.is_ccd(unit)
    if not is_valid_unit(unit) then
        return false, nil
    end
    
    local debuff_data = buff_manager:get_debuff_data(unit, ALL_CC_SPELLS)
    if not debuff_data then
        return false, nil
    end
    
    for spell_id, _ in pairs(debuff_data) do
        if ALL_CC_SPELLS[spell_id] then
            local cc_type = CC_TYPE_BY_SPELL[spell_id]
            return true, cc_type
        end
    end
    
    return false, nil
end

--[[
    Determine if rotation should stop due to CC
    Returns true for CC types that prevent meaningful action
    
    @param unit - Game object to check (typically local player)
    @return boolean - true if rotation should stop
    @return string|nil - reason for stopping
--]]
function cc_detector.should_stop_rotation(unit)
    if not is_valid_unit(unit) then
        return false, nil
    end
    
    local debuff_data = buff_manager:get_debuff_data(unit, ALL_CC_SPELLS)
    if not debuff_data then
        return false, nil
    end
    
    -- Priority order for stopping rotation
    local stop_reasons = {
        STUN = "stunned",
        POLYMORPH = "polymorphed",
        FEAR = "feared",
        PSYCHIC_SCREAM = "feared",
        HOWL_OF_TERROR = "feared",
        HORROR = "horrified",
        SAP = "sapped",
        GOUGE = "gouged",
        BLIND = "blinded",
        CYCLONE = "cycloned",
        CHARM = "charmed",
        SLEEP = "asleep",
        BANISH = "banished",
        HEX = "hexed",
        FREEZING_TRAP = "frozen",
        SCATTER_SHOT = "scattered",
        SHACKLE_UNDEAD = "shackled",
        INTIMIDATING_SHOUT = "feared",
    }
    
    for spell_id, _ in pairs(debuff_data) do
        local cc_type = CC_TYPE_BY_SPELL[spell_id]
        if cc_type and stop_reasons[cc_type] then
            return true, stop_reasons[cc_type]
        end
    end
    
    -- These CC types don't necessarily stop rotation
    -- ROOTS - can still cast/attack
    -- SILENCE - handled separately for casters
    -- DISARM - handled separately for melee
    
    return false, nil
end

--[[
    Check if unit is stunned
    
    @param unit - Game object to check
    @return boolean - true if stunned
--]]
function cc_detector.is_stunned(unit)
    if not is_valid_unit(unit) then
        return false
    end
    
    local debuff_data = buff_manager:get_debuff_data(unit, STUN_SPELLS)
    if not debuff_data then
        return false
    end
    
    for spell_id, _ in pairs(debuff_data) do
        if STUN_SPELLS[spell_id] then
            return true
        end
    end
    
    return false
end

--[[
    Check if unit is silenced
    
    @param unit - Game object to check
    @return boolean - true if silenced
--]]
function cc_detector.is_silenced(unit)
    if not is_valid_unit(unit) then
        return false
    end
    
    local debuff_data = buff_manager:get_debuff_data(unit, SILENCE_SPELLS)
    if not debuff_data then
        return false
    end
    
    for spell_id, _ in pairs(debuff_data) do
        if SILENCE_SPELLS[spell_id] then
            return true
        end
    end
    
    return false
end

--[[
    Check if unit is feared
    
    @param unit - Game object to check
    @return boolean - true if feared
--]]
function cc_detector.is_feared(unit)
    if not is_valid_unit(unit) then
        return false
    end
    
    local debuff_data = buff_manager:get_debuff_data(unit, FEAR_SPELLS)
    if not debuff_data then
        return false
    end
    
    for spell_id, _ in pairs(debuff_data) do
        if FEAR_SPELLS[spell_id] then
            return true
        end
    end
    
    return false
end

--[[
    Get remaining CC duration and type
    
    @param unit - Game object to check
    @return number - remaining duration in seconds (0 if not CC'd)
    @return string|nil - CC type if found
--]]
function cc_detector.get_cc_duration(unit)
    if not is_valid_unit(unit) then
        return 0, nil
    end
    
    local debuff_data = buff_manager:get_debuff_data(unit, ALL_CC_SPELLS)
    if not debuff_data then
        return 0, nil
    end
    
    local max_duration = 0
    local cc_type_found = nil
    
    for spell_id, debuff_info in pairs(debuff_data) do
        if ALL_CC_SPELLS[spell_id] then
            local remaining = debuff_info.remaining or 0
            if remaining > max_duration then
                max_duration = remaining
                cc_type_found = CC_TYPE_BY_SPELL[spell_id]
            end
        end
    end
    
    return max_duration, cc_type_found
end

--[[
    Check if unit has any of the specified debuffs
    
    @param unit - Game object to check
    @param spell_ids - Table of spell IDs to check for { [id] = true, ... }
    @return boolean - true if any debuff found
--]]
function cc_detector.has_any_debuff(unit, spell_ids)
    if not is_valid_unit(unit) then
        return false
    end
    
    if not spell_ids or type(spell_ids) ~= "table" then
        return false
    end
    
    local debuff_data = buff_manager:get_debuff_data(unit, spell_ids)
    if not debuff_data then
        return false
    end
    
    for spell_id, _ in pairs(debuff_data) do
        if spell_ids[spell_id] then
            return true
        end
    end
    
    return false
end

--[[
    Get all active CC debuffs on a unit
    
    @param unit - Game object to check
    @return table - Array of { spell_id, cc_type, remaining } tables
--]]
function cc_detector.get_all_cc_debuffs(unit)
    if not is_valid_unit(unit) then
        return {}
    end
    
    local debuff_data = buff_manager:get_debuff_data(unit, ALL_CC_SPELLS)
    if not debuff_data then
        return {}
    end
    
    local result = {}
    for spell_id, debuff_info in pairs(debuff_data) do
        if ALL_CC_SPELLS[spell_id] then
            table.insert(result, {
                spell_id = spell_id,
                cc_type = CC_TYPE_BY_SPELL[spell_id],
                remaining = debuff_info.remaining or 0,
                stacks = debuff_info.stacks or 1,
            })
        end
    end
    
    return result
end

--[[
    Check for specific CC type
    
    @param unit - Game object to check
    @param cc_type - String CC type from TBC_CC_SPELLS keys
    @return boolean - true if unit has that CC type
--]]
function cc_detector.has_cc_type(unit, cc_type)
    if not is_valid_unit(unit) then
        return false
    end
    
    if not cc_type or not TBC_CC_SPELLS[cc_type] then
        return false
    end
    
    local spell_table = {}
    for _, spell_id in ipairs(TBC_CC_SPELLS[cc_type]) do
        spell_table[spell_id] = true
    end
    
    local debuff_data = buff_manager:get_debuff_data(unit, spell_table)
    if not debuff_data then
        return false
    end
    
    for spell_id, _ in pairs(debuff_data) do
        if spell_table[spell_id] then
            return true
        end
    end
    
    return false
end

--[[
    Check if unit is disarmed
    
    @param unit - Game object to check
    @return boolean - true if disarmed
--]]
function cc_detector.is_disarmed(unit)
    return cc_detector.has_cc_type(unit, "DISARM")
end

--[[
    Check if unit is rooted
    
    @param unit - Game object to check
    @return boolean - true if rooted
--]]
function cc_detector.is_rooted(unit)
    return cc_detector.has_cc_type(unit, "ROOTS")
end

--[[
    Check if unit is polymorphed
    
    @param unit - Game object to check
    @return boolean - true if polymorphed
--]]
function cc_detector.is_polymorphed(unit)
    return cc_detector.has_cc_type(unit, "POLYMORPH")
end

--[[
    Check if unit is sapped
    
    @param unit - Game object to check
    @return boolean - true if sapped
--]]
function cc_detector.is_sapped(unit)
    return cc_detector.has_cc_type(unit, "SAP")
end

--[[
    Check if unit is cycloned
    
    @param unit - Game object to check
    @return boolean - true if cycloned
--]]
function cc_detector.is_cycloned(unit)
    return cc_detector.has_cc_type(unit, "CYCLONE")
end

-- Export the module
return cc_detector
