--[[
    dashboard_config.lua - Dashboard Configuration for Priest Discipline
    
    Defines cooldowns, buffs, and debuffs to track on the dashboard.
    
    Usage:
        local dashboard_config = require("libraries/dashboard_config")
        dashboard.init(dashboard_config)
--]]

local dashboard_config = {
    class_name = "Priest Discipline",
    resource_type = "mana",  -- Priests use mana
    
    -- Cooldowns to track (spell IDs from spells.lua)
    cooldowns = {
        -- Major cooldowns
        33206,  -- Pain Suppression
        10060,  -- Power Infusion
        14751,  -- Inner Focus
        34433,  -- Shadowfiend
        
        -- Utility
        6346,   -- Fear Ward
        586,    -- Fade
    },
    
    -- Buffs to track on player (with labels)
    buffs = {
        -- Common Priest buffs
        {id = 25218, label = "Power Word: Shield"},
        {id = 25219, label = "Renew"},
        {id = 25221, label = "Prayer of Fortitude"},
        {id = 25222, label = "Prayer of Spirit"},
        {id = 25223, label = "Prayer of Shadow Protection"},
        {id = 25312, label = "Inner Fire"},
        {id = 25431, label = "Inner Focus"},
        {id = 14752, label = "Divine Spirit"},
        {id = 14818, label = "Divine Spirit"},
        
        -- Discipline-specific buffs
        {id = 33206, label = "Pain Suppression"},
        {id = 10060, label = "Power Infusion"},
    },
    
    -- Debuffs to track on target (Weakened Soul tracking)
    debuffs = {
        {id = 10892, label = "Weakened Soul", target = true},
    },
    
    -- Dashboard feature toggles
    show_timer_bars = true,
    show_action_history = true,
    show_energy_tick = false,
    show_combo_points = false,
    show_threat_bar = false,
    enable_smart_collapse = true,
}

return dashboard_config



