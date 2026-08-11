-- shared/warlock_healthstone_sylvanas.lua — Shared Warlock Healthstone auto-use logic.
-- WHAT:  centralized match/execute helpers for Healthstone (and fallback healing potion).
-- WHEN:  any warlock spec wants an auto-healthstone strategy.
-- WHY:   avoids duplicating the same gating (use_auto_consumables, use_healthstones,
--         HP threshold, casting guard) in middleware + specs.
-- SAFETY: nil-guards on all context/state fields; supports both state.healthstone_id
--          (spec build_state) and live bag-scan modes.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")

-- Cache the optional consumable_manager at load time to avoid a hot-path require.
local _cm_ok, _consumable_manager = pcall(require, "shared/consumable_manager_sylvanas")
if not _cm_ok then _consumable_manager = nil end

-- Default TBC healthstone item IDs (best-to-worst).
local DEFAULT_HEALTHSTONE_IDS = {
    22105, 22104, 22103, 22102, 22101, 22100,
    19013, 19012, 19011, 19010, 19009, 19008, 19007, 19006, 19005, 19004,
    5512, 5511, 5510
}

-- Build a strategy table for auto-healthstone consumption.
--
-- `name` is the strategy name (e.g. "Healthstone" or "Warlock_Healthstone").
-- `opts` is an optional table:
--   - healthstone_ids: list of item IDs to try in order (default DEFAULT_HEALTHSTONE_IDS)
--   - fallback_potion_ids: list of healing potion item IDs to try if no healthstone works
--   - use_state_id: if true, execute uses state.healthstone_id directly instead of scanning bags
--   - allow_while_casting: if true, the strategy can match while the player is casting (default false)
--   - require_in_combat: if true, the strategy only matches while in combat (default true)
--   - use_consumable_manager: if true, use shared/consumable_manager_sylvanas for a cached bag scan
--   - priority: optional priority value for the strategy table
--   - is_defensive: optional flag for the strategy table
--
-- When use_state_id is true, callers are expected to populate:
--   state.healthstone_ready (boolean) and state.healthstone_id (number)
-- Otherwise the helper scans the provided item lists on every match/execute.
local function make_strategy(name, opts)
    opts = opts or {}
    local healthstone_ids = opts.healthstone_ids or DEFAULT_HEALTHSTONE_IDS
    local fallback_potion_ids = opts.fallback_potion_ids or {}
    local use_state_id = opts.use_state_id or false
    local allow_while_casting = opts.allow_while_casting or false
    local require_in_combat = opts.require_in_combat ~= false  -- default true
    local use_consumable_manager = opts.use_consumable_manager or false

    local strategy = {
        name = name or "Healthstone",
        matches = function(context, state)
            if require_in_combat and not context.in_combat then return false end
            if not spec_kit.setting_bool(context, "use_auto_consumables", true) then return false end
            if not spec_kit.setting_bool(context, "use_healthstones", true) then return false end
            local threshold = spec_kit.setting_number(context, "healthstone_hp", 0)
            if threshold <= 0 then return false end
            if (context.hp or 100) > threshold then return false end
            if not allow_while_casting and context.is_casting then return false end

            if use_state_id then
                return state and state.healthstone_ready or false
            end

            -- Cached fast-path via consumable_manager when requested.
            if use_consumable_manager and _consumable_manager and type(_consumable_manager.has_any_consumable) == "function" then
                local ids = {}
                local seen = {}
                local add = function(id)
                    if type(id) == "number" and id > 0 and not seen[id] then
                        seen[id] = true
                        ids[#ids + 1] = id
                    end
                end
                for _, id in ipairs(healthstone_ids) do add(id) end
                for _, id in ipairs(fallback_potion_ids) do add(id) end
                if #ids > 0 and not _consumable_manager.has_any_consumable(ids) then
                    return false
                end
                return true
            end

            -- Live bag-scan fallback: make sure at least one item is in bags.
            local has_any = false
            if NS.has_item then
                for _, id in ipairs(healthstone_ids) do
                    if NS.has_item(id) then has_any = true; break end
                end
                if not has_any then
                    for _, id in ipairs(fallback_potion_ids) do
                        if NS.has_item(id) then has_any = true; break end
                    end
                end
            end
            return has_any
        end,
        execute = function(context, state)
            if use_state_id then
                if state and state.healthstone_id and NS.use_item_by_id then
                    return NS.use_item_by_id(state.healthstone_id)
                end
                return false
            end

            local me = context.me or NS.PLAYER_UNIT
            -- Try Healthstone first (item-based, has CD)
            if NS.use_item and me then
                for _, item_id in ipairs(healthstone_ids) do
                    if NS.use_item(item_id, me) then
                        return true
                    end
                end
            end

            -- Fallback: Healing Potion if no Healthstone used
            if #fallback_potion_ids > 0 and NS.use_item and me then
                for _, item_id in ipairs(fallback_potion_ids) do
                    if NS.use_item(item_id, me) then
                        return true
                    end
                end
            end
            return false
        end,
    }

    if opts.priority then strategy.priority = opts.priority end
    if opts.is_defensive then strategy.is_defensive = opts.is_defensive end

    return strategy
end

return {
    make_strategy = make_strategy,
}

