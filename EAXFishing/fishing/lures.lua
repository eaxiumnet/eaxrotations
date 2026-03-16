-- =============================================================================
-- Fishing/Lures Module - Lure management
-- Uses APISurface for all runtime API calls
-- =============================================================================

local State = require("core/state")
local APISurface = require("core/api_surface")

local M = {}

-- Lure buff IDs
local LURE_BUFF_IDS = {
    8087, 8088, 8089, 8090, 8532, -- Classic lures
    7778, 7779, 25163, -- Legacy
}

local LURE_BUFF_ID_SET = {}
for _, id in ipairs(LURE_BUFF_IDS) do
    LURE_BUFF_ID_SET[id] = true
end

-- Lure enchant IDs (temporary enchant)
local TEMP_LURE_ENCHANT_IDS = {
    [263] = true, -- Fishing Lure +25
    [264] = true, -- Fishing Lure +50
    [265] = true, -- Fishing Lure +75
    [266] = true, -- Fishing Lure +100
}

-- Lure assumed durations (item_id -> seconds)
local LURE_ASSUMED_DURATION = {
    [6529] = 600.0, -- Shiny Bauble
    [6530] = 600.0, -- Nightcrawlers
    [6811] = 600.0, -- Aquadynamic Fish Lens
    [6532] = 600.0, -- Bright Baubles
    [6533] = 300.0, -- Aquadynamic Fish Attractor
}

local DEFAULT_LURE_DURATION = 420.0

--- Get assumed lure duration
-- @param lure_item_id number?
-- @return number duration in seconds
function M.get_assumed_duration(lure_item_id)
    if lure_item_id and LURE_ASSUMED_DURATION[lure_item_id] then
        return LURE_ASSUMED_DURATION[lure_item_id]
    end
    return DEFAULT_LURE_DURATION
end

--- Check if player has active lure buff
-- @param ctx table context
-- @param me table player object
-- @return boolean
function M.has_active_lure(ctx, me)
    local state = ctx.state
    
    if not APISurface.is_valid(me) then
        return false
    end
    
    local buffs = APISurface.get_buffs(me)
    if not buffs then
        return false
    end
    
    for _, buff in ipairs(buffs) do
        if buff then
            if type(buff.buff_id) == "number" and LURE_BUFF_ID_SET[buff.buff_id] then
                state.lure.assumed_expire_time = 0.0
                return true
            end
            
            if type(buff.buff_name) == "string" then
                local lower_name = string.lower(buff.buff_name)
                if string.find(lower_name, "lure") or string.find(lower_name, "fishing") then
                    state.lure.assumed_expire_time = 0.0
                    return true
                end
            end
        end
    end
    
    -- Check assumed expiry
    local now = APISurface.now()
    if type(now) == "number" and now < state.lure.assumed_expire_time then
        return true
    end
    
    return false
end

--- Check if player has active main hand enchant
-- @param me table player object
-- @return boolean
function M.has_main_hand_enchant(me)
    if not APISurface.is_valid(me) then
        return false
    end
    
    local main_hand = APISurface.get_item_at_inventory_slot(me, 16)
    if not main_hand then
        return false
    end
    
    local obj = main_hand.object
    if not obj then
        return false
    end
    
    -- Check if item has enchant using APISurface
    if not APISurface.item_has_enchant(obj) then
        return false
    end
    
    -- Check enchant details using APISurface
    local enchant_id = APISurface.item_enchant_id(obj)
    local enchant_expiration = APISurface.item_enchant_expiration(obj)
    local enchant_charges = APISurface.item_enchant_charges(obj)
    
    if type(enchant_id) == "number" and TEMP_LURE_ENCHANT_IDS[enchant_id] then
        return true
    end
    if type(enchant_expiration) == "number" and enchant_expiration > 0 then
        return true
    end
    if type(enchant_charges) == "number" and enchant_charges > 0 then
        return true
    end
    
    return false
end

-- Lure priority list — best bonus first, TBC content
-- All of these apply a temporary fishing enchant to the equipped pole.
local LURE_ITEMS = {
    { id = 6533,  name = "Aquadynamic Fish Attractor", bonus = 100 }, -- vendor/AH
    { id = 34861, name = "Sharpened Fish Hook",         bonus = 100 }, -- TBC Engineering (BoP)
    { id = 6532,  name = "Bright Baubles",              bonus = 75  }, -- vendor
    { id = 6811,  name = "Aquadynamic Fish Lens",       bonus = 50  }, -- vendor
    { id = 6530,  name = "Nightcrawlers",               bonus = 50  }, -- vendor
    { id = 6529,  name = "Shiny Bauble",                bonus = 25  }, -- vendor
}

--- Find best available lure in inventory
-- @param ctx table context
-- @return table? lure item object
-- @return string? lure name
-- @return number? lure item id
function M.find_best_lure(ctx)
    for _, lure_info in ipairs(LURE_ITEMS) do
        local item = APISurface.get_item(lure_info.id)
        if item then
            local ok, count = pcall(item.count, item)
            if ok and count and count > 0 then
                return item, lure_info.name, lure_info.id
            end
        end
    end
    
    return nil, nil, nil
end

--- Try to apply a lure to the fishing pole
-- @param ctx table context
-- @param me table player object
-- @param now number current time
-- @return boolean success
function M.try_apply_lure(ctx, me, now)
    local state = ctx.state
    local deps = ctx.deps
    
    if not APISurface.is_valid(me) then
        return false
    end
    
    -- Check throttle
    if now - state.equip.last_equip_time < 1.5 then
        return false
    end
    
    -- Don't apply if casting/channeling
    if APISurface.is_casting_spell(me) or APISurface.is_channelling_spell(me) then
        return false
    end
    
    -- Get main hand item object
    local main_hand = APISurface.get_item_at_inventory_slot(me, 16)
    if not main_hand or not main_hand.object then
        return false
    end
    
    -- Find best lure
    local lure, lure_name, lure_id = M.find_best_lure(ctx)
    if not lure then
        -- Don't print here - engine.lua handles the warning
        return false
    end
    
    -- Handle lure delay (humanization)
    local use_lure_delay = deps.config.menu.enable_lure_delays and deps.config.menu.enable_lure_delays:get_state()
    if use_lure_delay then
        if state.lure.lure_apply_delay_end <= 0 then
            -- Start the delay (0.4-1.0 seconds)
            local delay = (0.4 + math.random() * 0.6) 
            state.lure.lure_apply_delay_end = now + delay
            return false  -- Not ready yet
        end
        
        if now < state.lure.lure_apply_delay_end then
            -- Still waiting
            return false
        end
    end
    
    -- Clear delay and apply
    state.lure.lure_apply_delay_end = 0
    state.equip.last_equip_time = now
    
    APISurface.print("[EaxFishing] Applying " .. (lure_name or "Lure") .. "...")
    
    -- Try use_on first, fall back to use_self
    local applied = false
    if lure.use_on then
        local ok, result = pcall(lure.use_on, lure, main_hand.object)
        if ok and result then
            applied = true
        end
    end
    
    if not applied and lure.use_self then
        local ok, result = pcall(lure.use_self, lure)
        if ok and result then
            applied = true
        end
    end
    
    if applied then
        -- Set assumed expiration time
        state.lure.assumed_expire_time = now + M.get_assumed_duration(lure_id)
        APISurface.print("[EaxFishing] Lure applied successfully")
        return true
    else
        APISurface.print("[EaxFishing] Failed to apply lure")
        return false
    end
end

return M
