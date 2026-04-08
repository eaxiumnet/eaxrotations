--[[
    dashboard_config.lua | EAX Mage Arcane
    Dashboard configuration for Arcane Mage (TBC)
    
    Usage:
        local dashboard = require("libraries/dashboard_config")
        dashboard.init()
--]]

local dashboard_config = {}

-- ============================================================================
-- TBC ARCANE MAGE SPELL IDs
-- ============================================================================

local TBC_SPELL_IDS = {
    -- Cooldowns
    ARCANE_POWER = 12042,
    PRESENCE_OF_MIND = 12043,
    EVOCATION = 12051,
    ICY_VEINS = 12472,
    COLD_SNAP = 11958,
    ICE_BLOCK = 45438,
    FROST_NOVA = 27088,
    
    -- Buffs
    BUFF_ARCANE_POWER = 12042,
    BUFF_PRESENCE_OF_MIND = 12043,
    BUFF_EVOCATION = 12051,
    BUFF_CLEARCASTING = 12536,      -- Arcane Concentration proc
    BUFF_CLEARCASTING_ALT = 16870,  -- Higher rank
    BUFF_ARCANE_INSTABILITY = 18469, -- Talent proc
    BUFF_ICE_BLOCK = 45438,
    BUFF_ICE_BARRIER = 13033,
    BUFF_ICY_VEINS = 12472,
    BUFF_MAGE_ARMOR = 27131,
    BUFF_ICE_ARMOR = 7302,
    
    -- Debuffs (on target)
    DEBUFF_ARCANE_MISSILES = 27079,
    DEBUFF_SLOW = 31589,
    DEBUFF_ARCANE_BLAST = 36032,    -- Self-debuff stacks
}

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

local config = {
    class_name = "Arcane Mage",
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
        TBC_SPELL_IDS.ARCANE_POWER,
        TBC_SPELL_IDS.PRESENCE_OF_MIND,
        TBC_SPELL_IDS.EVOCATION,
        TBC_SPELL_IDS.ICY_VEINS,
        TBC_SPELL_IDS.COLD_SNAP,
        TBC_SPELL_IDS.ICE_BLOCK,
        TBC_SPELL_IDS.FROST_NOVA,
    }
    
    -- Build buff list (buff IDs to track on player)
    config.buffs = {
        {id = TBC_SPELL_IDS.BUFF_ARCANE_POWER, label = "Arcane Power"},
        {id = TBC_SPELL_IDS.BUFF_PRESENCE_OF_MIND, label = "Presence of Mind"},
        {id = TBC_SPELL_IDS.BUFF_EVOCATION, label = "Evocation"},
        {id = TBC_SPELL_IDS.BUFF_CLEARCASTING, label = "Clearcasting"},
        {id = TBC_SPELL_IDS.BUFF_CLEARCASTING_ALT, label = "Clearcasting"},
        {id = TBC_SPELL_IDS.BUFF_ARCANE_INSTABILITY, label = "Arcane Instability"},
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
        {id = TBC_SPELL_IDS.DEBUFF_ARCANE_MISSILES, label = "Arcane Missiles", target = true},
        {id = TBC_SPELL_IDS.DEBUFF_SLOW, label = "Slow", target = true},
        {id = TBC_SPELL_IDS.DEBUFF_ARCANE_BLAST, label = "Arcane Blast", target = false}, -- Self-debuff
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



