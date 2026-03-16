-- =============================================================================
-- Fishing/Gear Module - Equipment management
-- REPLACED: core.input.equip_item with izi.item:use_self_safe
-- REPLACED: me.get_inventory_item_id with me:get_item_at_inventory_slot
-- =============================================================================

local APISurface = require("core/api_surface")

local M = {}

-- Known fishing pole IDs (for detection)
local KNOWN_FISHING_POLES = {
    -- Vanilla / available in TBC
    [6256]  = true,  -- Fishing Pole
    [6365]  = true,  -- Strong Fishing Pole
    [6366]  = true,  -- Darkwood Fishing Pole
    [6367]  = true,  -- Big Iron Fishing Pole
    [12225] = true,  -- Blump Family Fishing Pole
    [19022] = true,  -- Nat Pagle's Extreme Angler FC-5000
    [19970] = true,  -- Arcanite Fishing Pole
    [25978] = true,  -- Seth's Graphite Fishing Pole
    -- TBC
    [34077] = true,  -- Jeweled Fishing Pole (S1 arena reward)
}

--- Check if item ID is a known fishing pole
-- @param item_id number?
-- @return boolean
function M.is_known_fishing_pole_id(item_id)
    if not item_id or type(item_id) ~= "number" then
        return false
    end
    return KNOWN_FISHING_POLES[item_id] or false
end

--- Check if player has fishing pole equipped
-- Uses same logic as old version: checks by ID first, then by name
-- @param me table player object
-- @return boolean
function M.is_fishing_pole_equipped(me)
    if not APISurface.is_valid(me) then
        return false
    end
    
    -- Get main hand item object (documented API)
    local main_hand = APISurface.get_item_at_inventory_slot(me, 16)
    if not main_hand then
        return false
    end
    
    -- Check by item ID
    local main_hand_id = APISurface.get_item_id_from_slot_item(main_hand)
    if main_hand_id and M.is_known_fishing_pole_id(main_hand_id) then
        return true
    end
    
    -- Check by name as fallback (for multilingual support)
    local item_name = APISurface.get_item_name_from_slot_item(main_hand)
    if type(item_name) == "string" then
        local lower = string.lower(item_name)
        if string.find(lower, "fishing pole", 1, true) or 
           string.find(lower, "fishing rod", 1, true) or
           string.find(lower, "anguer", 1, true) or    -- French
           string.find(lower, "angelrute", 1, true) or -- German
           string.find(lower, "caña de pescar", 1, true) then -- Spanish
            return true
        end
    end
    
    return false
end

--- Get equipped item ID at slot
-- Uses documented API instead of banned get_inventory_item_id
-- @param me table player object
-- @param slot_id number (16=main hand, 17=off hand)
-- @return number? item id
function M.get_equipped_item_id(me, slot_id)
    if not APISurface.is_valid(me) then
        return nil
    end
    
    local item = APISurface.get_item_at_inventory_slot(me, slot_id)
    if item then
        return APISurface.get_item_id_from_slot_item(item)
    end
    
    return nil
end

--- Snapshot current weapons for later restoration
-- @param ctx table context
-- @param me table player object
function M.snapshot_weapons(ctx, me)
    local state = ctx.state
    local main_id = M.get_equipped_item_id(me, 16)
    local off_id = M.get_equipped_item_id(me, 17)
    
    -- Only update if we have valid non-pole weapons
    local updated = false
    
    if main_id and not M.is_known_fishing_pole_id(main_id) then
        if state.equip.pre_main_hand_id ~= main_id then
            state.equip.pre_main_hand_id = main_id
            updated = true
        end
    end
    
    if off_id and off_id > 0 then
        if state.equip.pre_off_hand_id ~= off_id then
            state.equip.pre_off_hand_id = off_id
            updated = true
        end
    end
    
    -- Only print when we actually saved something and values changed
    if updated and (state.equip.pre_main_hand_id or state.equip.pre_off_hand_id) then
        APISurface.print("[EaxFishing] Weapon snapshot saved: main=" .. tostring(state.equip.pre_main_hand_id) .. ", off=" .. tostring(state.equip.pre_off_hand_id))
    end
end

--- Try to reequip combat weapons
-- Uses documented izi.item(id):use_self_safe() instead of banned core.input.equip_item
-- @param ctx table context
-- @param me table player object
-- @param now number current time
-- @return boolean success
function M.try_reequip_weapons(ctx, me, now)
    local state = ctx.state
    
    if not APISurface.is_valid(me) then
        return false
    end
    
    -- Throttle
    if now - state.equip.last_reequip_time < 1.5 then
        return false
    end
    state.equip.last_reequip_time = now
    
    -- Reequip main hand using documented API
    if state.equip.pre_main_hand_id and state.equip.pre_main_hand_id > 0 then
        APISurface.print("[EaxFishing] Re-equipping main hand weapon...")
        local success = APISurface.use_item_self_safe(state.equip.pre_main_hand_id)
        if not success then
            return false
        end
    end
    
    -- Reequip off hand if needed
    if state.equip.pre_off_hand_id and state.equip.pre_off_hand_id > 0 then
        APISurface.use_item_self_safe(state.equip.pre_off_hand_id)
    end
    
    return true
end

-- Auto-equip priority list — best pole first, TBC content only
local FISHING_POLE_IDS = {
    19970, -- Arcanite Fishing Pole        (+40 fishing, Vanilla crafted)
    34077, -- Jeweled Fishing Pole          (+35 fishing, TBC S1 arena)
    19022, -- Nat Pagle's Extreme Angler   (+25 fishing, Vanilla quest)
    25978, -- Seth's Graphite Fishing Pole  (+20 fishing, Classic/TBC rep)
    12225, -- Blump Family Fishing Pole     (+20 fishing, Vanilla quest)
    6367,  -- Big Iron Fishing Pole         (+20 fishing)
    6366,  -- Darkwood Fishing Pole         (+15 fishing)
    6365,  -- Strong Fishing Pole           (+5 fishing)
    6256,  -- Fishing Pole                  (basic)
}

--- Find a fishing pole in player's inventory
-- @param ctx table context
-- @return number|nil pole item_id
function M.get_owned_fishing_pole(ctx)
    -- Try known pole IDs first using documented API
    for _, pole_id in ipairs(FISHING_POLE_IDS) do
        local count = APISurface.get_item_count(pole_id)
        if count > 0 then
            return pole_id
        end
    end
    
    return nil
end

--- Try to equip fishing pole
-- Uses izi.item(id):use_self_safe() instead of banned core.input.equip_item
-- @param ctx table context
-- @param me table player object
-- @param now number current time
-- @return boolean success
function M.try_equip_fishing_pole(ctx, me, now)
    local state = ctx.state
    local deps = ctx.deps
    
    if not APISurface.is_valid(me) then
        return false
    end
    
    -- Check throttle
    if now - state.equip.last_equip_time < 1.5 then
        return false
    end
    
    -- Don't equip if casting/channeling
    if APISurface.is_casting_spell(me) or APISurface.is_channelling_spell(me) then
        return false
    end
    
    -- Find a fishing pole
    local pole_id = M.get_owned_fishing_pole(ctx)
    if not pole_id then
        APISurface.print("[EaxFishing] No fishing pole found in inventory!")
        return false
    end
    
    -- Handle equip delay (humanization)
    local use_equip_delay = deps.config.menu.enable_equip_delays and deps.config.menu.enable_equip_delays:get_state()
    if use_equip_delay then
        if state.equip.pole_equip_delay_end <= 0 then
            -- Start the delay
            local delay = math.random(300, 800) / 1000  -- 0.3-0.8 seconds
            state.equip.pole_equip_delay_end = now + delay
            return false  -- Not ready yet
        end
        
        if now < state.equip.pole_equip_delay_end then
            -- Still waiting
            return false
        end
    end
    
    -- Clear delay and equip
    state.equip.pole_equip_delay_end = 0
    state.equip.last_equip_time = now

    local success = APISurface.use_item_self_safe(pole_id)

    if not success then
        APISurface.print("[EaxFishing] Failed to equip pole")
        return false
    end
    
    return true
end

return M
