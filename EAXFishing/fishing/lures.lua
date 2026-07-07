-- =============================================================================
-- Fishing/Lures Module - Lure management
-- Uses APISurface for all runtime API calls
-- =============================================================================

local APISurface = require("core/api_surface")

local M = {}

-- Lure assumed durations (item_id -> seconds)
local LURE_ASSUMED_DURATION = {
    [6529] = 600.0, -- Shiny Bauble
    [6530] = 600.0, -- Nightcrawlers
    [6811] = 600.0, -- Aquadynamic Fish Lens
    [6532] = 600.0, -- Bright Baubles
    [6533] = 300.0, -- Aquadynamic Fish Attractor
    [7307] = 600.0, -- Flesh Eating Worm (+75, TBC lure, req. 100 fishing)
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

--- Check if lure is considered active
-- @param ctx table
-- @param me game_object
-- @param now number
-- @return boolean
function M.has_active_lure(ctx, me, now)
    local state = ctx.state
    if not APISurface.is_valid(me) then return false end

    -- Debug prints are gated by the master "Debug Logging" toggle AND throttled
    -- to once per 3s. Previously `dbg` was only a throttle, so the [DBG]
    -- enchant lines spammed the console every 3s regardless of any toggle.
    local debug_on = false
    local cfg = ctx.deps and ctx.deps.config and ctx.deps.config.menu
    if cfg and cfg.debug and cfg.debug.get_state then debug_on = cfg.debug:get_state() end
    local dbg = debug_on and (not state.lure.next_dbg_time or now >= state.lure.next_dbg_time)
    if dbg then state.lure.next_dbg_time = now + 3.0 end

    -- Primary: item_has_enchant called as a method on slot 16
    local ok, slot = pcall(APISurface.get_item_at_inventory_slot, me, 16)
    if ok and slot and slot.object then
        local ok2, has_enchant = pcall(slot.object.item_has_enchant, slot.object)
        if dbg then
            APISurface.print("[EaxFishing][dbg] item_has_enchant()=" .. tostring(has_enchant))
        end
        if ok2 and has_enchant then return true end
    end

    -- Fallback: get_equipped_items loop
    if type(me.get_equipped_items) == "function" then
        local ok2, items = pcall(me.get_equipped_items, me)
        if ok2 and items then
            for _, value in pairs(items) do
                if value.slot_id == 16 and value.object then
                    local ok3, has_enchant = pcall(value.object.item_has_enchant, value.object)
                    if dbg then
                        APISurface.print("[EaxFishing][dbg] equipped item_has_enchant()=" .. tostring(has_enchant))
                    end
                    if ok3 and has_enchant then return true end

                    local ok3, eid = pcall(value.object.item_enchant_id, value.object)
                    if ok3 and type(eid) == "number" and eid > 0 then
                        if dbg then APISurface.print("[EaxFishing][dbg] item_enchant_id=" .. tostring(eid)) end
                        return true
                    end
                    local ok4, exp = pcall(value.object.item_enchant_expiration, value.object)
                    if ok4 and type(exp) == "number" and exp > 0 then
                        if dbg then APISurface.print("[EaxFishing][dbg] item_enchant_expiration=" .. tostring(exp)) end
                        return true
                    end
                end
            end
        end
    end

    -- Final fallback: duration timer set on successful apply
    if state.lure.assumed_expire_time > 0 then
        if now < state.lure.assumed_expire_time then
            return true
        end
        state.lure.assumed_expire_time = 0.0
    end

    return false
end


-- Lure priority list — best bonus first, TBC content
-- All of these apply a temporary fishing enchant to the equipped pole.
local LURE_ITEMS = {
    { id = 6533,  name = "Aquadynamic Fish Attractor", bonus = 100 }, -- vendor/AH
    { id = 34861, name = "Sharpened Fish Hook",         bonus = 100 }, -- TBC Engineering (BoP)
    { id = 6532,  name = "Bright Baubles",              bonus = 75  }, -- vendor
    { id = 7307,  name = "Flesh Eating Worm",           bonus = 75  }, -- TBC drop lure (enchant 265)
    { id = 6811,  name = "Aquadynamic Fish Lens",       bonus = 50  }, -- vendor
    { id = 6530,  name = "Nightcrawlers",               bonus = 50  }, -- vendor
    { id = 6529,  name = "Shiny Bauble",                bonus = 25  }, -- vendor
}

--- Find best available lure in inventory
-- @param ctx table context
-- @return table? lure item object
-- @return string? lure name
-- @return number? lure item id
-- @return number? stack count (total across all stacks)
function M.find_best_lure(ctx)
    local best_item = nil
    local best_name = nil
    local best_id = nil
    local total_count = 0
    
    for _, lure_info in ipairs(LURE_ITEMS) do
        local item = APISurface.get_item(lure_info.id)
        if item then
            local ok, count = pcall(item.count, item)
            if ok and count and count > 0 then
                if not best_item then
                    best_item = item
                    best_name = lure_info.name
                    best_id = lure_info.id
                end
                total_count = total_count + count
            end
        end
    end
    
    return best_item, best_name, best_id, total_count
end

--- Get total lure count across all lure types (for HUD display).
-- @param ctx table context
-- @return number total_count, number best_id
function M.get_total_lure_count(ctx)
    local total = 0
    local best_id = nil
    for _, lure_info in ipairs(LURE_ITEMS) do
        local item = APISurface.get_item(lure_info.id)
        if item then
            local ok, count = pcall(item.count, item)
            if ok and count and count > 0 then
                total = total + count
                if not best_id then best_id = lure_info.id end
            end
        end
    end
    return total, best_id
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

    -- Defensive re-check: enchant detection may have been a false negative.
    -- Re-verify no lure is active before consuming an item.
    if M.has_active_lure(ctx, me, now) then
        return false
    end

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
        -- v2.4.1: reset lure expiry warning flag so it fires again for the new lure
        if state.qol then state.qol.lure_expiry_warned = false end
        APISurface.print("[EaxFishing] Lure applied successfully")
        return true
    else
        APISurface.print("[EaxFishing] Failed to apply lure")
        return false
    end
end

return M
