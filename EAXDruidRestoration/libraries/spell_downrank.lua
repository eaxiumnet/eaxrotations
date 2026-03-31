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

return spell_downrank
