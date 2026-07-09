-- items.lua — Item and equipment queries for EaxRotations.
-- WHAT:  equipped item IDs, set-bonus detection, item cooldowns, and use_item_by_id.
-- WHEN:  installed by core_sylvanas.lua during addon load.
-- WHY:   isolates core.inventory and core.input calls behind NS helpers.
-- SAFETY: pcall-guarded inventory access; nil-safe return values.

-- =============================================================================
-- core/items.lua
--
-- Items + equipment domain — extracted from EaxRotations/core_sylvanas.lua.
-- Owns the EQUIPMENT_SLOTS table and all item id queries: get_equipped_item_id,
-- get_equipped_item_ids, is_item_equipped, is_item_ready, register_item_manual_cooldown,
-- use_item_by_id, has_item, count_equipped_set, has_set_bonus.
--
-- WHY THIS EXTRACT
--   The items logic forms a coherent subsystem (~210 lines, 9 functions +
--   1 table). Splitting it isolates the spell_helper and core.input /
--   core.inventory calls behind one install point.
--
-- CONTRACT
--   - install(NS): wires the items domain. core (Sylvanas engine) is
--     available at install time via NS.core (set by core_sylvanas.lua top).
--   - Behaviour preserved verbatim from the original god-file block.
-- =============================================================================

local M = {}

local function item_id_from_slot_info(NS, slot_info)
    if not slot_info then return nil end
    if type(slot_info) == "number" then return slot_info end
    local id = slot_info.item_id or slot_info.entry or slot_info.id
    if type(id) == "number" and id > 0 then return id end
    local object = slot_info.object or slot_info.item or slot_info.game_object
    -- safe / safe_field from NS (installed by core_sylvanas).
    local safe, safe_field
    pcall(function() safe_field = NS.safe_field end)
    pcall(function() safe = NS.safe end)
    local get_item_id = safe_field and safe_field(object, "get_item_id") or nil
    id = (get_item_id and safe and safe(get_item_id, object)) or nil
    return type(id) == "number" and id > 0 and id or nil
end

function M.install(NS)
    if not NS.EQUIPMENT_SLOTS then
        NS.EQUIPMENT_SLOTS = {
            HEAD = 1, NECK = 2, SHOULDER = 3, SHIRT = 4, CHEST = 5,
            WAIST = 6, LEGS = 7, FEET = 8, WRIST = 9, HANDS = 10,
            FINGER1 = 11, FINGER2 = 12, TRINKET1 = 13, TRINKET2 = 14,
            BACK = 15, MAIN_HAND = 16, OFF_HAND = 17, RANGED = 18, TABARD = 19,
        }
    end

    function NS.get_equipped_item_id(slot)
        local safe, safe_field
        pcall(function() safe_field = NS.safe_field end)
        pcall(function() safe = NS.safe end)
        local player = NS.GetPlayer and NS.GetPlayer() or nil
        local get_item_at_inventory_slot = safe_field and safe_field(player, "get_item_at_inventory_slot") or nil
        local slot_info = (get_item_at_inventory_slot and safe and safe(get_item_at_inventory_slot, player, slot)) or nil
        return item_id_from_slot_info(NS, slot_info)
    end

    function NS.get_equipped_item_ids(out)
        out = out or {}
        for k in pairs(out) do out[k] = nil end
        local n = 0
        for slot = NS.EQUIPMENT_SLOTS.HEAD, NS.EQUIPMENT_SLOTS.TABARD do
            local id = NS.get_equipped_item_id(slot)
            if id then
                n = n + 1
                out[n] = id
            end
        end
        return out, n
    end

    function NS.is_item_equipped(item_ids)
        if type(item_ids) == "number" then item_ids = { item_ids } end
        if type(item_ids) ~= "table" then return false end
        for i = 1, #item_ids do
            local wanted = item_ids[i]
            if type(wanted) == "number" then
                for slot = NS.EQUIPMENT_SLOTS.HEAD, NS.EQUIPMENT_SLOTS.TABARD do
                    if NS.get_equipped_item_id(slot) == wanted then return true end
                end
            end
        end
        return false
    end

    function NS.is_item_ready(item_id)
        if type(item_id) ~= "number" or item_id <= 0 then return false end
        local manual_cd = NS._manual_item_cooldowns and NS._manual_item_cooldowns[item_id] or nil
        local last_used = NS._last_item_use and NS._last_item_use[item_id] or nil
        if type(manual_cd) == "number" and type(last_used) == "number" and manual_cd > 0 then
            if (NS.time_now() - last_used) < manual_cd then return false end
        end
        local safe, safe_field
        pcall(function() safe_field = NS.safe_field end)
        pcall(function() safe = NS.safe end)
        local player = NS.GetPlayer and NS.GetPlayer() or nil
        local get_item_cooldown = safe_field and safe_field(player, "get_item_cooldown") or nil
        if not get_item_cooldown then return true end
        local cooldown = safe and safe(get_item_cooldown, player, item_id)
        return type(cooldown) ~= "number" or cooldown <= 0
    end

    function NS.register_item_manual_cooldown(item_id, cooldown)
        if type(item_id) ~= "number" or item_id <= 0 then return false end
        NS._manual_item_cooldowns[item_id] = type(cooldown) == "number" and cooldown > 0 and cooldown or 1
        return true
    end

    function NS.use_item_by_id(item_id, target)
        if type(item_id) ~= "number" or item_id <= 0 then return false end
        if NS.is_item_ready and NS.is_item_ready(item_id) == false then return false end
        local safe
        pcall(function() safe = NS.safe end)
        local core = NS.core
        local input = core and core.input or nil
        local used = false
        if target and NS.not_same_unit(target, NS.GetPlayer()) and type(input and input.use_item_target) == "function" then
            used = safe and safe(input.use_item_target, item_id, target) == true
        elseif type(input and input.use_item) == "function" then
            used = safe and safe(input.use_item, item_id) == true
        end
        if used then NS._last_item_use[item_id] = NS.time_now() end
        return used
    end

    NS.use_item = NS.use_item_by_id

    function NS.has_item(item_id)
        if type(item_id) ~= "number" or item_id <= 0 then return false end
        local safe
        pcall(function() safe = NS.safe end)
        local core = NS.core
        local inventory = core and core.inventory or nil
        local get_items_in_bag = inventory and inventory.get_items_in_bag
        if type(get_items_in_bag) ~= "function" then return false end
        for bag_id = 0, 4 do
            local items = safe and safe(get_items_in_bag, bag_id)
            if type(items) == "table" then
                for i = 1, #items do
                    if item_id_from_slot_info(NS, items[i]) == item_id then return true end
                end
            end
        end
        return false
    end

    function NS.count_equipped_set(item_ids)
        if type(item_ids) ~= "table" then return 0 end
        local wanted = {}
        for i = 1, #item_ids do
            if type(item_ids[i]) == "number" then wanted[item_ids[i]] = true end
        end
        local count = 0
        for slot = NS.EQUIPMENT_SLOTS.HEAD, NS.EQUIPMENT_SLOTS.TABARD do
            local id = NS.get_equipped_item_id(slot)
            if id and wanted[id] then count = count + 1 end
        end
        return count
    end

    function NS.has_set_bonus(item_ids, pieces)
        return NS.count_equipped_set(item_ids) >= (pieces or 2)
    end
end

return M
