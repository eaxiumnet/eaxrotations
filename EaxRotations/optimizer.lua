-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "optimizer.lua"
local __eax_version = "1.1.1"
local __eax_modified = "2026-05-27"
local __eax_change = "File version stamp for runtime load verification"
local __eax_versions = rawget(_G, "EaxRotationsFileVersions") or {}
_G.EaxRotationsFileVersions = __eax_versions
__eax_versions[__eax_file] = { version = __eax_version, modified = __eax_modified, change = __eax_change }
local __eax_core = rawget(_G, "core")
if type(__eax_core) == "table" and type(__eax_core.log) == "function" then
    pcall(__eax_core.log, "[EaxRotations] Loaded " .. __eax_file .. " v" .. __eax_version)
end
local __eax_ns = rawget(_G, "EaxRotations")
if type(__eax_ns) == "table" then __eax_ns.file_versions = __eax_versions end
-- runtime module.

-- ============================================================================
-- EaxRotations - Decision Cache (Project Sylvanas API)
-- State tracking layer for rotation invalidation: detects combat/cast/resource changes
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
-- Tracks state changes across frames for rotation invalidation.
-- Invalidation triggers:
--   1. Combat state change
--   2. Cast start/end
--   3. Major aura gain/loss
--   4. Resource threshold crossing
--   5. Time advancement (> 0.1s)
-- ============================================================================
local DecisionCache = {
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
    self.last_invalidation_time = current_time()
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
    return {
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
