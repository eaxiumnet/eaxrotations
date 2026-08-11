-- burst_logic_sylvanas.lua -- should_auto_burst + offensive_autocast_match scoring helpers..
-- WHAT:   should_auto_burst + offensive_autocast_match scoring helpers.
-- WHEN:   called per-tick by melee/ranged specs when burstwindow is open
-- WHY:    centralises burst-window scoring into one dispatcher
-- SAFETY: pure scoring function; nil-guarded enemy list; no on_update allocs
-- DECISION: pure helper consumed via require() by specs; no on_update side-effects.

-- Pure functions extracted from core_sylvanas.lua for reuse in tests.
-- All NS/api/ dependencies are injected via the deps table for testability.
--

local M = {}

-- Bloodlust alignment timeout: if Bloodlust hasn't come by this many seconds
-- into combat, fire burst CDs anyway. Prevents holding CDs forever on fights
-- without a Shaman. Sim APL uses ~60s as the effective timeout; we use 45s
-- to avoid wasting the entire first CD usage window.
M.BLOODLUST_TIMEOUT_SECONDS = 45

--- Determine whether offensive cooldowns should auto-fire.
-- @param context table - Rotation context with settings, in_combat, etc.
-- @param deps table - Optional injected dependencies:
--   - is_bloodlust_active function(me) -> boolean
--   - is_drums_active function(me) -> boolean
-- @return boolean|nil - true (burst now), false (don't burst), nil (no config → fire on CD)
-- [PRE-ALLOC] Reusable empty table for `deps or {}` fallback.
-- Avoids creating a new table per frame when deps is nil (Lua 5.1 GC pressure).
-- Safe because should_auto_burst only READS from deps, never writes.
local EMPTY_DEPS = {}

function M.should_auto_burst(context, deps)
    deps = deps or EMPTY_DEPS
    local settings = context and context.settings
    if not settings then return nil end

    local any_configured = settings.burst_in_combat
        or settings.burst_on_pull
        or settings.burst_on_execute
        or settings.burst_on_bloodlust
    if not any_configured then return nil end

    if not context or not context.in_combat or not context.has_valid_enemy_target then
        return false
    end

    -- CD Min TTD gate: don't burst on dying targets
    local min_ttd = settings.cd_min_ttd or 0
    if min_ttd > 0 and (context.ttd or 999) < min_ttd then
        return false
    end

    if settings.burst_in_combat then return true end
    if settings.burst_on_pull and context.combat_time and context.combat_time < 5 then return true end
    if settings.burst_on_execute and context.target_hp and context.target_hp <= 20 then return true end
    if settings.burst_on_bloodlust then
        local me = context.me
        local bl_active = deps.is_bloodlust_active and deps.is_bloodlust_active(me) or false
        local drums_active = deps.is_drums_active and deps.is_drums_active(me) or false
        if bl_active or drums_active then return true end

        -- [BL-ALIGN] Timeout fallback: if we've been in combat long enough and
        -- Bloodlust still hasn't come, fire CDs anyway. This prevents holding CDs
        -- forever on fights without a Shaman or when Lust comes very late.
        -- Per sim APL: CDs aligned to Bloodlust have an effective ~45-60s timeout.
        -- Also allow if target is about to die (TTD ≤ 15s) — better to use CDs than waste them.
        local combat_time = context.combat_time or 0
        local ttd = context.ttd or 999
        if combat_time >= M.BLOODLUST_TIMEOUT_SECONDS or ttd <= 15 then
            return true
        end
    end

    return false
end


_G.BurstLogic = M
return M

