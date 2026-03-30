local dispel_engine = {}

local function normalize_type_name(value)
    if type(value) ~= "string" then return nil end
    return string.lower(value)
end

function dispel_engine.matches_type(dtype, numeric, name)
    if type(dtype) == "number" then
        return dtype == numeric
    end
    local normalized = normalize_type_name(dtype)
    return normalized ~= nil and normalized == name
end

function dispel_engine.unit_has_type(unit, type_def, buff_manager)
    if not unit or not unit.is_valid or not unit:is_valid() or unit:is_dead() then
        return false
    end
    if not type_def then return false end

    if buff_manager and buff_manager.get_debuff_cache then
        local ok, cache = pcall(function() return buff_manager:get_debuff_cache(unit, 100) end)
        if ok and cache then
            for _, aura in ipairs(cache) do
                if aura and aura.is_active and dispel_engine.matches_type(aura.buff_type, type_def.numeric, type_def.name) then
                    return true
                end
            end
        end
    end

    if unit.get_debuffs then
        local ok, debuffs = pcall(function() return unit:get_debuffs() end)
        if ok and debuffs then
            for _, debuff in ipairs(debuffs) do
                if debuff and dispel_engine.matches_type(debuff.type, type_def.numeric, type_def.name) then
                    return true
                end
            end
        end
    end

    return false
end

function dispel_engine.find_best_target(opts)
    if not opts or not opts.candidates or not opts.priorities then
        return nil, nil
    end

    local extract_unit = opts.extract_unit or function(entry) return entry end
    local get_hp = opts.get_hp or function() return 1 end
    local can_consider = opts.can_consider or function() return true end

    local best_target = {}
    local best_hp = {}

    local function consider(entry)
        local unit = extract_unit(entry)
        if not unit or not unit.is_valid or not unit:is_valid() or unit:is_dead() then
            return
        end
        if not can_consider(unit, entry) then
            return
        end

        for idx, priority in ipairs(opts.priorities) do
            local should_skip = priority.skip and priority.skip(unit, entry)
            if not should_skip and dispel_engine.unit_has_type(unit, priority.type_def, opts.buff_manager) then
                local hp = get_hp(unit, entry)
                if hp == nil then hp = 1 end
                if (not best_target[idx]) or hp < best_hp[idx] then
                    best_target[idx] = unit
                    best_hp[idx] = hp
                end
                break
            end
        end
    end

    if opts.preferred_target then
        consider(opts.preferred_target)
    end

    for _, entry in ipairs(opts.candidates) do
        consider(entry)
    end

    for idx, priority in ipairs(opts.priorities) do
        if best_target[idx] then
            return best_target[idx], priority
        end
    end

    return nil, nil
end

return dispel_engine
