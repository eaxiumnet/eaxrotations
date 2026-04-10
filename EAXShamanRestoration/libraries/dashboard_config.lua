--[[
    Dashboard Configuration for EAXShamanRestoration
     combat dashboard with resource bars, cooldown tracking, buff/debuff monitoring
--]]

local utils = require("libraries/utils")
local buff_manager = require("common/modules/buff_manager")

return {
    class_name = "Shaman Restoration",
    class_id = 7,  -- Shaman class ID for player validation
    
    -- Resource type
    resource_type = "mana",
    secondary_resource_type = nil,
    
    -- Cooldowns to track (spell IDs)
    cooldowns = {
        16188,   -- Nature's Swiftness
        2825,    -- Bloodlust
        16190,   -- Mana Tide Totem
        20608,   -- Reincarnation
        8143,    -- Tremor Totem
        8177,    -- Grounding Totem
        25908,   -- Tranquil Air Totem
    },
    
    -- Buffs to monitor (with labels)
    buffs = {
        {id = 16188, label = "Nature's Swiftness"},
        {id = 2825,  label = "Bloodlust"},
        {id = 32182, label = "Heroism"},
        {id = 25529, label = "Water Shield"},
        {id = 974,   label = "Earth Shield"},
        {id = 29203, label = "Healing Way"},
        {id = 26297, label = "Berserking"},
        {id = 33697, label = "Blood Fury"},
        {id = 28880, label = "Gift of the Naaru"},
        {id = 25560, label = "Grace of Air Totem"},
        {id = 25561, label = "Strength of Earth Totem"},
        {id = 2895,  label = "Wrath of Air Totem"},
        {id = 16191, label = "Mana Spring Totem"},
    },
    
    -- Debuffs to track on target (for purge)
    debuffs = {
        {id = 370,   label = "Purgeable", target = true, show_stacks = false},
    },
    
    -- Custom dashboard lines (label, value function)
    custom_lines = {
        -- Active Shield type
        function(ctx)
            local ok, me = pcall(function() return core.object_manager.get_local_player() end)
            if not ok or not me or not me:is_valid() then return "Shield", "None" end
            
            local spells = require("libraries/spells")
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
            if spells.BUFF_LIGHTNING_SHIELD then
                for _, id in ipairs(spells.BUFF_LIGHTNING_SHIELD) do
                    if buff_manager.has_buff(me, id) then return "Shield", "Lightning" end
                end
            end
            return "Shield", "None"
        end,
        
        -- Earth Shield stacks on target
        function(ctx)
            local target = (me and me:get_target())
            if not target or not target:is_valid() then return "Earth Shield", "--" end
            
            local spells = require("libraries/spells")
            local stacks = 0
            if spells.BUFF_EARTH_SHIELD then
                for _, id in ipairs(spells.BUFF_EARTH_SHIELD) do
                    local buff = target:get_buff(id)
                    if buff then
                        stacks = buff.stacks or 1
                        break
                    end
                end
            end
            if stacks > 0 then
                return "Earth Shield", tostring(stacks) .. "/10"
            else
                return "Earth Shield", "--"
            end
        end,
        
        -- Nature's Swiftness status
        function(ctx)
            local ok, me = pcall(function() return core.object_manager.get_local_player() end)
            if not ok or not me or not me:is_valid() then return "NS", "--" end
            
            local spells = require("libraries/spells")
            local has_ns = false
            if spells.BUFF_NATURES_SWIFTNESS then
                for _, id in ipairs(spells.BUFF_NATURES_SWIFTNESS) do
                    if buff_manager.has_buff(me, id) then has_ns = true break end
                end
            end
            
            if has_ns then
                return "NS", "READY"
            else
                local cd = 0
                if core.spell_book and core.spell_book.get_spell_cooldown then
                    cd = core.spell_book.get_spell_cooldown(16188)
                end
                if cd > 0 then
                    return "NS", string.format("%.0fs", cd)
                else
                    return "NS", "READY"
                end
            end
        end,
        
        -- Mana Tide status
        function(ctx)
            local cd = 0
            if core.spell_book and core.spell_book.get_spell_cooldown then
                cd = core.spell_book.get_spell_cooldown(16190)
            end
            if cd > 0 then
                return "Mana Tide", string.format("%.0fs", cd)
            else
                return "Mana Tide", "READY"
            end
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
