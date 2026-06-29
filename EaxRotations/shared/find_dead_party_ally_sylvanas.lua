-- find_dead_party_ally_sylvanas.lua -- Locate dead party ally for combat-res / ress macro..
-- WHAT:   Locate dead party ally for combat-res / ress macro.
-- WHEN:   called per-frame when no enemy target; only in group context
-- WHY:    centralises dead-ally lookup shared by priest/paladin/shamy
-- SAFETY: PCalled on GetPartyFrames; nil-guarded party list
-- DECISION: pure helper consumed via require() by specs; no on_update side-effects.

-- Pure function extracted from core_sylvanas.lua for reuse in tests.
-- All NS/api/ dependencies are injected via the deps table for testability.
--

local ipairs = ipairs
local M = {}

--- Find a dead friendly ally for combat resurrection (Rebirth, Soulstone, etc.)
-- Priority: mouseover > current target > party/raid scan
-- @param deps table - Injected dependencies:
--   - get_player function() -> player object (with get_mouseover, get_target)
--   - collect_healing_units function() -> array of unit objects
-- @return table|nil - The dead ally unit, or nil
-- [PRE-ALLOC] Reusable empty table for `deps or {}` fallback.
-- Avoids creating a new table per frame when deps is nil (Lua 5.1 GC pressure).
-- Safe because find_dead_party_ally only READS from deps, never writes.
local EMPTY_DEPS = {}

function M.find_dead_party_ally(deps)
    deps = deps or EMPTY_DEPS
    local get_player = deps.get_player
    local collect_healing_units = deps.collect_healing_units
    local get_mouseover = deps.get_mouseover

    local me = get_player and get_player() or nil
    if not me then return nil end

    -- Priority 1: Mouseover (explicit user intent)
    local mouseover = get_mouseover and get_mouseover() or nil
    if mouseover and mouseover.is_valid and mouseover:is_valid()
        and mouseover.is_dead_or_ghost and mouseover:is_dead_or_ghost()
        and mouseover.is_valid_ally and mouseover:is_valid_ally() then
        return mouseover
    end

    -- Priority 2: Current target (user targeted the dead ally manually)
    local target = me.get_target and me:get_target() or nil
    if target and target.is_valid and target:is_valid()
        and target.is_dead_or_ghost and target:is_dead_or_ghost()
        and target.is_valid_ally and target:is_valid_ally() then
        return target
    end

    -- Priority 3: Scan party/raid members for any dead ally
    local units = collect_healing_units and collect_healing_units() or nil
    if not units then return nil end

    local best_unit = nil
    local best_hp_pct = 0  -- Prefer dead allies with lowest HP% (= most recently died)
    for _, unit in ipairs(units) do
        if unit and unit.is_valid and unit:is_valid()
            and unit.is_dead_or_ghost and unit:is_dead_or_ghost()
            and unit.is_valid_ally and unit:is_valid_ally() then
            -- Prefer dead player characters (not NPCs), and among players prefer lower HP%
            local is_player = unit.is_player and unit:is_player()
            local hp_pct = unit.get_health_percentage and unit:get_health_percentage() or 0
            if is_player then
                if not best_unit or hp_pct < best_hp_pct then
                    best_unit = unit
                    best_hp_pct = hp_pct
                end
            end
        end
    end

    -- Fallback: any dead friendly NPC if no dead player found
    if not best_unit then
        for _, unit in ipairs(units) do
            if unit and unit.is_valid and unit:is_valid()
                and unit.is_dead_or_ghost and unit:is_dead_or_ghost()
                and unit.is_valid_ally and unit:is_valid_ally() then
                best_unit = unit
                break
            end
        end
    end

    return best_unit
end

_G.FindDeadPartyAlly = M
return M
