-- strategy_dsl_sylvanas.lua — Declarative strategy DSL for EaxRotations specs.
-- WHAT:  Compiles declarative strategy definitions into the {name, matches, execute}
--        tables consumed by main_sylvanas.lua.
-- WHEN:  Loaded by spec files that want to declare rotations declaratively.
-- WHY:   Reduces imperative boilerplate and makes strategy logic data-driven.
-- SAFETY: pcall-wrapped spell checks; nil-safe state reads; no banned APIs.
-- DECISION: Pure helper, no on_update side-effects. Lua 5.1 / LuaJIT compatible.
--
-- Example:
--   local dsl = require("shared/strategy_dsl_sylvanas")
--   local strategy = dsl.compile_strategy({
--       name = "BattleShout",
--       conditions = {
--           { type = "buff", unit = "self", ids = BATTLE_SHOUT_BUFF, invert = true },
--           { type = "state", field = "rage", op = ">=", value = 10 },
--       },
--       action = { type = "cast", spell = ACTION.BattleShout, target = "self" },
--   }, { get_state = build_state })

local spec_kit = require("shared/spec_kit_sylvanas")

local M = {}

-- ============================================================================
-- Condition evaluators
-- Each evaluator receives (context, state, node) and returns boolean.
-- ============================================================================
local condition_evaluators = {}

-- Logical AND
condition_evaluators["AND"] = function(context, state, node)
    if not node.conditions then return true end
    for i = 1, #node.conditions do
        if not M.evaluate_node(context, state, node.conditions[i]) then return false end
    end
    return true
end

-- Logical OR
condition_evaluators["OR"] = function(context, state, node)
    if not node.conditions then return false end
    for i = 1, #node.conditions do
        if M.evaluate_node(context, state, node.conditions[i]) then return true end
    end
    return false
end

-- Logical NOT
condition_evaluators["NOT"] = function(context, state, node)
    return not M.evaluate_node(context, state, node.condition)
end

-- Generic numeric/boolean comparison helper.
local function compare_value(val, op, target)
    if op == "==" then return val == target
    elseif op == "!=" then return val ~= target
    elseif op == ">" then return (val or 0) > target
    elseif op == ">=" then return (val or 0) >= target
    elseif op == "<" then return (val or 0) < target
    elseif op == "<=" then return (val or 0) <= target
    elseif op == "truthy" then return val == true
    elseif op == "falsy" then return val == false or val == nil
    end
    return false
end

-- Compare a state field against a value.
condition_evaluators["state"] = function(context, state, node)
    return compare_value(state[node.field], node.op or "==", node.value)
end

-- Compare a context field against a value.
condition_evaluators["context"] = function(context, state, node)
    if not context then return false end
    return compare_value(context[node.field], node.op or "==", node.value)
end

-- Check a menu setting.
condition_evaluators["setting"] = function(context, state, node)
    local val = spec_kit.setting(context, node.key, node.default)
    if node.op then
        local op = node.op
        local target = node.value
        if op == "==" then return val == target
        elseif op == "!=" then return val ~= target
        elseif op == ">" then return (val or 0) > target
        elseif op == ">=" then return (val or 0) >= target
        elseif op == "<" then return (val or 0) < target
        elseif op == "<=" then return (val or 0) <= target
        end
        return false
    end
    -- Default: truthy check
    return val ~= false and val ~= nil
end

-- Check if a buff is present on a unit.
condition_evaluators["buff"] = function(context, state, node)
    local NS = _G.EaxRotations
    if not NS or not NS.buff_up then return false end
    local unit
    if node.unit == "self" then
        unit = context.me or (NS.GetPlayer and NS.GetPlayer())
    elseif node.unit == "target" or node.unit == nil then
        unit = context.target
    else
        unit = node.unit
    end
    -- A missing unit is treated as "buff absent". When invert is true this
    -- means the condition passes (buff is considered missing on no one).
    if not unit then return node.invert == true end
    local has = NS.buff_up(unit, node.ids) or false
    if node.invert then has = not has end
    return has
end

-- Check if a debuff is present on the target.
condition_evaluators["debuff"] = function(context, state, node)
    local NS = _G.EaxRotations
    if not NS or not NS.debuff_up then return false end
    local target = context.target
    if not target then return node.invert == true end
    local has = NS.debuff_up(target, node.ids) or false
    if node.invert then has = not has end
    return has
end

-- Check if a debuff remains less/greater than a threshold.
condition_evaluators["debuff_remains"] = function(context, state, node)
    local NS = _G.EaxRotations
    if not NS or not NS.debuff_remains then return false end
    local target = context.target
    if not target then return false end
    local remains = NS.debuff_remains(target, node.ids) or 0
    return compare_value(remains, node.op or "<=", node.value or 0)
end

-- Check if a spell is ready.
condition_evaluators["spell_ready"] = function(context, state, node)
    local NS = _G.EaxRotations
    if not NS or not NS.spell_ready then return false end
    local target = node.target
    if target == "self" then
        target = context.me or NS.GetPlayer and NS.GetPlayer()
    elseif target == "target" or target == nil then
        target = context.target
    end
    if not target then return false end
    local ok, ready = pcall(NS.spell_ready, node.spell, target, node.opts)
    return ok and ready == true
end

-- Check enemy count against a threshold.
condition_evaluators["enemy_count"] = function(context, state, node)
    local count = state.enemy_count or state.enemies_count or 0
    local op = node.op or ">="
    local target = node.value
    if op == ">=" then return count >= target
    elseif op == ">" then return count > target
    elseif op == "<=" then return count <= target
    elseif op == "<" then return count < target
    elseif op == "==" then return count == target
    end
    return false
end

-- Check in_combat flag.
condition_evaluators["in_combat"] = function(context, state, node)
    local val = state.in_combat or context.in_combat or false
    if node.invert then return not val end
    return val
end

-- HP threshold (self, target, friendly, or party member).
condition_evaluators["hp_threshold"] = function(context, state, node)
    local unit = node.unit or "self"
    local hp
    if unit == "self" then
        hp = state.hp or context.hp or 100
    elseif unit == "target" then
        hp = state.target_hp or context.target_hp or 100
    elseif unit == "friendly" then
        local lowest = (context.lowest and context.lowest.hp) or (state.lowest_hp or 100)
        hp = lowest
    elseif unit == "party" then
        local lowest = (context.lowest and context.lowest.hp) or (state.lowest_hp or 100)
        hp = lowest
    end
    return compare_value(hp, node.op or "<=", node.value)
end

-- Check current stance.
condition_evaluators["stance"] = function(context, state, node)
    local stance = state.stance or context.stance
    if node.is then return stance == node.is end
    if node.is_not then return stance ~= node.is_not end
    return false
end

-- Check target distance.
condition_evaluators["distance"] = function(context, state, node)
    local dist = state.target_distance or context.target_distance or 0
    return compare_value(dist, node.op or "<=", node.value)
end

-- PvP check.
condition_evaluators["is_pvp"] = function(context, state, node)
    local val = state.is_pvp or context.is_pvp or false
    if node.invert then return not val end
    return val
end

-- Execute phase check.
condition_evaluators["execute_phase"] = function(context, state, node)
    local val = state.execute_phase or false
    if node.invert then return not val end
    return val
end

-- Custom condition via function.
condition_evaluators["custom"] = function(context, state, node)
    if type(node.fn) ~= "function" then return false end
    local ok, result = pcall(node.fn, context, state)
    if not ok then
        local NS = _G.EaxRotations
        if NS and type(NS.log_warning) == "function" then
            NS.log_warning("[strategy_dsl] custom condition error: " .. tostring(result))
        end
        return false
    end
    return result == true
end

-- Register a custom condition evaluator.
function M.register_condition(name, func)
    condition_evaluators[name] = func
end

-- Evaluate a single condition node.
function M.evaluate_node(context, state, node)
    if not node then return true end
    local eval = condition_evaluators[node.type]
    if not eval then return false end
    return eval(context, state, node) == true
end

-- ============================================================================
-- Action handlers
-- Each handler receives (context, state, action_def) and returns boolean.
-- ============================================================================
local action_handlers = {}

-- Resolve a target string/object into a unit.
local function resolve_target(context, target_spec)
    local NS = _G.EaxRotations
    if target_spec == "self" then
        return context.me or (NS and NS.GetPlayer and NS.GetPlayer())
    elseif target_spec == "target" or target_spec == nil then
        return context.target
    elseif target_spec == "friendly" then
        -- Return the lowest HP party member, or self if no group
        if context.lowest and context.lowest.unit then
            return context.lowest.unit
        end
        return context.me or (NS and NS.GetPlayer and NS.GetPlayer())
    end
    return target_spec
end

-- Cast a spell on a target.
action_handlers["cast"] = function(context, state, action)
    local NS = _G.EaxRotations
    if not NS or not NS.try_cast then return false end
    local target = resolve_target(context, action.target)
    if not target then return false end
    local opts = action.opts or {}
    local ok, result = pcall(NS.try_cast, action.spell, target, action.label or "[DSL]", opts)
    return ok and result == true
end

-- Use an item.
action_handlers["item"] = function(context, state, action)
    local NS = _G.EaxRotations
    if not NS or not NS.use_item_by_id then return false end
    local target = resolve_target(context, action.target)
    local ok, result = pcall(NS.use_item_by_id, action.item_id, target)
    return ok and result == true
end

-- Run a custom function.
action_handlers["custom"] = function(context, state, action)
    if type(action.fn) ~= "function" then return false end
    local ok, result = pcall(action.fn, context, state)
    return ok and result == true
end

-- Register a custom action handler.
function M.register_action(name, func)
    action_handlers[name] = func
end

-- Execute an action definition.
function M.execute_action(context, state, action)
    if not action or not action.type then return false end
    local handler = action_handlers[action.type]
    if not handler then return false end
    local ok, result = pcall(handler, context, state, action)
    if not ok then
        local NS = _G.EaxRotations
        if NS and type(NS.log_warning) == "function" then
            NS.log_warning("[strategy_dsl] action error: " .. tostring(result))
        end
        return false
    end
    return result == true
end

-- ============================================================================
-- Compiler: turn a DSL definition into a strategy table.
-- ============================================================================

-- Default matches function: evaluate all top-level conditions.
local function default_matches(conditions)
    return function(context, state)
        for i = 1, #conditions do
            if not M.evaluate_node(context, state, conditions[i]) then return false end
        end
        return true
    end
end

-- Default execute function: run the action.
local function default_execute(action)
    return function(context, state)
        return M.execute_action(context, state, action)
    end
end

-- Compile a single DSL strategy definition.
-- dsl_def: { name = "...", conditions = {...}, action = {...}, matches = fn?, execute = fn?, get_state = fn? }
-- opts: optional table; opts.get_state is used when dsl_def.get_state is absent.
function M.compile_strategy(dsl_def, opts)
    opts = opts or {}
    local conditions = dsl_def.conditions or dsl_def.condition and { dsl_def.condition } or {}
    local action = dsl_def.action or dsl_def.actions and dsl_def.actions[1] or nil

    local matches = dsl_def.matches
    if not matches then
        matches = default_matches(conditions)
    end

    -- Wrap matches/execute so that callers (e.g. unit tests) that omit state
    -- get a freshly-built state table from the spec's build_state function.
    -- Existing pre-DSL tests often pass an empty table {} as the second
    -- argument (it used to be the action table and was ignored). Treat an
    -- empty table the same as nil so those tests continue to work after DSL
    -- adoption.
    local get_state = dsl_def.get_state or opts.get_state
    local function ensure_state(state, context)
        if get_state and (state == nil or (type(state) == "table" and next(state) == nil)) then
            return get_state(context)
        end
        return state
    end
    local wrapped_matches = function(context, state)
        state = ensure_state(state, context)
        return matches(context, state)
    end

    local execute = dsl_def.execute
    if not execute and action then
        execute = default_execute(action)
    end
    -- Custom actions may read state in their execute (e.g. bear DemoRoar
    -- tracks immune targets). Wrap their execute so callers that omit state
    -- get a freshly-built state, but fall back to nil if build_state fails
    -- (some unit tests mock only part of the engine).
    local is_custom_execute = dsl_def.execute ~= nil or (action and action.type == "custom")
    local wrapped_execute = function(context, state)
        if is_custom_execute and get_state and (state == nil or (type(state) == "table" and next(state) == nil)) then
            local ok, built = pcall(get_state, context)
            if ok then state = built end
        end
        return execute(context, state)
    end

    return {
        name = dsl_def.name,
        matches = wrapped_matches,
        execute = wrapped_execute,
    }
end

-- Compile a list of DSL strategy definitions.
-- opts: optional table passed to every compile_strategy call.
function M.compile_strategies(dsl_defs, opts)
    local strategies = {}
    for i = 1, #dsl_defs do
        strategies[#strategies + 1] = M.compile_strategy(dsl_defs[i], opts)
    end
    return strategies
end

-- Convenience: build a strategy from a name, conditions, and action.
function M.strategy(name, conditions, action, opts)
    opts = opts or {}
    return M.compile_strategy({
        name = name,
        conditions = conditions,
        action = action,
        matches = opts.matches,
        execute = opts.execute,
    })
end

return M
