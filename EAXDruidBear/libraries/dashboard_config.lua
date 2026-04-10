--[[
    Dashboard Configuration for EAXDruidBear
     combat dashboard with rage tracking, cooldowns, buff/debuff monitoring
    Tank-focused: rage is primary resource, threat tracking, defensive cooldowns
--]]

local utils = require("libraries/utils")
local spells = require("libraries/spells")

-- Check if in bear form
local function is_in_bear_form()
    local ok, me = pcall(function() return core.object_manager.get_local_player() end)
    if not ok or not me or not me:is_valid() then return false end
    
    local buff_manager = require("common/modules/buff_manager")
    local bear = buff_manager:get_buff_data(me, spells.BUFF_BEAR_FORM)
    local dire_bear = buff_manager:get_buff_data(me, spells.BUFF_DIRE_BEAR_FORM)
    return (bear and bear.is_active) or (dire_bear and dire_bear.is_active)
end

-- Get rage percentage
local function get_rage_percent()
    local ok, me = pcall(function() return core.object_manager.get_local_player() end)
    if not ok or not me or not me:is_valid() then return 0 end
    
    if me.get_power and me.get_max_power then
        local ok_rage, rage = pcall(function() return me:get_power(1) end)
        local ok_max, max_rage = pcall(function() return me:get_max_power(1) end)
        if ok_rage and ok_max and max_rage > 0 then
            return (rage / max_rage) * 100
        end
    end
    return 0
end

-- Get Lacerate stack count on target
local function get_lacerate_stacks()
    local ok_target, target = pcall(function() if me and me.get_target then return me:get_target() end return nil end)
    if not ok_target then target = nil end
    if not target or not target:is_valid() then return 0 end
    
    local buff_manager = require("common/modules/buff_manager")
    local lacerate = buff_manager:get_debuff_data(target, spells.DEBUFF_LACERATE)
    if lacerate and lacerate.is_active then
        return lacerate.stacks or 1
    end
    return 0
end

return {
    class_name = "Druid Bear Tank",
    class_id = 11,  -- Druid class ID for player validation
    resource_type = "rage",  -- Tank uses rage
    secondary_resource_type = "mana",  -- Track mana when not shifted
    
    -- Cooldowns to track (spell IDs)
    cooldowns = {
        22812,   -- Barkskin
        22842,   -- Frenzied Regen
        16979,   -- Feral Charge
        5209,    -- Challenging Roar
        6795,    -- Growl
        29166,   -- Innervate
    },
    
    -- Buffs to monitor (with labels)
    buffs = {
        {id = 9634,   label = "Dire Bear Form"},
        {id = 5487,   label = "Bear Form"},
        {id = 22812,  label = "Barkskin"},
        {id = 22842,  label = "Frenzied Regeneration"},
        {id = 5229,   label = "Enrage"},
        {id = 29166,  label = "Innervate"},
        {id = 16870,  label = "Clearcasting"},
        {id = 26992,  label = "Thorns"},
        {id = 26990,  label = "Mark of the Wild"},
        {id = 16979,  label = "Feral Charge"},      -- Charge immunity
    },
    
    -- Debuffs to track on target
    debuffs = {
        {id = 33745, label = "Lacerate", target = true, show_stacks = true},
        {id = 26993, label = "Faerie Fire", target = true},
        {id = 27007, label = "Demoralizing Roar", target = true},
        {id = 33986, label = "Mangle", target = true},
    },
    
    -- Custom dashboard lines (label, value function)
    custom_lines = {
        -- Current form display
        function(ctx)
            local in_bear = is_in_bear_form()
            return "Form", in_bear and "Bear" or "Caster"
        end,
        
        -- Rage percentage
        function(ctx)
            local rage_pct = get_rage_percent()
            return "Rage", string.format("%.0f%%", rage_pct)
        end,
        
        -- Lacerate stacks on target
        function(ctx)
            local stacks = get_lacerate_stacks()
            return "Lacerate", tostring(stacks) .. "/5"
        end,
        
        -- Threat status (simplified)
        function(ctx)
            local ok_target, target = pcall(function() if me and me.get_target then return me:get_target() end return nil end)
    if not ok_target then target = nil end
            if not target or not target:is_valid() then
                return "Threat", "No Target"
            end
            
            -- Check if target is attacking us
            local target_of_target = nil
            if target.get_target then
                local ok, tot = pcall(function() return target:get_target() end)
                if ok then target_of_target = tot end
            end
            
            local ok, me = pcall(function() return core.object_manager.get_local_player() end)
            if target_of_target and me and utils.same_unit(target_of_target, me) then
                return "Threat", "TANKING"
            else
                return "Threat", "NOT TANKING"
            end
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
    show_threat_bar = true,
    enable_smart_collapse = true,
}
