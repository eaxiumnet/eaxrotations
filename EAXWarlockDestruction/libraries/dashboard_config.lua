--[[
    Dashboard Configuration for EAXWarlockDestruction
     combat dashboard with resource bars, cooldown tracking, buff/debuff monitoring
--]]

local utils = require("libraries/utils")

return {
    class_name = "Warlock Destruction",
    
    -- Resource type
    resource_type = "mana",
    secondary_resource_type = nil,
    
    -- Cooldowns to track (spell IDs)
    cooldowns = {
        27223,   -- Death Coil
        30545,   -- Shadow Burn
        17962,   -- Conflagrate
        30414,   -- Shadowfury
        18708,   -- Fel Domination
        27243,   -- Seed of Corruption
    },
    
    -- Buffs to monitor (with labels)
    buffs = {
        {id = 28189, label = "Fel Armor"},
        {id = 27260, label = "Demon Armor"},
        {id = 28610, label = "Shadow Ward"},
        {id = 34935, label = "Backlash"},  -- Instant Shadow Bolt proc (TBC)
        {id = 17941, label = "Shadowburn"}, -- Shadowburn ready
        {id = 26297, label = "Berserking"},
        {id = 33697, label = "Blood Fury"},
    },
    
    -- Debuffs to track on target
    debuffs = {
        {id = 27215, label = "Immolate", target = true, show_stacks = false},
        {id = 27218, label = "Curse of Agony", target = true, show_stacks = false},
        {id = 27228, label = "Curse of Elements", target = true, show_stacks = false},
        {id = 27243, label = "Seed of Corruption", target = true, show_stacks = false},
    },
    
    -- Custom dashboard lines (label, value function)
    custom_lines = {
        -- Backlash proc status
        function(ctx)
            local me = core.object_manager.get_local_player()
            if not me or not me:is_valid() then return "Backlash", "--" end
            
            local spells = require("libraries/spells")
            local has_backlash = false
            if spells.BUFF_BACKLASH then
                for _, id in ipairs(spells.BUFF_BACKLASH) do
                    if me:has_buff(id) then has_backlash = true break end
                end
            end
            
            return "Backlash", has_backlash and "PROC!" or "--"
        end,
        
        -- Immolate remaining time on target
        function(ctx)
            local target = core.object_manager.get_target()
            if not target or not target:is_valid() then return "Immolate", "--" end
            
            local spells = require("libraries/spells")
            local remaining = 0
            if spells.DEBUFF_IMMOLATE then
                for _, id in ipairs(spells.DEBUFF_IMMOLATE) do
                    local debuff = target:get_debuff(id)
                    if debuff and debuff.remaining then
                        remaining = debuff.remaining
                        break
                    end
                end
            end
            
            if remaining > 0 then
                return "Immolate", string.format("%.1fs", remaining)
            else
                return "Immolate", "MISSING"
            end
        end,
        
        -- Soul Shard count
        function(ctx)
            local count = 0
            if core.inventory and core.inventory.get_item_count then
                local spells = require("libraries/spells")
                if spells.SOUL_SHARD_ITEMS then
                    for _, id in ipairs(spells.SOUL_SHARD_ITEMS) do
                        count = count + (core.inventory.get_item_count(id) or 0)
                    end
                end
            end
            return "Soul Shards", tostring(count)
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
