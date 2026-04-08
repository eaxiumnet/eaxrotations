--[[
    Dashboard Configuration for EAXDruidBalance
     combat dashboard with resource bars, cooldown tracking, buff/debuff monitoring
--]]

local utils = require("libraries/utils")

return {
    class_name = "Druid Balance",
    class_id = 11,  -- Druid class ID for player validation
    resource_type = "mana",
    
    -- Cooldowns to track (spell IDs)
    cooldowns = {
        33831,   -- Force of Nature
        22812,   -- Barkskin
        29166,   -- Innervate
        16689,   -- Nature's Grasp
    },
    
    -- Buffs to monitor (with labels)
    buffs = {
        {id = 24880, label = "Moonkin Form"},
        {id = 22812, label = "Barkskin"},
        {id = 29166, label = "Innervate"},
        {id = 33831, label = "Force of Nature"},
        {id = 16870, label = "Clearcasting"},      -- Omen of Clarity
        {id = 16886, label = "Nature's Grace"},    -- Cast haste
        {id = 26992, label = "Thorns"},
        {id = 26990, label = "Mark of the Wild"},
    },
    
    -- Debuffs to track on target
    debuffs = {
        {id = 26988, label = "Moonfire", target = true},
        {id = 26989, label = "Insect Swarm", target = true},
        {id = 26993, label = "Faerie Fire", target = true},
    },
    
    -- Custom dashboard lines (label, value function)
    custom_lines = {
        function(ctx)
            local mana_pct = 0
            if ctx.me and ctx.me.get_power and ctx.me.get_max_power then
                local ok_mana, mana = pcall(function() return ctx.me:get_power(0) end)
                local ok_max, max_mana = pcall(function() return ctx.me:get_max_power(0) end)
                if ok_mana and ok_max and max_mana > 0 then
                    mana_pct = math.floor((mana / max_mana) * 100)
                end
            end
            return "Mana %", tostring(mana_pct) .. "%"
        end,
        function(ctx)
            -- Check for Clearcasting (Omen of Clarity)
            local has_clearcasting = false
            if ctx.me and ctx.me.has_aura then
                local ok, result = pcall(function() return ctx.me:has_aura(16870) end)
                if ok then has_clearcasting = result end
            end
            return "Clearcasting", has_clearcasting and "UP" or "DOWN"
        end,
        function(ctx)
            -- Check for Nature's Grace
            local has_ng = false
            if ctx.me and ctx.me.has_aura then
                local ok, result = pcall(function() return ctx.me:has_aura(16886) end)
                if ok then has_ng = result end
            end
            return "Nature's Grace", has_ng and "UP" or "DOWN"
        end,
        function(ctx)
            -- Moonkin Form status
            local in_moonkin = false
            if ctx.me and ctx.me.has_aura then
                local ok, result = pcall(function() return ctx.me:has_aura(24880) end)
                if ok then in_moonkin = result end
            end
            return "Form", in_moonkin and "Moonkin" or "Caster"
        end,
        
        -- MOTW status
        function(ctx)
            local has_motw = false
            if ctx.me and ctx.me.has_aura then
                local ok, result = pcall(function() return ctx.me:has_aura(26990) end)
                if ok then has_motw = result end
            end
            return "MOTW", has_motw and "UP" or "DOWN"
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
