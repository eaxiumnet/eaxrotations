-- What: Equipment comparison heuristic for EaxAutoQuester auto-equip
-- When: Called by quest reward / loot handlers to decide whether to equip an item
-- Why: TBC has no item level; use quality + the client's slot data + the existing keyword heuristic.
--      A free member of a ring/trinket pair is a destination of its own, so a reward that
--      does not beat the worn member fills the free one instead of being discarded.
-- Safety: All functions nil-guarded (Pattern 14); no math.sqrt(); no io.popen
-- Decision: Pure logic module — no core.* dependency; standalone testable.
--           Owns slot classification AND the INVSLOT destination a decision names.

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

-- Reverse of INVENTORY_SLOTS, derived from it so the two cannot drift: a category's
-- client INVSLOT_* ids in ascending order. The first entry is the slot a comparator
-- decision falls back to when nothing of that category is worn.
local SLOT_INVENTORY_IDS = {}
for _slot_id = 1, 19 do
    local _category = INVENTORY_SLOTS[_slot_id]
    if _category then
        local ids = SLOT_INVENTORY_IDS[_category]
        if not ids then
            ids = {}
            SLOT_INVENTORY_IDS[_category] = ids
        end
        ids[#ids + 1] = _slot_id
    end
end

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

--- The equipped row of this category the candidate is measured against: the lowest client
--- slot_id, or — for rows without one — the first in the list. Independent of the order the
--- client returns rows in, so an equal-quality comparison cannot change with it.
--- @param category string Slot type string
--- @param equipped_items_list table|nil Rows to search
--- @return table|nil row Matched row, or nil when this category is not worn
--- @return number|nil slot_id The row's client INVSLOT_* id, when it carries one
local function lowest_row_of_category(category, equipped_items_list)
    local match, match_index, match_slot_id
    if type(equipped_items_list) ~= "table" then return nil, nil end
    for index, item in ipairs(equipped_items_list) do
        if equipped_row_slot(item) == category then
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
    return match, match_slot_id
end

--- The first FREE member of a two-slot category (rings 11/12, trinkets 13/14), or nil when
--- the category has no pair, both members are occupied, or a row of the category carries no
--- slot_id — a member that cannot be proven occupied must never be treated as free, or an old
--- rejection would silently become an equip.
--- @param category string Slot type string
--- @param equipped_items_list table|nil Rows passed to should_equip
--- @return number|nil INVSLOT_* id of the free member, when there is one
local function free_pair_member(category, equipped_items_list)
    local ids = SLOT_INVENTORY_IDS[category]
    if not ids or #ids < 2 or type(equipped_items_list) ~= "table" then return nil end

    local occupied = {}
    for _, item in ipairs(equipped_items_list) do
        if equipped_row_slot(item) == category then
            local slot_id = item.slot_id and tonumber(item.slot_id) or nil
            if not slot_id then return nil end
            occupied[slot_id] = true
        end
    end

    for _, slot_id in ipairs(ids) do
        if not occupied[slot_id] then return slot_id end
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
-- comparison_slots — the one owner of "measured against what, equipped into which"
-- ============================================================================

--- What a candidate of this category is measured against, and which client slot a decision
--- made from that measurement lands in. One owner for both, so the decision and the
--- destination can never come from different rules:
---   * the lowest client slot carrying the category is the comparison target;
---   * an item that beats the target goes into the target's own slot (unchanged behavior);
---   * an item that does NOT beat it uses a free member of the pair (rings 11/12, trinkets
---     13/14) when there is one — the empty slot is a destination in its own right, exactly
---     like a category that is not worn at all — instead of overwriting a worn member.
--- @param category string Slot type string
--- @param candidate_quality number|nil Item quality integer (0-5)
--- @param candidate_name string|nil Item display name (keyword bonus)
--- @param equipped_items_list table|nil Rows to compare against
--- @return table|nil target Row the candidate is measured against (nil = nothing worn)
--- @return number|nil destination INVSLOT_* id a decision made here lands in
--- @return boolean|nil fills_free True when the destination is a free pair member
local function comparison_slots(category, candidate_quality, candidate_name, equipped_items_list)
    local ids = SLOT_INVENTORY_IDS[category]
    if not ids then return nil, nil end

    local target, target_slot_id = lowest_row_of_category(category, equipped_items_list)
    if not target then return nil, ids[1] end

    local equipped_quality = target.quality or 0
    local beats = candidate_quality > equipped_quality
        or (candidate_quality == equipped_quality and has_priority_keyword(candidate_name))
    if not beats then
        local free = free_pair_member(category, equipped_items_list)
        if free then return target, free, true end
    end
    return target, target_slot_id or ids[1]
end

--- The client INVSLOT_* id an item is equipped into — same positional arguments as
--- should_equip, so the destination always comes from the rule that made the decision.
--- Naming the destination is what the client's own equip call needs: on its own it never
--- fills the second ring (12), the second trinket (14) or the off hand (17)
--- (.api/core.lua, equip_container_item).
--- @param item_name string|nil Item display name
--- @param candidate_quality number|nil Item quality integer (0-5)
--- @param equipped_items_list table|nil The rows should_equip compared against
--- @param equip_loc string|number|nil Client item-info equipment location
--- @return number|nil INVSLOT_* id, or nil when the slot cannot be determined
local function equip_slot_for(item_name, candidate_quality, equipped_items_list, equip_loc)
    local category = classify_slot(item_name, equip_loc)
    if not category then return nil end
    return select(2, comparison_slots(category, candidate_quality, item_name, equipped_items_list))
end

-- ============================================================================
-- should_equip
-- ============================================================================

--- Decide whether to equip a candidate item based on quality, slot, and keywords. A free
--- member of a pair (rings 11/12, trinkets 13/14) is an empty slot, so a candidate that does
--- not beat the worn member is worn alongside it rather than rejected.
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

    local match, _, fills_free = comparison_slots(
        candidate_slot, candidate_quality, candidate_name, equipped_items_list)

    -- No equipped item for this slot type → empty slot, equip without replacement
    if not match then
        return true, nil
    end

    -- A free member of a pair is an empty slot too: it takes what the comparison against the
    -- worn member would otherwise discard, and the available member is never overwritten.
    if fills_free then
        return true, candidate_slot
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
    equip_slot_for = equip_slot_for,
}

-- Expose globally for cross-module access without re-require
_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.equipment_compare = M

return M
