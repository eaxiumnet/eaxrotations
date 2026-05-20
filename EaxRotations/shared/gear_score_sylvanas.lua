-- ============================================================================
-- Shared Helper: Gear Score Calculator
-- ============================================================================
local M = {}
local _G = _G
local NS = _G.EaxRotations
local _data_ok, TBC = pcall(require, "shared/tbc_data_sylvanas")
if not _data_ok or type(TBC) ~= "table" then TBC = { BUFFS = {} } end

-- Inventory slots to check (using NS.EQUIPMENT_SLOTS constants)
local INVENTORY_SLOTS = {
    "HEAD", "NECK", "SHOULDER", "CHEST", "WAIST", "LEGS", "FEET", "WRIST", "HANDS",
    "FINGER1", "FINGER2", "TRINKET1", "TRINKET2", "BACK", "MAIN_HAND", "OFF_HAND", "RANGED",
}

-- Slot weights (higher = more important)
local SLOT_WEIGHTS = {
    HEAD = 1.0,
    NECK = 0.6,
    SHOULDER = 0.9,
    CHEST = 1.0,
    WAIST = 0.7,
    LEGS = 1.0,
    FEET = 0.8,
    WRIST = 0.6,
    HANDS = 0.7,
    FINGER1 = 0.5,
    FINGER2 = 0.5,
    TRINKET1 = 0.8,
    TRINKET2 = 0.8,
    BACK = 0.5,
    MAIN_HAND = 1.5,  -- Weapons are crucial
    OFF_HAND = 1.0,
    RANGED = 0.9,
}

-- Tier item level ranges (approximate for TBC)
local TIER_RANGES = {
    preraid = { min = 80, max = 109 },
    t4 = { min = 110, max = 124 },
    t5 = { min = 125, max = 138 },
    t6 = { min = 139, max = 151 },
    sunwell = { min = 152, max = 164 },
}

-- Get equipped item ID for a slot
local function get_item_in_slot(slot_name)
    if not NS then return nil end
    
    -- Try NS.get_equipped_item_id if available
    if NS.get_equipped_item_id then
        return NS.get_equipped_item_id(slot_name)
    end
    
    -- Try player:get_item_at_inventory_slot
    local me = NS.GetPlayer and NS.GetPlayer()
    if not me then return nil end
    
    local ok, item_id = pcall(function() return me:get_item_at_inventory_slot(slot_name) end)
    if ok then return item_id end
    
    return nil
end

-- Scan all equipped items
function M.scan(context)
    local results = {
        items = {},
        total_score = 0,
        weak_slots = {},
        missing_slots = {},
        tier = "unknown",
    }
    
    for _, slot in ipairs(INVENTORY_SLOTS) do
        local item_id = get_item_in_slot(slot)
        local slot_weight = SLOT_WEIGHTS[slot] or 0.5
        
        if item_id then
            results.items[slot] = {
                id = item_id,
                slot = slot,
                weight = slot_weight,
                score = 0,  -- Will calculate
            }
        else
            results.missing_slots[slot] = true
        end
    end
    
    -- Calculate scores (approximate based on item ID ranges)
    -- This is a rough approximation - real gear score needs item data
    for slot, item_data in pairs(results.items) do
        -- Estimate item level from item ID (very rough)
        -- In TBC, item IDs generally correlate with item level
        local item_id = item_data.id
        local estimated_ilevel = M.estimate_item_level(item_id)
        
        item_data.estimated_ilevel = estimated_ilevel
        item_data.score = estimated_ilevel * item_data.weight
        results.total_score = results.total_score + item_data.score
        
        -- Check if weak slot (below expected for tier)
        if estimated_ilevel < 110 then
            results.weak_slots[slot] = item_data
        end
    end
    
    -- Determine tier based on average item level
    local avg_ilevel = 0
    local item_count = 0
    for _, item_data in pairs(results.items) do
        avg_ilevel = avg_ilevel + item_data.estimated_ilevel
        item_count = item_count + 1
    end
    
    if item_count > 0 then
        avg_ilevel = avg_ilevel / item_count
        
        for tier_name, range in pairs(TIER_RANGES) do
            if avg_ilevel >= range.min and avg_ilevel <= range.max then
                results.tier = tier_name
                break
            end
        end
        
        if avg_ilevel > TIER_RANGES.sunwell.max then
            results.tier = "sunwell"
        elseif avg_ilevel < TIER_RANGES.preraid.min then
            results.tier = "preraid"
        end
    end
    
    results.avg_ilevel = avg_ilevel
    
    return results
end

-- Estimate item level from item ID (rough approximation)
function M.estimate_item_level(item_id)
    if not item_id or type(item_id) ~= "number" then return 80 end
    
    -- TBC item ID ranges (very approximate)
    if item_id < 20000 then
        return 80  -- Classic items
    elseif item_id < 24000 then
        return 90  -- Early TBC
    elseif item_id < 28000 then
        return 100 -- Mid TBC
    elseif item_id < 32000 then
        return 115 -- Late TBC Kara
    elseif item_id < 33000 then
        return 125 -- T5
    elseif item_id < 34000 then
        return 135 -- T6
    elseif item_id < 35000 then
        return 145 -- T6.5
    else
        return 155 -- Sunwell
    end
end

-- Get gear score for current player
function M.get_score(context)
    local scan_result = M.scan(context)
    return scan_result.total_score, scan_result
end

-- Get weak slots (slots below expected item level)
function M.get_weak_slots(context)
    local scan_result = M.scan(context)
    return scan_result.weak_slots, scan_result
end

-- Check consumable status
function M.get_consumable_status(context)
    if not NS or not context then
        return { score = 0, flask = false, food = false, weapon_buff = false }
    end
    
    local me = context.me
    if not me then
        return { score = 0, flask = false, food = false, weapon_buff = false }
    end
    
    local status = {
        score = 0,
        flask = false,
        food = false,
        weapon_buff = false,
        battle_elixir = false,
        guardian_elixir = false,
        scrolls = false,
    }
    
    local buffs = TBC.BUFFS or {}
    if NS.has_buff then
        for _, id in ipairs(buffs.flasks or {}) do
            if NS.has_buff(me, id) then
                status.flask = true
                status.score = status.score + 25
                break
            end
        end
        
        for _, id in ipairs(buffs.food or {}) do
            if NS.has_buff(me, id) then
                status.food = true
                status.score = status.score + 15
                break
            end
        end

        for _, id in ipairs(buffs.battle_elixirs or {}) do
            if NS.has_buff(me, id) then
                status.battle_elixir = true
                status.score = status.score + 10
                break
            end
        end

        for _, id in ipairs(buffs.guardian_elixirs or {}) do
            if NS.has_buff(me, id) then
                status.guardian_elixir = true
                status.score = status.score + 10
                break
            end
        end
    end

    local weapon = NS and NS.WeaponImbueManager
    if type(weapon) == "table" and type(weapon.get_status) == "function" then
        local ok, weapon_status = pcall(weapon.get_status)
        if ok and type(weapon_status) == "table" and (weapon_status.mh_imbue or weapon_status.oh_imbue) then
            status.weapon_buff = true
            status.score = status.score + 10
        end
    end
    
    -- Clamp score to 0-100
    status.score = math.min(100, status.score)
    
    return status
end

-- Get full gear audit
function M.get_full_audit(context)
    local score, scan_result = M.get_score(context)
    local consumables = M.get_consumable_status(context)
    local weak_slots = scan_result.weak_slots
    
    local total_score = score + consumables.score
    
    return {
        gear_score = score,
        consumable_score = consumables.score,
        total_score = total_score,
        tier = scan_result.tier,
        avg_ilevel = scan_result.avg_ilevel,
        weak_slots = weak_slots,
        missing_slots = scan_result.missing_slots,
        consumables = consumables,
        parse_ready = (total_score >= 70 and scan_result.tier ~= "preraid"),
    }
end

if NS then
    NS.GearScore = M
end

return M
