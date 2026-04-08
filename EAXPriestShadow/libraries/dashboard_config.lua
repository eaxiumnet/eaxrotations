--[[
    dashboard_config.lua - Dashboard Configuration for Priest Shadow
    
    Defines cooldowns, buffs, and debuffs to track on the dashboard.
    
    Usage:
        local dashboard_config = require("libraries/dashboard_config")
        dashboard.init(dashboard_config)
--]]

local dashboard_config = {
    class_name = "Priest Shadow",
    class_id = 5,  -- Priest class ID for player validation
    resource_type = "mana",  -- Priests use mana
    
    -- Cooldowns to track (spell IDs from spells.lua)
    cooldowns = {
        -- DPS cooldowns
        18807,  -- Mind Blast (Rank 11)
        32996,  -- Shadow Word: Death (Rank 2)
        34433,  -- Shadowfiend
        14751,  -- Inner Focus
        
        -- Utility
        586,    -- Fade
        6346,   -- Fear Ward
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
        
        -- Shadow-specific buffs
        {id = 15473, label = "Shadowform"},
        {id = 15286, label = "Vampiric Embrace"},
        {id = 34917, label = "Vampiric Touch"},
        {id = 25387, label = "Mind Flay"},
        {id = 25311, label = "Shadow Word: Pain"},
        {id = 18807, label = "Mind Blast"},
        {id = 25308, label = "Devouring Plague"},
        {id = 25437, label = "Shadowguard"},
        {id = 25467, label = "Touch of Weakness"},
    },
    
    -- Debuffs to track on target (DoTs)
    debuffs = {
        {id = 25368, label = "Shadow Word: Pain", target = true},
        {id = 25387, label = "Mind Flay", target = true},
        {id = 25467, label = "Devouring Plague", target = true},
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



