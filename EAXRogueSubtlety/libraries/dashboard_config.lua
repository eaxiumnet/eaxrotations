--[[
    Dashboard Configuration for EAXRogueSubtlety
     combat dashboard with resource bars, cooldown tracking, buff/debuff monitoring
--]]

local utils = require("libraries/utils")

return {
    class_name = "Rogue Subtlety",
    class_id = 4,  -- Rogue class ID for player validation
    resource_type = "energy",
    
    -- Cooldowns to track (spell IDs)
    cooldowns = {
        14177,   -- Cold Blood
        36554,   -- Shadowstep
        26889,   -- Vanish
        26669,   -- Evasion
        31224,   -- Cloak of Shadows
        14185,   -- Preparation
    },
    
    -- Buffs to monitor (with labels)
    buffs = {
        -- Common Rogue buffs
        {id = 1787,  label = "Stealth"},            -- Stealth
        {id = 11327, label = "Vanish"},            -- Vanish
        {id = 2983,  label = "Sprint"},            -- Sprint
        {id = 13750, label = "Adrenaline Rush"},   -- Adrenaline Rush
        {id = 13877, label = "Blade Flurry"},      -- Blade Flurry
        {id = 31224, label = "Cloak of Shadows"},  -- Cloak of Shadows
        {id = 14177, label = "Cold Blood"},        -- Cold Blood
        {id = 36554, label = "Shadowstep"},         -- Shadowstep
        {id = 26669, label = "Evasion"},           -- Evasion
        {id = 11305, label = "Sprint"},            -- Max rank Sprint
        {id = 1769,  label = "Slice and Dice"},    -- SnD (track remaining time)
        {id = 6774,  label = "Slice and Dice"},     -- SnD higher rank
        -- Subtlety-specific
        {id = 36554, label = "Shadowstep"},
        {id = 14183, label = "Premeditation"},
        {id = 14070, label = "Ghostly Strike"}, -- If used
    },
    
    -- Debuffs to track on target
    -- Focus on: Shadowstep, Premeditation, Hemorrhage stacks
    debuffs = {
        {id = 26864, label = "Hemorrhage", target = true, show_stacks = true},
        {id = 26891, label = "Garrote", target = true},
    },
    
    -- Custom dashboard lines (label, value function)
    custom_lines = {
        function(ctx)
            local me = core.object_manager.get_local_player()
            if not me or not me:is_valid() then return "Energy", "N/A" end
            
            local energy = 0
            if me.get_power then
                local ok, power = pcall(function() return me:get_power(3) end)
                if ok then energy = power end
            end
            return "Energy", tostring(energy)
        end,
        function(ctx)
            local me = core.object_manager.get_local_player()
            if not me or not me:is_valid() then return "Combo", "N/A" end
            
            local cp = 0
            if me.get_power then
                local ok, power = pcall(function() return me:get_power(4) end)
                if ok then cp = power end
            end
            return "Combo Points", tostring(cp) .. "/5"
        end,
        function(ctx)
            local spells = require("libraries/spells")
            local me = core.object_manager.get_local_player()
            if not me or not me:is_valid() then return "Stealth", "N/A" end
            
            local has_stealth = utils.has_buff(me, spells.BUFF_STEALTH)
            return "Stealth", has_stealth and "UP" or "DOWN"
        end,
    },

    -- Dashboard feature toggles
    show_timer_bars = true,
    show_action_history = true,
    show_energy_tick = true,
    show_combo_points = true,
    show_threat_bar = false,
    enable_smart_collapse = true,
}
