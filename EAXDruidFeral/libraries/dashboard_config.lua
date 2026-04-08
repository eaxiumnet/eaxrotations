--[[
    Dashboard Configuration for EAXDruidFeral
     combat dashboard with resource bars, cooldown tracking, buff/debuff monitoring
--]]

local utils = require("libraries/utils")

return {
    class_name = "Druid Feral",
    
    -- Dynamic resource type based on current form
    resource_type = "energy",  -- Will be overridden dynamically: energy (cat), rage (bear), mana (caster)
    secondary_resource_type = "mana",  -- Always track mana as secondary when shifted
    
    -- Cooldowns to track (spell IDs)
    cooldowns = {
        5217,    -- Tiger's Fury
        22812,   -- Barkskin
        29166,   -- Innervate
        1850,    -- Dash
        22842,   -- Frenzied Regeneration
        16979,   -- Feral Charge
        5209,    -- Challenging Roar
        6795,    -- Growl
        8998,    -- Cower
        27005,   -- Pounce (max rank)
    },
    
    -- Buffs to monitor (with labels)
    buffs = {
        {id = 16864, label = "Clearcasting"},     -- Omen of Clarity
        {id = 5217,  label = "Tiger's Fury"},
        {id = 1850,  label = "Dash"},
        {id = 22812, label = "Barkskin"},
        {id = 29166, label = "Innervate"},
        {id = 768,   label = "Cat Form"},
        {id = 5487,  label = "Bear Form"},
        {id = 9634,  label = "Dire Bear Form"},
        {id = 22842, label = "Frenzied Regen"},
        {id = 5229,  label = "Enrage"},
        {id = 26992, label = "Thorns"},      -- Thorns max rank (TBC)
        {id = 26991, label = "Mark of the Wild"}, -- MOTW max rank (TBC)
        {id = 9913,  label = "Prowl"},       -- Prowl max rank (TBC)
        {id = 9846,  label = "Tiger's Fury (Max)"}, -- Max rank Tiger's Fury
        {id = 9850,  label = "Dash (Max)"},  -- Max rank Dash
    },
    
    -- Debuffs to track on target (TBC max ranks)
    debuffs = {
        {id = 27008, label = "Rip", target = true, show_stacks = false},        -- Rip max rank (TBC)
        {id = 27003, label = "Rake", target = true, show_stacks = false},       -- Rake max rank (TBC)
        {id = 33987, label = "Mangle", target = true, show_stacks = false},     -- Mangle (Cat) max rank
        {id = 33986, label = "Mangle (Bear)", target = true, show_stacks = false}, -- Mangle (Bear) max rank
        {id = 26993, label = "Faerie Fire", target = true, show_stacks = false}, -- Faerie Fire (Feral) max rank
        {id = 27007, label = "Demoralizing Roar", target = true, show_stacks = false}, -- Demo Roar max rank
        {id = 33745, label = "Lacerate", target = true, show_stacks = true},     -- Show stacks for Lacerate
    },
    
    -- Custom dashboard lines (label, value function)
    custom_lines = {
        -- Current form display
        function(ctx)
            local form = utils.get_form_name and utils.get_form_name() or "Unknown"
            return "Form", form
        end,
        
        -- Combo Points (when in cat form)
        function(ctx)
            local me = core.object_manager.get_local_player()
            if not me or not me:is_valid() then return "Combo Points", "0" end
            
            -- Only show combo points in cat form
            local spells = require("libraries/spells")
            if not utils.has_buff(me, spells.BUFF_CAT_FORM) then
                return "Combo Points", "-"
            end
            
            local cp = utils.get_combo_points and utils.get_combo_points(me) or 0
            return "Combo Points", tostring(cp) .. "/5"
        end,
        
        -- Energy tick status (from energy_tick module)
        function(ctx)
            local energy_tick = require("libraries/energy_tick")
            if not energy_tick then return "Tick", "N/A" end
            
            local time_until = energy_tick.time_until_next_tick and energy_tick.time_until_next_tick() or 0
            if time_until <= 0.5 then
                return "Tick", "SOON"
            else
                return "Tick", string.format("%.1fs", time_until)
            end
        end,
        
        -- Wolfshead Helm status
        function(ctx)
            local energy_tick = require("libraries/energy_tick")
            if not energy_tick then return "Wolfshead", "N/A" end
            
            local has_wolfshead = energy_tick.is_wolfshead_equipped and energy_tick.is_wolfshead_equipped() or false
            return "Wolfshead", has_wolfshead and "EQUIPPED" or "NONE"
        end,
    },

    -- Dashboard feature toggles
    show_timer_bars = true,
    show_action_history = true,
    show_energy_tick = true,
    show_combo_points = true,
    show_threat_bar = false,
    enable_smart_collapse = true,
}
