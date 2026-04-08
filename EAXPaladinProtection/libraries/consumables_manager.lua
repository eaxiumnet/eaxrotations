-- EAXPaladinProtection Consumables Manager
-- Handles combat consumables: Healthstones, Healing Potions, Mana Potions

local consumables_manager = {}

-- Item ID tables (highest rank first)
local HEALTHSTONE_IDS = { 22105, 22104, 22103, 22102, 22101 }
local HEALING_POTION_IDS = { 22829 }  -- Super Healing Potion
local MANA_POTION_IDS = { 22832 }     -- Super Mana Potion

-- Throttle tracking
local _last_attempt_time = 0
local THROTTLE_INTERVAL = 1.5  -- seconds between consumable attempts

---Find the first available item from a list of IDs
-- @param me GameObject: Local player
-- @param item_ids table: Array of item IDs to check
-- @return number|nil: First available item ID or nil
local function find_available_item(me, item_ids)
    if not me or not item_ids then return nil end
    for _, item_id in ipairs(item_ids) do
        if me:has_item(item_id) then
            return item_id
        end
    end
    return nil
end

---Check if an item is ready to use (has item and off cooldown)
-- @param me GameObject: Local player
-- @param item_id number: Item ID to check
-- @return boolean: True if item can be used
local function is_item_ready(me, item_id)
    if not me or not item_id then return false end
    if not me:has_item(item_id) then return false end
    local cd = me:get_item_cooldown(item_id)
    return cd <= 0
end

---Try to use a healthstone
-- Healthstones are OFF-GCD and should be used first
-- @param me GameObject: Local player
-- @param menu table: Menu module for settings
-- @return boolean: True if healthstone was used
local function try_use_healthstone(me, menu)
    local use_healthstone = (menu.use_healthstone and menu.use_healthstone:get_state()) or false
    if not use_healthstone then return false end
    
    local hp_threshold = (menu.healthstone_hp_pct and menu.healthstone_hp_pct:get()) or 30
    local hp_pct = me:get_health_percentage()
    
    if hp_pct > hp_threshold then return false end
    
    -- Find available healthstone
    local item_id = find_available_item(me, HEALTHSTONE_IDS)
    if not item_id then return false end
    
    if not is_item_ready(me, item_id) then return false end
    
    -- Use the healthstone
    core.input.use_item(item_id)
    return true
end

---Try to use a healing potion
-- @param me GameObject: Local player
-- @param menu table: Menu module for settings
-- @return boolean: True if healing potion was used
local function try_use_healing_potion(me, menu)
    local use_health_potion = (menu.use_health_potion and menu.use_health_potion:get_state()) or false
    if not use_health_potion then return false end
    
    local hp_threshold = (menu.health_potion_hp_pct and menu.health_potion_hp_pct:get()) or 40
    local hp_pct = me:get_health_percentage()
    
    if hp_pct > hp_threshold then return false end
    
    -- Find available healing potion
    local item_id = find_available_item(me, HEALING_POTION_IDS)
    if not item_id then return false end
    
    if not is_item_ready(me, item_id) then return false end
    
    -- Use the healing potion
    core.input.use_item(item_id)
    return true
end

---Try to use a mana potion
-- @param me GameObject: Local player
-- @param menu table: Menu module for settings
-- @param utils table: Utils module for mana percentage
-- @return boolean: True if mana potion was used
local function try_use_mana_potion(me, menu, utils)
    local use_mana_potion = (menu.use_mana_potion and menu.use_mana_potion:get_state()) or false
    if not use_mana_potion then return false end
    
    local mana_threshold = (menu.mana_potion_pct and menu.mana_potion_pct:get()) or 15
    local mana_pct = utils.mana_pct(me) * 100  -- Convert to percentage
    
    if mana_pct > mana_threshold then return false end
    
    -- Find available mana potion
    local item_id = find_available_item(me, MANA_POTION_IDS)
    if not item_id then return false end
    
    if not is_item_ready(me, item_id) then return false end
    
    -- Use the mana potion
    core.input.use_item(item_id)
    return true
end

---Main entry point: Try to use any combat consumable
-- Priority: Healthstone (off-GCD) > Healing Potion > Mana Potion
-- @param me GameObject: Local player
-- @param menu table: Menu module for settings
-- @param utils table: Utils module for helper functions
-- @return boolean: True if any consumable was used
function consumables_manager.try_use_combat_consumable(me, menu, utils)
    if not me or not me:is_valid() then return false end
    if not me:is_in_combat() then return false end
    if not menu then return false end
    
    -- Check master toggle
    local auto_combat_potions = (menu.auto_combat_potions and menu.auto_combat_potions:get_state()) or false
    if not auto_combat_potions then return false end
    
    -- Throttle attempts
    local now = core.time()
    if (now - _last_attempt_time) < THROTTLE_INTERVAL then return false end
    
    -- Try healthstone first (off-GCD)
    if try_use_healthstone(me, menu) then
        _last_attempt_time = now
        return true
    end
    
    -- Try healing potion
    if try_use_healing_potion(me, menu) then
        _last_attempt_time = now
        return true
    end
    
    -- Try mana potion
    if try_use_mana_potion(me, menu, utils) then
        _last_attempt_time = now
        return true
    end
    
    return false
end

return consumables_manager
