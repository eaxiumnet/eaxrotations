-- Readability notes:
--   What: runtime module.
--   When: loaded by bootstrap or tests when required.
--   Why: keeps related behavior in one auditable file.
--   Safety: use NS helpers, guard nil values, and avoid hot-path allocations.

-- Decision notes:
--   This support module keeps side effects explicit and routes runtime-sensitive work through NS helpers.
--   Comments emphasize intent and constraints so future edits preserve behavior without adding frame-costly checks.
--   When API data is missing, callers should skip unsafe work rather than guessing.
-- ============================================================================
-- EaxRotations - Decision Cache (Project Sylvanas API)
-- Memoization layer for rotation decisions: avoids redundant checks per frame
-- Note: strategy registry
-- itself is the optimizer. DecisionCache is the only useful optimization
-- primitive that doesn't duplicate what the registry already does.
-- ============================================================================

local NS = _G.EaxRotations
if not NS then
    print("[EaxRotations ERROR] Core module not loaded!")
    return
end

local core = NS.core or _G.core or {}
local function current_time()
    if core and type(core.time) == "function" then
        local ok, value = pcall(core.time)
        if ok and type(value) == "number" then return value end
    end
    return 0
end
-- izi removed: unused (DecisionCache uses core time directly)

-- ============================================================================
-- DECISION CACHE
-- Memoizes function results for a single "generation" (frame window).
-- Invalidation triggers:
--   1. Combat state change
--   2. Cast start/end
--   3. Major aura gain/loss
--   4. Resource threshold crossing
--   5. Time advancement (> 0.1s)
-- ============================================================================
local DecisionCache = {
    cache = {},
    generation = 0,
    last_invalidation_time = 0,
    -- Track previous-frame state to detect change triggers
    _prev_in_combat = nil,
    _prev_casting = nil,
    _prev_mana_pct = nil,
    _prev_hp_pct = nil,
}

--- Increment generation to invalidate all cached values
function DecisionCache:invalidate()
    self.generation = self.generation + 1
    for key in pairs(self.cache) do
        self.cache[key] = nil
    end
    self.last_invalidation_time = current_time()
end

--- Memoize a function result for the current generation
-- @param key string - Cache key (use strategy name or unique identifier)
-- @param fn function - Function to compute value
-- @return any - Cached or computed value
-- [#31] NOTE: No class, strategy, or middleware currently calls DecisionCache:memoize().
-- The check_invalidation() call in main_sylvanas.lua still runs every tick,
-- which provides value (generation tracking, state delta detection) even without
-- memoize() consumers. The invalidation logic is lightweight and detects
-- combat/cast/resource state changes between ticks.
--
-- To activate memoization: wrap expensive per-tick computations like
-- collect_healing_units, GetEnemiesInRange, has_phys_immunity in:
--   DecisionCache:memoize("heal_units", function() return NS.collect_healing_units() end)
-- This would avoid redundant work when multiple strategies query the same data
-- within the same generation (0.1s window).
function DecisionCache:memoize(key, fn)
    local entry = self.cache[key]
    if entry and entry.gen == self.generation then
        return entry.value
    end

    local value = fn()
    self.cache[key] = { gen = self.generation, value = value }
    return value
end

--- Check if cache should be invalidated based on state changes
-- Call once per frame from the main rotation loop
-- @param context table - Current rotation context
function DecisionCache:check_invalidation(context)
    local now = current_time()
    local me = context and context.me

    if not me then return end

    -- Trigger 5: Time advancement (> 0.1s)
    if (now - self.last_invalidation_time) > 0.1 then
        self:invalidate()
        -- Record state at time of invalidation for delta detection
        self._prev_in_combat = context.in_combat
        self._prev_casting = context.casting_or_channeling
        self._prev_mana_pct = context.mana_pct
        self._prev_hp_pct = context.hp
        return
    end

    local needs_invalidate = false

    -- Trigger 1: Combat state change
    if context.in_combat ~= self._prev_in_combat then
        needs_invalidate = true
    end

    -- Trigger 2: Cast start/end
    if context.casting_or_channeling ~= self._prev_casting then
        needs_invalidate = true
    end

    -- Trigger 3: Major aura changes handled implicitly by time-based
    -- invalidation (0.1s window is short enough that aura changes are
    -- picked up). For instant invalidation on specific aura events,
    -- call DecisionCache:invalidate() directly from the aura handler.

    -- Trigger 4: Resource threshold crossing (mana dropped below 50%,
    -- HP dropped below 30%, etc.)
    local prev_mana = self._prev_mana_pct or 100
    local cur_mana = context.mana_pct or 100
    if (prev_mana >= 50 and cur_mana < 50) or (prev_mana >= 20 and cur_mana < 20) then
        needs_invalidate = true
    end

    local prev_hp = self._prev_hp_pct or 100
    local cur_hp = context.hp or 100
    if (prev_hp >= 30 and cur_hp < 30) then
        needs_invalidate = true
    end

    if needs_invalidate then
        self:invalidate()
        self._prev_in_combat = context.in_combat
        self._prev_casting = context.casting_or_channeling
        self._prev_mana_pct = context.mana_pct
        self._prev_hp_pct = context.hp
    end
end

--- Get cache statistics (for diagnostics)
-- @return table - { entries, generation, age }
function DecisionCache:get_stats()
    local count = 0
    for _ in pairs(self.cache) do count = count + 1 end
    return {
        entries = count,
        generation = self.generation,
        age = current_time() - self.last_invalidation_time,
    }
end

NS.DecisionCache = DecisionCache

NS.log("DecisionCache module loaded")

-- Return the optimizer module
return {
    DecisionCache = DecisionCache,
}
