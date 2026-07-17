-- leveling_ladder_helper.lua -- helpers for verifying leveling rotations at specific level bands.
-- WHAT:  load a leveling spec and assert at least one strategy matches at each level band.
-- WHEN:  run via run_leveling_tests.lua.
-- WHY:   catches dead rotations and over-strict gates at low level.
-- SAFETY: pure mocks; no real API calls.

local M = {}

local default_ns = {
    log = function() end,
    log_warning = function() end,
    log_error = function() end,
    spell_ready = function(spell, target, opts) return true end,
    spell_exists = function(spell) return true end,
    is_spell_learned = function(spell) return true end,
    try_cast = function(spell, target, label) return true end,
    buff_up = function(unit, ids) return false end,
    debuff_up = function(unit, ids) return false end,
    debuff_remains = function(unit, ids) return 0 end,
    buff_remains = function(unit, ids) return 0 end,
    has_form = function(form) return true end,
    is_behind_target = function(target) return true end,
    is_stealthed = function() return false end,
    rotation_registry = { register = function() end },
}

function M.make_context(level, extra)
    local ctx = {
        level = level,
        player_level = level,
        has_valid_enemy_target = true,
        target = {},
        in_combat = true,
        is_group = false,
        enemy_count = 1,
        settings = {},
        is_leveling = true,
    }
    if extra then
        for k, v in pairs(extra) do
            ctx[k] = v
        end
    end
    return ctx
end

function M.make_state(level, extra)
    local state = {
        level = level,
        hp = 100,
        hp_pct = 100,
        mana_pct = 100,
        rage = 100,
        energy = 100,
        combo_points = 5,
        enemy_count = 1,
        in_combat = true,
        has_valid_enemy_target = true,
    }
    if extra then
        for k, v in pairs(extra) do
            state[k] = v
        end
    end
    return state
end

function M.run_ladder(spec_path, level_bands, ns_overrides, state_overrides)
    local ns = {}
    for k, v in pairs(default_ns) do
        ns[k] = v
    end
    if ns_overrides then
        for k, v in pairs(ns_overrides) do
            ns[k] = v
        end
    end

    ns.me = ns.me or {
        get_health_percentage = function() return 100 end,
        get_health = function() return 10000 end,
        get_max_health = function() return 10000 end,
        get_mana = function() return 5000 end,
        get_max_mana = function() return 5000 end,
        get_mana_percentage = function() return 100 end,
        get_energy = function() return 100 end,
        get_combo_points = function() return 5 end,
        get_rage = function() return 100 end,
        get_focus = function() return 100 end,
        get_power = function(type) return 100 end,
        get_level = function() return 70 end,
        is_valid = function() return true end,
    }
    ns.GetPlayer = function() return ns.me end

    local class_names = { "Warrior", "Paladin", "Hunter", "Rogue", "Priest", "Mage", "Warlock", "Druid", "Shaman", "DeathKnight" }
    for _, class in ipairs(class_names) do
        local key = class .. "Spells"
        if not ns[key] then
            ns[key] = setmetatable({}, { __index = function(_, spell_field) return spell_field end })
        end
    end

    _G.EaxRotations = ns
    local ok, result = pcall(dofile, spec_path)
    _G.EaxRotations = nil

    if not ok then
        error("failed to load " .. spec_path .. ": " .. tostring(result))
    end

    local strategies = result.strategies or result
    if type(strategies) ~= "table" or #strategies == 0 then
        error(spec_path .. " has no strategies (returned " .. type(result) .. ")")
    end

    local failures = {}
    for _, level in ipairs(level_bands) do
        local ctx = M.make_context(level, state_overrides)
        local state = M.make_state(level, state_overrides)
        if result and type(result.build_state) == "function" then
            local ok, built = pcall(result.build_state, ctx)
            if ok and built and type(built) == "table" then
                local mt = getmetatable(built)
                if mt and mt.__pairs then
                    local iter, t, k = mt.__pairs(built)
                    for k2, v2 in iter, t, k do
                        state[k2] = v2
                    end
                else
                    for k, v in pairs(built) do
                        state[k] = v
                    end
                end
            end
        end
        local matched = false
        for i = 1, #strategies do
            local s = strategies[i]
            if s.matches and s.matches(ctx, state) then
                matched = true
                break
            end
        end
        if not matched then
            failures[#failures + 1] = level
        end
    end

    return failures
end

return M
