-- Shared Helper: Weapon Imbue Manager
-- Uses GetWeaponEnchantInfo() (TBC API from wow_api_clone.lua)
--   + item:item_has_enchant() via equipped item slots
-- ============================================================================
local M = {}
local _G = _G
local NS = _G.EaxRotations

-- Expose GetWeaponEnchantInfo from wow_api_clone (TBC temp enchant detection)
-- Returns: hasMH, mhExpiration, mhCharges, mhEnchantID, hasOH, ohExpiration, ohCharges, ohEnchantID
pcall(require, "common/wow_api_clone")

-- Slot constants (standard WoW inventory slot indices)
local MAIN_HAND_SLOT = 16
local OFF_HAND_SLOT = 17

-- API availability flags
local api_available = {
    weapon_enchant = false,
    item_has_enchant = false,
}

-- Cache GetWeaponEnchantInfo global if available
local _GetWeaponEnchantInfo = type(GetWeaponEnchantInfo) == "function" and GetWeaponEnchantInfo or nil

-- ============================================================================
-- Internal helpers
-- ============================================================================

-- Get equipped item object for a slot
local function get_equipped_item(slot)
    local me = NS and NS.GetPlayer and NS.GetPlayer()
    if not me or not me.get_item_at_inventory_slot then return nil end
    local ok, item_slot = pcall(function() return me:get_item_at_inventory_slot(slot) end)
    if not ok or type(item_slot) ~= "table" then return nil end
    return item_slot.object or item_slot.item or item_slot[1]
end

-- Check if a weapon slot has an enchant using item:item_has_enchant()
local function check_item_enchant(slot)
    local item = get_equipped_item(slot)
    if not item then return nil end
    if item.item_has_enchant then
        local ok, result = pcall(function() return item:item_has_enchant() end)
        if ok then return result end
    end
    return nil
end

-- ============================================================================
-- Public API
-- ============================================================================

-- Probe which APIs are available
function M.probe_apis()
    -- Check GetWeaponEnchantInfo
    if _GetWeaponEnchantInfo then
        local ok = pcall(_GetWeaponEnchantInfo)
        api_available.weapon_enchant = ok
    end

    -- Check item:item_has_enchant
    local item = get_equipped_item(MAIN_HAND_SLOT)
    if item and item.item_has_enchant then
        local ok = pcall(function() return item:item_has_enchant() end)
        api_available.item_has_enchant = ok
    end

    return api_available.weapon_enchant or api_available.item_has_enchant
end

-- Returns true if mainhand has a temporary weapon enchant
function M.mainhand_has_imbue()
    -- Method 1: GetWeaponEnchantInfo() (TBC Blizzard API, detects temp enchants)
    if api_available.weapon_enchant and _GetWeaponEnchantInfo then
        local ok, hasMH = pcall(function()
            local has_mh = _GetWeaponEnchantInfo()
            return has_mh
        end)
        if ok and hasMH then return true end
    end

    -- Method 2: item:item_has_enchant() (detects permanent enchants too)
    if api_available.item_has_enchant then
        local result = check_item_enchant(MAIN_HAND_SLOT)
        if result ~= nil then return result end
    end

    return false
end

-- Returns true if offhand has a temporary weapon enchant
function M.offhand_has_imbue()
    -- Method 1: GetWeaponEnchantInfo()
    if api_available.weapon_enchant and _GetWeaponEnchantInfo then
        local ok, _, _, _, _, hasOH = pcall(function()
            local a, b, c, d, e = _GetWeaponEnchantInfo()
            return a, b, c, d, e
        end)
        if ok and hasOH then return true end
    end

    -- Method 2: item:item_has_enchant()
    if api_available.item_has_enchant then
        local result = check_item_enchant(OFF_HAND_SLOT)
        if result ~= nil then return result end
    end

    return false
end

-- Get mainhand enchant info (spell ID and remaining time)
function M.get_mainhand_enchant_info()
    if not api_available.weapon_enchant or not _GetWeaponEnchantInfo then return nil end
    local ok, hasMH, mhExpiration, mhCharges, mhEnchantID = pcall(function()
        local a, b, c, d = _GetWeaponEnchantInfo()
        return a, b, c, d
    end)
    if ok and hasMH then
        return {
            has = true,
            expiration = mhExpiration,
            charges = mhCharges,
            enchant_id = mhEnchantID,
        }
    end
    return nil
end

-- Get offhand enchant info
function M.get_offhand_enchant_info()
    if not api_available.weapon_enchant or not _GetWeaponEnchantInfo then return nil end
    local ok, _, _, _, hasOH, ohExpiration, ohCharges, ohEnchantID = pcall(function()
        local a, b, c, d, e, f, g, h = _GetWeaponEnchantInfo()
        return a, b, c, d, e, f, g, h
    end)
    if ok and hasOH then
        return {
            has = true,
            expiration = ohExpiration,
            charges = ohCharges,
            enchant_id = ohEnchantID,
        }
    end
    return nil
end

-- Check if weapon has specific imbue
function M.has_imbue(slot, imbue_ids)
    if type(imbue_ids) ~= "table" then
        imbue_ids = { imbue_ids }
    end

    -- First try GetWeaponEnchantInfo for temp enchants
    local info = nil
    if slot == "mainhand" then
        info = M.get_mainhand_enchant_info()
    elseif slot == "offhand" then
        info = M.get_offhand_enchant_info()
    end

    if info and info.has then
        for _, id in ipairs(imbue_ids) do
            if info.enchant_id == id then return true end
        end
    end

    -- Fallback
    if slot == "mainhand" then
        local has = M.mainhand_has_imbue()
        return has ~= nil and has == true
    elseif slot == "offhand" then
        local has = M.offhand_has_imbue()
        return has ~= nil and has == true
    end

    return false
end

-- Get full imbue status
-- Returns mh_has_imbue/oh_has_imbue (new names) AND mh_imbue/oh_imbue (backward compat)
function M.get_status()
    local mh_has = M.mainhand_has_imbue()
    local oh_has = M.offhand_has_imbue()
    return {
        mh_has_imbue = mh_has,
        oh_has_imbue = oh_has,
        -- Backward compatible aliases (consumable_manager, gear_score use these)
        mh_imbue = mh_has and 1 or nil,
        oh_imbue = oh_has and 1 or nil,
        mh_enchant_info = M.get_mainhand_enchant_info(),
        oh_enchant_info = M.get_offhand_enchant_info(),
        api_available = api_available.weapon_enchant,
    }
end

-- Get recommended imbue for class/spec (returns spell IDs)
function M.get_recommended_imbue(class, spec)
    if class == "shaman" then
        if spec == "enhancement" then
            return {
                mh = 32911, -- Windfury Weapon Rank 6
                oh = 25490, -- Flametongue Weapon Rank 8
            }
        elseif spec == "elemental" or spec == "restoration" then
            return {
                mh = 25490, -- Flametongue Weapon Rank 8
            }
        end
    elseif class == "rogue" then
        return {
            mh = 2672, -- Instant Poison
            oh = 2673, -- Deadly Poison
        }
    end
    return nil
end

-- Check if imbue needs refresh
function M.needs_refresh(slot, threshold_seconds)
    threshold_seconds = threshold_seconds or 300

    if not api_available.weapon_enchant then
        return true
    end

    local info = nil
    if slot == "mainhand" then
        info = M.get_mainhand_enchant_info()
    elseif slot == "offhand" then
        info = M.get_offhand_enchant_info()
    end

    if not info or not info.has then return true end

    if info.expiration and info.expiration > 0 then
        return info.expiration <= threshold_seconds
    end

    return false
end

-- Initialize
function M.init()
    M.probe_apis()
    if NS then
        NS.WeaponImbueManager = M
    end
end

M.init()

return M
