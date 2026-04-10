--[[
    Dashboard Configuration for EAXPaladinProtection
     combat dashboard with resource bars, cooldown tracking, buff/debuff monitoring
--]]

local utils = require("libraries/utils")

return {
    class_name = "Paladin Protection",
    class_id = 2,  -- Paladin class ID for player validation
    
    -- Resource type
    resource_type = "mana",
    secondary_resource_type = nil,
    
    -- Cooldowns to track (spell IDs)
    cooldowns = {
        31884,   -- Avenging Wrath
        20925,   -- Holy Shield (Rank 1, max rank is 27179)
        31789,   -- Righteous Defense
        642,     -- Divine Shield
        27182,   -- Divine Protection (max rank)
        633,     -- Lay on Hands
        26573,   -- Consecration
        10308,   -- Hammer of Justice
    },
    
    -- Buffs to monitor (with labels)
    buffs = {
        {id = 31884, label = "Avenging Wrath"},
        {id = 642,   label = "Divine Shield"},
        {id = 20925, label = "Holy Shield"},
        {id = 25780, label = "Righteous Fury"},
        {id = 27168, label = "Seal of Righteousness"},
        {id = 31892, label = "Seal of Vengeance"},
        {id = 27168, label = "Blessing of Kings"},
        {id = 27169, label = "Blessing of Sanctuary"},
        {id = 27150, label = "Devotion Aura"},
        {id = 27152, label = "Concentration Aura"},
        {id = 27179, label = "Blessing of Freedom"},
        {id = 27180, label = "Blessing of Protection"},
        {id = 27181, label = "Blessing of Sacrifice"},
        {id = 27182, label = "Divine Protection"},
        {id = 1022,  label = "Hand of Protection"},
    },
    
    -- Debuffs to track on target
    debuffs = {
        {id = 25771, label = "Forbearance", target = false, show_stacks = false},
        {id = 31803, label = "Holy Vengeance", target = true, show_stacks = true},
        {id = 27158, label = "Judgement of Wisdom", target = true, show_stacks = false},
        {id = 27159, label = "Judgement of Light", target = true, show_stacks = false},
        {id = 27160, label = "Judgement of Justice", target = true, show_stacks = false},
    },
    
    -- Custom dashboard lines (label, value function)
    custom_lines = {
        -- Current Seal
        function(ctx)
            local ok, me = pcall(function() return core.object_manager.get_local_player() end)
            if not ok or not me or not me:is_valid() then return "Seal", "Unknown" end
            
            local spells = require("libraries/spells")
            if utils.has_buff(me, spells.BUFF_SEAL_OF_VENGEANCE) then
                return "Seal", "Vengeance"
            elseif utils.has_buff(me, spells.BUFF_SEAL_OF_RIGHTEOUSNESS) then
                return "Seal", "Righteousness"
            elseif utils.has_buff(me, spells.BUFF_SEAL_OF_WISDOM) then
                return "Seal", "Wisdom"
            else
                return "Seal", "None"
            end
        end,
        
        -- Holy Shield status
        function(ctx)
            local ok, me = pcall(function() return core.object_manager.get_local_player() end)
            if not ok or not me or not me:is_valid() then return "Holy Shield", "-" end
            
            local spells = require("libraries/spells")
            if utils.has_buff(me, spells.BUFF_HOLY_SHIELD) then
                return "Holy Shield", "ACTIVE"
            else
                return "Holy Shield", "DOWN"
            end
        end,
        
        -- Righteous Fury status (tank stance)
        function(ctx)
            local ok, me = pcall(function() return core.object_manager.get_local_player() end)
            if not ok or not me or not me:is_valid() then return "RFury", "-" end
            
            local spells = require("libraries/spells")
            if utils.has_buff(me, spells.BUFF_RIGHTEOUS_FURY) then
                return "RFury", "ACTIVE"
            else
                return "RFury", "INACTIVE"
            end
        end,
        
        -- Forbearance status
        function(ctx)
            local ok, me = pcall(function() return core.object_manager.get_local_player() end)
            if not ok or not me or not me:is_valid() then return "Forbearance", "-" end
            
            local spells = require("libraries/spells")
            if utils.has_debuff(me, spells.DEBUFF_FORBEARANCE) then
                return "Forbearance", "ACTIVE"
            else
                return "Forbearance", "CLEAR"
            end
        end,
        
        -- Holy Vengeance stacks (if using SoV)
        function(ctx)
            local target = ctx.target
            if not target or not target:is_valid() then return "SoV Stacks", "-" end
            
            local spells = require("libraries/spells")
            local stacks = utils.get_aura_stacks and utils.get_aura_stacks(target, spells.DEBUFF_SEAL_OF_VENGEANCE[1]) or 0
            return "SoV Stacks", tostring(stacks)
        end,
    },

    -- Dashboard feature toggles
    show_timer_bars = true,
    show_action_history = true,
    show_energy_tick = false,
    show_combo_points = false,
    show_threat_bar = true,
    enable_smart_collapse = true,
}
