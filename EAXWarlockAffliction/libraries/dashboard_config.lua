--[[
    Dashboard Configuration for EAXWarlockAffliction
     combat dashboard with resource bars, cooldown tracking, buff/debuff monitoring
--]]

local utils = require("libraries/utils")
local buff_manager = require("common/modules/buff_manager")

return {
    class_name = "Warlock Affliction",
    class_id = 9,  -- Warlock class ID for player validation
    
    -- Resource type
    resource_type = "mana",
    secondary_resource_type = nil,
    
    -- Cooldowns to track (spell IDs)
    cooldowns = {
        18288,   -- Amplify Curse
        27223,   -- Death Coil
        30545,   -- Shadow Burn
        18708,   -- Fel Domination
        1120,    -- Drain Soul
    },
    
    -- Buffs to monitor (with labels)
    buffs = {
        {id = 18288, label = "Amplify Curse"},
        {id = 28189, label = "Fel Armor"},
        {id = 27260, label = "Demon Armor"},
        {id = 28610, label = "Shadow Ward"},
        {id = 17941, label = "Nightfall"},  -- Shadow Trance
        {id = 27216, label = "Soul Siphon"}, -- Life Tap buff
        {id = 26297, label = "Berserking"},
        {id = 33697, label = "Blood Fury"},
    },
    
    -- Debuffs to track on target (DoTs)
    debuffs = {
        {id = 30405, label = "Unstable Affliction", target = true, show_stacks = false},
        {id = 27216, label = "Corruption", target = true, show_stacks = false},
        {id = 30911, label = "Siphon Life", target = true, show_stacks = false},
        {id = 27218, label = "Curse of Agony", target = true, show_stacks = false},
        {id = 30910, label = "Curse of Doom", target = true, show_stacks = false},
        {id = 27228, label = "Curse of Elements", target = true, show_stacks = false},
        {id = 27215, label = "Immolate", target = true, show_stacks = false},
        {id = 27243, label = "Seed of Corruption", target = true, show_stacks = false},
    },
    
    -- Custom dashboard lines (label, value function)
    custom_lines = {
        -- Active DoT count on target
        function(ctx)
            local target = (me and me:get_target())
            if not target or not target:is_valid() then return "DoTs", "0/6" end
            
            local spells = require("libraries/spells")
            local dot_count = 0
            local max_dots = 6
            
            local dot_buffs = {
                spells.DEBUFF_UNSTABLE_AFFLICTION,
                spells.DEBUFF_CORRUPTION,
                spells.DEBUFF_SIPHON_LIFE,
                spells.DEBUFF_CURSE_OF_AGONY,
                spells.DEBUFF_CURSE_OF_DOOM,
                spells.DEBUFF_IMMOLATE,
            }
            
            for _, buff_list in ipairs(dot_buffs) do
                if buff_list then
                    for _, id in ipairs(buff_list) do
                        if target:has_debuff(id) then
                            dot_count = dot_count + 1
                            break
                        end
                    end
                end
            end
            
            return "DoTs", tostring(dot_count) .. "/" .. tostring(max_dots)
        end,
        
        -- Nightfall proc status
        function(ctx)
            local ok, me = pcall(function() return core.object_manager.get_local_player() end)
            if not ok or not me or not me:is_valid() then return "Nightfall", "--" end
            
            local spells = require("libraries/spells")
            local has_nightfall = false
            if spells.BUFF_NIGHTFALL then
                for _, id in ipairs(spells.BUFF_NIGHTFALL) do
                    if buff_manager.has_buff(me, id) then has_nightfall = true break end
                end
            end
            
            return "Nightfall", has_nightfall and "PROC!" or "--"
        end,
        
        -- Soul Shard count
        function(ctx)
            -- TODO: Soul shard counting requires bag scanning API not available in Sylvanas
            -- Return placeholder until alternative implementation found
            return "Soul Shards", "N/A"
        end,
        
        -- Active pet
        function(ctx)
            local pet = core.pet and core.pet.get_pet()
            if pet and pet:is_valid() then
                return "Pet", "Active"
            else
                return "Pet", "None"
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
