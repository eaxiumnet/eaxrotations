-- pull_optimizer.lua
-- Shared pull speed optimization for leveling 1-70.
-- Detects trivial targets and adjusts rotation for faster kills.

local pull_optimizer = {}

local THROTTLE_INTERVAL = 0.5

function pull_optimizer.is_trivial_target(me, target)
    if not me or not target or not target:is_valid() or target:is_dead() then
        return false
    end
    local player_level = me.get_level and me:get_level() or 70
    local target_level = target.get_level and target:get_level() or 70
    return (player_level - target_level) > 10
end

function pull_optimizer.should_use_instant_only(me, target)
    return pull_optimizer.is_trivial_target(me, target)
end

function pull_optimizer.should_skip_expensive_spell(me, target, spell_cost)
    if not pull_optimizer.is_trivial_target(me, target) then
        return false
    end
    return spell_cost and spell_cost > 15
end

function pull_optimizer.get_target_ttd_estimate(me, target)
    if not target or not target:is_valid() or target:is_dead() then
        return 999
    end
    local hp = target.get_health_percentage and target:get_health_percentage() or 100
    local player_level = me.get_level and me:get_level() or 70
    local target_level = target.get_level and target:get_level() or 70
    local level_diff = player_level - target_level
    if level_diff > 15 then
        return hp / 100 * 2
    elseif level_diff > 10 then
        return hp / 100 * 4
    end
    return 999
end

return pull_optimizer
