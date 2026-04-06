-- enchant_checker.lua
-- Conservative shared enchant warnings.

local enchant_checker = {}

local _last_weapon_check = 0
local CHECK_INTERVAL = 300.0

local SLOT_MAP = {
    head = 0,
    shoulders = 2,
    chest = 4,
    cloak = 14,
    main_hand = 15,
}

local SLOT_ORDER = { "main_hand", "chest", "cloak", "head", "shoulders" }

local function get_equipped_main_hand(me)
    if not me then return nil end

    local candidates = {
        "get_equipped_item",
        "get_equipped_main_hand",
        "get_main_hand_item",
    }

    for _, method in ipairs(candidates) do
        if type(me[method]) == "function" then
            local ok, item = pcall(me[method], me)
            if ok and item then return item end
        end
    end

    if core and core.inventory and type(core.inventory.get_equipped_item) == "function" then
        local ok, item = pcall(core.inventory.get_equipped_item, 16)
        if ok and item then return item end
    end

    return nil
end

local function get_equipped_item_at_slot(me, slot)
    if not me or type(me.get_item_at_inventory_slot) ~= "function" then return nil end

    local ok, slot_info = pcall(me.get_item_at_inventory_slot, me, slot)
    if not ok or not slot_info then return nil end

    local item = slot_info.object or slot_info.item or slot_info
    if not item then return nil end
    if type(item.is_valid) == "function" then
        local ok_valid, valid = pcall(item.is_valid, item)
        if ok_valid and not valid then return nil end
    end

    return item
end

local function get_item_id(item)
    if not item then return nil end
    if type(item.get_item_id) == "function" then
        local ok, id = pcall(item.get_item_id, item)
        if ok and type(id) == "number" then return id end
    end
    return nil
end

local function get_item_enchant_id(item)
    if not item then return nil end

    local methods = { "get_enchant_id", "get_item_enchant_id", "get_temp_enchant_id" }
    for _, method in ipairs(methods) do
        if type(item[method]) == "function" then
            local ok, value = pcall(item[method], item)
            if ok and type(value) == "number" then return value end
        end
    end

    return nil
end

local function item_has_enchant(item)
    if not item then return false end

    local methods = { "item_has_enchant", "has_enchant" }
    for _, method in ipairs(methods) do
        if type(item[method]) == "function" then
            local ok, value = pcall(item[method], item)
            if ok then
                return value == true
            end
        end
    end

    local enchant_id = get_item_enchant_id(item)
    return type(enchant_id) == "number" and enchant_id > 0
end

local function format_expected_names(config)
    if type(config) ~= "table" then return "expected enchant" end

    local names = config.names or config.enchants or {}
    local parts = {}
    for i = 1, #names do
        if type(names[i]) == "string" then
            parts[#parts + 1] = names[i]
        end
    end

    if #parts == 0 then
        return "expected enchant"
    end

    return table.concat(parts, " or ")
end

local function check_slot_config(me, slot_key, config)
    local slot_id = SLOT_MAP[slot_key]
    if not slot_id or type(config) ~= "table" then return nil end

    local item = get_equipped_item_at_slot(me, slot_id)
    if not item then return nil end

    local expected = format_expected_names(config)
    local enchant_id = get_item_enchant_id(item)
    local has_any = item_has_enchant(item)
    local allowed_ids = {}
    local has_numeric_expectation = false

    local enchants = config.enchants or {}
    for i = 1, #enchants do
        if type(enchants[i]) == "number" then
            allowed_ids[#allowed_ids + 1] = enchants[i]
            has_numeric_expectation = true
        end
    end

    if has_numeric_expectation then
        for i = 1, #allowed_ids do
            if enchant_id == allowed_ids[i] then
                return nil
            end
        end

        return {
            slot_key = slot_key,
            slot_label = config.label or slot_key,
            expected = expected,
            message = string.format("%s missing expected enchant: %s.", config.label or slot_key, expected),
        }
    end

    if has_any then
        return nil
    end

    return {
        slot_key = slot_key,
        slot_label = config.label or slot_key,
        expected = expected,
        message = string.format("%s missing expected enchant: %s.", config.label or slot_key, expected),
    }
end

function enchant_checker.check_weapon(me)
    local now = core and core.time and core.time() or 0
    if (now - _last_weapon_check) < CHECK_INTERVAL then return false end
    _last_weapon_check = now

    local item = get_equipped_main_hand(me)
    if not item then return false end

    local item_id = get_item_id(item)
    if not item_id then return false end

    local enchant_id = get_item_enchant_id(item)
    if enchant_id == nil then
        return false
    end

    if enchant_id > 0 then return false end

    return true
end

function enchant_checker.check_spec(me, spec_enchants)
    local now = core and core.time and core.time() or 0
    if (now - _last_weapon_check) < CHECK_INTERVAL then return nil end
    _last_weapon_check = now

    if type(spec_enchants) ~= "table" then return nil end

    for i = 1, #SLOT_ORDER do
        local slot_key = SLOT_ORDER[i]
        local missing = check_slot_config(me, slot_key, spec_enchants[slot_key])
        if missing then
            return missing
        end
    end

    return nil
end

return enchant_checker
