-- =============================================================================
-- Fishing/Lures Module - Lure management
-- Uses APISurface for all runtime API calls
-- FIXED: try_apply_lure now uses APISurface.use_item_on_safe / use_item_self_safe
--        instead of calling lure.use_on directly (bypassed safe fallback chain)
-- FIXED: lure_apply_delay_end reset logged on failure so silent failures are visible
-- FIXED: get_buffs wrapped in pcall for safety if API returns unexpected type
-- =============================================================================

local State = require("core/state")
local APISurface = require("core/api_surface")

local M = {}

-- Lures in TBC apply BOTH a temporary weapon enchant to the pole AND a player aura/buff.
-- Detection checks both: player buff (fast, authoritative) AND pole enchant slot (persistent).
-- Either confirming means the lure is active.

-- Lure buff/aura IDs (player aura applied when lure is active)
local LURE_BUFF_IDS = {
    8087, 8088, 8089, 8090, 8532, -- Classic lures
    7778, 7779, 25163,             -- Legacy
}
local LURE_BUFF_ID_SET = {}
for _, id in ipairs(LURE_BUFF_IDS) do
    LURE_BUFF_ID_SET[id] = true
end

-- Lure enchant IDs (temporary enchant on pole)
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

--- Check if player has an active lure
-- TBC lures apply BOTH a player aura/buff AND a temporary weapon enchant on the pole.
-- We check both — whichever confirms first wins. Player buff is fastest (single table
-- lookup per tick). Enchant slot is the persistent ground truth.
-- assumed_expire_time is a SHORT-WINDOW fallback (5s max) covering the 1-2 tick gap
-- between use_item dispatch and the enchant/buff registering. Capped so a silent
-- apply failure does not suppress reapply for the full lure duration.
-- @param ctx table context
-- @param me table player object
-- @return boolean
function M.has_active_lure(ctx, me, now)
    local state = ctx.state

    if not APISurface.is_valid(me) then
        return false
    end

    -- Check 1: Player aura/buff (fast path — lures give a buff to the player in TBC)
    local buffs = APISurface.get_buffs(me)
    if buffs and type(buffs) == "table" then
        local ok, found = pcall(function()
            for _, buff in ipairs(buffs) do
                if buff then
                    if type(buff.buff_id) == "number" and LURE_BUFF_ID_SET[buff.buff_id] then
                        state.lure.assumed_expire_time = 0.0
                        return true
                    end
                    if type(buff.buff_name) == "string" then
                        local lower = string.lower(buff.buff_name)
                        if string.find(lower, "lure", 1, true) then
                            state.lure.assumed_expire_time = 0.0
                            return true
                        end
                    end
                end
            end
            return false
        end)
        if ok and found then return true end
    end

    -- Check 2: Pole enchant slot (ground truth — lures also apply a temp enchant)
    local main_hand = APISurface.get_item_at_inventory_slot(me, 16)
    if main_hand and main_hand.object then
        local obj = main_hand.object
        if APISurface.item_has_enchant(obj) then
            local enchant_id         = APISurface.item_enchant_id(obj)
            local enchant_charges    = APISurface.item_enchant_charges(obj)
            local enchant_expiration = APISurface.item_enchant_expiration(obj)

            -- Known lure enchant ID — definitely a lure
            if type(enchant_id) == "number" and TEMP_LURE_ENCHANT_IDS[enchant_id] then
                state.lure.assumed_expire_time = 0.0
                return true
            end
            -- Lure charges remaining
            if type(enchant_charges) == "number" and enchant_charges > 0 then
                state.lure.assumed_expire_time = 0.0
                return true
            end
            -- Temp enchant with time remaining and no permanent enchant ID = lure
            if type(enchant_expiration) == "number" and enchant_expiration > 0 then
                if not enchant_id or enchant_id == 0 then
                    state.lure.assumed_expire_time = 0.0
                    return true
                end
            end
        end
    end

    -- Check 3: Short-window dispatch timer (covers 1-2 tick gap after use_item)
    -- Uses the engine's own 'now' (passed in) — avoids clock mismatch between
    -- izi.now() floats and os.time() integer fallback in APISurface.now()
    if type(now) == "number" and state.lure.assumed_expire_time > 0 then
        if now < state.lure.assumed_expire_time then
            return true
        end
        -- Timer expired without buff or enchant confirming — lure failed silently
        state.lure.assumed_expire_time = 0.0
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
    local enchant_charges = APISurface.item_enchant_charges(obj)

    -- FIXED: Removed enchant_expiration > 0 check — permanent pole enchants
    -- (e.g. +fishing enchant) also return expiration > 0, causing the bot to
    -- think a lure was always active and never reapply after clicking it off.
    if type(enchant_id) == "number" and TEMP_LURE_ENCHANT_IDS[enchant_id] then
        return true
    end
    -- Charges are lure-specific (lures consume charges), safe to keep
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
    
    -- Lure-specific throttle (separate from gear equip throttle).
    -- 10s window: long enough that the buff and enchant slot have definitely
    -- registered before we'd attempt another apply. Prevents the spam loop
    -- where use_item returns true but the buff hasn't landed on the next tick.
    local time_since_last = now - state.lure.last_lure_apply_time
    APISurface.print("[EaxFishing] [DBG] lure throttle check: now=" .. tostring(now) .. " last=" .. tostring(state.lure.last_lure_apply_time) .. " diff=" .. tostring(time_since_last))
    if time_since_last < 10.0 then
        APISurface.print("[EaxFishing] [DBG] lure throttle BLOCKED")
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
    state.lure.last_lure_apply_time = now  -- stamp dedicated lure throttle
    
    APISurface.print("[EaxFishing] Applying " .. (lure_name or "Lure") .. "...")
    
    -- Use APISurface safe wrappers (tries use_on_safe -> use_on fallback chain)
    -- Prefer use_on (apply to main hand weapon) over use_self
    local applied = false
    
    if main_hand.object then
        applied = APISurface.use_item_on_safe(lure_id, main_hand.object)
    end
    
    if not applied then
        -- Fallback: use_self in case the item API changed
        applied = APISurface.use_item_self_safe(lure_id)
    end
    
    if applied then
        -- Short-window fallback timer: covers the 1-2 tick gap between use_item
        -- dispatch and the enchant slot updating. Capped at 5s — if the enchant
        -- slot doesn't confirm after that, has_active_lure will return false and
        -- reapply will trigger. The old full-duration timer was causing reapply
        -- suppression when a lure apply silently failed.
        state.lure.assumed_expire_time = now + 5.0
        APISurface.print("[EaxFishing] Lure applied successfully")
        return true
    else
        APISurface.print("[EaxFishing] Failed to apply lure (id=" .. tostring(lure_id) .. " name=" .. tostring(lure_name) .. ") - check item is in bags and pole is equipped")
        return false
    end
end

return M
