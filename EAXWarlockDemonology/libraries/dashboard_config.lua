--[[
    Dashboard Configuration for EAXWarlockDemonology
     combat dashboard with resource bars, cooldown tracking, buff/debuff monitoring
--]]

local utils = require("libraries/utils")

return {
    class_name = "Warlock Demonology",
    class_id = 9,  -- Warlock class ID for player validation
    
    -- Resource type
    resource_type = "mana",
    secondary_resource_type = nil,
    
    -- Cooldowns to track (spell IDs)
    cooldowns = {
        18708,   -- Fel Domination
        27223,   -- Death Coil
        30146,   -- Summon Felguard
        697,     -- Summon Voidwalker
        712,     -- Summon Succubus
        691,     -- Summon Felhunter
        18788,   -- Demonic Sacrifice
    },
    
    -- Buffs to monitor (with labels)
    buffs = {
        {id = 28189, label = "Fel Armor"},
        {id = 27260, label = "Demon Armor"},
        {id = 30149, label = "Soul Link"},
        {id = 28610, label = "Shadow Ward"},
        {id = 27216, label = "Demonic Sacrifice"},
        {id = 23841, label = "Master Demonologist"},
        {id = 26297, label = "Berserking"},
        {id = 33697, label = "Blood Fury"},
    },
    
    -- Debuffs to track on target
    debuffs = {
        {id = 27216, label = "Corruption", target = true, show_stacks = false},
        {id = 27215, label = "Immolate", target = true, show_stacks = false},
        {id = 27218, label = "Curse of Agony", target = true, show_stacks = false},
        {id = 27228, label = "Curse of Elements", target = true, show_stacks = false},
    },
    
    -- Custom dashboard lines (label, value function)
    custom_lines = {
        -- Active pet type
        function(ctx)
            local pet = core.pet and core.pet.get_pet()
            if pet and pet:is_valid() then
                local pet_name = pet:get_name() or "Unknown"
                return "Pet", pet_name
            else
                return "Pet", "None"
            end
        end,
        
        -- Pet health percentage
        function(ctx)
            local pet = core.pet and core.pet.get_pet()
            if pet and pet:is_valid() then
                local hp_pct = pet:get_health_percentage() or 0
                return "Pet HP", string.format("%.0f%%", hp_pct)
            else
                return "Pet HP", "--"
            end
        end,
        
        -- Soul Link status
        function(ctx)
            local me = core.object_manager.get_local_player()
            if not me or not me:is_valid() then return "Soul Link", "--" end
            
            local spells = require("libraries/spells")
            local has_soul_link = false
            if spells.BUFF_SOUL_LINK then
                for _, id in ipairs(spells.BUFF_SOUL_LINK) do
                    if me:has_buff(id) then has_soul_link = true break end
                end
            end
            
            return "Soul Link", has_soul_link and "Active" or "Inactive"
        end,
        
        -- Soul Shard count
        function(ctx)
            -- TODO: Soul shard counting requires bag scanning API not available in Sylvanas
            -- Return placeholder until alternative implementation found
            return "Soul Shards", "N/A"
        end,
        
        -- Fel Domination cooldown
        function(ctx)
            local cd = 0
            if core.spell_book and core.spell_book.get_spell_cooldown then
                cd = core.spell_book.get_spell_cooldown(18708)
            end
            if cd > 0 then
                return "Fel Dom", string.format("%.0fs", cd)
            else
                return "Fel Dom", "READY"
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
