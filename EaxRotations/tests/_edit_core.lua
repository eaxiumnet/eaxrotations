-- This is a Python script saved as .lua so write_file works
-- It edits core_sylvanas.lua to add category caching and inline strategy_allowed
-- Run with: python EaxRotations/tests/_edit_core.lua
-- (the .lua extension is just to fit within write_file restrictions)

import sys
import os

os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

with open('core_sylvanas.lua', 'r') as f:
    content = f.read()

# === Edit 1: strategy_category - add per-playstyle cache ===
old_cat = """local function strategy_category(strategy, list_name, active)

    if type(strategy) ~= "table" then return "damage" end

    if type(strategy.category) == "string" then return strategy.category end

    local name = tostring(strategy.name or ""):gsub("%s+", ""):lower()

    if contains_any(name, HEALING_NAMES) then return "healing" end

    if contains_any(name, DEFENSIVE_NAMES) then return "utility" end

    if strategy.is_burst or contains_any(name, COOLDOWN_NAMES) then return "cooldown" end

    if contains_any(name, UTILITY_NAMES) then return "utility" end

    if list_name == "middleware" then return "utility" end

    if HEALING_PLAYSTYLES[tostring(active or ""):lower()] then

        if contains_any(name, DAMAGE_NAMES) then return "damage" end

        return "healing"

    end

    return "damage"

end"""

new_cat = """local function strategy_category(strategy, list_name, active)

    if type(strategy) ~= "table" then return "damage" end

    if type(strategy.category) == "string" then return strategy.category end

    -- Per-playstyle cache: category is stable for same active playstyle
    local cat_cache = strategy._cat_cache
    if cat_cache and cat_cache[active] then return cat_cache[active] end
    if not cat_cache then cat_cache = {}; strategy._cat_cache = cat_cache end

    local name = tostring(strategy.name or ""):gsub("%s+", ""):lower()

    local cat
    if contains_any(name, HEALING_NAMES) then cat = "healing"
    elseif contains_any(name, DEFENSIVE_NAMES) then cat = "utility"
    elseif strategy.is_burst or contains_any(name, COOLDOWN_NAMES) then cat = "cooldown"
    elseif contains_any(name, UTILITY_NAMES) then cat = "utility"
    elseif list_name == "middleware" then cat = "utility"
    elseif HEALING_PLAYSTYLES[tostring(active or ""):lower()] then
        if contains_any(name, DAMAGE_NAMES) then cat = "damage"
        else cat = "healing" end
    else cat = "damage"
    end

    cat_cache[active] = cat
    return cat
end"""

count = content.count(old_cat)
print('strategy_category occurrences:', count)
if count == 1:
    content = content.replace(old_cat, new_cat, 1)
    print('strategy_category REPLACED OK')
else:
    print('ERROR: expected 1 strategy_category, found', count)
    sys.exit(1)

# === Edit 2: run_unified_strategies - precompute settings, inline allowed ===
old_run = """    for i = 1, #NS.unified_registry do

        local s = NS.unified_registry[i]

        -- Filter by playstyle: _global strategies run in all playstyles; nil defaults to _global

        local ps = s.playstyle

        if (not ps or ps == "_global" or ps == active) and NS.strategy_allowed(s, nil, active, context) then

            local ok = true

            if type(s.matches) == "function" then ok = s.matches(context, state) == true end

            if ok and safe_fn(s.execute, context, state) then return true end

        end

    end"""

new_run = """    -- Precompute tick-constant settings for strategy gating
    local settings = context and context.settings or EMPTY
    local is_healer = HEALING_PLAYSTYLES[tostring(active or ""):lower()] == true
    local utility_enabled = settings.utility_enabled
    local healing_enabled = settings.healing_enabled
    local damage_enabled = settings.damage_enabled
    local use_cooldowns = settings.use_cooldowns
    local should_burst = context and context.should_burst

    for i = 1, #NS.unified_registry do

        local s = NS.unified_registry[i]

        -- Filter by playstyle: _global strategies run in all playstyles; nil defaults to _global

        local ps = s.playstyle

        if not ps or ps == "_global" or ps == active then
            -- Inline strategy_allowed checks (avoid per-strategy function call + settings lookup)
            local category = strategy_category(s, nil, active)
            local gated = (utility_enabled == false and category == "utility")
                or (healing_enabled == false and (category == "healing" or (is_healer and category == "cooldown")))
                or (damage_enabled == false and (category == "damage" or (category == "cooldown" and not is_healer)))
                or (use_cooldowns == false and category == "cooldown" and not should_burst)
            if not gated then
                local ok = true
                if type(s.matches) == "function" then ok = s.matches(context, state) == true end
                if ok and safe_fn(s.execute, context, state) then return true end
            end
        end

    end"""

count2 = content.count(old_run)
print('run_unified_strategies occurrences:', count2)
if count2 == 1:
    content = content.replace(old_run, new_run, 1)
    print('run_unified_strategies REPLACED OK')
else:
    print('ERROR: expected 1 run_unified_strategies, found', count2)
    sys.exit(1)

with open('core_sylvanas.lua', 'w') as f:
    f.write(content)
print('ALL EDITS COMPLETE')
