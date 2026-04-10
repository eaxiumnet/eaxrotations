--[[
    Dashboard Configuration for EAXHunterMM
     combat dashboard with resource bars, cooldown tracking, buff/debuff monitoring
--]]

local utils = require("libraries/utils")

return {
    class_name = "Hunter Marksmanship",
    class_id = 3,  -- Hunter class ID for player validation

    -- Resource type
    resource_type = "mana",
    secondary_resource_type = nil,

    -- Cooldowns to track (spell IDs)
    cooldowns = {
        3045,    -- Rapid Fire
        34490,   -- Silencing Shot
        23989,   -- Readiness
        34026,   -- Kill Command
        34477,   -- Misdirection
        19263,   -- Deterrence
        5384,    -- Feign Death
    },

    -- Buffs to monitor (with labels)
    buffs = {
        {id = 13165, label = "Aspect of the Hawk"},
        {id = 27045, label = "Aspect of the Viper"},
        {id = 14320, label = "Aspect of the Monkey"},
        {id = 20178, label = "Aspect of the Pack"},
        {id = 3045,  label = "Rapid Fire"},
        {id = 19263, label = "Deterrence"},
        {id = 3044,  label = "Scare Beast"},
        {id = 14294, label = "Volley"},
        {id = 26297, label = "Berserking"},
        {id = 33697, label = "Blood Fury"},
        {id = 6150,  label = "Quick Shots"},
        {id = 19434, label = "Aimed Shot"},
        {id = 27020, label = "Scatter Shot"},
    },

    -- Debuffs to track on target
    debuffs = {
        {id = 27018, label = "Serpent Sting", target = true, show_stacks = false},
        {id = 27016, label = "Scorpid Sting", target = true, show_stacks = false},
        {id = 14288, label = "Hunter's Mark", target = true, show_stacks = false},
        {id = 2974,  label = "Wing Clip", target = true, show_stacks = false},
        {id = 5116,  label = "Concussive Shot", target = true, show_stacks = false},
        {id = 27021, label = "Silencing Shot", target = true, show_stacks = false},
    },

    -- Custom dashboard lines (label, value function)
    custom_lines = {
        -- Pet status
        function(ctx)
            local pet = utils.get_pet and utils.get_pet() or nil
            if not pet or not pet:is_valid() then
                return "Pet", "NONE"
            end
            local pet_hp = 0
            local ok, hp = pcall(function() return ((pet:get_health() / pet:get_max_health()) * 100) end)
            if ok then pet_hp = hp or 0 end
            return "Pet HP", string.format("%.0f%%", pet_hp)
        end,

        -- Current Aspect
        function(ctx)
            local ok, me = pcall(function() return core.object_manager.get_local_player() end)
            if not ok or not me or not me:is_valid() then return "Aspect", "Unknown" end

            local spells = require("libraries/spells")
            if utils.has_buff(me, spells.BUFF_ASPECT_OF_THE_HAWK) then
                return "Aspect", "Hawk"
            elseif utils.has_buff(me, spells.BUFF_ASPECT_OF_THE_VIPER) then
                return "Aspect", "Viper"
            elseif utils.has_buff(me, spells.BUFF_ASPECT_OF_THE_MONKEY) then
                return "Aspect", "Monkey"
            else
                return "Aspect", "None"
            end
        end,

        -- Trueshot Aura status
        function(ctx)
            local ok, me = pcall(function() return core.object_manager.get_local_player() end)
            if not ok or not me or not me:is_valid() then return "Trueshot", "-" end

            local spells = require("libraries/spells")
            if utils.has_buff(me, spells.BUFF_TRUESHOT_AURA) then
                return "Trueshot", "ACTIVE"
            else
                return "Trueshot", "INACTIVE"
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
