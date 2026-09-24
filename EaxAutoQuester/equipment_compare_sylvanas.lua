-- What: Equipment comparison heuristic for EaxAutoQuester auto-equip
-- When: Called by quest reward / loot handlers to decide whether to equip an item
-- Why: TBC has no item level; use quality + the client's slot data + the existing keyword heuristic
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

-- pairs() made the first matching slot depend on Lua's hash order. Keep the
-- existing heuristic categories, but visit them in this explicit, stable order.
local SLOT_ORDER = {
    "HEAD", "SHOULDERS", "CHEST", "LEGS", "FEET", "HANDS", "WRIST", "WAIST",
    "WEAPON_MAIN", "WEAPON_OFF", "RANGED",
}

-- The classic client's get_equipped_items() rows carry a 1-based INVSLOT_*.
-- Only 1..19 are worn gear; 20+ are bag/container positions on the supported
-- client and must not be compared as equipment.
local INVENTORY_SLOTS = {
    [1] = "HEAD",
    [2] = "NECK",
    [3] = "SHOULDERS",
    [4] = "SHIRT",
    [5] = "CHEST",
    [6] = "WAIST",
    [7] = "LEGS",
    [8] = "FEET",
    [9] = "WRIST",
    [10] = "HANDS",
    [11] = "FINGER",
    [12] = "FINGER",
    [13] = "TRINKET",
    [14] = "TRINKET",
    [15] = "BACK",
    [16] = "WEAPON_MAIN",
    [17] = "WEAPON_OFF",
    [18] = "RANGED",
    [19] = "TABARD",
}

-- quest_item_info exposes equip_loc as a string. These aliases normalize the
-- documented location names (and common INVEQUIPLOC spellings) to the same
-- categories used by the name fallback; this is data normalization, not a
-- second item-scoring policy.
local EQUIP_LOC_ALIASES = {
    HEAD = "HEAD",
    HEADS = "HEAD",
    HELM = "HEAD",
    NECK = "NECK",
    NECKLACE = "NECK",
    SHOULDER = "SHOULDERS",
    SHOULDERS = "SHOULDERS",
    SHIRT = "SHIRT",
    CHEST = "CHEST",
    WAIST = "WAIST",
    BELT = "WAIST",
    LEG = "LEGS",
    LEGS = "LEGS",
    FEET = "FEET",
    FOOT = "FEET",
    BOOTS = "FEET",
    WRIST = "WRIST",
    WRISTS = "WRIST",
    BRACERS = "WRIST",
    HAND = "HANDS",
    HANDS = "HANDS",
    FINGER = "FINGER",
    FINGERS = "FINGER",
    RING = "FINGER",
    TRINKET = "TRINKET",
    TRINKETS = "TRINKET",
    BACK = "BACK",
    CLOAK = "BACK",
    MAINHAND = "WEAPON_MAIN",
    WEAPONMAIN = "WEAPON_MAIN",
    WEAPONMAINHAND = "WEAPON_MAIN",
    OFFHAND = "WEAPON_OFF",
    WEAPONOFF = "WEAPON_OFF",
    WEAPONOFFHAND = "WEAPON_OFF",
    SHIELD = "WEAPON_OFF",
    RANGED = "RANGED",
    RANGEDRIGHT = "RANGED",
    RANGEDLEFT = "RANGED",
    TABARD = "TABARD",
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

local function inventory_slot(slot_id)
    if slot_id == nil then return nil end
    local numeric_id = tonumber(slot_id)
    if not numeric_id or numeric_id % 1 ~= 0 then return nil end
    return INVENTORY_SLOTS[numeric_id]
end

local function equip_location(value)
    if type(value) == "number" then return inventory_slot(value) end
    if type(value) ~= "string" then return nil end

    local token = value:upper():gsub("[^A-Z0-9]", "")
    if token:sub(1, 11) == "INVEQUIPLOC" then token = token:sub(12) end
    if token:match("^%d+$") then return inventory_slot(tonumber(token)) end
    if token:match("^FINGER%d+$") or token:match("^TRINKET%d+$") then
        token = token:match("^([A-Z]+)")
    end
    return EQUIP_LOC_ALIASES[token]
end

local function canonical_slot(value)
    if type(value) ~= "string" then return nil end
    local upper = value:upper()
    if SLOT_KEYWORDS[upper] then return upper end
    return equip_location(upper)
end

--- Determine an equipment slot from client data, with the old name heuristic
--- as a fallback. `slot_id` is the authoritative equipped-row field;
--- `equip_loc` is the authoritative reward/item-info field.
--- @param item_name string|nil Item display name
--- @param equip_loc string|number|nil Client item-info equipment location
--- @param slot_id number|string|nil Client equipped-row INVSLOT_* id
--- @return string|nil Slot type string or nil if unclassified/non-equipment
local function classify_slot(item_name, equip_loc, slot_id)
    -- Accept classify_slot(name, slot_id) as a small convenience without
    -- changing the original one-argument name-classifier contract.
    if slot_id == nil and type(equip_loc) == "number" then
        slot_id = equip_loc
        equip_loc = nil
    end

    if slot_id ~= nil then return inventory_slot(slot_id) end
    local location_slot = equip_location(equip_loc)
    if location_slot then return location_slot end
    if type(item_name) ~= "string" then return nil end

    local lower = item_name:lower()
    for _, slot in ipairs(SLOT_ORDER) do
        for _, keyword in ipairs(SLOT_KEYWORDS[slot]) do
            if lower:find(keyword, 1, true) then
                return slot
            end
        end
    end
    return nil
end

local function equipped_row_slot(item)
    if type(item) ~= "table" then return nil end
    -- A client row's slot_id wins over its display name and any convenience
    -- `slot` field. This also filters the documented backpack overshoot.
    if item.slot_id ~= nil then
        return classify_slot(item.name, item.equip_loc, item.slot_id)
    end
    if item.slot ~= nil then
        local slot = canonical_slot(item.slot)
        if slot then return slot end
    end
    return classify_slot(item.name, item.equip_loc)
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
--- @param candidate_name string|table|nil Item display name (or item-info table)
--- @param candidate_quality number|nil  Item quality integer (0-5)
--- @param equipped_items_list table|nil List of {slot, name, quality} rows
--- @param candidate_equip_loc string|number|nil Optional client item-info location
--- @return boolean should_equip        true if candidate should replace an equipped item
--- @return string|nil slot_to_replace  Slot type to replace, or nil if no replacement needed
local function should_equip(candidate_name, candidate_quality, equipped_items_list, candidate_equip_loc)
    -- Accept the item-info table as a convenience while preserving the original
    -- (name, quality, equipped_list) call shape.
    if type(candidate_name) == "table" then
        local candidate = candidate_name
        candidate_name = candidate.name
        candidate_equip_loc = candidate.equip_loc or candidate_equip_loc
        if candidate_quality == nil then candidate_quality = candidate.quality end
    end

    -- Nil-guard all inputs (Pattern 14)
    if not candidate_name or candidate_quality == nil then return false, nil end
    if not equipped_items_list or type(equipped_items_list) ~= "table" then return false, nil end

    local candidate_slot = classify_slot(candidate_name, candidate_equip_loc)
    if not candidate_slot then return false, nil end

    -- Pick the same client slot consistently. For paired slots (rings,
    -- trinkets), the lowest INVSLOT_* is the stable first slot; this only
    -- makes the existing first-match policy independent of list/hash order.
    local match, match_index, match_slot_id
    for index, item in ipairs(equipped_items_list) do
        if equipped_row_slot(item) == candidate_slot then
            local slot_id = item.slot_id and tonumber(item.slot_id) or nil
            local better = false
            if not match then
                better = true
            elseif slot_id and match_slot_id then
                better = slot_id < match_slot_id
            elseif slot_id then
                better = true
            elseif not match_slot_id then
                better = index < match_index
            end
            if better then
                match = item
                match_index = index
                match_slot_id = slot_id
            end
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
