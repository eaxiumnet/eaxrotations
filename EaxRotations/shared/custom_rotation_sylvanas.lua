-- ============================================================================
-- What: Shared helper for custom rotation profiles and condition execution
-- When: On tick while evaluating custom profiles
-- Why: Let data-driven profiles drive actions without bespoke class code
-- Safety: Validates profiles, nil-guards settings/spells/targets, and falls back safely
-- ============================================================================
-- Shared Helper: Custom Rotation Engine
-- ============================================================================
local M = {}
local _G = _G
local NS = _G.EaxRotations

-- Get setting safely
local function get_setting(context, key, default)
    if not context or not context.settings then return default end
    local value = context.settings[key]
    if value == nil then return default end
    return value
end

-- Get spell from spell key (class-specific)
local function get_spell_from_key(class, spec, spell_key)
    if not NS or not NS.spell_database then return nil end
    local db = NS.spell_database[class]
    if not db then return nil end
    local spec_db = db[spec]
    if not spec_db then return nil end
    return spec_db[spell_key]
end

-- Condition evaluators
-- Each returns true/false based on context
local CONDITION_EVALUATORS = {
    -- Check if setting is enabled (not false)
    setting_enabled = function(context, params)
        local key = params.key
        if not key then return false end
        local value = get_setting(context, key, true)
        return value ~= false and value ~= 0
    end,
    
    -- Check player buff
    player_buff = function(context, params)
        if not NS or not NS.has_buff then return false end
        if not context or not context.me then return false end
        local buff_ids = params.ids or {params.id}
        for _, id in ipairs(buff_ids) do
            if NS.has_buff(context.me, id) then return true end
        end
        return false
    end,
    
    -- Check player buff missing
    player_buff_missing = function(context, params)
        return not CONDITION_EVALUATORS.player_buff(context, params)
    end,
    
    -- Check target debuff
    target_debuff = function(context, params)
        if not NS or not NS.has_debuff then return false end
        if not context or not context.target then return false end
        local debuff_ids = params.ids or {params.id}
        for _, id in ipairs(debuff_ids) do
            if NS.has_debuff(context.target, id) then return true end
        end
        return false
    end,
    
    -- Check target debuff missing
    target_debuff_missing = function(context, params)
        return not CONDITION_EVALUATORS.target_debuff(context, params)
    end,
    
    -- Check target debuff remains
    target_debuff_remains = function(context, params)
        if not NS or not NS.debuff_remains then return false end
        if not context or not context.target then return false end
        local debuff_ids = params.ids or {params.id}
        local threshold = params.threshold or params.seconds or 3
        for _, id in ipairs(debuff_ids) do
            local remains = NS.debuff_remains(context.target, id) or 0
            if remains < threshold then return true end
        end
        return false
    end,
    
    -- Check target HP below threshold
    target_hp_below = function(context, params)
        if not context then return false end
        local hp = context.target_hp or 100
        local threshold = params.value or params.pct or 35
        return hp < threshold
    end,
    
    -- Check target HP above threshold
    target_hp_above = function(context, params)
        if not context then return false end
        local hp = context.target_hp or 100
        local threshold = params.value or params.pct or 35
        return hp > threshold
    end,
    
    -- Check player HP below threshold
    player_hp_below = function(context, params)
        if not context then return false end
        local hp = context.player_hp or 100
        local threshold = params.value or params.pct or 50
        return hp < threshold
    end,
    
    -- Check player HP above threshold
    player_hp_above = function(context, params)
        if not context then return false end
        local hp = context.player_hp or 100
        local threshold = params.value or params.pct or 50
        return hp > threshold
    end,
    
    -- Check if spell is ready
    spell_ready = function(context, params)
        if not NS or not NS.spell_ready then return false end
        local spell_id = params.spell_id or params.id
        if not spell_id then return false end
        local target = params.on_player and context.me or context.target
        return NS.spell_ready(spell_id, target)
    end,
    
    -- Check if in combat
    in_combat = function(context, params)
        if not context then return false end
        return context.in_combat or false
    end,
    
    -- Check if not in combat
    not_in_combat = function(context, params)
        return not CONDITION_EVALUATORS.in_combat(context, params)
    end,
    
    -- Check enemy count
    enemies_count = function(context, params)
        if not context then return false end
        local count = context.enemies_count or 0
        local op = params.op or ">="
        local value = params.value or 1
        if op == ">=" then return count >= value end
        if op == ">" then return count > value end
        if op == "<=" then return count <= value end
        if op == "<" then return count < value end
        if op == "==" then return count == value end
        return false
    end,
    
    -- Check combat time
    combat_time = function(context, params)
        if not context then return false end
        local time = context.combat_time or 0
        local op = params.op or ">="
        local value = params.value or 0
        if op == ">=" then return time >= value end
        if op == ">" then return time > value end
        if op == "<=" then return time <= value end
        if op == "<" then return time < value end
        return false
    end,
    
    -- Check execute phase
    execute_phase = function(context, params)
        if not context then return false end
        return context.execute_phase or false
    end,
    
    -- Check PvP mode
    is_pvp = function(context, params)
        if not context then return false end
        return context.is_pvp or false
    end,
    
    -- Check if should burst
    should_burst = function(context, params)
        if not context then return false end
        return context.should_burst or false
    end,
}

-- Evaluate a single condition
local function evaluate_condition(context, condition)
    if type(condition) ~= "table" then return false end
    
    local type_name = condition.type
    if not type_name then return false end
    
    local evaluator = CONDITION_EVALUATORS[type_name]
    if not evaluator then
        -- Unknown condition type - be safe and skip
        return false
    end
    
    local ok, result = pcall(evaluator, context, condition)
    if not ok then return false end
    return result
end

-- Evaluate all conditions (AND logic)
local function evaluate_conditions(context, conditions)
    if not conditions or #conditions == 0 then return true end
    
    for _, condition in ipairs(conditions) do
        if not evaluate_condition(context, condition) then
            return false
        end
    end
    return true
end

-- Get target for action
local function get_target_for_action(context, target_type)
    if not context then return nil end
    
    if target_type == "self" then
        return context.me
    elseif target_type == "focus" then
        if NS and NS.GetFocus then
            return NS.GetFocus()
        end
        return nil
    elseif target_type == "target" then
        return context.target
    else
        return context.target
    end
end

-- Execute a single action
local function execute_action(context, action)
    if not NS then return false end
    if not action then return false end
    
    local spell_id = action.spell_id
    if not spell_id then
        -- Try to resolve from spell_key
        if action.spell_key and action.class and action.spec then
            spell_id = get_spell_from_key(action.class, action.spec, action.spell_key)
        end
    end
    
    if not spell_id then return false end
    
    local target = get_target_for_action(context, action.target or "target")
    if not target then return false end
    
    local label = action.label or "[Custom]"
    
    if NS.try_cast then
        return NS.try_cast(spell_id, target, label)
    elseif NS.action_execute then
        return NS.action_execute(context, {
            spell = spell_id,
            target = target,
            label = label,
        })
    end
    
    return false
end

-- Validate a custom rotation profile
function M.validate_profile(profile, class_spells)
    if type(profile) ~= "table" then
        return false, "profile must be a table"
    end
    
    if not profile.priorities or type(profile.priorities) ~= "table" then
        return false, "profile must have priorities table"
    end
    
    local errors = {}
    
    for i, entry in ipairs(profile.priorities) do
        if not entry.spell_key then
            table.insert(errors, "Entry " .. i .. ": missing spell_key")
        end
        
        if entry.conditions then
            for j, condition in ipairs(entry.conditions) do
                if not condition.type then
                    table.insert(errors, "Entry " .. i .. ", Condition " .. j .. ": missing type")
                elseif not CONDITION_EVALUATORS[condition.type] then
                    table.insert(errors, "Entry " .. i .. ", Condition " .. j .. ": unknown type '" .. condition.type .. "'")
                end
            end
        end
    end
    
    if #errors > 0 then
        return false, table.concat(errors, "; ")
    end
    
    return true, nil
end

-- Evaluate a custom rotation
-- Returns the first matching action or nil
function M.evaluate(context, profile, class_spells)
    if not profile or not profile.priorities then return nil end
    if not profile.enabled then return nil end
    
    for _, entry in ipairs(profile.priorities) do
        -- Check conditions
        local conditions_match = true
        if entry.conditions then
            conditions_match = evaluate_conditions(context, entry.conditions)
        end
        
        if conditions_match then
            -- Resolve spell
            local spell_id = entry.spell_id
            if not spell_id and entry.spell_key and class_spells then
                spell_id = class_spells[entry.spell_key]
            end
            
            if spell_id then
                return {
                    spell_id = spell_id,
                    spell_key = entry.spell_key,
                    target = entry.target or "target",
                    label = entry.label or "[Custom]",
                    priority = entry.priority or 0,
                }
            end
        end
    end
    
    return nil
end

-- Try to execute a custom rotation
-- Returns true if an action was taken
function M.try_execute(context, profile, class_spells)
    local action = M.evaluate(context, profile, class_spells)
    if not action then return false end
    
    return execute_action(context, action)
end

-- Create a default profile for a class/spec
function M.create_default_profile(class, spec, class_spells)
    local profile = {
        enabled = false,
        name = class .. " " .. spec .. " Custom",
        class = class,
        spec = spec,
        priorities = {},
    }
    
    -- Add some sensible defaults based on class/spec
    -- These would be populated based on class_spells
    
    return profile
end

-- Example profile structure:
-- {
--   enabled = true,
--   name = "My Custom Rotation",
--   class = "hunter",
--   spec = "beast_mastery",
--   priorities = {
--     {
--       spell_key = "ArcaneShot",
--       target = "target",
--       conditions = {
--         {type = "setting_enabled", key = "use_arcane_shot"},
--         {type = "target_hp_below", value = 35},
--         {type = "player_buff", ids = {3045}}, -- Rapid Fire
--       },
--     },
--   },
-- }

if NS then
    NS.CustomRotation = M
end

return M
