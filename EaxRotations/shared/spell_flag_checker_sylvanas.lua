-- ============================================================================
-- Shared Helper: Spell Flag Checker (Form-Aware Casting)
-- ============================================================================
-- Provides utilities for checking spell restrictions related to shapeshift
-- forms, particularly for druids who have many form-specific abilities.
--
-- Features:
--   - Reads spell flags from wowhead_data JSON files (cached)
--   - Hardcoded TBC druid form restriction table for accuracy
--   - can_cast_in_form(spell_id, form_id) for form-aware rotation logic
--   - is_form_restricted(spell_id) to check if spell has any form requirement
--
-- Form IDs (TBC):
--   0 = Humanoid (no form)
--   1 = Bear Form (Dire Bear Form uses same ID)
--   2 = Cat Form
--   3 = Travel Form (Aquatic also uses 3 in some contexts)
--   4 = Moonkin Form
--   5 = Tree of Life Form
--
-- Usage:
--   local spell_flags = require("shared/spell_flag_checker_sylvanas")
--   if spell_flags.can_cast_in_form(SPELLS.Shred, 2) then  -- Cat Form
--       -- Can cast Shred
--   end
--
-- No NS/api/ dependencies — safe for unit testing.
-- ============================================================================

local M = {}

-- ============================================================================
-- Spell Flag Data — uses only hardcoded FORM_RESTRICTIONS table (240+ entries).
-- The wowhead_data bridge module contains spell flags but the hardcoded table
-- is the authoritative source for TBC druid form restrictions.
-- ============================================================================

local _flag_cache = {}  -- [spell_id] = flags table or false (miss)
local _bridge = nil
local function get_bridge()
    if _bridge then return _bridge end
    local ok, mod = pcall(require, "shared/wowhead_data_bridge_sylvanas")
    if ok and type(mod) == "table" then
        _bridge = mod
        return mod
    end
    return nil
end

-- ============================================================================
-- Hardcoded TBC Druid Form Restrictions
-- ============================================================================
-- Based on TBC spell data (patch 2.4.3). These are the most common form
-- restrictions. Wowhead data doesn't include explicit flags, so this table
-- provides accurate form requirements for rotation logic.
--
-- Form IDs:
--   0 = Humanoid
--   1 = Bear/Dire Bear
--   2 = Cat
--   3 = Travel/Aquatic
--   4 = Moonkin
--   5 = Tree of Life
--
-- Structure: [spell_id] = {required_form = form_id, description = "reason"}
-- Only spells with explicit form requirements are listed.

local FORM_RESTRICTIONS = {
    -- Bear Form abilities (require Bear Form = 1)
    [99] = {required_form = 1, description = "Demoralizing Roar - Bear only"},
    [1735] = {required_form = 1, description = "Demoralizing Roar - Bear only"},
    [9490] = {required_form = 1, description = "Demoralizing Roar - Bear only"},
    [9747] = {required_form = 1, description = "Demoralizing Roar - Bear only"},
    [9898] = {required_form = 1, description = "Demoralizing Roar - Bear only"},
    [26998] = {required_form = 1, description = "Demoralizing Roar - Bear only"},
    [6807] = {required_form = 1, description = "Maul - Bear only"},
    [6808] = {required_form = 1, description = "Maul - Bear only"},
    [6809] = {required_form = 1, description = "Maul - Bear only"},
    [8972] = {required_form = 1, description = "Maul - Bear only"},
    [9745] = {required_form = 1, description = "Maul - Bear only"},
    [9880] = {required_form = 1, description = "Maul - Bear only"},
    [9881] = {required_form = 1, description = "Maul - Bear only"},
    [26996] = {required_form = 1, description = "Maul - Bear only"},
    [779] = {required_form = 1, description = "Swipe - Bear only"},
    [780] = {required_form = 1, description = "Swipe - Bear only"},
    [769] = {required_form = 1, description = "Swipe - Bear only"},
    [9754] = {required_form = 1, description = "Swipe - Bear only"},
    [9908] = {required_form = 1, description = "Swipe - Bear only"},
    [26997] = {required_form = 1, description = "Swipe - Bear only"},
    [5209] = {required_form = 1, description = "Challenging Roar - Bear only"},
    [5211] = {required_form = 1, description = "Bash - Bear only"},
    [6798] = {required_form = 1, description = "Bash - Bear only"},
    [8983] = {required_form = 1, description = "Bash - Bear only"},
    [6795] = {required_form = 1, description = "Growl - Bear only"},
    [33878] = {required_form = 1, description = "Mangle (Bear) - Bear only"},
    [33986] = {required_form = 1, description = "Mangle (Bear) - Bear only"},
    [33987] = {required_form = 1, description = "Mangle (Bear) - Bear only"},

    -- Cat Form abilities (require Cat Form = 2)
    [1082] = {required_form = 2, description = "Claw - Cat only"},
    [3029] = {required_form = 2, description = "Claw - Cat only"},
    [5201] = {required_form = 2, description = "Claw - Cat only"},
    [9849] = {required_form = 2, description = "Claw - Cat only"},
    [9850] = {required_form = 2, description = "Claw - Cat only"},
    [27000] = {required_form = 2, description = "Claw - Cat only"},
    [5221] = {required_form = 2, description = "Shred - Cat only"},
    [6800] = {required_form = 2, description = "Shred - Cat only"},
    [8992] = {required_form = 2, description = "Shred - Cat only"},
    [9829] = {required_form = 2, description = "Shred - Cat only"},
    [9830] = {required_form = 2, description = "Shred - Cat only"},
    [27001] = {required_form = 2, description = "Shred - Cat only"},
    [27002] = {required_form = 2, description = "Shred - Cat only"},
    [1822] = {required_form = 2, description = "Rake - Cat only"},
    [1823] = {required_form = 2, description = "Rake - Cat only"},
    [1824] = {required_form = 2, description = "Rake - Cat only"},
    [9904] = {required_form = 2, description = "Rake - Cat only"},
    [27003] = {required_form = 2, description = "Rake - Cat only"},
    [1079] = {required_form = 2, description = "Rip - Cat only"},
    [9492] = {required_form = 2, description = "Rip - Cat only"},
    [9493] = {required_form = 2, description = "Rip - Cat only"},
    [9752] = {required_form = 2, description = "Rip - Cat only"},
    [9894] = {required_form = 2, description = "Rip - Cat only"},
    [9896] = {required_form = 2, description = "Rip - Cat only"},
    [27008] = {required_form = 2, description = "Rip - Cat only"},
    [22568] = {required_form = 2, description = "Ferocious Bite - Cat only"},
    [22827] = {required_form = 2, description = "Ferocious Bite - Cat only"},
    [22828] = {required_form = 2, description = "Ferocious Bite - Cat only"},
    [22829] = {required_form = 2, description = "Ferocious Bite - Cat only"},
    [31018] = {required_form = 2, description = "Ferocious Bite - Cat only"},
    [24248] = {required_form = 2, description = "Ferocious Bite - Cat only"},
    [5217] = {required_form = 2, description = "Tiger's Fury - Cat only"},
    [6793] = {required_form = 2, description = "Tiger's Fury - Cat only"},
    [9845] = {required_form = 2, description = "Tiger's Fury - Cat only"},
    [9846] = {required_form = 2, description = "Tiger's Fury - Cat only"},
    [27004] = {required_form = 2, description = "Tiger's Fury - Cat only"},
    [5215] = {required_form = 2, description = "Prowl - Cat only"},
    [6783] = {required_form = 2, description = "Prowl - Cat only"},
    [9913] = {required_form = 2, description = "Prowl - Cat only"},
    [1850] = {required_form = 2, description = "Dash - Cat only"},
    [9821] = {required_form = 2, description = "Dash - Cat only"},
    [33357] = {required_form = 2, description = "Dash - Cat only"},
    [33876] = {required_form = 2, description = "Mangle (Cat) - Cat only"},
    [33982] = {required_form = 2, description = "Mangle (Cat) - Cat only"},
    [33983] = {required_form = 2, description = "Mangle (Cat) - Cat only"},
    [22570] = {required_form = 2, description = "Maim - Cat only"},
    [49802] = {required_form = 2, description = "Maim - Cat only"},

    -- Moonkin Form abilities (require Moonkin Form = 4)
    [24858] = {required_form = 4, description = "Moonkin Form itself"},

    -- Tree of Life Form abilities (require Tree of Life = 5)
    [33891] = {required_form = 5, description = "Tree of Life Form itself"},

    -- Caster-only spells (cannot be cast in any form)
    -- These are spells that explicitly cannot be used while shapeshifted
    [2912] = {required_form = 0, description = "Starfire - Caster only"},
    [8949] = {required_form = 0, description = "Starfire - Caster only"},
    [8950] = {required_form = 0, description = "Starfire - Caster only"},
    [8951] = {required_form = 0, description = "Starfire - Caster only"},
    [9875] = {required_form = 0, description = "Starfire - Caster only"},
    [9876] = {required_form = 0, description = "Starfire - Caster only"},
    [25298] = {required_form = 0, description = "Starfire - Caster only"},
    [26986] = {required_form = 0, description = "Starfire - Caster only"},
    [5176] = {required_form = 0, description = "Wrath - Caster only"},
    [5177] = {required_form = 0, description = "Wrath - Caster only"},
    [5178] = {required_form = 0, description = "Wrath - Caster only"},
    [5179] = {required_form = 0, description = "Wrath - Caster only"},
    [5180] = {required_form = 0, description = "Wrath - Caster only"},
    [6780] = {required_form = 0, description = "Wrath - Caster only"},
    [8905] = {required_form = 0, description = "Wrath - Caster only"},
    [9912] = {required_form = 0, description = "Wrath - Caster only"},
    [26984] = {required_form = 0, description = "Wrath - Caster only"},
    [26985] = {required_form = 0, description = "Wrath - Caster only"},
    [33782] = {required_form = 0, description = "Wrath - Caster only"},
    [8921] = {required_form = 0, description = "Moonfire - Caster only"},
    [8924] = {required_form = 0, description = "Moonfire - Caster only"},
    [8925] = {required_form = 0, description = "Moonfire - Caster only"},
    [8926] = {required_form = 0, description = "Moonfire - Caster only"},
    [8927] = {required_form = 0, description = "Moonfire - Caster only"},
    [8928] = {required_form = 0, description = "Moonfire - Caster only"},
    [8929] = {required_form = 0, description = "Moonfire - Caster only"},
    [9833] = {required_form = 0, description = "Moonfire - Caster only"},
    [9834] = {required_form = 0, description = "Moonfire - Caster only"},
    [9835] = {required_form = 0, description = "Moonfire - Caster only"},
    [26987] = {required_form = 0, description = "Moonfire - Caster only"},
    [26988] = {required_form = 0, description = "Moonfire - Caster only"},
    [33783] = {required_form = 0, description = "Moonfire - Caster only"},
    [5570] = {required_form = 0, description = "Insect Swarm - Caster only"},
    [24974] = {required_form = 0, description = "Insect Swarm - Caster only"},
    [24975] = {required_form = 0, description = "Insect Swarm - Caster only"},
    [24976] = {required_form = 0, description = "Insect Swarm - Caster only"},
    [24977] = {required_form = 0, description = "Insect Swarm - Caster only"},
    [27013] = {required_form = 0, description = "Insect Swarm - Caster only"},
    [33784] = {required_form = 0, description = "Insect Swarm - Caster only"},
    [339] = {required_form = 0, description = "Entangling Roots - Caster only"},
    [1062] = {required_form = 0, description = "Entangling Roots - Caster only"},
    [5195] = {required_form = 0, description = "Entangling Roots - Caster only"},
    [5196] = {required_form = 0, description = "Entangling Roots - Caster only"},
    [9852] = {required_form = 0, description = "Entangling Roots - Caster only"},
    [9853] = {required_form = 0, description = "Entangling Roots - Caster only"},
    [26989] = {required_form = 0, description = "Entangling Roots - Caster only"},
    [27010] = {required_form = 0, description = "Entangling Roots - Caster only"},
    [1126] = {required_form = 0, description = "Mark of the Wild - Caster only"},
    [5232] = {required_form = 0, description = "Mark of the Wild - Caster only"},
    [6756] = {required_form = 0, description = "Mark of the Wild - Caster only"},
    [5234] = {required_form = 0, description = "Mark of the Wild - Caster only"},
    [9884] = {required_form = 0, description = "Mark of the Wild - Caster only"},
    [9885] = {required_form = 0, description = "Mark of the Wild - Caster only"},
    [26990] = {required_form = 0, description = "Mark of the Wild - Caster only"},
    [774] = {required_form = 0, description = "Rejuvenation - Caster only"},
    [1058] = {required_form = 0, description = "Rejuvenation - Caster only"},
    [3627] = {required_form = 0, description = "Rejuvenation - Caster only"},
    [8910] = {required_form = 0, description = "Rejuvenation - Caster only"},
    [9839] = {required_form = 0, description = "Rejuvenation - Caster only"},
    [9840] = {required_form = 0, description = "Rejuvenation - Caster only"},
    [9841] = {required_form = 0, description = "Rejuvenation - Caster only"},
    [25299] = {required_form = 0, description = "Rejuvenation - Caster only"},
    [26981] = {required_form = 0, description = "Rejuvenation - Caster only"},
    [26982] = {required_form = 0, description = "Rejuvenation - Caster only"},
    [740] = {required_form = 0, description = "Tranquility - Caster only"},
    [8918] = {required_form = 0, description = "Tranquility - Caster only"},
    [9862] = {required_form = 0, description = "Tranquility - Caster only"},
    [9863] = {required_form = 0, description = "Tranquility - Caster only"},
    [26983] = {required_form = 0, description = "Tranquility - Caster only"},
    [33785] = {required_form = 0, description = "Tranquility - Caster only"},
    [18562] = {required_form = 0, description = "Swiftmend - Caster only"},
    [33763] = {required_form = 0, description = "Lifebloom - Caster only"},
    [48450] = {required_form = 0, description = "Lifebloom - Caster only"},
    [48451] = {required_form = 0, description = "Lifebloom - Caster only"},
    [48443] = {required_form = 0, description = "Regrowth - Caster only"},
    [8936] = {required_form = 0, description = "Regrowth - Caster only"},
    [8938] = {required_form = 0, description = "Regrowth - Caster only"},
    [8939] = {required_form = 0, description = "Regrowth - Caster only"},
    [8940] = {required_form = 0, description = "Regrowth - Caster only"},
    [8941] = {required_form = 0, description = "Regrowth - Caster only"},
    [9750] = {required_form = 0, description = "Regrowth - Caster only"},
    [9856] = {required_form = 0, description = "Regrowth - Caster only"},
    [9857] = {required_form = 0, description = "Regrowth - Caster only"},
    [9858] = {required_form = 0, description = "Regrowth - Caster only"},
    [26980] = {required_form = 0, description = "Regrowth - Caster only"},
    [33781] = {required_form = 0, description = "Regrowth - Caster only"},
    [5185] = {required_form = 0, description = "Healing Touch - Caster only"},
    [5186] = {required_form = 0, description = "Healing Touch - Caster only"},
    [5187] = {required_form = 0, description = "Healing Touch - Caster only"},
    [5188] = {required_form = 0, description = "Healing Touch - Caster only"},
    [5189] = {required_form = 0, description = "Healing Touch - Caster only"},
    [6778] = {required_form = 0, description = "Healing Touch - Caster only"},
    [8903] = {required_form = 0, description = "Healing Touch - Caster only"},
    [9758] = {required_form = 0, description = "Healing Touch - Caster only"},
    [9888] = {required_form = 0, description = "Healing Touch - Caster only"},
    [9889] = {required_form = 0, description = "Healing Touch - Caster only"},
    [25297] = {required_form = 0, description = "Healing Touch - Caster only"},
    [26978] = {required_form = 0, description = "Healing Touch - Caster only"},
    [26979] = {required_form = 0, description = "Healing Touch - Caster only"},
    [33779] = {required_form = 0, description = "Healing Touch - Caster only"},
    [29166] = {required_form = 0, description = "Innervate - Caster only"},
    [27005] = {required_form = 0, description = "Innervate - Caster only"},
}

-- Form ID constants for caller convenience
M.FORM_HUMANOID = 0
M.FORM_BEAR = 1
M.FORM_CAT = 2
M.FORM_TRAVEL = 3
M.FORM_MOONKIN = 4
M.FORM_TREE = 5

--- Get spell flags from embedded data bridge.
-- Returns flags table from the bridge, or nil if not found.
-- Cached after first read — safe to call every frame.
-- @param spell_id  number — spell ID
-- @return table|nil — flags table, or nil
function M.get_spell_flags(spell_id)
    if not spell_id then return nil end
    local cached = _flag_cache[spell_id]
    if cached ~= nil then
        return cached or nil
    end

    local bridge = get_bridge()
    if not bridge or not bridge.spell_detail then
        _flag_cache[spell_id] = false
        return nil
    end

    local detail = bridge.spell_detail[spell_id]
    if not detail or not detail[9] then
        _flag_cache[spell_id] = false
        return nil
    end

    -- detail[9] = flags array
    _flag_cache[spell_id] = detail[9]
    return detail[9]
end

--- Check if a spell can be cast in a given form.
-- Uses hardcoded form restriction table for accuracy.
-- Returns true if spell can be cast, false if restricted.
-- @param spell_id  number — spell ID
-- @param form_id   number — current form ID (0=humanoid, 1=bear, 2=cat, etc.)
-- @return boolean — true if spell can be cast in the given form
function M.can_cast_in_form(spell_id, form_id)
    if not spell_id then return true end  -- No spell = no restriction
    if form_id == nil then form_id = 0 end  -- Default to humanoid

    local restriction = FORM_RESTRICTIONS[spell_id]
    if not restriction then return true end  -- No restriction = can cast

    local required = restriction.required_form
    if required == nil then return true end  -- No required form specified

    -- required_form = 0 means caster-only (cannot be in any form)
    if required == 0 then
        return form_id == 0
    end

    -- Otherwise, must be in the specific form
    return form_id == required
end

--- Check if a spell has any form restriction.
-- Returns true if the spell has a required_form entry.
-- @param spell_id  number — spell ID
-- @return boolean — true if spell is restricted to a specific form
function M.is_form_restricted(spell_id)
    if not spell_id then return false end
    return FORM_RESTRICTIONS[spell_id] ~= nil
end

--- Get the required form for a spell.
-- Returns the form ID required, or nil if no restriction.
-- @param spell_id  number — spell ID
-- @return number|nil — required form ID, or nil
function M.get_required_form(spell_id)
    if not spell_id then return nil end
    local restriction = FORM_RESTRICTIONS[spell_id]
    if restriction then
        return restriction.required_form
    end
    return nil
end

-- Export to _G for dofile pattern (unit testing)
local _G = _G
_G.SpellFlagChecker = M

-- Export to NS namespace (Sylvanas production path)
if _G.EaxRotations then
    _G.EaxRotations.get_spell_flags = M.get_spell_flags
    _G.EaxRotations.can_cast_in_form = M.can_cast_in_form
    _G.EaxRotations.is_form_restricted = M.is_form_restricted
    _G.EaxRotations.get_required_form = M.get_required_form
    _G.EaxRotations.FORM_HUMANOID = M.FORM_HUMANOID
    _G.EaxRotations.FORM_BEAR = M.FORM_BEAR
    _G.EaxRotations.FORM_CAT = M.FORM_CAT
    _G.EaxRotations.FORM_TRAVEL = M.FORM_TRAVEL
    _G.EaxRotations.FORM_MOONKIN = M.FORM_MOONKIN
    _G.EaxRotations.FORM_TREE = M.FORM_TREE
end

return M
