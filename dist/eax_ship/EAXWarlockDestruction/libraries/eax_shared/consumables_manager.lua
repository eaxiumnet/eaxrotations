-- consumables_manager.lua
-- Shared policy helpers for potions, food/drink, and flask upkeep.

local consumables_manager = {}

local COMBAT_POTION_IDS = { 22838, 22839, 32947, 32948 }
local FOOD_ITEM_IDS = { 33052, 27854, 20452, 13928, 4457, 4456, 4455, 422, 4540 }
local DRINK_ITEM_IDS = { 33445, 27860, 22018, 8766, 8428, 4605, 1708, 1205, 1179, 159 }
local FLASK_ITEM_IDS = { 22851, 22853, 22854, 22861, 33208, 13512 }

local last_combat_consumable_at = 0
local last_ooc_food_drink_at = 0
local last_flask_attempt_at = 0

local function now_seconds()
    if core and core.time then
        return core.time()
    end
    return 0
end

local function can_attempt(last_at, cooldown_s)
    return (now_seconds() - last_at) >= cooldown_s
end

local function use_first_ready_item(me, ids)
    if not me or not ids then return false end

    for _, item_id in ipairs(ids) do
        if me:has_item(item_id) and me:get_item_cooldown(item_id) <= 0 then
            if core and core.input and core.input.use_item and core.input.use_item(item_id) then
                return true
            end
        end
    end

    return false
end

function consumables_manager.try_use_combat_consumable(me, menu, utils)
    if not me or not me.is_valid or not me:is_valid() then return false end
    if not me:is_in_combat() then return false end
    if not can_attempt(last_combat_consumable_at, 1.5) then return false end

    last_combat_consumable_at = now_seconds()

    local used = use_first_ready_item(me, COMBAT_POTION_IDS)
    if used and utils and utils.log_debug then
        utils.log_debug(menu, "Consumables: used combat potion")
    end
    return used
end

function consumables_manager.try_use_ooc_food_drink(me, menu, utils)
    if not me or not me.is_valid or not me:is_valid() then return false end
    if me:is_in_combat() then return false end
    if me:is_moving() then return false end
    if not can_attempt(last_ooc_food_drink_at, 2.0) then return false end

    local hp_pct = (utils and utils.get_health_pct and utils.get_health_pct(me)) or 1.0
    local max_mana = me:get_max_power(0)
    local mana_pct = (max_mana and max_mana > 0) and (me:get_power(0) / max_mana) or 1.0

    local eat_threshold = menu and menu.eat_threshold and (menu.eat_threshold:get() / 100.0) or 0.80
    local drink_threshold = menu and menu.drink_threshold and (menu.drink_threshold:get() / 100.0) or 0.80

    last_ooc_food_drink_at = now_seconds()

    if hp_pct < eat_threshold and use_first_ready_item(me, FOOD_ITEM_IDS) then
        if utils and utils.log_debug then
            utils.log_debug(menu, "Consumables: used food")
        end
        return true
    end

    if mana_pct < drink_threshold and use_first_ready_item(me, DRINK_ITEM_IDS) then
        if utils and utils.log_debug then
            utils.log_debug(menu, "Consumables: used drink")
        end
        return true
    end

    return false
end

function consumables_manager.try_maintain_flask(me, menu, utils)
    if not me or not me.is_valid or not me:is_valid() then return false end
    if me:is_dead() then return false end
    if me.get_level and me:get_level() < 60 then return false end
    if not can_attempt(last_flask_attempt_at, 5.0) then return false end

    last_flask_attempt_at = now_seconds()

    local used = use_first_ready_item(me, FLASK_ITEM_IDS)
    if used and utils and utils.log_debug then
        utils.log_debug(menu, "Consumables: used flask")
    end
    return used
end

return consumables_manager
