--[[
    Dashboard Configuration for EAXDruidResto
     combat dashboard with mana tracking, cooldowns, buff/debuff monitoring
    Healer-focused: mana is primary resource, HoT tracking, Rebirth cooldown
--]]

local utils = require("libraries/utils")
local spells = require("libraries/spells")

-- Buff IDs for tracking
local BUFF_INNERVATE = 29166
local BUFF_REJUVENATION = 26981
local BUFF_REGROWTH = 26980
local BUFF_LIFEBLOOM = 33763

-- Get active HoT count on party/raid
local function get_active_hot_count()
    local me = core.object_manager.get_local_player()
    if not me then return 0 end
    
    local hot_count = 0
    local buff_manager = require("common/modules/buff_manager")
    
    for _, o in ipairs(core.object_manager.get_all_objects()) do
        if o and o:is_valid() and o:is_unit() and not o:is_dead() then
            if o:is_party_member() or utils.same_unit(o, me) then
                -- Check for Rejuvenation
                local rejuv = buff_manager:get_buff_data(o, spells.BUFF_REJUVENATION)
                if rejuv and rejuv.is_active then
                    hot_count = hot_count + 1
                end
                -- Check for Regrowth
                local regrowth = buff_manager:get_buff_data(o, spells.BUFF_REGROWTH)
                if regrowth and regrowth.is_active then
                    hot_count = hot_count + 1
                end
                -- Check for Lifebloom
                local lifebloom = buff_manager:get_buff_data(o, spells.BUFF_LIFEBLOOM)
                if lifebloom and lifebloom.is_active then
                    hot_count = hot_count + 1
                end
            end
        end
    end
    
    return hot_count
end

-- Get Rebirth cooldown
local function get_rebirth_cooldown()
    local rebirth_id = utils.resolve_spell_id(spells.REBIRTH)
    if not rebirth_id then return "N/A" end
    
    if core.spell_book and core.spell_book.get_spell_cooldown then
        local cd = core.spell_book.get_spell_cooldown(rebirth_id)
        if cd > 0 then
            return string.format("%.0fs", cd)
        else
            return "READY"
        end
    end
    return "N/A"
end

-- Check if has Innervate buff
local function has_innervate_buff()
    local me = core.object_manager.get_local_player()
    if not me or not me:is_valid() then return false end
    
    local buff_manager = require("common/modules/buff_manager")
    local innervate = buff_manager:get_buff_data(me, { BUFF_INNERVATE })
    return innervate and innervate.is_active
end

-- Check Tree of Life form
local function is_tree_of_life()
    local me = core.object_manager.get_local_player()
    if not me or not me:is_valid() then return false end
    
    local buff_manager = require("common/modules/buff_manager")
    local tree = buff_manager:get_buff_data(me, spells.BUFF_TREE_OF_LIFE_FORM)
    return tree and tree.is_active
end

return {
    class_name = "Druid Restoration",
    resource_type = "mana",  -- Healer priority: mana
    
    -- Cooldowns to track (spell IDs)
    cooldowns = {
        29166,   -- Innervate
        22812,   -- Barkskin
        17116,   -- Nature's Swiftness
        1850,    -- Dash (emergency)
    },
    
    -- Buffs to monitor (with labels)
    buffs = {
        {id = 29166, label = "Innervate"},
        {id = 22812, label = "Barkskin"},
        {id = 17116, label = "Nature's Swiftness"},
        {id = 16870, label = "Clearcasting"},
        {id = 26992, label = "Thorns"},
        {id = 26990, label = "Mark of the Wild"},
        {id = 26980, label = "Rejuvenation"},       -- Self rejuv
        {id = 26982, label = "Regrowth"},          -- Self regrowth
    },
    
    -- Debuffs to track on target
    debuffs = {
        {id = 26993, label = "Faerie Fire", target = true},
    },
    
    -- Custom dashboard lines (label, value function)
    custom_lines = {
        -- Mana percentage (primary healer resource)
        function(ctx)
            local me = core.object_manager.get_local_player()
            local mana_pct = 0
            if me and me.get_power and me.get_max_power then
                local ok_mana, mana = pcall(function() return me:get_power(0) end)
                local ok_max, max_mana = pcall(function() return me:get_max_power(0) end)
                if ok_mana and ok_max and max_mana > 0 then
                    mana_pct = (mana / max_mana) * 100
                end
            end
            return "Mana", string.format("%.0f%%", mana_pct)
        end,
        
        -- Active HoT count
        function(ctx)
            local count = get_active_hot_count()
            return "Active HoTs", tostring(count)
        end,
        
        -- Rebirth cooldown
        function(ctx)
            local cd = get_rebirth_cooldown()
            return "Rebirth", cd
        end,
        
        -- Innervate status
        function(ctx)
            local has_innervate = has_innervate_buff()
            return "Innervate", has_innervate and "ACTIVE" or "--"
        end,
        
        -- Tree of Life form status
        function(ctx)
            local is_tree = is_tree_of_life()
            return "Form", is_tree and "Tree of Life" or "Caster"
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
