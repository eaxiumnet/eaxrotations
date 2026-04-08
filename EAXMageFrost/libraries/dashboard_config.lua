--[[
    dashboard_config.lua | EAX Mage Frost
    Dashboard configuration for Frost Mage (TBC)
    
    Usage:
        local dashboard = require("libraries/dashboard_config")
        dashboard.init()
--]]

local dashboard_config = {}

-- ============================================================================
-- TBC FROST MAGE SPELL IDs
-- ============================================================================

local TBC_SPELL_IDS = {
    -- Cooldowns
    ICY_VEINS = 12472,
    COLD_SNAP = 11958,
    WATER_ELEMENTAL = 31687,
    EVOCATION = 12051,
    ICE_BLOCK = 45438,
    FROST_NOVA = 27088,
    ICE_BARRIER = 13033,
    CONE_OF_COLD = 27087,
    BLIZZARD = 27085,
    
    -- Buffs
    BUFF_ICY_VEINS = 12472,
    BUFF_ICE_BARRIER = 13033,
    BUFF_ICE_BLOCK = 45438,
    BUFF_COLD_SNAP = 11958,
    BUFF_WATER_ELEMENTAL = 31687,
    BUFF_FROSTBITE = 12519,
    BUFF_MAGE_ARMOR = 27131,
    BUFF_ICE_ARMOR = 7302,
    
    -- Debuffs (on target)
    DEBUFF_FROSTBOLT = 27071,
    DEBUFF_CONE_OF_COLD = 27072,
    DEBUFF_BLIZZARD = 27073,
    DEBUFF_FROST_NOVA = 27074,
    DEBUFF_FREEZE = 28609,          -- Water Elemental freeze
}

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

local config = {
    class_name = "Frost Mage",
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
        TBC_SPELL_IDS.ICY_VEINS,
        TBC_SPELL_IDS.COLD_SNAP,
        TBC_SPELL_IDS.WATER_ELEMENTAL,
        TBC_SPELL_IDS.EVOCATION,
        TBC_SPELL_IDS.ICE_BLOCK,
        TBC_SPELL_IDS.FROST_NOVA,
        TBC_SPELL_IDS.ICE_BARRIER,
        TBC_SPELL_IDS.CONE_OF_COLD,
        TBC_SPELL_IDS.BLIZZARD,
    }
    
    -- Build buff list (buff IDs to track on player)
    config.buffs = {
        {id = TBC_SPELL_IDS.BUFF_ICY_VEINS, label = "Icy Veins"},
        {id = TBC_SPELL_IDS.BUFF_ICE_BARRIER, label = "Ice Barrier"},
        {id = TBC_SPELL_IDS.BUFF_ICE_BLOCK, label = "Ice Block"},
        {id = TBC_SPELL_IDS.BUFF_COLD_SNAP, label = "Cold Snap"},
        {id = TBC_SPELL_IDS.BUFF_WATER_ELEMENTAL, label = "Water Elemental"},
        {id = TBC_SPELL_IDS.BUFF_FROSTBITE, label = "Frostbite"},
        {id = TBC_SPELL_IDS.BUFF_MAGE_ARMOR, label = "Mage Armor"},
        {id = TBC_SPELL_IDS.BUFF_ICE_ARMOR, label = "Ice Armor"},
        -- Common mage buffs
        {id = 10173, label = "Dampen Magic"},
        {id = 10174, label = "Amplify Magic"},
    }
    
    -- Build debuff list (debuff IDs to track on target)
    config.debuffs = {
        {id = TBC_SPELL_IDS.DEBUFF_FROSTBOLT, label = "Frostbolt", target = true},
        {id = TBC_SPELL_IDS.DEBUFF_CONE_OF_COLD, label = "Cone of Cold", target = true},
        {id = TBC_SPELL_IDS.DEBUFF_BLIZZARD, label = "Blizzard", target = true},
        {id = TBC_SPELL_IDS.DEBUFF_FROST_NOVA, label = "Frost Nova", target = true},
        {id = TBC_SPELL_IDS.DEBUFF_FREEZE, label = "Freeze", target = true},
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



