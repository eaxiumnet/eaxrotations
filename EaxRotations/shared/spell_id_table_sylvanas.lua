-- spell_id_table_sylvanas.lua -- auto-generated expansion-aware spell ID table (TBC + Anniversary + Vanilla keys).
-- WHAT:   auto-generated expansion-aware spell ID table (TBC + Anniversary + Vanilla keys).
-- WHEN:   consumed by every spec build_state.
-- WHY:    eliminates per-spec string-key spell lookups.
-- SAFETY: pure constants; generator-stamped; nil-tolerant key fetch.
-- DECISION: pure data; consumed via require(); nil-tolerant key fetch.


-- =============================================================================
-- Expansion-aware Spell ID Table (AUTO-GENERATED)
-- =============================================================================
-- Generated: 2026-06-06 03:51:40
-- Source: lexxer.org API (TBC + Vanilla)
--
-- Maps spell names to their expansion-specific IDs.
-- Only includes spells whose IDs DIFFER between TBC and Vanilla.
-- All other spells use the same ID in both expansions.
--
-- Usage:
--   local table = require('shared/spell_id_table_sylvanas')
--   local id = table.resolve('Death Wish')  -- returns expansion-correct ID
-- =============================================================================

local M = {}

-- Lookup: spell_name -> { tbc = id, vanilla = id }
local SWAPPED_SPELLS = {
    -- Mage
    ["Arcane Missiles"] = { tbc = 8418, vanilla = 8417 },  -- TBC=8418, Vanilla=8417 (arcane)
    ["Cold Snap"] = { tbc = 11958, vanilla = 12472 },  -- TBC=11958, Vanilla=12472
    ["Icy Veins"] = { tbc = 12472, vanilla = nil },  -- TBC-only; ID 12472 conflicts with Vanilla "Cold Snap"

    -- Warrior
    ["Death Wish"] = { tbc = 12292, vanilla = 12328 },  -- TBC=12292, Vanilla=12328 (physical)
    ["Sweeping Strikes"] = { tbc = 12328, vanilla = 12292 },  -- TBC=12328, Vanilla=12292
}

-- Cached expansion key (populated on first call)
local _expansion = nil

--- Resolve a spell name to its expansion-specific ID.
--- Returns nil if the spell is not in the swapped table.
--- For non-swapped spells, use the ID directly (same in both expansions).
---
--- @param spell_name string The spell name (e.g., 'Death Wish')
--- @return number|nil spell_id The expansion-correct spell ID, or nil
function M.resolve(spell_name)
    local entry = SWAPPED_SPELLS[spell_name]
    if not entry then return nil end
    -- Lazy-init expansion detection
    if _expansion == nil then
        local NS = _G.EaxRotations
        if NS and NS.is_vanilla and NS.is_vanilla() then
            _expansion = "vanilla"
        else
            _expansion = "tbc"
        end
    end
    return entry[_expansion]
end

--- Get the TBC ID for a swapped spell.
--- @param spell_name string
--- @return number|nil
function M.tbc_id(spell_name)
    local entry = SWAPPED_SPELLS[spell_name]
    return entry and entry.tbc or nil
end

--- Get the Vanilla ID for a swapped spell.
--- @param spell_name string
--- @return number|nil
function M.vanilla_id(spell_name)
    local entry = SWAPPED_SPELLS[spell_name]
    return entry and entry.vanilla or nil
end

--- Check if a spell name has swapped IDs between expansions.
--- @param spell_name string
--- @return boolean
function M.is_swapped(spell_name)
    return SWAPPED_SPELLS[spell_name] ~= nil
end

--- Get all swapped spell names (for debugging/testing).
--- @return string[]
function M.get_all_swapped()
    local result = {}
    local n = 0
    for name in pairs(SWAPPED_SPELLS) do
        n = n + 1
        result[n] = name
    end
    table.sort(result)
    return result
end

--- Force re-detection of expansion (for testing).
function M._reset_expansion()
    _expansion = nil
end

--- Raw table access (for testing).
M._SWAPPED_SPELLS = SWAPPED_SPELLS

return M
