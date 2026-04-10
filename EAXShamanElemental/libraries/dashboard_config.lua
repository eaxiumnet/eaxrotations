--[[
    Dashboard Configuration for EAXShamanElemental
     combat dashboard with resource bars, cooldown tracking, buff/debuff monitoring
--]]

local utils = require("libraries/utils")
local buff_manager = require("common/modules/buff_manager")

return {
    class_name = "Shaman Elemental",
    class_id = 7,  -- Shaman class ID for player validation
    
    -- Resource type
    resource_type = "mana",
    secondary_resource_type = nil,
    
    -- Cooldowns to track (spell IDs)
    cooldowns = {
        16166,   -- Elemental Mastery
        16188,   -- Nature's Swiftness
        2825,    -- Bloodlust
        30706,   -- Totem of Wrath
        2894,    -- Fire Elemental Totem
        2062,    -- Earth Elemental Totem
        16190,   -- Mana Tide Totem
        8143,    -- Tremor Totem
        8177,    -- Grounding Totem
    },
    
    -- Buffs to monitor (with labels)
    buffs = {
        {id = 16166, label = "Elemental Mastery"},
        {id = 16188, label = "Nature's Swiftness"},
        {id = 2825,  label = "Bloodlust"},
        {id = 32182, label = "Heroism"},
        {id = 16246, label = "Clearcasting"},  -- Elemental Focus
        {id = 25528, label = "Lightning Shield"},
        {id = 25529, label = "Water Shield"},
        {id = 974,   label = "Earth Shield"},
        {id = 26297, label = "Berserking"},
        {id = 33697, label = "Blood Fury"},
        {id = 25560, label = "Grace of Air Totem"},
        {id = 25561, label = "Strength of Earth Totem"},
        {id = 2895,  label = "Wrath of Air Totem"},
        {id = 8512,  label = "Windfury Totem"},
        {id = 10478, label = "Flametongue Totem"},
    },
    
    -- Debuffs to track on target
    debuffs = {
        {id = 25454, label = "Flame Shock", target = true, show_stacks = false},
        {id = 25457, label = "Frost Shock", target = true, show_stacks = false},
        {id = 25449, label = "Earth Shock", target = true, show_stacks = false},
        {id = 3600,  label = "Earthbind", target = true, show_stacks = false},
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
            if spells.BUFF_EARTH_SHIELD then
                for _, id in ipairs(spells.BUFF_EARTH_SHIELD) do
                    if buff_manager.has_buff(me, id) then return "Shield", "Earth" end
                end
            end
            return "Shield", "None"
        end,
        
        -- Active Fire Totem
        function(ctx)
            -- This would need totem tracking from the game API
            return "Fire Totem", "--"
        end,
        
        -- Active Earth Totem
        function(ctx)
            return "Earth Totem", "--"
        end,
        
        -- Clearcasting status
        function(ctx)
            local ok, me = pcall(function() return core.object_manager.get_local_player() end)
            if not ok or not me or not me:is_valid() then return "Clearcasting", "No" end
            
            local spells = require("libraries/spells")
            local has_clearcasting = false
            if spells.BUFF_CLEARCASTING then
                for _, id in ipairs(spells.BUFF_CLEARCASTING) do
                    if buff_manager.has_buff(me, id) then has_clearcasting = true break end
                end
            end
            return "Clearcasting", has_clearcasting and "READY" or "--"
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
