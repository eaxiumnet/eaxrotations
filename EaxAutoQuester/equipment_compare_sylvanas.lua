-- What: Equipment comparison heuristic for EaxAutoQuester auto-equip
-- When: Called by quest reward / loot handlers to decide whether to equip an item
-- Why: TBC has no item level; use quality + slot type + keyword heuristic instead
-- Safety: All functions nil-guarded (Pattern 14); no math.sqrt(); no io.popen
-- Decision: Pure logic module — no core.* dependency; standalone testable

-- ============================================================================
-- Slot Classification Table (Pattern 2: cached at load)
-- First-match-wins. Order matters: more specific keywords first.
-- ============================================================================

local SLOT_KEYWORDS = {
    HEAD      = { "helm", "cap", "hood", "crown", "circlet" },
    SHOULDERS = { "pauldrons", "shoulders", "mantle", "spaulders" },
    CHEST     = { "chest", "robe", "tunic", "vest", "jerkin" },
    LEGS      = { "leggings", "pants", "breeches", "trousers" },
    FEET      = { "boots", "sabatons", "greaves" },
    HANDS     = { "gloves", "gauntlets" },
    WRIST     = { "bracers", "wristguards" },
    WAIST     = { "belt", "girdle" },
    WEAPON_MAIN = { "sword", "axe", "mace", "staff", "dagger", "wand" },
    WEAPON_OFF  = { "shield", "tome", "orb", "off" },
    RANGED    = { "bow", "gun", "crossbow", "blunderbuss" },
}

-- ============================================================================
-- Priority Keywords — same-quality tiebreaker bonus
-- Sourced from TBC item suffix tiers: Superior, Heroic, Sorcerer, Lord, etc.
-- ============================================================================

local PRIORITY_KEYWORDS = {
    "Superior", "Heroic", "Sorcerer", "Lord",
    "Knight", "Marshal", "Warden",
}

-- Cache lowercase versions for comparison
local _priority_lower = {}
for _, kw in ipairs(PRIORITY_KEYWORDS) do
    _priority_lower[#_priority_lower + 1] = kw:lower()
end

-- ============================================================================
-- classify_slot
-- ============================================================================

--- Determine equipment slot type from item name.
--- @param item_name string|nil Item display name
--- @return string|nil Slot type string (e.g. "CHEST", "HEAD") or nil if unclassified
local function classify_slot(item_name)
    if not item_name or type(item_name) ~= "string" then return nil end
    local lower = item_name:lower()
    for slot, keywords in pairs(SLOT_KEYWORDS) do
        for _, kw in ipairs(keywords) do
            if lower:find(kw, 1, true) then
                return slot
            end
        end
    end
    return nil
end

-- ============================================================================
-- has_priority_keyword
-- ============================================================================

--- Check if an item name contains any priority keyword (case-insensitive).
--- @param item_name string|nil Item display name
--- @return boolean true if a priority keyword is found
local function has_priority_keyword(item_name)
    if not item_name or type(item_name) ~= "string" then return false end
    local lower = item_name:lower()
    for _, kw in ipairs(_priority_lower) do
        if lower:find(kw, 1, true) then
            return true
        end
    end
    return false
end

-- ============================================================================
-- should_equip
-- ============================================================================

--- Decide whether to equip a candidate item based on quality, slot, and keywords.
--- @param candidate_name string|nil    Item display name being considered
--- @param candidate_quality number|nil  Item quality integer (0-5)
--- @param equipped_items_list table|nil List of {slot, name, quality} for currently equipped items
--- @return boolean should_equip        true if candidate should replace an equipped item
--- @return string|nil slot_to_replace  Slot type to replace, or nil if no replacement needed
local function should_equip(candidate_name, candidate_quality, equipped_items_list)
    -- Nil-guard all inputs (Pattern 14)
    if not candidate_name or candidate_quality == nil then return false, nil end
    if not equipped_items_list or type(equipped_items_list) ~= "table" then return false, nil end

    -- Classify candidate slot
    local candidate_slot = classify_slot(candidate_name)
    if not candidate_slot then return false, nil end

    -- Find equipped item in the same slot
    local match = nil
    for _, item in ipairs(equipped_items_list) do
        if item and item.slot == candidate_slot then
            match = item
            break
        end
    end

    -- No equipped item for this slot type → empty slot, equip without replacement
    if not match then
        return true, nil
    end

    -- Compare quality (nil-guard equipped quality)
    local equipped_quality = match.quality or 0

    if candidate_quality > equipped_quality then
        -- Upgrade: higher quality → equip and replace
        return true, candidate_slot
    elseif candidate_quality < equipped_quality then
        -- Downgrade: lower quality → don't equip
        return false, nil
    end

    -- Equal quality: check priority keyword bonus
    if has_priority_keyword(candidate_name) then
        return true, candidate_slot
    end

    return false, nil
end

-- ============================================================================
-- Module Table
-- ============================================================================

local M = {
    classify_slot = classify_slot,
    should_equip = should_equip,
}

-- Expose globally for cross-module access without re-require
_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.equipment_compare = M

return M
