-- =============================================================================
-- DRUID ROTATION ENGINE
-- Ported from Flux AIO - Strategy registry and execution engine
-- =============================================================================

local core = _G.core
local izi = require("common/izi_sdk")
local Constants = require("libraries/constants")
local Utils = require("libraries/utils")

local RotationEngine = {}

-- ============================================================================
-- STRATEGY REGISTRY
-- ============================================================================

local registry = {
    cat = {},
    bear = {},
    balance = {},
    resto = {},
    middleware = {},
}

local priority_order = {
    "middleware",
    "cat",
    "bear",
    "balance",
    "resto",
}

-- ============================================================================
-- REGISTRATION FUNCTIONS
-- ============================================================================

--- Register strategies for a playstyle
function RotationEngine.register(playstyle, strategies, config)
    if not registry[playstyle] then
        core.log("[Druid] ERROR: Unknown playstyle: " .. tostring(playstyle))
        return
    end
    
    -- Add strategies to registry
    for _, strategy in ipairs(strategies) do
        table.insert(registry[playstyle], {
            name = strategy.name or "unnamed",
            matches = strategy.matches,
            execute = strategy.execute,
            requires_combat = strategy.requires_combat,
            requires_enemy = strategy.requires_enemy,
            requires_in_range = strategy.requires_in_range,
            requires_stealth = strategy.requires_stealth,
            requires_phys_immune = strategy.requires_phys_immune,
            requires_clearcasting = strategy.requires_clearcasting,
            requires_behind = strategy.requires_behind,
            min_energy = strategy.min_energy,
            min_cp = strategy.min_cp,
            setting_key = strategy.setting_key,
            is_gcd_gated = strategy.is_gcd_gated,
            is_defensive = strategy.is_defensive,
            is_burst = strategy.is_burst,
            spell = strategy.spell,
        })
    end
    
    -- Store config (context_builder, check_prerequisites)
    registry[playstyle .. "_config"] = config or {}
    
    core.log(string.format("[Druid] Registered %d strategies for %s", #strategies, playstyle))
end

--- Register a middleware handler
function RotationEngine.register_middleware(middleware)
    table.insert(registry.middleware, {
        name = middleware.name or "unnamed",
        priority = middleware.priority or 100,
        matches = middleware.matches,
        execute = middleware.execute,
        is_gcd_gated = middleware.is_gcd_gated,
        is_defensive = middleware.is_defensive,
        setting_key = middleware.setting_key,
    })
    
    -- Sort by priority (higher first)
    table.sort(registry.middleware, function(a, b) return a.priority > b.priority end)
end

-- ============================================================================
-- PREREQUISITE CHECKS
-- ============================================================================

local function check_prerequisites(strategy, ctx, state)
    -- Combat check
    if strategy.requires_combat ~= nil and strategy.requires_combat ~= ctx.in_combat then
        return false
    end
    
    -- Enemy check
    if strategy.requires_enemy ~= nil then
        local has_enemy = ctx.target and ctx.target:is_valid() and ctx.target:is_valid_enemy()
        if strategy.requires_enemy ~= has_enemy then
            return false
        end
    end
    
    -- In-range check
    if strategy.requires_in_range ~= nil then
        local in_range = ctx.target and ctx.target:is_valid() and 
            (ctx.target:distance_to(ctx.me) or 100) <= 5
        if strategy.requires_in_range ~= in_range then
            return false
        end
    end
    
    -- Stealth check
    if strategy.requires_stealth ~= nil and strategy.requires_stealth ~= ctx.is_stealthed then
        return false
    end
    
    -- Physical immunity check (skip if target physically immune)
    if strategy.requires_phys_immune ~= nil and strategy.requires_phys_immune ~= ctx.target_phys_immune then
        return false
    end
    
    -- Clearcasting check
    if strategy.requires_clearcasting ~= nil and strategy.requires_clearcasting ~= ctx.has_clearcasting then
        return false
    end
    
    -- Behind check
    if strategy.requires_behind ~= nil and strategy.requires_behind ~= ctx.is_behind then
        return false
    end
    
    -- Energy check (Cat only)
    if strategy.min_energy and ctx.energy and ctx.energy < strategy.min_energy then
        return false
    end
    
    -- Combo points check (Cat only)
    if strategy.min_cp and ctx.cp and ctx.cp < strategy.min_cp then
        return false
    end
    
    -- Setting check
    if strategy.setting_key then
        local setting_value = ctx.settings[strategy.setting_key]
        if setting_value == false or setting_value == nil then
            return false
        end
    end
    
    return true
end

-- ============================================================================
-- CONTEXT BUILDERS
-- ============================================================================

-- Cache for computed state per frame
local state_cache = {
    cat = { valid = false },
    bear = { valid = false },
    balance = { valid = false },
    resto = { valid = false },
}

--- Invalidate all state caches (call at start of rotation frame)
function RotationEngine.invalidate_cache()
    state_cache.cat.valid = false
    state_cache.bear.valid = false
    state_cache.balance.valid = false
    state_cache.resto.valid = false
end

--- Get cached state for playstyle
function RotationEngine.get_state(playstyle)
    return state_cache[playstyle]
end

--- Mark state as valid
function RotationEngine.set_state_valid(playstyle)
    state_cache[playstyle].valid = true
end

-- ============================================================================
-- MAIN EXECUTION
-- ============================================================================

--- Execute rotation for a playstyle
function RotationEngine.execute_playstyle(playstyle, ctx)
    local strategies = registry[playstyle]
    if not strategies or #strategies == 0 then
        return nil
    end
    
    -- Get or build context state
    local config = registry[playstyle .. "_config"]
    local state = state_cache[playstyle]
    
    if config.context_builder and not state.valid then
        config.context_builder(ctx, state)
        state.valid = true
    end
    
    -- Execute strategies in order
    for _, strategy in ipairs(strategies) do
        -- Check prerequisites
        local prereq_ok = check_prerequisites(strategy, ctx, state)
        if prereq_ok then
            -- Check custom matches function
            if strategy.matches then
                local ok, matches_result = pcall(function() return strategy.matches(ctx, state) end)
                if ok and matches_result then
                    -- Execute strategy
                    local exec_ok, exec_result = pcall(function() return strategy.execute(ctx, state) end)
                    if exec_ok and exec_result then
                        return true  -- Action taken
                    end
                end
            end
        end
    end
    
    return nil  -- No action taken
end

--- Execute middleware
function RotationEngine.execute_middleware(ctx)
    for _, mw in ipairs(registry.middleware) do
        -- Check setting
        if mw.setting_key and not ctx.settings[mw.setting_key] then
            -- skip
        else
            -- Check matches
            if mw.matches then
                local ok, matches_result = pcall(function() return mw.matches(ctx) end)
                if ok and matches_result then
                    local exec_ok, exec_result = pcall(function() return mw.execute(ctx) end)
                    if exec_ok and exec_result then
                        return true
                    end
                end
            end
        end
    end
    return nil
end

-- ============================================================================
-- PLAYSTYLE DETECTION
-- ============================================================================

--- Detect active playstyle based on stance
function RotationEngine.get_active_playstyle(ctx)
    local stance = ctx.stance
    
    -- Bear and Cat have reliable fixed stance indices
    if stance == Constants.STANCE.BEAR then
        return "bear"
    elseif stance == Constants.STANCE.CAT then
        return "cat"
    elseif stance == Constants.STANCE.MOONKIN then
        return "balance"
    elseif stance == Constants.STANCE.TREE then
        return "resto"
    end
    
    -- Stance 5 is shared - differentiate by spell known
    if stance == 5 then
        local me = ctx.me
        if me then
            -- Check for Moonkin Form buff
            if me:buff_up(24858) then return "balance" end
            -- Check for Tree of Life buff  
            if me:buff_up(33891) then return "resto" end
        end
    end
    
    -- Caster form defaults to resto healing logic
    if stance == Constants.STANCE.CASTER then
        return "resto"
    end
    
    return nil
end

return RotationEngine
