-- set_bonus.lua  |  Set Bonus Detection  |  TBC
-- Detects equipped set pieces and returns active damage multipliers

local set_bonus = {}

local INVENTORY_SLOT_HEAD = 0
local INVENTORY_SLOT_NECK = 1
local INVENTORY_SLOT_SHOULDER = 2
local INVENTORY_SLOT_CHEST = 4
local INVENTORY_SLOT_WAIST = 5
local INVENTORY_SLOT_LEGS = 6
local INVENTORY_SLOT_FEET = 7
local INVENTORY_SLOT_WRIST = 8
local INVENTORY_SLOT_HAND = 9
local INVENTORY_SLOT_FINGER = 10
local INVENTORY_SLOT_TRINKET_1 = 12
local INVENTORY_SLOT_TRINKET_2 = 13
local INVENTORY_SLOT_BACK = 14
local INVENTORY_SLOT_MAINHAND = 15
local INVENTORY_SLOT_OFFHAND = 16
local INVENTORY_SLOT_RANGED = 18

local ALL_EQUIP_SLOTS = {
    INVENTORY_SLOT_HEAD, INVENTORY_SLOT_NECK, INVENTORY_SLOT_SHOULDER,
    INVENTORY_SLOT_CHEST, INVENTORY_SLOT_WAIST, INVENTORY_SLOT_LEGS,
    INVENTORY_SLOT_FEET, INVENTORY_SLOT_WRIST, INVENTORY_SLOT_HAND,
    INVENTORY_SLOT_FINGER, INVENTORY_SLOT_TRINKET_1, INVENTORY_SLOT_TRINKET_2,
    INVENTORY_SLOT_BACK, INVENTORY_SLOT_MAINHAND, INVENTORY_SLOT_OFFHAND, INVENTORY_SLOT_RANGED
}

local BM_SETS = {
    ["Cryptstalker"] = {
        items = { 29055, 29056, 29057, 29058, 29059 },
        bonuses = { [2] = 1.05, [4] = 1.10 },
        desc = "T4 2p=5% pet dmg, 4p=10% all dmg"
    },
    ["CryptstalkerBattlegear"] = {
        items = { 30103, 30104, 30105, 30106, 30107 },
        bonuses = { [2] = 1.05, [4] = 1.10 },
        desc = "T5 2p=5% pet dmg, 4p=10% all dmg"
    },
    ["CryptstalkerVindication"] = {
        items = { 30914, 30915, 30916, 30917, 30918 },
        bonuses = { [2] = 1.05, [4] = 1.10 },
        desc = "T6 2p=5% pet dmg, 4p=10% all dmg"
    },
    ["Predators"] = {
        items = { 30206, 30207, 30208, 30209, 30210 },
        bonuses = { [2] = 1.05, [4] = 1.10 },
        desc = "T5 Predator's 2p=5% KC, 4p=10% focus regen"
    },
    ["Gronnstalkers"] = {
        items = { 31008, 31009, 31010, 31011, 31012 },
        bonuses = { [2] = 1.05, [4] = 1.10 },
        desc = "T6 Gronnstalker's 2p=5% pet crit, 4p=10% dmg"
    },
}

function set_bonus.get_item_id_in_slot(me, slot_id)
    if not me then return nil end
    local ok, slot_info = pcall(function() return me:get_item_at_inventory_slot(slot_id) end)
    if not ok or not slot_info or not slot_info.object then return nil end
    local item = slot_info.object
    if not item or not item.is_valid or not item:is_valid() then return nil end
    local item_id = item.get_item_id and item:get_item_id()
    return item_id
end

function set_bonus.get_equipped_items(me)
    local items = {}
    for _, slot in ipairs(ALL_EQUIP_SLOTS) do
        local item_id = set_bonus.get_item_id_in_slot(me, slot)
        if item_id and item_id > 0 then
            table.insert(items, item_id)
        end
    end
    return items
end

function set_bonus.count_set_pieces(me, set_name)
    if not me then return 0 end
    local set_def = BM_SETS[set_name]
    if not set_def or not set_def.items then return 0 end
    local items = set_bonus.get_equipped_items(me)
    local count = 0
    for _, item_id in ipairs(items) do
        for _, set_item_id in ipairs(set_def.items) do
            if item_id == set_item_id then
                count = count + 1
                break
            end
        end
    end
    return count
end

function set_bonus.get_multiplier(me, set_name)
    if not me then return 1.0 end
    local count = set_bonus.count_set_pieces(me, set_name)
    if count == 0 then return 1.0 end
    local set_def = BM_SETS[set_name]
    if not set_def or not set_def.bonuses then return 1.0 end
    if count >= 4 and set_def.bonuses[4] then
        return set_def.bonuses[4]
    elseif count >= 2 and set_def.bonuses[2] then
        return set_def.bonuses[2]
    end
    return 1.0
end

function set_bonus.get_best_multiplier(me)
    if not me then return 1.0 end
    local best = 1.0
    for set_name, _ in pairs(BM_SETS) do
        local mult = set_bonus.get_multiplier(me, set_name)
        if mult > best then
            best = mult
        end
    end
    return best
end

function set_bonus.get_active_sets(me)
    if not me then return {} end
    local active = {}
    for set_name, set_def in pairs(BM_SETS) do
        local count = set_bonus.count_set_pieces(me, set_name)
        if count >= 2 then
            local mult = set_bonus.get_multiplier(me, set_name)
            table.insert(active, {
                name = set_name,
                count = count,
                multiplier = mult,
                desc = set_def.desc or ""
            })
        end
    end
    return active
end

return set_bonus
