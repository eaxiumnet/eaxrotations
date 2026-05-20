-- ============================================================================
-- reagent_guard_sylvanas.lua (Phase 1)
-- Centralised reagent check for spells that consume items.
--
-- Purpose:
--   Prevents the rotation from attempting to cast spells when the player
--   lacks the required reagent (soul shards, candles, symbols, ankhs, etc.)
--   Provides a single lookup point so individual spec rotations don't need
--   to duplicate item-count checks.
--
-- Usage:
--   local reagent_guard = require("shared/reagent_guard_sylvanas")
--   if not reagent_guard.check_reagent(spell_id) then
--       -- skip cast
--   end
-- ============================================================================

local NS = _G.EaxRotations
if not NS then return nil end

---@class reagent_guard_entry
---@field item integer Item ID of the required reagent.
---@field count integer Number consumed per cast (default 1).

--- Maps spell_id -> { item = <itemId>, count = <n> }
--- For TBC-era spells that consume a reagent on cast.
--- Only spells with a non-zero ReagentCost are listed here.
---
--- NOTE:
---   If the Blizzard / Sylvanas API later exposes reagent info through
---   core.spell_book, this table can be replaced with a dynamic lookup.
---   For now, hardcoded entries cover the most common reagent-gated spells.
local REAGENT_MAP = {
    -- ========================================================================
    -- Warlock — Soul Shard (item 6265)
    -- ========================================================================
    [635]  = { item = 6265, count = 1 }, -- Soul Fire (Rank 1)
    [636]  = { item = 6265, count = 1 }, -- Soul Fire (Rank 2)
    [637]  = { item = 6265, count = 1 }, -- Soul Fire (Rank 3)
    [638]  = { item = 6265, count = 1 }, -- Soul Fire (Rank 4)
    [639]  = { item = 6265, count = 1 }, -- Soul Fire (Rank 5)
    [27247] = { item = 6265, count = 1 }, -- Shadowburn (Rank 6)
    [27248] = { item = 6265, count = 1 }, -- Shadowburn (Rank 7)
    [17877] = { item = 6265, count = 1 }, -- Shadowburn (Rank 8/Immo-lock variant)
    [6201]  = { item = 6265, count = 1 }, -- Create Healthstone (Rank 1)
    [6202]  = { item = 6265, count = 1 }, -- Create Healthstone (Rank 2)
    [5699]  = { item = 6265, count = 1 }, -- Create Healthstone (Rank 3)
    [11729] = { item = 6265, count = 1 }, -- Create Healthstone (Rank 4)
    [11730] = { item = 6265, count = 1 }, -- Create Healthstone (Rank 5)
    [27230] = { item = 6265, count = 1 }, -- Create Healthstone (Rank 6)
    [693]   = { item = 6265, count = 1 }, -- Create Soulstone (Rank 1)
    [20752] = { item = 6265, count = 1 }, -- Create Soulstone (Rank 2)
    [20755] = { item = 6265, count = 1 }, -- Create Soulstone (Rank 3)
    [20756] = { item = 6265, count = 1 }, -- Create Soulstone (Rank 4)
    [20757] = { item = 6265, count = 1 }, -- Create Soulstone (Rank 5)
    [27238] = { item = 6265, count = 1 }, -- Create Soulstone (Rank 6)
    [29893] = { item = 6265, count = 2 }, -- Ritual of Souls (costs 2 shards)
    -- Drain Soul (rank-dependent shard generation, not a consumer)

    -- ========================================================================
    -- Priest — Sacred Candle (item 17030) / Holy Candle (item 17031)
    -- ========================================================================
    [27683] = { item = 17030, count = 1 }, -- Shadowguard (Rank 1, Scared Candle)
    [39374] = { item = 17030, count = 1 }, -- Shadowguard (Rank 2, Sacred Candle)
    [27681] = { item = 17031, count = 1 }, -- Divine Spirit (Rank 6, Holy Candle)
    [32999] = { item = 17031, count = 1 }, -- Divine Spirit (Rank 7, Holy Candle)
    [14752] = { item = 17031, count = 1 }, -- Divine Spirit (Rank 1)
    [14818] = { item = 17031, count = 1 }, -- Divine Spirit (Rank 2)
    [14819] = { item = 17031, count = 1 }, -- Divine Spirit (Rank 3)
    [27841] = { item = 17031, count = 1 }, -- Divine Spirit (Rank 4)
    [25312] = { item = 17031, count = 1 }, -- Divine Spirit (Rank 5)

    -- ========================================================================
    -- Paladin — Symbol of Kings (item 21142) for Greater Blessings
    -- ========================================================================
    [25898] = { item = 21142, count = 2 }, -- Greater Blessing of Kings (rank 1)
    [25916] = { item = 21142, count = 2 }, -- Greater Blessing of Kings (rank 2)
    [25917] = { item = 21142, count = 2 }, -- Greater Blessing of Kings (rank 3)
    [27181] = { item = 21142, count = 2 }, -- Greater Blessing of Kings (rank 4)
    [25918] = { item = 21142, count = 2 }, -- Greater Blessing of Might (rank 1)
    [27143] = { item = 21142, count = 2 }, -- Greater Blessing of Might (rank 2)
    [27144] = { item = 21142, count = 2 }, -- Greater Blessing of Might (rank 3)
    [27145] = { item = 21142, count = 2 }, -- Greater Blessing of Might (rank 4)
    [25919] = { item = 21142, count = 2 }, -- Greater Blessing of Wisdom (rank 1)
    [27146] = { item = 21142, count = 2 }, -- Greater Blessing of Wisdom (rank 2)
    [27147] = { item = 21142, count = 2 }, -- Greater Blessing of Wisdom (rank 3)
    [27148] = { item = 21142, count = 2 }, -- Greater Blessing of Wisdom (rank 4)
    [25920] = { item = 21142, count = 2 }, -- Greater Blessing of Light (rank 1)
    [27149] = { item = 21142, count = 2 }, -- Greater Blessing of Light (rank 2)
    [27150] = { item = 21142, count = 2 }, -- Greater Blessing of Light (rank 3)
    [27151] = { item = 21142, count = 2 }, -- Greater Blessing of Light (rank 4)
    [25921] = { item = 21142, count = 2 }, -- Greater Blessing of Salvation (rank 1)
    [27152] = { item = 21142, count = 2 }, -- Greater Blessing of Salvation (rank 2)
    [27153] = { item = 21142, count = 2 }, -- Greater Blessing of Salvation (rank 3)
    [27154] = { item = 21142, count = 2 }, -- Greater Blessing of Salvation (rank 4)
    [27155] = { item = 21142, count = 2 }, -- Greater Blessing of Sanctuary (rank 1)
    [27156] = { item = 21142, count = 2 }, -- Greater Blessing of Sanctuary (rank 2)
    [27157] = { item = 21142, count = 2 }, -- Greater Blessing of Sanctuary (rank 3)
    [25899] = { item = 21142, count = 2 }, -- Greater Blessing of Sanctuary (rank 4)

    -- ========================================================================
    -- Shaman — Ankh (item 17030) for Reincarnation / Ancestral Spirit
    -- NOTE: Item 17030 is shared with Priest Sacred Candle — Blizzard re-used
    -- the item ID across class reagents that aren't tradeable.
    -- ========================================================================
    [20608] = { item = 17030, count = 1 }, -- Reincarnation
    [2008]  = { item = 17030, count = 1 }, -- Ancestral Spirit (Rank 1)
    [20609] = { item = 17030, count = 1 }, -- Ancestral Spirit (Rank 2)
    [20610] = { item = 17030, count = 1 }, -- Ancestral Spirit (Rank 3)
    [20776] = { item = 17030, count = 1 }, -- Ancestral Spirit (Rank 4)
    [20777] = { item = 17030, count = 1 }, -- Ancestral Spirit (Rank 5)
    [25590] = { item = 17030, count = 1 }, -- Ancestral Spirit (Rank 6)
}

-- ============================================================================
-- Public API
-- ============================================================================

--- Returns true if the player has the required reagent(s) for the given spell.
--- If the spell has no reagent entry, returns true (no check needed).
---@param spell_id integer The spell ID to check.
---@return boolean has_reagent True if reagent is available or not required.
function M_check(spell_id)
    local entry = REAGENT_MAP[spell_id]
    if not entry then return true end

    -- Use NS.has_item which returns the count of the item in bags
    local ok, count = pcall(NS.has_item, entry.item)
    if not ok or type(count) ~= "number" then
        -- If has_item fails or returns non-number, assume missing
        return false
    end
    return count >= entry.count
end

--- Returns the first blocking reason if the player lacks the required reagent.
--- Returns nil if the spell is not reagent-gated or the player has enough.
---@param spell_id integer The spell ID to check.
---@return string|nil reason Nil if okay, or a string like "missing_reagent:soul_shard".
function M_get_fail_reason(spell_id)
    local entry = REAGENT_MAP[spell_id]
    if not entry then return nil end

    local ok, count = pcall(NS.has_item, entry.item)
    if not ok or type(count) ~= "number" or count < entry.count then
        return "missing_reagent:item_" .. tostring(entry.item)
    end
    return nil
end

--- Returns the reagent map entry for a spell, or nil if none.
--- Useful for diagnostics / unit testing.
---@param spell_id integer
---@return table|nil
function M_lookup(spell_id)
    return REAGENT_MAP[spell_id]
end

-- ============================================================================
-- Export
-- ============================================================================
local M = {}
M.check_reagent = M_check
M.get_fail_reason = M_get_fail_reason
M.lookup = M_lookup
return M
