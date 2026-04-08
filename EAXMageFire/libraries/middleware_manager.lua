--[[
    middleware_manager.lua | EAX Mage Fire
     middleware for Fire Mage rotation
    
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
    combustion = nil,
    fire_blast = nil,
    icy_veins = nil,
    evocation = nil,
    ice_block = nil,
    frost_nova = nil,
    blast_wave = nil,
    dragons_breath = nil,
}

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

local function resolve_spell_ids()
    spell_ids.combustion = utils.resolve_spell_id(spells.COMBUSTION)
    spell_ids.fire_blast = utils.resolve_spell_id(spells.FIRE_BLAST)
    spell_ids.icy_veins = utils.resolve_spell_id(spells.ICY_VEINS)
    spell_ids.evocation = utils.resolve_spell_id(spells.EVOCATION)
    spell_ids.ice_block = utils.resolve_spell_id(spells.ICE_BLOCK)
    spell_ids.frost_nova = utils.resolve_spell_id(spells.FROST_NOVA)
    spell_ids.blast_wave = utils.resolve_spell_id(spells.BLAST_WAVE)
    spell_ids.dragons_breath = utils.resolve_spell_id(spells.DRAGONS_BREATH)
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
            local hp_threshold = get_menu_value(menu, "ice_block_hp_pct", 30)
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
            local objects = core.object_manager.get_all_objects()
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
            if ctx.me:is_moving() then return false end
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

-- Combustion offensive CD
local function combustion_middleware(menu)
    return {
        name = "Combustion",
        priority = PRIORITY.OFFENSIVE_CDS,
        is_burst = true,
        is_defensive = false,
        is_gcd_gated = true,
        setting_key = "use_combustion",
        matches = function(ctx)
            if not ctx.in_combat then return false end
            if not ctx.target then return false end
            if not spell_ids.combustion then return false end
            if utils.has_buff(ctx.me, spells.BUFF_COMBUSTION) then return false end
            if not utils.can_cast_self(spell_ids.combustion, ctx.me) then return false end
            
            -- Check HP threshold if configured
            local hp_threshold = get_menu_value(menu, "combustion_below_hp", 0)
            if hp_threshold > 0 then
                local target_hp = ctx.target.get_health_percentage and ctx.target:get_health_percentage() or 100
                if target_hp > hp_threshold then return false end
            end
            
            return true
        end,
        execute = function(icon, ctx)
            if utils.cast_self_fast(spell_ids.combustion, ctx.me, "Combustion [MW]") then
                return true, "[MW] Combustion"
            end
            return false
        end,
    }
end

-- Icy Veins middleware
local function icy_veins_middleware(menu)
    return {
        name = "IcyVeins",
        priority = PRIORITY.OFFENSIVE_CDS - 10,
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

-- Blast Wave AoE middleware
local function blast_wave_middleware(menu)
    return {
        name = "BlastWave",
        priority = PRIORITY.BURST_ABILITIES,
        is_burst = true,
        is_defensive = false,
        is_gcd_gated = true,
        setting_key = "use_blast_wave",
        matches = function(ctx)
            if not ctx.in_combat then return false end
            if not spell_ids.blast_wave then return false end
            if not utils.can_cast_self(spell_ids.blast_wave, ctx.me) then return false end
            
            -- Check for enough enemies
            local min_enemies = get_menu_value(menu, "fire_aoe_threshold", 3)
            local count = 0
            local objects = core.object_manager.get_all_objects()
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
            if utils.cast_self(spell_ids.blast_wave, ctx.me, "Blast Wave [MW]") then
                return true, "[MW] Blast Wave"
            end
            return false
        end,
    }
end

-- Dragon's Breath AoE middleware
local function dragons_breath_middleware(menu)
    return {
        name = "DragonsBreath",
        priority = PRIORITY.BURST_ABILITIES - 10,
        is_burst = true,
        is_defensive = false,
        is_gcd_gated = true,
        setting_key = "use_dragons_breath",
        matches = function(ctx)
            if not ctx.in_combat then return false end
            if not ctx.target then return false end
            if not spell_ids.dragons_breath then return false end
            if not utils.can_cast_hostile(spell_ids.dragons_breath, ctx.me, ctx.target) then return false end
            
            -- Check for enough enemies
            local min_enemies = get_menu_value(menu, "fire_aoe_threshold", 3)
            local count = 0
            local objects = core.object_manager.get_all_objects()
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
            if utils.cast_target(spell_ids.dragons_breath, ctx.target, "Dragon's Breath [MW]") then
                return true, "[MW] Dragon's Breath"
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
    
    -- Register all Fire-specific middleware
    _compat.register_middleware(ice_block_middleware(menu))
    _compat.register_middleware(frost_nova_middleware(menu))
    _compat.register_middleware(mana_gem_middleware(menu))
    _compat.register_middleware(evocation_middleware(menu))
    _compat.register_middleware(combustion_middleware(menu))
    _compat.register_middleware(icy_veins_middleware(menu))
    _compat.register_middleware(blast_wave_middleware(menu))
    _compat.register_middleware(dragons_breath_middleware(menu))
end

function middleware_manager.execute(icon, context)
    return _compat.execute_middleware(icon, context)
end

function middleware_manager.build_context(me, target, menu)
    return _compat.build_context(me, target, menu, utils)
end

return middleware_manager
