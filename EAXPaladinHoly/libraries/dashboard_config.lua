--[[
    Dashboard Configuration for EAXPaladinHoly
     combat dashboard with resource bars, cooldown tracking, buff/debuff monitoring
--]]

local utils = require("libraries/utils")

return {
    class_name = "Paladin Holy",
    class_id = 2,  -- Paladin class ID for player validation
    resource_type = "mana",
    
    -- Cooldowns to track (spell IDs)
    cooldowns = {
        20473,   -- Holy Shock
        31842,   -- Divine Favor
        31821,   -- Divine Illumination
        31884,   -- Avenging Wrath
        642,     -- Divine Shield
        27182,   -- Divine Protection (max rank)
        633,     -- Lay on Hands
    },
    
    -- Buffs to monitor (with labels)
    buffs = {
        {id = 31842, label = "Divine Favor"},
        {id = 31821, label = "Divine Illumination"},
        {id = 31884, label = "Avenging Wrath"},
        {id = 642,   label = "Divine Shield"},
        {id = 27182, label = "Divine Protection"},
        {id = 27168, label = "Seal of Wisdom"},
        {id = 27167, label = "Seal of Light"},
        {id = 27152, label = "Concentration Aura"},
        {id = 27150, label = "Devotion Aura"},
        {id = 27168, label = "Blessing of Kings"},
        {id = 27169, label = "Blessing of Sanctuary"},
        {id = 27179, label = "Blessing of Freedom"},
        {id = 27180, label = "Blessing of Protection"},
        {id = 27181, label = "Blessing of Sacrifice"},
        {id = 1022,  label = "Hand of Protection"},
    },
    
    -- Debuffs to track on target
    debuffs = {
        {id = 25771, label = "Forbearance", target = false},
        {id = 27158, label = "Judgement of Wisdom", target = true},
        {id = 27159, label = "Judgement of Light", target = true},
        {id = 27160, label = "Judgement of Justice", target = true},
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
            -- Check for Divine Favor buff
            local has_divine_favor = false
            if ctx.me and ctx.me.has_aura then
                local ok, result = pcall(function() return ctx.me:has_aura(31842) end)
                if ok then has_divine_favor = result end
            end
            return "Divine Favor", has_divine_favor and "UP" or "DOWN"
        end,
        function(ctx)
            -- Check for Avenging Wrath
            local has_wings = false
            if ctx.me and ctx.me.has_aura then
                local ok, result = pcall(function() return ctx.me:has_aura(31884) end)
                if ok then has_wings = result end
            end
            return "Avenging Wrath", has_wings and "UP" or "DOWN"
        end,
        function(ctx)
            -- Check active seal
            local seal_name = "None"
            if ctx.me and ctx.me.has_aura then
                local ok_wisdom, has_wisdom = pcall(function() return ctx.me:has_aura(27168) end)
                local ok_light, has_light = pcall(function() return ctx.me:has_aura(27167) end)
                if ok_wisdom and has_wisdom then seal_name = "Wisdom"
                elseif ok_light and has_light then seal_name = "Light" end
            end
            return "Seal", seal_name
        end,
        function(ctx)
            -- Check Forbearance (prevents bubble/LoH)
            local has_forbearance = false
            if ctx.me and ctx.me.has_aura then
                local ok, result = pcall(function() return ctx.me:has_aura(25771) end)
                if ok then has_forbearance = result end
            end
            return "Forbearance", has_forbearance and "UP" or "DOWN"
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
