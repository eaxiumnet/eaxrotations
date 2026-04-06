-- spell_downrank.lua
-- Conservative first-wave TBC heal downranking helper.

local spell_downrank = {}

local function is_learned(spell_id)
    return spell_id and core and core.spell_book and core.spell_book.is_spell_learned(spell_id)
end

local function learned_ranks(rank_table)
    local learned = {}
    for i = 1, #rank_table do
        local spell_id = rank_table[i]
        if is_learned(spell_id) then
            learned[#learned + 1] = spell_id
        end
    end
    return learned
end

local function clamp_index(index, count)
    local value = math.floor(tonumber(index) or 1)
    if value < 1 then
        return 1
    end
    if value > count then
        return count
    end
    return value
end

local function select_from_indices(learned, index)
    if #learned == 0 then
        return nil
    end
    return learned[clamp_index(index, #learned)]
end

function spell_downrank.resolve_rank(rank_table, preferred_index)
    if type(rank_table) == "number" then
        return is_learned(rank_table) and rank_table or nil
    end

    if type(rank_table) ~= "table" or #rank_table == 0 then
        return nil
    end

    return select_from_indices(learned_ranks(rank_table), preferred_index or 1)
end

function spell_downrank.select_heal_rank(rank_table, target_hp_pct, mana_pct, options)
    if type(rank_table) == "number" then
        return is_learned(rank_table) and rank_table or nil
    end

    if type(rank_table) ~= "table" or #rank_table == 0 then
        return nil
    end

    local learned = learned_ranks(rank_table)
    if #learned == 0 then
        return nil
    end

    local opts = options or {}
    local emergency_hp_threshold = tonumber(opts.emergency_hp_threshold) or 0.40
    local sustain_hp_threshold = tonumber(opts.sustain_hp_threshold or opts.target_hp_threshold) or 0.72
    local mana_threshold = tonumber(opts.mana_threshold) or 0.35
    local mana_floor = tonumber(opts.mana_floor)
    local hard_mana_floor = tonumber(opts.hard_mana_floor or opts.min_mana_pct)

    local emergency_rank = select_from_indices(learned, opts.emergency_rank_index or 1)
    local sustain_rank = select_from_indices(learned, opts.sustain_rank_index or math.min(2, #learned)) or emergency_rank
    local efficient_rank = select_from_indices(learned, opts.efficient_rank_index or math.min(3, #learned)) or sustain_rank

    local hp = tonumber(target_hp_pct)
    local mana = tonumber(mana_pct)

    if hp and hp <= emergency_hp_threshold then
        return emergency_rank
    end

    if mana and hard_mana_floor and mana < hard_mana_floor then
        return nil
    end

    if mana and mana_floor and mana <= mana_floor then
        return efficient_rank
    end

    if mana and mana <= mana_threshold then
        return efficient_rank
    end

    if hp and hp >= sustain_hp_threshold then
        return efficient_rank
    end

    return sustain_rank
end

function spell_downrank.select_dps_rank(rank_table, target_level, player_level, mana_pct)
    if type(rank_table) == "number" then
        return is_learned(rank_table) and rank_table or nil
    end
    if type(rank_table) ~= "table" or #rank_table == 0 then
        return nil
    end
    local learned = learned_ranks(rank_table)
    if #learned == 0 then return nil end

    local level_diff = (player_level or 70) - (target_level or 70)

    if level_diff > 15 then
        return learned[1]
    elseif level_diff > 8 then
        local idx = math.max(1, math.floor(#learned * 0.3))
        return learned[idx]
    elseif level_diff > 3 then
        local idx = math.max(1, math.floor(#learned * 0.6))
        return learned[idx]
    end

    if mana_pct and mana_pct < 0.30 then
        local idx = math.max(1, math.floor(#learned * 0.4))
        return learned[idx]
    end

    return learned[#learned]
end

-- ============================================================================
-- FLUX ADAPTATION: Deficit-Based Smart Rank Selection
-- Ported from Flux cast_best_heal_rank() with Sylvanas API adaptations
-- ============================================================================

local spells = require("libraries/spells")

--- Calculate heal amount for a given spell ID
---@param spell_id number Spell ID
---@param spell_type string "healing_touch" or "regrowth"
---@return number heal_amount
local function get_heal_amount(spell_id, spell_type)
    if spell_type == "healing_touch" then
        local data = spells.HEALING_TOUCH_DATA[spell_id]
        return data and data.avg_heal or 0
    elseif spell_type == "regrowth" then
        return spells.get_regrowth_effective_heal(spell_id)
    end
    return 0
end

--- Calculate mana cost for a spell
---@param spell_id number Spell ID
---@param spell_type string "healing_touch" or "regrowth"
---@return number mana_cost
local function get_mana_cost(spell_id, spell_type)
    local data
    if spell_type == "healing_touch" then
        data = spells.HEALING_TOUCH_DATA[spell_id]
    elseif spell_type == "regrowth" then
        data = spells.REGROWTH_DATA[spell_id]
    end
    return data and data.mana_cost or 0
end

--- Check if a heal rank is viable (won't overheal too much)
---@param spell_id number Spell ID
---@param spell_type string Spell type
---@param hp_deficit_pct number HP deficit as percentage (0-1)
---@param overheal_threshold number Max allowed overheal ratio (1.2 = 20% overheal)
---@return boolean is_viable
local function is_heal_viable(spell_id, spell_type, hp_deficit_pct, overheal_threshold)
    if hp_deficit_pct <= 0 then return false end
    local heal = get_heal_amount(spell_id, spell_type)
    if heal <= 0 then return false end
    -- heal / deficit <= threshold means viable
    return (heal / hp_deficit_pct) <= overheal_threshold
end

--- Select best heal rank based on deficit and overheal protection
---@param rank_table table Array of spell IDs (high-to-low rank order)
---@param target_hp_deficit_pct number Target HP deficit (0-1)
---@param current_mana_pct number Current mana percentage (0-1)
---@param spell_type string "healing_touch" or "regrowth"
---@param options table Selection options
---@return number|nil selected_spell_id
---@return string|nil rank_info Debug info
function spell_downrank.select_heal_rank_by_deficit(rank_table, target_hp_deficit_pct, current_mana_pct, spell_type, options)
    if type(rank_table) ~= "table" or #rank_table == 0 then
        return nil, "invalid_rank_table"
    end
    
    local opts = options or {}
    local overheal_threshold = tonumber(opts.overheal_threshold) or 1.3  -- Default: 30% overheal allowed
    local mana_floor_pct = tonumber(opts.mana_floor) or 0  -- Don't drop below this mana %
    local prioritize_speed = opts.prioritize_speed == true   -- For emergency: pick first viable
    local prioritize_efficiency = opts.prioritize_efficiency == true  -- For conserve: best HPM
    
    -- Get learned ranks only
    local learned = learned_ranks(rank_table)
    if #learned == 0 then
        return nil, "no_learned_ranks"
    end
    
    local deficit = tonumber(target_hp_deficit_pct) or 0
    if deficit <= 0 then
        return nil, "no_deficit"
    end
    
    local current_mana = tonumber(current_mana_pct) or 1.0
    
    -- Check if any rank is viable at all
    local any_viable = false
    for _, spell_id in ipairs(learned) do
        if is_heal_viable(spell_id, spell_type, deficit, overheal_threshold) then
            any_viable = true
            break
        end
    end
    
    -- If nothing is viable (all overheal), fall back to lowest rank
    if not any_viable then
        return learned[#learned], "fallback_lowest"
    end
    
    -- PRIORITIZE SPEED: Pick first viable rank that we can afford
    if prioritize_speed then
        for _, spell_id in ipairs(learned) do
            local mana_cost_pct = get_mana_cost(spell_id, spell_type) / 10000  -- Rough conversion
            if is_heal_viable(spell_id, spell_type, deficit, overheal_threshold) then
                if current_mana >= (mana_floor_pct + mana_cost_pct) then
                    return spell_id, "speed_viable"
                end
            end
        end
    end
    
    -- PRIORITIZE EFFICIENCY: Best heal-per-mana ratio among viable ranks
    if prioritize_efficiency then
        local best_efficiency = 0
        local best_spell_id = nil
        
        for _, spell_id in ipairs(learned) do
            if is_heal_viable(spell_id, spell_type, deficit, overheal_threshold) then
                local mana_cost_pct = get_mana_cost(spell_id, spell_type) / 10000
                if current_mana >= (mana_floor_pct + mana_cost_pct) then
                    local heal = get_heal_amount(spell_id, spell_type)
                    local mana = get_mana_cost(spell_id, spell_type)
                    local efficiency = mana > 0 and (heal / mana) or 0
                    
                    if efficiency > best_efficiency then
                        best_efficiency = efficiency
                        best_spell_id = spell_id
                    end
                end
            end
        end
        
        if best_spell_id then
            return best_spell_id, "efficiency_optimized"
        end
    end
    
    -- DEFAULT: Balance approach - find rank that covers at least 80% of deficit
    -- Prefer higher ranks that meet this criteria, fall back to efficiency
    local best_spell_id = nil
    local best_efficiency = 0
    
    for i, spell_id in ipairs(learned) do
        if is_heal_viable(spell_id, spell_type, deficit, overheal_threshold) then
            local heal = get_heal_amount(spell_id, spell_type)
            local mana = get_mana_cost(spell_id, spell_type)
            local mana_cost_pct = mana / 10000
            
            if current_mana >= (mana_floor_pct + mana_cost_pct) then
                -- Check if this covers at least 80% of deficit
                if heal >= (deficit * 0.8) then
                    return spell_id, "balanced_coverage"
                end
                
                -- Track best efficiency as fallback
                local efficiency = mana > 0 and (heal / mana) or 0
                if efficiency > best_efficiency then
                    best_efficiency = efficiency
                    best_spell_id = spell_id
                end
            end
        end
    end
    
    -- Return best efficiency match if no perfect coverage found
    if best_spell_id then
        return best_spell_id, "balanced_efficiency"
    end
    
    -- Final fallback: lowest rank
    return learned[#learned], "fallback_final"
end

return spell_downrank
