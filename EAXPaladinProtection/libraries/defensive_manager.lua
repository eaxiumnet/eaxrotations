-- EAX Paladin Protection - defensive_manager.lua
-- Defensive cooldown management for Protection Paladin
-- Handles Divine Shield, Lay on Hands, and Divine Protection with Forbearance checking

local spells = require("libraries/spells")
local utils = require("libraries/utils")

---@type smart_defensive
local smart_defensive = require("libraries/smart_defensive")

local defensive_manager = {}

-- Throttle keys to prevent spam
local THROTTLE_KEY = "defensive_manager"
local THROTTLE_INTERVAL = 0.5  -- seconds between defensive attempts

-- HP tier thresholds (default values, overridden by menu settings)
local HP_TIER_LOH = 15         -- Lay on Hands: <=15%
local HP_TIER_DIVINE_SHIELD = 20  -- Divine Shield: <=20%
local HP_TIER_DIVINE_PROTECTION = 30  -- Divine Protection: <=30%

---Check if player has Forbearance debuff
---@param me game_object
---@return boolean has_forbearance
local function has_forbearance(me)
    if not me or not me:is_valid() then return false end
    return utils.has_debuff(me, spells.DEBUFF_FORBEARANCE)
end

---Get current health percentage safely
---@param me game_object
---@return number hp_pct (0-100)
local function get_hp_pct(me)
    if not me or not me:is_valid() then return 100 end
    local ok, hp_pct = pcall(function() return me:get_health_percentage() end)
    if ok and type(hp_pct) == "number" then
        return hp_pct
    end
    -- Fallback calculation
    local hp = me:get_health()
    local max_hp = me:get_max_health()
    if max_hp and max_hp > 0 then
        return (hp / max_hp) * 100
    end
    return 100
end

---Try to cast Lay on Hands
---Full heal, but applies Forbearance
---@param me game_object
---@param menu table
---@return boolean success
local function try_lay_on_hands(me, menu)
    -- Check toggle
    local use_lay_on_hands = (menu.use_lay_on_hands and menu.use_lay_on_hands:get_state())
    if not use_lay_on_hands then return false end
    
    -- Resolve spell ID
    local spell_id = utils.resolve_spell_id(spells.LAY_ON_HANDS)
    if not spell_id then return false end
    
    -- Check Forbearance FIRST - CRITICAL for LoH
    if has_forbearance(me) then return false end
    
    -- Check HP threshold
    local threshold = ((menu.lay_on_hands_hp_pct and menu.lay_on_hands_hp_pct:get()) or HP_TIER_LOH)
    local hp_pct = get_hp_pct(me)
    if hp_pct > threshold then return false end
    
    -- Check if can cast
    if not utils.can_cast_self(spell_id, me) then return false end
    
    -- Use smart_defensive for predictive validation
    local ctx = {}
    local settings = { lay_on_hands_hp = threshold }
    local should_use, reason = smart_defensive.should_use(me, "lay_on_hands", ctx, settings)
    if not should_use then return false end
    
    -- Cast the spell
    local ok, result = pcall(function()
        return utils.cast_self(spell_id, me)
    end)
    
    if ok and result then
        return true
    end
    
    return false
end

---Try to cast Divine Shield
---Immunity bubble, but applies Forbearance
---@param me game_object
---@param menu table
---@return boolean success
local function try_divine_shield(me, menu)
    -- Check toggle
    local use_divine_shield = (menu.use_divine_shield and menu.use_divine_shield:get_state())
    if not use_divine_shield then return false end
    
    -- Resolve spell ID
    local spell_id = utils.resolve_spell_id(spells.DIVINE_SHIELD)
    if not spell_id then return false end
    
    -- Check Forbearance FIRST - CRITICAL for Divine Shield
    if has_forbearance(me) then return false end
    
    -- Check HP threshold
    local threshold = ((menu.divine_shield_hp_pct and menu.divine_shield_hp_pct:get()) or HP_TIER_DIVINE_SHIELD)
    local hp_pct = get_hp_pct(me)
    if hp_pct > threshold then return false end
    
    -- Check if can cast
    if not utils.can_cast_self(spell_id, me) then return false end
    
    -- Use smart_defensive for predictive validation
    local ctx = {}
    local settings = { divine_shield_hp = threshold }
    local should_use, reason = smart_defensive.should_use(me, "divine_shield", ctx, settings)
    if not should_use then return false end
    
    -- Cast the spell
    local ok, result = pcall(function()
        return utils.cast_self(spell_id, me)
    end)
    
    if ok and result then
        return true
    end
    
    return false
end

---Try to cast Divine Protection
---Damage reduction, does NOT apply Forbearance
---@param me game_object
---@param menu table
---@return boolean success
local function try_divine_protection(me, menu)
    -- Check toggle
    local use_divine_protection = (menu.use_divine_protection and menu.use_divine_protection:get_state())
    if not use_divine_protection then return false end
    
    -- Resolve spell ID
    local spell_id = utils.resolve_spell_id(spells.DIVINE_PROTECTION)
    if not spell_id then return false end
    
    -- Check if already buffed (don't double-cast)
    if smart_defensive.has_similar_buff(me, "divine_protection") then return false end
    
    -- Check HP threshold
    local threshold = ((menu.divine_protection_hp_pct and menu.divine_protection_hp_pct:get()) or HP_TIER_DIVINE_PROTECTION)
    local hp_pct = get_hp_pct(me)
    if hp_pct > threshold then return false end
    
    -- Check if can cast
    if not utils.can_cast_self(spell_id, me) then return false end
    
    -- Use smart_defensive for predictive validation
    local ctx = {}
    local settings = { divine_protection_hp = threshold }
    local should_use, reason = smart_defensive.should_use(me, "divine_protection", ctx, settings)
    if not should_use then return false end
    
    -- Cast the spell
    local ok, result = pcall(function()
        return utils.cast_self(spell_id, me)
    end)
    
    if ok and result then
        return true
    end
    
    return false
end

---Main defensive cooldown handler
---Implements HP tier system:
---  <=15%: Try Lay on Hands (full heal)
---  <=20%: Try Divine Shield (immunity)
---  <=30%: Try Divine Protection (damage reduction)
---@param me game_object
---@param menu table
---@return boolean defensive_used
function defensive_manager.on_update(me, menu)
    if not me or not me:is_valid() then return false end
    if not me:is_in_combat() then return false end
    
    -- Throttle to prevent spam
    if not utils.throttle(THROTTLE_KEY, THROTTLE_INTERVAL) then
        return false
    end
    
    local hp_pct = get_hp_pct(me)
    
    -- HP Tier System - check in priority order (most critical first)
    
    -- Tier 1: <=15% - Lay on Hands (full heal, highest priority)
    if hp_pct <= ((menu.lay_on_hands_hp_pct and menu.lay_on_hands_hp_pct:get()) or HP_TIER_LOH) then
        if try_lay_on_hands(me, menu) then
            return true
        end
    end
    
    -- Tier 2: <=20% - Divine Shield (immunity)
    if hp_pct <= ((menu.divine_shield_hp_pct and menu.divine_shield_hp_pct:get()) or HP_TIER_DIVINE_SHIELD) then
        if try_divine_shield(me, menu) then
            return true
        end
    end
    
    -- Tier 3: <=30% - Divine Protection (damage reduction)
    if hp_pct <= ((menu.divine_protection_hp_pct and menu.divine_protection_hp_pct:get()) or HP_TIER_DIVINE_PROTECTION) then
        if try_divine_protection(me, menu) then
            return true
        end
    end
    
    return false
end

---Try to use Divine Shield specifically for CC breaking
---Called from main.lua when CC'd
---@param me game_object
---@param menu table
---@return boolean success
function defensive_manager.try_divine_shield_cc_break(me, menu)
    if not me or not me:is_valid() then return false end
    
    -- Check toggle
    local use_divine_shield = (menu.use_divine_shield and menu.use_divine_shield:get_state())
    if not use_divine_shield then return false end
    
    -- Resolve spell ID
    local spell_id = utils.resolve_spell_id(spells.DIVINE_SHIELD)
    if not spell_id then return false end
    
    -- Check Forbearance FIRST
    if has_forbearance(me) then return false end
    
    -- Check if can cast
    if not utils.can_cast_self(spell_id, me) then return false end
    
    -- Cast the spell (bypass HP check for CC break)
    local ok, result = pcall(function()
        return utils.cast_self(spell_id, me)
    end)
    
    if ok and result then
        return true
    end
    
    return false
end

---Get current defensive status for debugging
---@param me game_object
---@param menu table
---@return table status
function defensive_manager.get_status(me, menu)
    if not me or not me:is_valid() then
        return { error = "invalid_player" }
    end
    
    local hp_pct = get_hp_pct(me)
    local forbearance = has_forbearance(me)
    
    -- Resolve spell IDs
    local loh_id = utils.resolve_spell_id(spells.LAY_ON_HANDS)
    local ds_id = utils.resolve_spell_id(spells.DIVINE_SHIELD)
    local dp_id = utils.resolve_spell_id(spells.DIVINE_PROTECTION)
    
    -- Check cooldowns
    local loh_cd = loh_id and core.spell_book.get_spell_cooldown(loh_id) or 999
    local ds_cd = ds_id and core.spell_book.get_spell_cooldown(ds_id) or 999
    local dp_cd = dp_id and core.spell_book.get_spell_cooldown(dp_id) or 999
    
    -- Get menu settings
    local loh_threshold = ((menu.lay_on_hands_hp_pct and menu.lay_on_hands_hp_pct:get()) or HP_TIER_LOH)
    local ds_threshold = ((menu.divine_shield_hp_pct and menu.divine_shield_hp_pct:get()) or HP_TIER_DIVINE_SHIELD)
    local dp_threshold = ((menu.divine_protection_hp_pct and menu.divine_protection_hp_pct:get()) or HP_TIER_DIVINE_PROTECTION)
    
    return {
        hp_pct = hp_pct,
        has_forbearance = forbearance,
        lay_on_hands = {
            available = loh_id ~= nil and loh_cd <= 0 and not forbearance,
            cooldown = loh_cd,
            threshold = loh_threshold,
            would_use = hp_pct <= loh_threshold and not forbearance,
        },
        divine_shield = {
            available = ds_id ~= nil and ds_cd <= 0 and not forbearance,
            cooldown = ds_cd,
            threshold = ds_threshold,
            would_use = hp_pct <= ds_threshold and not forbearance,
        },
        divine_protection = {
            available = dp_id ~= nil and dp_cd <= 0,
            cooldown = dp_cd,
            threshold = dp_threshold,
            would_use = hp_pct <= dp_threshold,
        },
    }
end

return defensive_manager
