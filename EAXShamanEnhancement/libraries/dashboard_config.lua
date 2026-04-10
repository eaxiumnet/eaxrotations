--[[
    Dashboard Configuration for EAXShamanEnhancement
     combat dashboard with resource bars, cooldown tracking, buff/debuff monitoring
--]]

local utils = require("libraries/utils")
local buff_manager = require("common/modules/buff_manager")

return {
    class_name = "Shaman Enhancement",
    class_id = 7,  -- Shaman class ID for player validation
    
    -- Resource type
    resource_type = "mana",
    secondary_resource_type = nil,
    
    -- Cooldowns to track (spell IDs)
    cooldowns = {
        17364,   -- Stormstrike
        30823,   -- Shamanistic Rage
        2825,    -- Bloodlust
        2894,    -- Fire Elemental Totem
        8143,    -- Tremor Totem
        8177,    -- Grounding Totem
    },
    
    -- Buffs to monitor (with labels)
    buffs = {
        {id = 30823, label = "Shamanistic Rage"},
        {id = 2825,  label = "Bloodlust"},
        {id = 32182, label = "Heroism"},
        {id = 16280, label = "Flurry"},
        {id = 25528, label = "Lightning Shield"},
        {id = 25529, label = "Water Shield"},
        {id = 25585, label = "Windfury Weapon"},
        {id = 25589, label = "Flametongue Weapon"},
        {id = 25590, label = "Frostbrand Weapon"},
        {id = 25591, label = "Rockbiter Weapon"},
        {id = 26297, label = "Berserking"},
        {id = 20572, label = "Blood Fury"},
        {id = 25560, label = "Grace of Air Totem"},
        {id = 25561, label = "Strength of Earth Totem"},
        {id = 8512,  label = "Windfury Totem"},
    },
    
    -- Debuffs to track on target
    debuffs = {
        {id = 17364, label = "Stormstrike", target = true, show_stacks = false},
        {id = 25454, label = "Flame Shock", target = true, show_stacks = false},
        {id = 25457, label = "Frost Shock", target = true, show_stacks = false},
    },
    
    -- Custom dashboard lines (label, value function)
    custom_lines = {
        -- Active Shield type
        function(ctx)
            local ok, me = pcall(function() return core.object_manager.get_local_player() end)
            if not ok or not me or not me:is_valid() then return "Shield", "None" end
            
            local spells = require("libraries/spells")
            if spells.BUFF_LIGHTNING_SHIELD then
                for _, id in ipairs(spells.BUFF_LIGHTNING_SHIELD) do
                    if buff_manager.has_buff(me, id) then return "Shield", "Lightning" end
                end
            end
            if spells.BUFF_WATER_SHIELD then
                for _, id in ipairs(spells.BUFF_WATER_SHIELD) do
                    if buff_manager.has_buff(me, id) then return "Shield", "Water" end
                end
            end
            return "Shield", "None"
        end,
        
        -- Weapon Imbues status
        function(ctx)
            local ok, me = pcall(function() return core.object_manager.get_local_player() end)
            if not ok or not me or not me:is_valid() then return "Weapon Imbues", "--" end
            
            local spells = require("libraries/spells")
            local mainhand = "None"
            local offhand = "None"
            
            if spells.BUFF_WINDFURY_WEAPON then
                for _, id in ipairs(spells.BUFF_WINDFURY_WEAPON) do
                    if buff_manager.has_buff(me, id) then mainhand = "WF" break end
                end
            end
            if spells.BUFF_FLAMETONGUE_WEAPON then
                for _, id in ipairs(spells.BUFF_FLAMETONGUE_WEAPON) do
                    if buff_manager.has_buff(me, id) then offhand = "FT" break end
                end
            end
            
            return "Weapons", mainhand .. "/" .. offhand
        end,
        
        -- Stormstrike cooldown status
        function(ctx)
            local spells = require("libraries/spells")
            local cd = 0
            if core.spell_book and core.spell_book.get_spell_cooldown then
                cd = core.spell_book.get_spell_cooldown(17364)
            end
            if cd > 0 then
                return "Stormstrike", string.format("%.1fs", cd)
            else
                return "Stormstrike", "READY"
            end
        end,
        
        -- Flurry stacks
        function(ctx)
            local ok, me = pcall(function() return core.object_manager.get_local_player() end)
            if not ok or not me or not me:is_valid() then return "Flurry", "0" end
            
            local spells = require("libraries/spells")
            local stacks = 0
            if spells.BUFF_FLURRY then
                for _, id in ipairs(spells.BUFF_FLURRY) do
                    local ok_buff, buff = pcall(function() return me:get_buff(id) end)
                    if not ok_buff then buff = nil end
                    buff = buff
                    if buff then
                        stacks = buff.stacks or 1
                        break
                    end
                end
            end
            return "Flurry", tostring(stacks) .. "/5"
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
