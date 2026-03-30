-- enchant_checker.lua
-- Conservative shared enchant warnings.

local enchant_checker = {}

local _last_weapon_check = 0
local CHECK_INTERVAL = 300.0

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

return enchant_checker
