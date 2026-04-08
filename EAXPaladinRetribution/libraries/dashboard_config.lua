--[[
    Dashboard Configuration for EAXPaladinRetribution
     combat dashboard with resource bars, cooldown tracking, buff/debuff monitoring
--]]

local utils = require("libraries/utils")

return {
    class_name = "Paladin Retribution",
    
    -- Resource type
    resource_type = "mana",
    secondary_resource_type = nil,
    
    -- Cooldowns to track (spell IDs)
    cooldowns = {
        35395,   -- Crusader Strike
        31884,   -- Avenging Wrath
        642,     -- Divine Shield
        633,     -- Lay on Hands
        24275,   -- Hammer of Wrath
        10308,   -- Hammer of Justice
        20066,   -- Repentance
    },
    
    -- Buffs to monitor (with labels)
    buffs = {
        {id = 31884, label = "Avenging Wrath"},
        {id = 642,   label = "Divine Shield"},
        {id = 20375, label = "Seal of Command"},
        {id = 31801, label = "Seal of Blood"},
        {id = 31892, label = "Seal of Vengeance"},
        {id = 20218, label = "Sanctity Aura"},
        {id = 27150, label = "Devotion Aura"},
        {id = 27151, label = "Retribution Aura"},
        {id = 27152, label = "Concentration Aura"},
        {id = 19746, label = "Crusader Aura"},
        {id = 27168, label = "Blessing of Kings"},
        {id = 27169, label = "Blessing of Sanctuary"},
        {id = 27179, label = "Blessing of Freedom"},
        {id = 27180, label = "Blessing of Protection"},
        {id = 27181, label = "Blessing of Sacrifice"},
        {id = 27182, label = "Divine Protection"},
        {id = 1022,  label = "Hand of Protection"},
    },
    
    -- Debuffs to track on target
    debuffs = {
        {id = 25771, label = "Forbearance", target = false, show_stacks = false},
        {id = 27173, label = "Judgement of the Crusader", target = true, show_stacks = false},
        {id = 27158, label = "Judgement of Wisdom", target = true, show_stacks = false},
        {id = 27159, label = "Judgement of Light", target = true, show_stacks = false},
        {id = 27160, label = "Judgement of Justice", target = true, show_stacks = false},
        {id = 31803, label = "Holy Vengeance", target = true, show_stacks = true},
    },
    
    -- Custom dashboard lines (label, value function)
    custom_lines = {
        -- Current Seal
        function(ctx)
            local me = core.object_manager.get_local_player()
            if not me or not me:is_valid() then return "Seal", "Unknown" end
            
            local spells = require("libraries/spells")
            if utils.has_buff(me, spells.BUFF_SEAL_OF_COMMAND) then
                return "Seal", "Command"
            elseif utils.has_buff(me, spells.BUFF_SEAL_OF_BLOOD) then
                return "Seal", "Blood"
            elseif utils.has_buff(me, spells.BUFF_SEAL_OF_VENGEANCE) then
                return "Seal", "Vengeance"
            elseif utils.has_buff(me, spells.BUFF_SEAL_OF_THE_CRUSADER) then
                return "Seal", "Crusader"
            else
                return "Seal", "None"
            end
        end,
        
        -- Vengeance talent stacks (+5% holy damage per stack)
        function(ctx)
            local me = core.object_manager.get_local_player()
            if not me or not me:is_valid() then return "Vengeance", "0" end
            
            local spells = require("libraries/spells")
            local stacks = utils.get_aura_stacks and utils.get_aura_stacks(me, spells.BUFF_VENGEANCE_TALENT[1]) or 0
            return "Vengeance", tostring(stacks) .. "/5"
        end,
        
        -- Current Aura
        function(ctx)
            local me = core.object_manager.get_local_player()
            if not me or not me:is_valid() then return "Aura", "Unknown" end
            
            local spells = require("libraries/spells")
            if utils.has_buff(me, spells.BUFF_SANCTITY_AURA) then
                return "Aura", "Sanctity"
            elseif utils.has_buff(me, spells.BUFF_DEVOTION_AURA) then
                return "Aura", "Devotion"
            elseif utils.has_buff(me, spells.BUFF_RETRIBUTION_AURA) then
                return "Aura", "Retribution"
            elseif utils.has_buff(me, spells.BUFF_CRUSADER_AURA) then
                return "Aura", "Crusader"
            else
                return "Aura", "None"
            end
        end,
        
        -- Forbearance status
        function(ctx)
            local me = core.object_manager.get_local_player()
            if not me or not me:is_valid() then return "Forbearance", "-" end
            
            local spells = require("libraries/spells")
            if utils.has_debuff(me, spells.DEBUFF_FORBEARANCE) then
                return "Forbearance", "ACTIVE"
            else
                return "Forbearance", "CLEAR"
            end
        end,
        
        -- Active Judgement on target
        function(ctx)
            local target = ctx.target
            if not target or not target:is_valid() then return "Judgement", "-" end
            
            local spells = require("libraries/spells")
            if utils.has_debuff(target, spells.DEBUFF_JUDGEMENT_OF_THE_CRUSADER) then
                return "Judgement", "Crusader"
            elseif utils.has_debuff(target, spells.DEBUFF_JUDGEMENT_OF_WISDOM) then
                return "Judgement", "Wisdom"
            elseif utils.has_debuff(target, spells.DEBUFF_JUDGEMENT_OF_LIGHT) then
                return "Judgement", "Light"
            else
                return "Judgement", "None"
            end
        end,
        
        -- Holy Vengeance stacks (if using SoV)
        function(ctx)
            local target = ctx.target
            if not target or not target:is_valid() then return "SoV Stacks", "-" end
            
            local spells = require("libraries/spells")
            local stacks = utils.get_aura_stacks and utils.get_aura_stacks(target, spells.DEBUFF_HOLY_VENGEANCE[1]) or 0
            return "SoV Stacks", tostring(stacks)
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
