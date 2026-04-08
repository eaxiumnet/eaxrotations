--[[
    Dashboard Configuration for EAXWarriorProtection
     combat dashboard with resource bars, cooldown tracking, buff/debuff monitoring
--]]

local utils = require("libraries/utils")

return {
    class_name = "Warrior Protection",
    
    -- Resource type
    resource_type = "rage",
    secondary_resource_type = nil,
    
    -- Cooldowns to track (spell IDs)
    cooldowns = {
        12292,   -- Bloodrage
        18499,   -- Berserker Rage
        12809,   -- Last Stand
        2565,    -- Shield Block
        23920,   -- Spell Reflection
        12975,   -- Shield Wall
        6554,    -- Pummel (if berserker switch)
        72,      -- Shield Bash (interrupt)
        1160,    -- Demoralizing Shout
        11596,   -- Sunder Armor
    },
    
    -- Buffs to monitor (with labels)
    buffs = {
        {id = 12292, label = "Bloodrage"},
        {id = 18499, label = "Berserker Rage"},
        {id = 1719,  label = "Recklessness"},
        {id = 12809, label = "Last Stand"},
        {id = 2565,  label = "Shield Block"},          -- Shield Block charges
        {id = 23920, label = "Spell Reflection"},      -- Spell Reflect
        {id = 12975, label = "Shield Wall"},           -- Shield Wall
        {id = 2687,  label = "Bloodrage"},             -- Lower rank
        {id = 71,    label = "Defensive Stance"},      -- Stance indicator
        {id = 29131, label = "Commanding Shout"},      -- If maintained
        {id = 25289, label = "Battle Shout"},          -- If used
    },
    
    -- Debuffs to track on target
    debuffs = {
        {id = 25225, label = "Sunder", target = true, show_stacks = true},
        {id = 25264, label = "Thunder Clap", target = true},
        {id = 25203, label = "Demoralizing Shout", target = true},
        {id = 12873, label = "Concussion Blow", target = true},  -- Stun
        {id = 11580, label = "Rend", target = true},
    },
    
    -- Custom dashboard lines (label, value function)
    custom_lines = {
        -- Current stance
        function(ctx)
            local me = core.object_manager.get_local_player()
            if not me or not me:is_valid() then return "Stance", "Unknown" end
            
            local spells = require("libraries/spells")
            if spells.BUFF_DEFENSIVE_STANCE then
                for _, id in ipairs(spells.BUFF_DEFENSIVE_STANCE) do
                    if me:has_buff(id) then return "Stance", "Defensive" end
                end
            end
            if spells.BUFF_BATTLE_STANCE then
                for _, id in ipairs(spells.BUFF_BATTLE_STANCE) do
                    if me:has_buff(id) then return "Stance", "Battle" end
                end
            end
            if spells.BUFF_BERSERKER_STANCE then
                for _, id in ipairs(spells.BUFF_BERSERKER_STANCE) do
                    if me:has_buff(id) then return "Stance", "Berserker" end
                end
            end
            return "Stance", "None"
        end,
        
        -- Shield Block status
        function(ctx)
            local me = core.object_manager.get_local_player()
            if not me or not me:is_valid() then return "Shield Block", "--" end
            
            local spells = require("libraries/spells")
            local has_shield_block = false
            local remaining = 0
            if spells.BUFF_SHIELD_BLOCK then
                for _, id in ipairs(spells.BUFF_SHIELD_BLOCK) do
                    local buff = me:get_buff(id)
                    if buff then
                        has_shield_block = true
                        remaining = buff.remaining or 0
                        break
                    end
                end
            end
            
            if has_shield_block then
                return "Shield Block", string.format("%.1fs", remaining)
            else
                local cd = 0
                if core.spell_book and core.spell_book.get_spell_cooldown then
                    cd = core.spell_book.get_spell_cooldown(2565)
                end
                if cd > 0 then
                    return "Shield Block", string.format("CD %.1fs", cd)
                else
                    return "Shield Block", "READY"
                end
            end
        end,
        
        -- Sunder Armor stacks on target
        function(ctx)
            local target = core.object_manager.get_target()
            if not target or not target:is_valid() then return "Sunder", "--" end
            
            local spells = require("libraries/spells")
            local stacks = 0
            if spells.DEBUFF_SUNDER_ARMOR then
                for _, id in ipairs(spells.DEBUFF_SUNDER_ARMOR) do
                    local debuff = target:get_debuff(id)
                    if debuff then
                        stacks = debuff.stacks or 1
                        break
                    end
                end
            end
            
            if stacks > 0 then
                return "Sunder", tostring(stacks) .. "/5"
            else
                return "Sunder", "0/5"
            end
        end,
        
        -- Revenge availability (must be active)
        function(ctx)
            local cd = 0
            if core.spell_book and core.spell_book.get_spell_cooldown then
                cd = core.spell_book.get_spell_cooldown(6572)
            end
            if cd > 0 then
                return "Revenge", string.format("%.1fs", cd)
            else
                return "Revenge", "READY"
            end
        end,
        
        -- Rage level indicator
        function(ctx)
            local me = core.object_manager.get_local_player()
            if not me or not me:is_valid() then return "Rage", "0" end
            
            local rage = me:get_power() or 0
            local max_rage = 100
            return "Rage", tostring(rage) .. "/" .. tostring(max_rage)
        end,
        
        -- Defensive cooldowns status
        function(ctx)
            local last_stand_cd = 0
            local shield_wall_cd = 0
            
            if core.spell_book and core.spell_book.get_spell_cooldown then
                last_stand_cd = core.spell_book.get_spell_cooldown(12975)
                shield_wall_cd = core.spell_book.get_spell_cooldown(871)
            end
            
            local status = ""
            if last_stand_cd > 0 then
                status = status .. "LS:" .. string.format("%.0f", last_stand_cd) .. "s "
            else
                status = status .. "LS:READY "
            end
            
            if shield_wall_cd > 0 then
                status = status .. "SW:" .. string.format("%.0f", shield_wall_cd) .. "s"
            else
                status = status .. "SW:READY"
            end
            
            return "Defensives", status
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
