--[[
    Dashboard Configuration for EAXHunterBM
     combat dashboard with resource bars, cooldown tracking, buff/debuff monitoring
--]]

local utils = require("libraries/utils")

return {
    class_name = "Hunter BM",
    class_id = 3,  -- Hunter class ID for player validation
    resource_type = "mana",
    secondary_resource_type = nil,

    -- Cooldowns to track (spell IDs)
    cooldowns = {
        19574,   -- Bestial Wrath
        34026,   -- Kill Command
        19577,   -- Intimidation
        3045,    -- Rapid Fire
        34477,   -- Misdirection
        19263,   -- Deterrence
        5384,    -- Feign Death
        781,     -- Disengage
    },

    -- Buffs to monitor (with labels)
    buffs = {
        {id = 13165, label = "Aspect of the Hawk"},
        {id = 27045, label = "Aspect of the Viper"},
        {id = 14320, label = "Aspect of the Monkey"},
        {id = 20178, label = "Aspect of the Pack"},
        {id = 3045,  label = "Rapid Fire"},
        {id = 19574, label = "Bestial Wrath"},
        {id = 34471, label = "The Beast Within"},
        {id = 19263, label = "Deterrence"},
        {id = 3044,  label = "Scare Beast"},
        {id = 14294, label = "Volley"},
        {id = 26297, label = "Berserking"},
        {id = 33697, label = "Blood Fury"},
        {id = 34696, label = "Frenzy"},
        {id = 19615, label = "Frenzy Effect"},
    },

    -- Debuffs to track on target
    debuffs = {
        {id = 27018, label = "Serpent Sting", target = true, show_stacks = false},
        {id = 27016, label = "Scorpid Sting", target = true, show_stacks = false},
        {id = 27017, label = "Viper Sting", target = true, show_stacks = false},
        {id = 27019, label = "Wyvern Sting", target = true, show_stacks = false},
        {id = 1130,  label = "Hunter's Mark", target = true, show_stacks = false},
        {id = 2974,  label = "Wing Clip", target = true, show_stacks = false},
        {id = 5116,  label = "Concussive", target = true, show_stacks = false},
    },

    -- Custom dashboard lines (label, value function)
    custom_lines = {
        -- Pet status
        function(ctx)
            local ok, me = pcall(function() return core.object_manager.get_local_player() end)
            if not ok or not me or not me:is_valid() then return "Pet", "N/A" end

            local ok, pet = pcall(function() return me:get_pet() end)
            if not ok or not pet or not pet:is_valid() then
                return "Pet", "NONE"
            end

            if pet:is_dead() then
                return "Pet", "DEAD"
            end

            local ok_hp, hp = pcall(function() return pet:get_health() end)
local ok_max, max_hp = pcall(function() return pet:get_max_health() end)
local pet_hp = (ok_hp and ok_max and hp and max_hp and max_hp > 0) and ((hp / max_hp) * 100) or 0
            return "Pet HP", string.format("%.0f%%", pet_hp)
        end,

        -- Current Aspect
        function(ctx)
            local spells = require("libraries/spells")
            local ok, me = pcall(function() return core.object_manager.get_local_player() end)
            if not ok or not me or not me:is_valid() then return "Aspect", "None" end

            if utils.has_buff(me, spells.BUFF_ASPECT_OF_THE_HAWK) then
                return "Aspect", "Hawk"
            elseif utils.has_buff(me, spells.BUFF_ASPECT_OF_THE_VIPER) then
                return "Aspect", "Viper"
            elseif utils.has_buff(me, spells.BUFF_ASPECT_OF_THE_MONKEY) then
                return "Aspect", "Monkey"
            elseif utils.has_buff(me, spells.BUFF_ASPECT_OF_THE_CHEETAH) then
                return "Aspect", "Cheetah"
            elseif utils.has_buff(me, spells.BUFF_ASPECT_OF_THE_PACK) then
                return "Aspect", "Pack"
            else
                return "Aspect", "None"
            end
        end,

        -- Mana status
        function(ctx)
            local ok, me = pcall(function() return core.object_manager.get_local_player() end)
            if not ok or not me or not me:is_valid() then return "Mana", "N/A" end

            local ok_mana, mana = pcall(function() return me:get_power(0) end)
            local ok_max_mana, max_mana = pcall(function() return me:get_max_power(0) end)

            if ok_mana and ok_max_mana and max_mana > 0 then
                local mana_pct = (mana / max_mana) * 100
                return "Mana", string.format("%.0f%%", mana_pct)
            end

            return "Resource", "N/A"
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
