--[[
    middleware_manager.lua | EAX Mage Frost
     middleware for Frost Mage rotation
    
    Usage:
        local mw = require("libraries/middleware_manager")
        mw.init()
        
        -- In rotation:
        local result, msg = mw.execute(icon, context)
        if result then return result, msg end
--]]

local middleware_manager = {}

-- ============================================================================
-- REQUIRES
-- ============================================================================

local spells = require("libraries/spells")
local utils = require("libraries/utils")
local _compat = require("libraries/compat")

-- ============================================================================
-- API CACHING (at module load - never in on_update)
-- ============================================================================

local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player
local _get_spell_cooldown = core.spell_book.get_spell_cooldown

-- ============================================================================
-- MIDDLEWARE PRIORITIES
-- ============================================================================

local PRIORITY = {
    EMERGENCY_DEFENSIVE = 500,
    EMERGENCY_HEAL = 400,
    MANA_RECOVERY = 350,
    OFFENSIVE_CDS = 300,
    BURST_ABILITIES = 250,
    UTILITY = 200,
    INTERRUPTS = 150,
}

-- ============================================================================
-- SPELL ID CACHE
-- ============================================================================

local spell_ids = {
    icy_veins = nil,
    cold_snap = nil,
    water_elemental = nil,
    evocation = nil,
    ice_block = nil,
    frost_nova = nil,
    ice_barrier = nil,
    cone_of_cold = nil,
    blizzard = nil,
}

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

local function resolve_spell_ids()
    spell_ids.icy_veins = utils.resolve_spell_id(spells.ICY_VEINS)
    spell_ids.cold_snap = utils.resolve_spell_id(spells.COLD_SNAP)
    spell_ids.water_elemental = utils.resolve_spell_id(spells.SUMMON_WATER_ELEMENTAL)
    spell_ids.evocation = utils.resolve_spell_id(spells.EVOCATION)
    spell_ids.ice_block = utils.resolve_spell_id(spells.ICE_BLOCK)
    spell_ids.frost_nova = utils.resolve_spell_id(spells.FROST_NOVA)
    spell_ids.ice_barrier = utils.resolve_spell_id(spells.ICE_BARRIER)
    spell_ids.cone_of_cold = utils.resolve_spell_id(spells.CONE_OF_COLD)
    spell_ids.blizzard = utils.resolve_spell_id(spells.BLIZZARD)
end

local function get_menu_value(menu, key, default)
    if not menu then return default end
    local item = menu[key]
    if item and type(item.get) == "function" then
        return item:get()
    elseif item and type(item.get_state) == "function" then
        return item:get_state()
    end
    return default
end

-- ============================================================================
-- MIDDLEWARE FACTORIES
-- ============================================================================

-- Ice Block emergency defensive
local function ice_block_middleware(menu)
    return {
        name = "IceBlock",
        priority = PRIORITY.EMERGENCY_DEFENSIVE,
        is_burst = false,
        is_defensive = true,
        is_gcd_gated = true,
        setting_key = "use_ice_block",
        matches = function(ctx)
            local hp_threshold = get_menu_value(menu, "ice_block_hp_pct", 20)
            if ctx.hp_pct >= hp_threshold then return false end
            if not ctx.in_combat then return false end
            if not spell_ids.ice_block then return false end
            if utils.has_buff(ctx.me, spells.BUFF_ICE_BLOCK) then return false end
            if not utils.can_cast_self(spell_ids.ice_block, ctx.me) then return false end
            return true
        end,
        execute = function(icon, ctx)
            if utils.cast_self(spell_ids.ice_block, ctx.me, "Ice Block [MW]") then
                return true, "[MW] Ice Block"
            end
            return false
        end,
    }
end

-- Ice Barrier defensive
local function ice_barrier_middleware(menu)
    return {
        name = "IceBarrier",
        priority = PRIORITY.EMERGENCY_DEFENSIVE - 5,
        is_burst = false,
        is_defensive = true,
        is_gcd_gated = true,
        setting_key = "use_ice_barrier",
        matches = function(ctx)
            local hp_threshold = get_menu_value(menu, "ice_barrier_hp_pct", 40)
            if ctx.hp_pct >= hp_threshold then return false end
            if not ctx.in_combat then return false end
            if not spell_ids.ice_barrier then return false end
            if utils.has_buff(ctx.me, spells.BUFF_ICE_BARRIER) then return false end
            if not utils.can_cast_self(spell_ids.ice_barrier, ctx.me) then return false end
            return true
        end,
        execute = function(icon, ctx)
            if utils.cast_self(spell_ids.ice_barrier, ctx.me, "Ice Barrier [MW]") then
                return true, "[MW] Ice Barrier"
            end
            return false
        end,
    }
end

-- Frost Nova defensive
local function frost_nova_middleware(menu)
    return {
        name = "FrostNova",
        priority = PRIORITY.EMERGENCY_DEFENSIVE - 10,
        is_burst = false,
        is_defensive = true,
        is_gcd_gated = true,
        setting_key = "use_frost_nova",
        matches = function(ctx)
            if not ctx.in_combat then return false end
            if not spell_ids.frost_nova then return false end
            if not utils.can_cast_self(spell_ids.frost_nova, ctx.me) then return false end
            
            -- Check for melee attackers within 8 yards
            local ok_objects, objects = pcall(function() return core.object_manager.get_all_objects() end)
            if not ok_objects or not objects then return false end
            for i = 1, #objects do
                local obj = objects[i]
                if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead()
                   and ctx.me:can_attack(obj) and utils.is_close_to(ctx.me, obj, 8) then
                    return true
                end
            end
            return false
        end,
        execute = function(icon, ctx)
            if utils.cast_self(spell_ids.frost_nova, ctx.me, "Frost Nova [MW]") then
                return true, "[MW] Frost Nova"
            end
            return false
        end,
    }
end

-- Mana Gem middleware
local function mana_gem_middleware(menu)
    return {
        name = "ManaGem",
        priority = PRIORITY.MANA_RECOVERY,
        is_burst = false,
        is_defensive = false,
        is_gcd_gated = false,  -- Items are off-GCD
        setting_key = "use_mana_gem",
        matches = function(ctx)
            if not ctx.in_combat then return false end
            local threshold = get_menu_value(menu, "mana_gem_pct", 30)
            if ctx.mp_pct > threshold then return false end
            
            -- Check if any mana gem is available
            for i = 1, #spells.MANA_GEM_ITEMS do
                if utils.use_consumable_if_ready(ctx.me, spells.MANA_GEM_ITEMS[i]) then
                    return true
                end
            end
            return false
        end,
        execute = function(icon, ctx)
            for i = 1, #spells.MANA_GEM_ITEMS do
                if utils.use_consumable_if_ready(ctx.me, spells.MANA_GEM_ITEMS[i]) then
                    return true, "[MW] Mana Gem"
                end
            end
            return false
        end,
    }
end

-- Evocation middleware
local function evocation_middleware(menu)
    return {
        name = "Evocation",
        priority = PRIORITY.MANA_RECOVERY - 10,
        is_burst = false,
        is_defensive = false,
        is_gcd_gated = true,
        setting_key = "use_evocation",
        matches = function(ctx)
            if not ctx.in_combat then return false end
            local ok_moving, is_moving = pcall(function() return ctx.me:is_moving() end)
            if not ok_moving then is_moving = false end
            if is_moving then return false end
            if ctx.me:is_channelling_spell() then return false end
            local threshold = get_menu_value(menu, "evocation_pct", 25)
            if ctx.mp_pct > threshold then return false end
            if not spell_ids.evocation then return false end
            if not utils.can_cast_self(spell_ids.evocation, ctx.me) then return false end
            return true
        end,
        execute = function(icon, ctx)
            if utils.cast_self(spell_ids.evocation, ctx.me, "Evocation [MW]") then
                return true, "[MW] Evocation"
            end
            return false
        end,
    }
end

-- Icy Veins offensive CD
local function icy_veins_middleware(menu)
    return {
        name = "IcyVeins",
        priority = PRIORITY.OFFENSIVE_CDS,
        is_burst = true,
        is_defensive = false,
        is_gcd_gated = true,
        setting_key = "use_icy_veins",
        matches = function(ctx)
            if not ctx.in_combat then return false end
            if not ctx.target then return false end
            if not spell_ids.icy_veins then return false end
            if utils.has_buff(ctx.me, spells.BUFF_ICY_VEINS) then return false end
            if not utils.can_cast_self(spell_ids.icy_veins, ctx.me) then return false end
            return true
        end,
        execute = function(icon, ctx)
            if utils.cast_self_fast(spell_ids.icy_veins, ctx.me, "Icy Veins [MW]") then
                return true, "[MW] Icy Veins"
            end
            return false
        end,
    }
end

-- Water Elemental offensive CD
local function water_elemental_middleware(menu)
    return {
        name = "WaterElemental",
        priority = PRIORITY.OFFENSIVE_CDS - 10,
        is_burst = true,
        is_defensive = false,
        is_gcd_gated = true,
        setting_key = "use_water_elemental",
        matches = function(ctx)
            if not ctx.in_combat then return false end
            if not ctx.target then return false end
            if not spell_ids.water_elemental then return false end
            if not utils.can_cast_self(spell_ids.water_elemental, ctx.me) then return false end
            return true
        end,
        execute = function(icon, ctx)
            if utils.cast_self(spell_ids.water_elemental, ctx.me, "Water Elemental [MW]") then
                return true, "[MW] Water Elemental"
            end
            return false
        end,
    }
end

-- Cold Snap middleware
local function cold_snap_middleware(menu)
    return {
        name = "ColdSnap",
        priority = PRIORITY.OFFENSIVE_CDS - 20,
        is_burst = true,
        is_defensive = false,
        is_gcd_gated = true,
        setting_key = "use_cold_snap",
        matches = function(ctx)
            if not ctx.in_combat then return false end
            if not spell_ids.cold_snap then return false end
            if utils.has_buff(ctx.me, spells.BUFF_ICY_VEINS) then return false end
            if not utils.can_cast_self(spell_ids.cold_snap, ctx.me) then return false end
            
            -- Only use if Icy Veins is on significant cooldown
            if spell_ids.icy_veins then
                local iv_cd = _get_spell_cooldown(spell_ids.icy_veins)
                if iv_cd < 20 then return false end
            end
            
            -- Also check Water Elemental cooldown if available
            if spell_ids.water_elemental then
                local we_cd = _get_spell_cooldown(spell_ids.water_elemental)
                if we_cd < 20 then return false end
            end
            
            return true
        end,
        execute = function(icon, ctx)
            if utils.cast_self_fast(spell_ids.cold_snap, ctx.me, "Cold Snap [MW]") then
                return true, "[MW] Cold Snap"
            end
            return false
        end,
    }
end

-- Cone of Cold AoE middleware
local function cone_of_cold_middleware(menu)
    return {
        name = "ConeOfCold",
        priority = PRIORITY.BURST_ABILITIES,
        is_burst = true,
        is_defensive = false,
        is_gcd_gated = true,
        setting_key = "use_cone_of_cold",
        matches = function(ctx)
            if not ctx.in_combat then return false end
            if not ctx.target then return false end
            if not spell_ids.cone_of_cold then return false end
            if not utils.can_cast_hostile(spell_ids.cone_of_cold, ctx.me, ctx.target) then return false end
            
            -- Check for enough enemies
            local min_enemies = get_menu_value(menu, "frost_aoe_threshold", 3)
            local count = 0
            local ok_objects, objects = pcall(function() return core.object_manager.get_all_objects() end)
            if not ok_objects or not objects then return false end
            for i = 1, #objects do
                local obj = objects[i]
                if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead() and ctx.me:can_attack(obj) then
                    if utils.is_close_to(ctx.me, obj, 10) then
                        count = count + 1
                        if count >= min_enemies then break end
                    end
                end
            end
            
            return count >= min_enemies
        end,
        execute = function(icon, ctx)
            if utils.cast_target_fast(spell_ids.cone_of_cold, ctx.target, "Cone of Cold [MW]") then
                return true, "[MW] Cone of Cold"
            end
            return false
        end,
    }
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function middleware_manager.init(menu)
    resolve_spell_ids()
    
    -- Register all Frost-specific middleware
    _compat.register_middleware(ice_block_middleware(menu))
    _compat.register_middleware(ice_barrier_middleware(menu))
    _compat.register_middleware(frost_nova_middleware(menu))
    _compat.register_middleware(mana_gem_middleware(menu))
    _compat.register_middleware(evocation_middleware(menu))
    _compat.register_middleware(icy_veins_middleware(menu))
    _compat.register_middleware(water_elemental_middleware(menu))
    _compat.register_middleware(cold_snap_middleware(menu))
    _compat.register_middleware(cone_of_cold_middleware(menu))
end

function middleware_manager.execute(icon, context)
    return _compat.execute_middleware(icon, context)
end

function middleware_manager.build_context(me, target, menu)
    return _compat.build_context(me, target, menu, utils)
end

return middleware_manager
