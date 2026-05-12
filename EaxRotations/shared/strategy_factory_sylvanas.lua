-- ============================================================================
-- Shared Helper: Strategy Factory
-- ============================================================================
-- Readability notes:
--   What: factory functions for creating standard strategy tables with less boilerplate.
--   When: defining new playstyle strategies or middleware strategies.
--   Why: reduces copy-paste errors and ensures consistent structure.
--   Safety: pure functions, returns tables ready for registration.

local M = {}
local _G = _G
local NS = _G.EaxRotations

local EMPTY = {}

-- Helper: safely get setting from context
local function get_setting(context, key, default)
    if not context or not context.settings then return default end
    local value = context.settings[key]
    if value == nil then return default end
    return value
end

-- Create a named strategy wrapper
-- Adds .name field for debugging/logging
function M.named(name, strategy)
    if type(strategy) ~= "table" then return nil end
    strategy.name = name
    return strategy
end

-- Create a basic combat strategy
-- spell: spell_id or spell object
-- opts: {
--   setting_key = "use_spell",      -- setting to check (optional)
--   stance = "berserker",            -- required stance (optional)
--   requires_target = true,           -- needs valid target
--   target_pct = {min = 0, max = 100},-- target HP % range
--   player_pct = {min = 0, max = 100},-- player HP % range
--   extra_match = function(context)  -- additional conditions (optional)
--     return boolean
--   end,
--   target = "target" | "self" | "focus", -- target type
--   label = "[CLASS] SpellName",      -- debug label
-- }
function M.create_combat_strategy(spell, opts)
    opts = opts or EMPTY
    
    -- Capture values in closure
    local _spell = spell
    local _setting_key = opts.setting_key
    local _stance = opts.stance
    local _requires_target = opts.requires_target ~= false -- default true
    local _target_pct = opts.target_pct
    local _player_pct = opts.player_pct
    local _extra_match = opts.extra_match
    local _target_type = opts.target or "target"
    local _label = opts.label or "[Strategy]"
    
    local strategy = {
        spell = _spell,
        label = _label,
        
        -- Dispatcher calls: matches(context, state)
        matches = function(context, state)
            -- Setting check
            if _setting_key then
                local enabled = get_setting(context, _setting_key, true)
                if not enabled then return false end
            end
            
            -- Stance check
            if _stance then
                if not context or context.stance ~= _stance then
                    return false
                end
            end
            
            -- Target requirement
            if _requires_target then
                local target = context and context.target
                if not target then return false end
                
                -- Target HP range
                if _target_pct then
                    local hp = context.target_hp or 100
                    if _target_pct.min and hp < _target_pct.min then return false end
                    if _target_pct.max and hp > _target_pct.max then return false end
                end
            end
            
            -- Player HP range
            if _player_pct then
                local hp = context.player_hp or 100
                if _player_pct.min and hp < _player_pct.min then return false end
                if _player_pct.max and hp > _player_pct.max then return false end
            end
            
            -- Extra conditions
            if _extra_match then
                local ok, result = pcall(_extra_match, context)
                if not ok or not result then return false end
            end
            
            return true
        end,
        
        -- Dispatcher calls: execute(context, state)
        execute = function(context, state)
            if not NS then return false end
            
            local target = context and context.target
            if _target_type == "self" then
                target = context and context.me
            elseif _target_type == "focus" then
                target = NS.GetFocus and NS.GetFocus() or target
            end
            
            if not target then return false end
            
            -- Use NS.try_cast or NS.action_execute
            if NS.try_cast then
                return NS.try_cast(_spell, target, _label)
            elseif NS.action_execute then
                return NS.action_execute(context, {
                    spell = _spell,
                    target = target,
                    label = _label,
                })
            end
            
            return false
        end,
    }
    
    return strategy
end

-- Create a self-buff strategy (simplified combat strategy)
-- spell: spell_id or spell object
-- opts: {
--   setting_key = "use_buff",
--   buff_id = spell_id,              -- buff to check for
--   buff_name = "Buff Name",         -- alternative to buff_id
--   refresh_pct = 30,                -- refresh when buff has X seconds left
--   player_pct = {min = 0, max = 100}, -- HP restriction
--   label = "[CLASS] BuffName",
-- }
function M.create_self_buff_strategy(spell, opts)
    opts = opts or EMPTY
    
    -- Capture values in closure
    local _spell = spell
    local _setting_key = opts.setting_key
    local _buff_id = opts.buff_id
    local _buff_name = opts.buff_name
    local _refresh_pct = opts.refresh_pct or 0
    local _player_pct = opts.player_pct
    local _label = opts.label or "[SelfBuff]"
    
    local strategy = {
        spell = _spell,
        label = _label,
        
        -- Dispatcher calls: matches(context, state)
        matches = function(context, state)
            -- Setting check
            if _setting_key then
                local enabled = get_setting(context, _setting_key, true)
                if not enabled then return false end
            end
            
            -- Player HP check
            if _player_pct then
                local hp = context and context.player_hp or 100
                if _player_pct.min and hp < _player_pct.min then return false end
                if _player_pct.max and hp > _player_pct.max then return false end
            end
            
            -- Check if buff already present
            if _buff_id and NS and NS.has_buff then
                local me = context and context.me
                if me and NS.has_buff(me, _buff_id) then
                    return false  -- Already have buff
                end
            end
            
            return true
        end,
        
        -- Dispatcher calls: execute(context, state)
        execute = function(context, state)
            if not NS then return false end
            local me = context and context.me
            if not me then return false end
            
            if NS.try_cast then
                return NS.try_cast(_spell, me, _label)
            end
            return false
        end,
    }
    
    return strategy
end

-- Create a debuff strategy
-- spell: spell_id or spell object (the debuff spell)
-- opts: {
--   setting_key = "use_debuff",
--   debuff_id = spell_id,            -- debuff to check
--   refresh_pct = 30,                -- refresh when X% duration remains
--   target_required = true,
--   single_target_only = false,      -- don't refresh on multiple targets
--   label = "[CLASS] DebuffName",
-- }
function M.create_debuff_strategy(spell, opts)
    opts = opts or EMPTY
    
    -- Capture values in closure
    local _spell = spell
    local _setting_key = opts.setting_key
    local _debuff_id = opts.debuff_id or spell
    local _refresh_pct = opts.refresh_pct or 30
    local _target_required = opts.target_required ~= false
    local _single_target_only = opts.single_target_only or false
    local _label = opts.label or "[Debuff]"
    
    local strategy = {
        spell = _spell,
        label = _label,
        
        -- Dispatcher calls: matches(context, state)
        matches = function(context, state)
            -- Setting check
            if _setting_key then
                local enabled = get_setting(context, _setting_key, true)
                if not enabled then return false end
            end
            
            -- Target requirement
            if _target_required then
                if not context or not context.target then return false end
            end
            
            -- Check existing debuff
            if _debuff_id and context and context.target and NS and NS.has_debuff then
                if NS.has_debuff(context.target, _debuff_id) then
                    -- Check refresh threshold
                    if NS.debuff_remains then
                        local remains = NS.debuff_remains(context.target, _debuff_id) or 0
                        local threshold = (context.target_ttd and context.target_ttd > 0) and math.min(_refresh_pct, context.target_ttd * 0.3) or _refresh_pct
                        if remains > threshold then
                            return false  -- Don't refresh yet
                        end
                    else
                        return false  -- Can't check remains, assume present
                    end
                end
            end
            
            return true
        end,
        
        -- Dispatcher calls: execute(context, state)
        execute = function(context, state)
            if not NS or not context then return false end
            local target = context.target
            if not target then return false end
            
            if NS.try_cast then
                return NS.try_cast(_spell, target, _label)
            end
            return false
        end,
    }
    
    return strategy
end

-- Create a cooldown strategy
-- spell: spell_id or spell object (cooldown spell)
-- opts: {
--   setting_key = "use_cooldown",
--   phase = "opener" | "execute" | "burst" | "any", -- when to use
--   min_target_hp_pct = 0,
--   max_target_hp_pct = 100,
--   min_player_hp_pct = 0,
--   requires_bloodlust = false,      -- wait for bloodlust
--   requires_trinket = false,        -- sync with trinket
--   label = "[CLASS] Cooldown",
-- }
function M.create_cooldown_strategy(spell, opts)
    opts = opts or EMPTY
    
    -- Capture values in closure
    local _spell = spell
    local _setting_key = opts.setting_key
    local _phase = opts.phase or "any"
    local _min_target_hp_pct = opts.min_target_hp_pct or 0
    local _max_target_hp_pct = opts.max_target_hp_pct or 100
    local _min_player_hp_pct = opts.min_player_hp_pct or 0
    local _requires_bloodlust = opts.requires_bloodlust or false
    local _requires_trinket = opts.requires_trinket or false
    local _label = opts.label or "[Cooldown]"
    
    local strategy = {
        spell = _spell,
        label = _label,
        
        -- Dispatcher calls: matches(context, state)
        matches = function(context, state)
            -- Setting check
            if _setting_key then
                local enabled = get_setting(context, _setting_key, true)
                if not enabled then return false end
            end
            
            -- Target HP check
            if context and context.target_hp then
                if context.target_hp < _min_target_hp_pct then return false end
                if context.target_hp > _max_target_hp_pct then return false end
            end
            
            -- Player HP check
            if context and context.player_hp then
                if context.player_hp < _min_player_hp_pct then return false end
            end
            
            -- Phase checks
            if _phase ~= "any" then
                if _phase == "opener" and context and context.combat_time > 10 then
                    return false
                end
                if _phase == "execute" and context and (not context.execute_phase or context.target_hp > 25) then
                    return false
                end
                if _phase == "burst" and context and not context.should_burst then
                    return false
                end
            end
            
            -- Bloodlust check
            if _requires_bloodlust then
                if not NS or not NS.has_buff then return false end
                local me = context and context.me
                if not me or not NS.has_buff(me, 2825) then  -- Bloodlust/Heroism
                    return false
                end
            end
            
            -- Trinket sync check
            if _requires_trinket then
                if NS and NS.TrinketManager and NS.TrinketManager.are_trinkets_ready then
                    if not NS.TrinketManager.are_trinkets_ready(context) then
                        return false
                    end
                end
            end
            
            return true
        end,
        
        -- Dispatcher calls: execute(context, state)
        execute = function(context, state)
            if not NS or not context then return false end
            local target = context.target or context.me
            if not target then return false end
            
            if NS.try_cast then
                return NS.try_cast(_spell, target, _label)
            end
            return false
        end,
    }
    
    return strategy
end

-- Factory for creating a complete strategy set from a spec table
-- spec: {
--   name = "Combat",
--   combat_spells = {{spell = id, opts = {...}}, ...},
--   self_buffs = {{spell = id, opts = {...}}, ...},
--   debuffs = {{spell = id, opts = {...}}, ...},
--   cooldowns = {{spell = id, opts = {...}}, ...},
-- }
function M.create_strategy_set(spec)
    if type(spec) ~= "table" then return nil end
    
    local strategies = {}
    
    -- Combat strategies
    if spec.combat_spells then
        for _, entry in ipairs(spec.combat_spells) do
            local strategy = M.create_combat_strategy(entry.spell, entry.opts)
            if strategy then
                table.insert(strategies, M.named(entry.opts and entry.opts.name or "Combat", strategy))
            end
        end
    end
    
    -- Self buffs
    if spec.self_buffs then
        for _, entry in ipairs(spec.self_buffs) do
            local strategy = M.create_self_buff_strategy(entry.spell, entry.opts)
            if strategy then
                table.insert(strategies, M.named(entry.opts and entry.opts.name or "SelfBuff", strategy))
            end
        end
    end
    
    -- Debuffs
    if spec.debuffs then
        for _, entry in ipairs(spec.debuffs) do
            local strategy = M.create_debuff_strategy(entry.spell, entry.opts)
            if strategy then
                table.insert(strategies, M.named(entry.opts and entry.opts.name or "Debuff", strategy))
            end
        end
    end
    
    -- Cooldowns
    if spec.cooldowns then
        for _, entry in ipairs(spec.cooldowns) do
            local strategy = M.create_cooldown_strategy(entry.spell, entry.opts)
            if strategy then
                table.insert(strategies, M.named(entry.opts and entry.opts.name or "Cooldown", strategy))
            end
        end
    end
    
    return strategies
end

if NS then
    NS.StrategyFactory = M
end

return M
