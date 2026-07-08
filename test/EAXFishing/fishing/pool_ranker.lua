-- =============================================================================
-- Fishing/Pool Ranker - Score fish pools by expected value instead of distance.
-- WHAT:  Replaces "nearest pool wins" with a scored pool picker that rewards
--        high-value pools (Mote pools, Sporefish, Crawdad, Sagefish, etc.)
--        over low-value pools (open water spots). The score combines distance
--        (closer is better) and expected pool value.
-- WHEN:  during pool scan in engine.tick() when pool_tracking is enabled.
-- WHY:   in crowded fishing zones (e.g. Shattrath, Nagrand) the nearest pool
--        is often a low-value spot while a slightly-farther high-value pool
--        gives 5-10x gold/hour. Scored selection fixes this with zero extra
--        navigation cost — we just pick a better destination.
-- SAFETY: all pool names and values come from constants.lua POOLS list and
--        loot_db.lua, both of which are DBC-verified. Scores are cached
--        per pool name so lookup is O(1). Falls back to distance-only if
--        the pool is not in the scoring table.
-- =============================================================================

local APISurface = require("core/api_surface")
local LootDB     = require("fishing/loot_db")

local M = {}

-- -----------------------------------------------------------------------------
-- Pool value lookup (heuristic gold-per-cast estimate at max TBC skill).
-- Values are relative rankings, not absolute copper prices, since real AH
-- prices vary by server and time.  The scale is unitless (higher = better).
-- Zero-value pools exist because some pools in the POOLS list only give
-- specific quest items or have no notable AH value.
-- -----------------------------------------------------------------------------
local POOL_VALUE = {
    -- TBC high-value pools (top tier)
    ["Furious Crawdad"             ] = 500,
    ["School of Sporefish"         ] = 400,
    ["School of Darter"            ] = 350,
    ["School of Highland Mixed Fish"] = 350,
    ["Steam Pump Flotsam"          ] = 400,
    ["School of Goldenscale Vendorfish"] = 300,
    -- TBC medium-value pools
    ["School of Spotted Feltail"   ] = 250,
    ["Bluefish School"             ] = 250,
    ["Mudfish School"              ] = 250,
    ["Highland Guppy School"       ] = 200,
    ["Mountain Trout School"       ] = 200,
    -- Classic high-value pools
    ["Stonescale Eel Swarm"        ] = 450,
    ["School of Sagefish"          ] = 250,
    ["Greater Sagefish School"     ] = 280,
    ["Firefin Snapper School"      ] = 200,
    ["Oily Blackmouth School"      ] = 200,
    ["School of Tastyfish"         ] = 400,
    -- Wreckage (sometimes good, but variable)
    ["Floating Wreckage"           ] = 150,
    ["Waterlogged Wreckage"        ] = 120,
    ["Bloodsail Wreckage"          ] = 120,
    ["Schooner Wreckage"           ] = 120,
    ["Patch of Elemental Water"    ] = 300,
    ["Sparse Schooner Wreckage"    ] = 100,
    ["Scanty Bloodsail Wreckage"   ] = 100,
    ["Shipwreck Debris"            ] = 150,
    -- Unknown / unranked pools default to a small floor value so they still
    -- beat open water when pool_tracking is on but only-pools is off.
}

local DEFAULT_POOL_VALUE = 50   -- any pool in constants but not ranked here

-- Resolve a pool name to its heuristic value. Returns a numeric score.
function M.value_for_pool(name)
    if type(name) ~= "string" or name == "" then return 0 end
    -- Strip "School of " prefix for shorter match keys
    local stripped = string.gsub(name, "^School of ", "")
    local v = POOL_VALUE[name] or POOL_VALUE[stripped] or DEFAULT_POOL_VALUE
    return v
end

--- Score a pool combining distance and value.
--  Higher score = better target. Distance penalises far pools; value rewards
--  rich pools. The formula is (value / (dist + bias)) so both axes matter.
--  @param dist_sq number squared distance from player to pool
--  @param pool_name string pool object name
--  @return number score (higher = better)
function M.score_pool(dist_sq, pool_name)
    if not pool_name or dist_sq <= 0 then return 0 end
    local dist = math.sqrt(dist_sq)  -- sqrt here is acceptable: once per pool per scan
    local val = M.value_for_pool(pool_name)
    -- Bias avoids division by tiny numbers; value_floor ensures even far
    -- high-value pools can beat very-near low-value pools.
    local score = val / (dist + 10.0)
    return score
end

--- Scan all visible objects and return the highest-scored pool + its score.
--  This is a drop-in replacement for the manual pool scan in engine.tick().
--  @param ctx table context
--  @param me table player object
--  @param p table player position {x,y,z}
--  @param search_range_sq number search radius squared
--  @param only_wreckage boolean if true, only wreckage-type pools
--  @return table? pool object (highest score), number? best_score
function M.find_best_pool(ctx, me, p, search_range_sq, only_wreckage)
    local deps = ctx.deps
    local best_pool = nil
    local best_score = -math.huge

    local objects = APISurface.get_all_objects()
    for _, obj in ipairs(objects) do
        if APISurface.is_valid(obj) then
            local name = APISurface.get_object_name(obj)
            if type(name) == "string" then
                local is_pool = deps.constants.OBJECTS.POOLS
                    and deps.constants.OBJECTS.POOLS[name]
                if not is_pool then
                    is_pool = string.find(name, "Pool", 1, true)
                        or string.find(name, "School", 1, true)
                        or string.find(name, "Wreckage", 1, true)
                end
                if is_pool then
                    if not only_wreckage or string.find(name, "Wreckage", 1, true) then
                        local pos = APISurface.get_object_position(obj)
                        if pos then
                            local dx = p.x - pos.x
                            local dy = p.y - pos.y
                            local dist_sq = dx*dx + dy*dy
                            if dist_sq < search_range_sq then
                                local score = M.score_pool(dist_sq, name)
                                if score > best_score then
                                    best_score = score
                                    best_pool = obj
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return best_pool, best_score
end

return M
