-- ============================================================================
-- Shared Helper: AoE Heal Optimizer
-- ============================================================================
-- What:   Finds optimal targets for AoE healing spells by evaluating clusters
--         of injured allies within spell radius, including Chain Heal bounce
--         simulation.
-- When:   Called by healer specs when multiple allies are injured and an AoE
--         heal spell is available.
-- Why:    AoE heals are most mana-efficient when they hit the most injured
--         cluster of allies. Naive "count below HP" checks miss positioning.
-- Safety: All distance checks use squared values. Nil-guarded throughout.
--
-- Usage:
--   local aoe = NS.AoEHeal
--   local best = aoe.best_target(entries, count, 12, 3)  -- 12yd radius, 3+ targets
--   local chain = aoe.chain_heal_target(entries, count, 12.5, 3)  -- bounce simulation
-- ============================================================================

local _G = _G
local NS = _G.EaxRotations
if not NS then return end

local math_max = math.max
local math_min = math.min

local M = {}
NS.AoEHeal = M

-- ---------------------------------------------------------------------------
-- Distance helper (squared)
-- ---------------------------------------------------------------------------
local function distance_sq(unit_a, unit_b)
    if not unit_a or not unit_b then return 99999 end
    local ok, dist = pcall(function()
        if unit_a.get_distance then return unit_a:get_distance(unit_b) end
        return nil
    end)
    if ok and type(dist) == "number" then
        return dist * dist
    end
    return 99999
end

local function distance(unit_a, unit_b)
    if not unit_a or not unit_b then return 99999 end
    local ok, dist = pcall(function()
        if unit_a.get_distance then return unit_a:get_distance(unit_b) end
        return nil
    end)
    if ok and type(dist) == "number" then
        return dist
    end
    return 99999
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

--- Find the best target for an AoE heal by evaluating clusters of injured allies.
-- For each injured entry, counts how many other injured entries are within
-- `radius` yards. Returns the entry with the highest cluster deficit sum.
---@param entries table Healing entries from build_healing_entries
---@param count number Number of entries
---@param radius number AoE spell radius in yards
---@param min_targets number Minimum targets to be worth casting
---@return table|nil best_entry The best center target, or nil if no cluster found
---@return number hit_count Number of targets in the cluster
---@return number total_deficit Total deficit of the cluster
function M.best_target(entries, count, radius, min_targets)
    if not entries or count < min_targets then return nil, 0, 0 end

    local radius_sq = radius * radius
    local best_entry = nil
    local best_deficit = 0
    local best_count = 0

    for i = 1, count do
        local center = entries[i]
        local center_unit = center.unit
        if center_unit then
            local cluster_deficit = center.deficit or 0
            local cluster_count = 1

            for j = 1, count do
                if i ~= j then
                    local other = entries[j]
                    if other.unit and distance_sq(center_unit, other.unit) <= radius_sq then
                        cluster_deficit = cluster_deficit + (other.deficit or 0)
                        cluster_count = cluster_count + 1
                    end
                end
            end

            if cluster_count >= min_targets and cluster_deficit > best_deficit then
                best_deficit = cluster_deficit
                best_count = cluster_count
                best_entry = center
            end
        end
    end

    return best_entry, best_count, best_deficit
end

--- Simulate Chain Heal bouncing from a primary target to injured nearby allies.
-- Chain Heal jumps to the most injured ally within bounce_range of the previous
-- target, up to max_bounces times.
---@param entries table Healing entries
---@param count number Number of entries
---@param bounce_range number Chain Heal bounce range in yards (default 12.5)
---@param max_bounces number Maximum bounces (default 3, including primary)
---@return table|nil primary Best primary target
---@return number total_healing Estimated total healing across all bounces
---@return table bounce_targets Array of bounce target entries
function M.chain_heal_target(entries, count, bounce_range, max_bounces)
    bounce_range = bounce_range or 12.5
    max_bounces = max_bounces or 3

    if not entries or count < 1 then return nil, 0, {} end

    -- Chain Heal base healing (TBC rank 5: 1053-1157 per bounce, decaying)
    local BASE_HEAL = 1100
    local BOUNCE_DECAY = { 1.0, 0.65, 0.42 }  -- 100%, 65%, 42% per bounce

    local best_primary = nil
    local best_total = 0
    local best_bounces = {}

    for i = 1, count do
        local primary = entries[i]
        local primary_unit = primary.unit
        if primary_unit and (primary.deficit or 0) > 0 then
            local total = 0
            local bounces = { primary }
            local used = { [i] = true }

            -- Simulate bounce chain
            for bounce = 1, max_bounces do
                local current = bounces[#bounces]
                local current_unit = current.unit
                local heal_amount = BASE_HEAL * BOUNCE_DECAY[bounce]
                local best_next = nil

                -- Find nearest injured ally within bounce range
                for j = 1, count do
                    if not used[j] then
                        local other = entries[j]
                        if other.unit and (other.deficit or 0) > 0 then
                            local dist = distance(current_unit, other.unit)
                            if dist <= bounce_range then
                                if not best_next or (other.deficit or 0) > (best_next.deficit or 0) then
                                    best_next = other
                                end
                            end
                        end
                    end
                end

                if best_next then
                    -- Effective healing capped by target's deficit
                    local effective = math_max(0, math_min(heal_amount, (best_next.deficit or 0)))
                    total = total + effective
                    bounces[#bounces + 1] = best_next
                    -- Find index of best_next in entries
                    for j = 1, count do
                        if entries[j] == best_next then used[j] = true; break end
                    end
                else
                    break  -- No more bounce targets
                end
            end

            -- Add primary target healing
            total = total + BASE_HEAL * BOUNCE_DECAY[1]

            if total > best_total then
                best_total = total
                best_primary = primary
                best_bounces = bounces
            end
        end
    end

    return best_primary, best_total, best_bounces
end

--- Count injured allies within radius of a center point.
---@param entries table Healing entries
---@param count number Number of entries
---@param center_unit table Center unit for distance check
---@param radius number Radius in yards
---@return number injured_count Number of injured allies in radius
---@return number total_deficit Sum of deficits
function M.count_in_radius(entries, count, center_unit, radius)
    if not entries or count <= 0 or not center_unit then return 0, 0 end

    local radius_sq = radius * radius
    local injured = 0
    local deficit_sum = 0

    for i = 1, count do
        local entry = entries[i]
        if entry.unit and (entry.deficit or 0) > 0 then
            if distance_sq(center_unit, entry.unit) <= radius_sq then
                injured = injured + 1
                deficit_sum = deficit_sum + (entry.deficit or 0)
            end
        end
    end

    return injured, deficit_sum
end
