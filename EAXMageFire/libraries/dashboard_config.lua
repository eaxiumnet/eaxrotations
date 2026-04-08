--[[
    dashboard_config.lua | EAX Mage Fire
    Dashboard configuration for Fire Mage (TBC)
    
    Usage:
        local dashboard = require("libraries/dashboard_config")
        dashboard.init()
--]]

local dashboard_config = {}

-- ============================================================================
-- TBC FIRE MAGE SPELL IDs
-- ============================================================================

local TBC_SPELL_IDS = {
    -- Cooldowns
    COMBUSTION = 11129,
    ICY_VEINS = 12472,
    EVOCATION = 12051,
    ICE_BLOCK = 45438,
    FROST_NOVA = 27088,
    BLAST_WAVE = 11113,
    DRAGONS_BREATH = 31661,
    
    -- Buffs
    BUFF_COMBUSTION = 11129,
    BUFF_MOLTEN_ARMOR = 30482,
    BUFF_PYROBLAST = 11366,
    BUFF_FIREBALL = 2120,
    BUFF_IMPACT = 18469,
    BUFF_ICE_BLOCK = 45438,
    BUFF_ICE_BARRIER = 13033,
    BUFF_ICY_VEINS = 12472,
    BUFF_MAGE_ARMOR = 27131,
    BUFF_ICE_ARMOR = 7302,
    
    -- Debuffs (on target)
    DEBUFF_FIREBALL = 27087,
    DEBUFF_PYROBLAST = 27086,
    DEBUFF_FLAMESTRIKE = 27088,
    DEBUFF_SCORCH = 27089,
    DEBUFF_IGNITE = 12873,
}

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

local config = {
    class_name = "Fire Mage",
    class_id = 8,  -- Mage class ID for player validation
    resource_type = "mana",
    
    -- Cooldowns to track (spell IDs)
    cooldowns = {},
    
    -- Buffs to track on player {id, label}
    buffs = {},
    
    -- Debuffs to track on target {id, label, target}
    debuffs = {},
    
    -- Dashboard feature toggles
    show_timer_bars = true,
    show_action_history = true,
    show_energy_tick = false,
    show_combo_points = false,
    show_threat_bar = false,
    enable_smart_collapse = true,
}

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function dashboard_config.init()
    -- Build cooldown list
    config.cooldowns = {
        TBC_SPELL_IDS.COMBUSTION,
        TBC_SPELL_IDS.ICY_VEINS,
        TBC_SPELL_IDS.EVOCATION,
        TBC_SPELL_IDS.ICE_BLOCK,
        TBC_SPELL_IDS.FROST_NOVA,
        TBC_SPELL_IDS.BLAST_WAVE,
        TBC_SPELL_IDS.DRAGONS_BREATH,
    }
    
    -- Build buff list (buff IDs to track on player)
    config.buffs = {
        {id = TBC_SPELL_IDS.BUFF_COMBUSTION, label = "Combustion"},
        {id = TBC_SPELL_IDS.BUFF_MOLTEN_ARMOR, label = "Molten Armor"},
        {id = TBC_SPELL_IDS.BUFF_PYROBLAST, label = "Pyroblast"},
        {id = TBC_SPELL_IDS.BUFF_FIREBALL, label = "Fireball"},
        {id = TBC_SPELL_IDS.BUFF_IMPACT, label = "Impact"},
        {id = TBC_SPELL_IDS.BUFF_ICE_BLOCK, label = "Ice Block"},
        {id = TBC_SPELL_IDS.BUFF_ICE_BARRIER, label = "Ice Barrier"},
        {id = TBC_SPELL_IDS.BUFF_ICY_VEINS, label = "Icy Veins"},
        {id = TBC_SPELL_IDS.BUFF_MAGE_ARMOR, label = "Mage Armor"},
        {id = TBC_SPELL_IDS.BUFF_ICE_ARMOR, label = "Ice Armor"},
        -- Common mage buffs
        {id = 10173, label = "Dampen Magic"},
        {id = 10174, label = "Amplify Magic"},
    }
    
    -- Build debuff list (debuff IDs to track on target)
    config.debuffs = {
        {id = TBC_SPELL_IDS.DEBUFF_FIREBALL, label = "Fireball", target = true},
        {id = TBC_SPELL_IDS.DEBUFF_PYROBLAST, label = "Pyroblast", target = true},
        {id = TBC_SPELL_IDS.DEBUFF_FLAMESTRIKE, label = "Flamestrike", target = true},
        {id = TBC_SPELL_IDS.DEBUFF_SCORCH, label = "Scorch", target = true},
        {id = TBC_SPELL_IDS.DEBUFF_IGNITE, label = "Ignite", target = true},
    }
    
    return config
end

function dashboard_config.get_config()
    return config
end

function dashboard_config.get_cooldowns()
    return config.cooldowns
end

function dashboard_config.get_buffs()
    return config.buffs
end

function dashboard_config.get_debuffs()
    return config.debuffs
end

return dashboard_config



