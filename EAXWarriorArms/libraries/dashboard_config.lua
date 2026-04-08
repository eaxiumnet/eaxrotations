--[[
    Dashboard Configuration for EAXWarriorArms
     combat dashboard with resource bars, cooldown tracking, buff/debuff monitoring
--]]

local utils = require("libraries/utils")

return {
    class_name = "Warrior Arms",
    resource_type = "rage",
    
    -- Cooldowns to track (spell IDs)
    cooldowns = {
        12292,   -- Bloodrage
        18499,   -- Berserker Rage
        1719,    -- Recklessness
        12809,   -- Last Stand
        12328,   -- Death Wish
        6554,    -- Pummel
        20252,   -- Intercept
        1680,    -- Whirlwind (if berserker)
        6572,    -- Revenge (if defensive)
        7384,    -- Sundering Cleave (if protection)
    },
    
    -- Buffs to monitor (with labels)
    buffs = {
        {id = 12292, label = "Bloodrage"},
        {id = 18499, label = "Berserker Rage"}, 
        {id = 1719,  label = "Recklessness"},
        {id = 12809, label = "Last Stand"},
        {id = 12328, label = "Death Wish"},
        {id = 12964, label = "Unbridled Wrath"},   -- Arms also has this
        {id = 12970, label = "Flurry"},            -- If using fast weapons
        {id = 6572,  label = "Revenge"},           -- Revenge window indicator
        {id = 30016, label = "Overpower"},         -- Overpower aura
        {id = 25251, label = "Execute"},           -- Execute spam mode
    },
    
    -- Debuffs to track on target
    debuffs = {
        {id = 11597, label = "Sunder", target = true, show_stacks = true},
        {id = 25264, label = "Thunder Clap", target = true},
        {id = 1160, label = "Demoralizing Shout", target = true},
        {id = 25208, label = "Rend", target = true},
        {id = 25212, label = "Hamstring", target = true},
    },
    
    -- Custom dashboard lines (label, value function)
    custom_lines = {
        function(ctx)
            local stance = utils.get_stance_name and utils.get_stance_name() or "Unknown"
            return "Stance", stance
        end,
        function(ctx)
            local overpower_usable = false
            if core.spell_book and core.spell_book.is_usable_spell then
                overpower_usable = core.spell_book.is_usable_spell(11585) or core.spell_book.is_usable_spell(7384)
            end
            return "Overpower", overpower_usable and "READY" or "---"
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
