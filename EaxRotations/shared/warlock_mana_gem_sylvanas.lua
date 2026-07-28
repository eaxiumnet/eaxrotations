-- shared/warlock_mana_gem_sylvanas.lua — Shared Warlock ManaGem auto-use logic.
-- WHAT:  centralized match/execute helpers for ManaGem-style mana consumables.
-- WHEN:  any warlock spec wants an auto-mana-item strategy.
-- WHY:   avoids duplicating the same threshold + state.mana_gem_ready gating.
-- SAFETY: nil-guards on all context/state fields.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")

-- Build a strategy table for auto-mana-item consumption.
--
-- `name` is the strategy name (default "ManaGem").
-- `setting_key` is the setting that controls the mana % threshold.
-- `default_threshold` is the fallback threshold when the setting is missing.
local function make_strategy(name, setting_key, default_threshold)
    setting_key = setting_key or "destro_mana_gem_threshold"
    default_threshold = default_threshold or 35

    return {
        name = name or "ManaGem",
        matches = function(context, state)
            local threshold = spec_kit.setting_number(context, setting_key, default_threshold)
            if (state.mana_pct or 100) > threshold then return false end
            return state.mana_gem_ready or false
        end,
        execute = function(context, state)
            local id = state and state.mana_gem_id
            if id and NS.use_item_by_id then
                NS.use_item_by_id(id)
                return true
            end
            return false
        end,
    }
end

return {
    make_strategy = make_strategy,
}
