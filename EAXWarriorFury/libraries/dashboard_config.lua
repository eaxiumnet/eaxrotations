--[[
    Dashboard Configuration for EAXWarriorFury
     combat dashboard with resource bars, cooldown tracking, buff/debuff monitoring
--]]

local utils = require("libraries/utils")

return {
    class_name = "Warrior Fury",
    resource_type = "rage",

    -- Cooldowns to track (spell IDs)
    cooldowns = {
        12292,   -- Bloodrage
        18499,   -- Berserker Rage
        1719,    -- Recklessness
        12809,   -- Last Stand
        12328,   -- Death Wish
        29801,   -- Rampage
        6554,    -- Pummel
        20252,   -- Intercept
        1680,    -- Whirlwind
    },

    -- Buffs to monitor (with labels)
    buffs = {
        {id = 12964, label = "Unbridled Wrath"},    -- Unbridled Wrath (rage gen proc)
        {id = 12292, label = "Bloodrage"},          -- Bloodrage buff
        {id = 18499, label = "Berserker Rage"},     -- Berserker Rage buff
        {id = 1719,  label = "Recklessness"},      -- Recklessness buff
        {id = 12809, label = "Last Stand"},        -- Last Stand buff
        {id = 12328, label = "Death Wish"},        -- Death Wish buff (should match spells.lua)
        {id = 29801, label = "Rampage"},           -- Rampage buff
        {id = 12970, label = "Flurry"},            -- Flurry (haste from crits)
        {id = 29131, label = "Bloodrage"},         -- Bloodrage damage taken effect
    },

    -- Debuffs to track on target
    debuffs = {
        {id = 25225, label = "Sunder", target = true, show_stacks = true},        -- Sunder Armor (max rank)
        {id = 25264, label = "Thunder Clap", target = true},                      -- Thunder Clap (max rank)
        {id = 25203, label = "Demoralizing Shout", target = true},               -- Demo Shout (max rank)
        {id = 11580, label = "Rend", target = true},                             -- Rend
        {id = 30022, label = "Hamstring", target = true},                        -- Hamstring
    },

    -- Custom dashboard lines (label, value function)
    custom_lines = {
        function(ctx)
            local stance = utils.get_stance_name and utils.get_stance_name() or "Unknown"
            return "Stance", stance
        end,
        function(ctx)
            local enrage = utils.get_enrage_status and utils.get_enrage_status() or false
            return "Enrage", enrage and "UP" or "DOWN"
        end,
    },

    -- Dashboard feature toggles
    show_timer_bars = true,
    show_action_history = true,
    show_energy_tick = false,
    show_combo_points = false,
    show_threat_bar = false,
    enable_smart_collapse = true,
}
