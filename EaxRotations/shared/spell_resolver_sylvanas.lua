-- spell_resolver_sylvanas.lua -- resolve a spell to its highest learned rank + valid id
-- WHAT:  given a name/id and the local player, return the active rank id
-- WHEN:  called from spec helpers and izi.spell() consumers
-- WHY:   lets specs request 'Spell X' and get the right id for the player's level
-- SAFETY: is_spell_learned() gate; nil result is benign (returns nil)

-- spell_resolver_sylvanas.lua -- cached spell resolution table with talent-modifier awareness.
-- WHAT:   cached spell resolution table with talent-modifier awareness
-- WHEN:   called per-frame in spec match functions; caches outcomes in-process
-- WHY:    replaces string-key spell lookups with pre-resolved ID tables
-- SAFETY: cache TTL 5s; nil-guarded on cache miss
-- DECISION: consumed by specs via require(); no on_update side-effects.

-- ============================================================================
-- Shared Module: Talent-Modified Spell Resolution
-- ============================================================================
-- What:   Auto-resolves talent-modified spell IDs using the WoW client's
--         spell override API. When a talent improves a spell (e.g., Improved
--         Seal of Righteousness), the client reports a different spell ID
--         for the talented version. This module resolves those overrides.
-- When:   Loaded once at module init. Used by rotation match functions
--         to check if a talented version of a spell should be cast instead.
-- Why:    Talents like "Improved Seal of Righteousness" change spell IDs.
--         Casting the base spell ID won't apply talent benefits. The engine
--         provides get_override_spell_id() to resolve the talented version.
--         This module caches results with a 30s TTL to avoid repeated API calls.
-- Safety: Cached with TTL to avoid API spam. Nil-safe: returns base_id if
--         the API is unavailable or returns 0 (no override).
--         Does NOT modify existing NS.get_spell_id() or NS.refresh_spell_cache().
-- Decision: Separate module rather than extending core_sylvanas.lua to keep
--           concerns isolated. Follows existing shared module pattern with M.*
--           exports and NS namespace registration.
-- ============================================================================

local _G = _G
local NS = _G.EaxRotations
if not NS then return end

local M = {}

-- ============================================================================
-- Cache
-- ============================================================================
-- Keys: base_spell_id (number)
-- Values: { result = override_id or base_id, ts = timestamp }
-- TTL: 30s, matching core_sylvanas.lua _SPELL_ID_CACHE_TTL

local _override_cache = {}
local _CACHE_TTL = 30

-- ============================================================================
-- resolve_talent_spell(base_id)
-- ============================================================================
-- Returns the talent-modified override spell ID if one exists.
-- Falls back to base_id if no override or API unavailable.
-- Results cached for _CACHE_TTL seconds.
-- @param base_id number — the base spell ID to resolve
-- @return number — the override spell ID, or base_id if no override
-- @usage local talented_id = NS.resolve_talent_spell(20154) -- Seal of Righteousness

function M.resolve_talent_spell(base_id)
    if type(base_id) ~= "number" then return base_id end

    -- Check cache first
    local now = NS.time_now and NS.time_now() or 0
    local cached = _override_cache[base_id]
    if cached and now - cached.ts < _CACHE_TTL then
        return cached.result
    end

    -- Resolve via API (nil-safe, dynamic lookup for testability)
    local api = core and core.spell_book and core.spell_book.get_override_spell_id
    if api then
        local ok, override_id = pcall(api, base_id)
        if ok and override_id and override_id > 0 then
            _override_cache[base_id] = { result = override_id, ts = now }
            return override_id
        end
    end

    -- No override: cache and return base_id
    _override_cache[base_id] = { result = base_id, ts = now }
    return base_id
end

-- ============================================================================
-- get_base_spell_id(override_id)
-- ============================================================================
-- Reverse lookup: given a talent-modified spell ID, return the base spell ID.
-- Useful for mapping known talented IDs back to their original spell.
-- Falls back to override_id if API unavailable.
-- Results cached for _CACHE_TTL seconds.
-- @param override_id number — the override/talented spell ID
-- @return number — the base spell ID, or override_id if no base found
-- @usage local base_id = NS.get_base_spell_id(12345) -- returns 686

function M.get_base_spell_id(override_id)
    if type(override_id) ~= "number" then return override_id end

    -- Check cache (keyed with negative to avoid collision with forward cache)
    local now = NS.time_now and NS.time_now() or 0
    local cache_key = -override_id
    local cached = _override_cache[cache_key]
    if cached and now - cached.ts < _CACHE_TTL then
        return cached.result
    end

    -- Resolve via API (nil-safe, dynamic lookup for testability)
    local api = core and core.spell_book and core.spell_book.get_base_spell_id
    if api then
        local ok, base_id = pcall(api, override_id)
        if ok and base_id and base_id > 0 then
            _override_cache[cache_key] = { result = base_id, ts = now }
            return base_id
        end
    end

    -- No base found: cache and return override_id
    _override_cache[cache_key] = { result = override_id, ts = now }
    return override_id
end

-- ============================================================================
-- Cache invalidation — hooks into existing NS.refresh_spell_cache()
-- ============================================================================

-- Wrap existing refresh_spell_cache to also clear override cache.
-- Preserves original behavior — adds only _override_cache clearing.
if NS.refresh_spell_cache then
    local _original_refresh = NS.refresh_spell_cache
    NS.refresh_spell_cache = function()
        _original_refresh()
        for k in pairs(_override_cache) do _override_cache[k] = nil end
    end
end

-- ============================================================================
-- Export to NS namespace
-- ============================================================================

_G.SpellResolver = M

if NS then
    NS.resolve_talent_spell = M.resolve_talent_spell
    NS.get_base_spell_id = M.get_base_spell_id
end
