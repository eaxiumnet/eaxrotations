-- =============================================================================
-- SPELL RANK OPTIMIZATION FOR RESTO DRUID
-- Intelligent heal rank selection to prevent overheal and mana waste
-- Ported from Flux AIO cast_best_heal_rank pattern
-- =============================================================================

local izi = require("common/izi_sdk")

-- =============================================================================
-- REGROWTH RANK DATA (TBC 2.4.3)
-- Approximate heal values including hot component
-- Format: { rank = N, spell_id = ID, direct_heal = X, hot_total = Y }
-- =============================================================================
local REGROWTH_RANKS = {
    { rank = 1,  spell_id = 8936,  direct_heal = 100,  hot_total = 150,  mana_cost = 280 },
    { rank = 2,  spell_id = 8938,  direct_heal = 175,  hot_total = 245,  mana_cost = 350 },
    { rank = 3,  spell_id = 8939,  direct_heal = 255,  hot_total = 350,  mana_cost = 420 },
    { rank = 4,  spell_id = 8940,  direct_heal = 340,  hot_total = 455,  mana_cost = 505 },
    { rank = 5,  spell_id = 8941,  direct_heal = 430,  hot_total = 560,  mana_cost = 595 },
    { rank = 6,  spell_id = 9750,  direct_heal = 545,  hot_total = 700,  mana_cost = 715 },
    { rank = 7,  spell_id = 9856,  direct_heal = 690,  hot_total = 875,  mana_cost = 855 },
    { rank = 8,  spell_id = 9857,  direct_heal = 855,  hot_total = 1050, mana_cost = 1005 },
    { rank = 9,  spell_id = 9858,  direct_heal = 1040, hot_total = 1225, mana_cost = 1165 },
    { rank = 10, spell_id = 26980, direct_heal = 1250, hot_total = 1470, mana_cost = 1350 },
}

-- =============================================================================
-- HEALING TOUCH RANK DATA (TBC 2.4.3)
-- Direct heal only (no HoT)
-- =============================================================================
local HEALING_TOUCH_RANKS = {
    { rank = 1,  spell_id = 5185,  heal = 50,   mana_cost = 30 },
    { rank = 2,  spell_id = 5186,  heal = 100,  mana_cost = 55 },
    { rank = 3,  spell_id = 5187,  heal = 200,  mana_cost = 100 },
    { rank = 4,  spell_id = 5188,  heal = 350,  mana_cost = 165 },
    { rank = 5,  spell_id = 5189,  heal = 550,  mana_cost = 235 },
    { rank = 6,  spell_id = 6778,  heal = 800,  mana_cost = 315 },
    { rank = 7,  spell_id = 8903,  heal = 1100, mana_cost = 405 },
    { rank = 8,  spell_id = 9758,  heal = 1450, mana_cost = 505 },
    { rank = 9,  spell_id = 9888,  heal = 1850, mana_cost = 620 },
    { rank = 10, spell_id = 9889,  heal = 2300, mana_cost = 750 },
    { rank = 11, spell_id = 25297, heal = 2800, mana_cost = 885 },
    { rank = 12, spell_id = 26978, heal = 3100, mana_cost = 975 },
    { rank = 13, spell_id = 26979, heal = 3400, mana_cost = 1070 },
}

-- =============================================================================
-- PRE-ALLOCATED OPTIONS TABLE (no inline table creation in combat)
-- =============================================================================
local default_heal_options = {
    overheal_threshold = 1.3,  -- Allow 30% overheal
    prioritize_speed = false,  -- If true, pick fastest cast that won't overheal too much
    prioritize_efficiency = false, -- If true, pick best heal per mana
    mana_floor = 0,  -- Minimum mana % to use expensive ranks
}

-- =============================================================================
-- SPELL RANK SELECTOR
-- Selects best heal rank based on target deficit and options
-- Returns: spell_object, rank_info_string
-- =============================================================================
local function cast_best_heal_rank(rank_table, target, ctx, spell_name, options)
    options = options or default_heal_options
    local overheal_threshold = options.overheal_threshold or 1.3
    local prioritize_speed = options.prioritize_speed or false
    local prioritize_efficiency = options.prioritize_efficiency or false
    local mana_floor = options.mana_floor or 0
    
    -- Check mana floor
    if ctx.mana_pct and ctx.mana_pct < mana_floor then
        return nil, "mana_floor"
    end
    
    -- Get target deficit in HP amount (not percentage)
    local max_hp = target.unit:get_health_max() or 1
    local current_hp = target.unit:get_health() or 0
    local deficit = max_hp - current_hp
    
    if deficit <= 0 then
        return nil, "no_deficit"
    end
    
    -- Mode: Prioritize speed (fastest cast that won't overheal too much)
    if prioritize_speed then
        for _, rank in ipairs(rank_table) do
            local spell = izi.spell(rank.spell_id)
            if spell:is_learned() and spell:cooldown_up() then
                local expected_heal = rank.direct_heal or rank.heal or 0
                -- Include HoT component for Regrowth
                if rank.hot_total then
                    expected_heal = expected_heal + (rank.hot_total * 0.5)  -- 50% of HoT value
                end
                
                local overheal_ratio = expected_heal / deficit
                if overheal_ratio <= overheal_threshold then
                    return spell, "R" .. rank.rank
                end
            end
        end
        return nil, "no_suitable_rank"
    end
    
    -- Mode: Prioritize efficiency (best heal per mana)
    if prioritize_efficiency then
        local best_rank = nil
        local best_efficiency = 0
        
        for _, rank in ipairs(rank_table) do
            local spell = izi.spell(rank.spell_id)
            if spell:is_learned() and spell:cooldown_up() and rank.mana_cost > 0 then
                local expected_heal = rank.direct_heal or rank.heal or 0
                if rank.hot_total then
                    expected_heal = expected_heal + (rank.hot_total * 0.5)
                end
                
                local efficiency = expected_heal / rank.mana_cost
                if efficiency > best_efficiency then
                    -- Check overheal constraint
                    local overheal_ratio = expected_heal / deficit
                    if overheal_ratio <= overheal_threshold then
                        best_efficiency = efficiency
                        best_rank = rank
                    end
                end
            end
        end
        
        if best_rank then
            return izi.spell(best_rank.spell_id), "R" .. best_rank.rank .. "(eff)"
        end
        return nil, "no_efficient_rank"
    end
    
    -- Default: Largest rank that won't overheal beyond threshold
    -- Iterate from largest to smallest
    for i = #rank_table, 1, -1 do
        local rank = rank_table[i]
        local spell = izi.spell(rank.spell_id)
        if spell:is_learned() and spell:cooldown_up() then
            local expected_heal = rank.direct_heal or rank.heal or 0
            if rank.hot_total then
                expected_heal = expected_heal + (rank.hot_total * 0.5)
            end
            
            -- Allow some overheal (up to threshold)
            local min_deficit_needed = expected_heal / overheal_threshold
            if deficit >= min_deficit_needed then
                return spell, "R" .. rank.rank
            end
        end
    end
    
    -- Fallback: smallest available rank (always use something)
    for _, rank in ipairs(rank_table) do
        local spell = izi.spell(rank.spell_id)
        if spell:is_learned() and spell:cooldown_up() then
            return spell, "R" .. rank.rank .. "(min)"
        end
    end
    
    return nil, "no_rank_available"
end

-- =============================================================================
-- PUBLIC API
-- =============================================================================
local SpellRankOptimizer = {
    -- Rank tables
    REGROWTH_RANKS = REGROWTH_RANKS,
    HEALING_TOUCH_RANKS = HEALING_TOUCH_RANKS,
    
    -- Default options
    default_options = default_heal_options,
    
    -- Main function
    cast_best_heal_rank = cast_best_heal_rank,
    
    -- Convenience wrappers
    cast_best_regrowth = function(target, ctx, options)
        return cast_best_heal_rank(REGROWTH_RANKS, target, ctx, "Regrowth", options)
    end,
    
    cast_best_healing_touch = function(target, ctx, options)
        return cast_best_heal_rank(HEALING_TOUCH_RANKS, target, ctx, "HealingTouch", options)
    end,
    
    -- Utility: Get estimated heal amount for a rank
    get_estimated_heal = function(rank_entry)
        local heal = rank_entry.direct_heal or rank_entry.heal or 0
        if rank_entry.hot_total then
            heal = heal + (rank_entry.hot_total * 0.5)  -- 50% of HoT value
        end
        return heal
    end,
    
    -- Utility: Check if rank is learned
    is_rank_learned = function(spell_id)
        local spell = izi.spell(spell_id)
        return spell:is_learned()
    end,
}

return SpellRankOptimizer
