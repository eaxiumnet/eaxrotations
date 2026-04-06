-- spell_resolver.lua
-- Shared spell ID resolution with persistent caching.
-- Eliminates redundant core.spell_book.is_spell_learned() calls across all specs.
--
-- Usage:
--   local spell_resolver = require("libraries/spell_resolver")
--   local spell_id = spell_resolver.resolve_spell_id(rank_table)
--   spell_resolver.invalidate_cache()  -- call when talents change

local spell_resolver = {}

-- Cache: key = table reference string, value = resolved spell_id
-- Key strategy: use the table reference as string (unique per rank_table)
-- This works because Lua tables passed to resolve_spell_id are persistent
-- (defined at module level in spells.lua), so their references are stable.
local _cache = {}

-- Track if cache is valid (starts false, auto-validates on first resolve)
local _is_valid = false

--- Resolve the highest-learned rank from a spell rank table.
--- Results are cached until invalidate_cache() is called.
--- Cache auto-validates on first successful resolve.
---@param rank_table number[] Array of spell IDs (highest rank first)
---@return number|nil Highest learned spell ID, or nil if not learned
function spell_resolver.resolve_spell_id(rank_table)
    if not rank_table then return nil end

    -- Handle single spell ID (not a table)
    if type(rank_table) == "number" then
        return core.spell_book.is_spell_learned(rank_table) and rank_table or nil
    end

    -- Check cache first (only if cache is valid)
    if _is_valid then
        local key = tostring(rank_table)
        local cached = _cache[key]
        if cached ~= nil then
            return cached
        end
    end

    -- Cache miss or invalidated - resolve and cache
    local resolved = nil
    for i = 1, #rank_table do
        local spell_id = rank_table[i]
        if spell_id and core.spell_book.is_spell_learned(spell_id) then
            resolved = spell_id
            break
        end
    end

    -- Store in cache (keyed by table reference)
    _cache[tostring(rank_table)] = resolved

    -- Auto-validate cache after first successful resolve (player is loaded)
    if not _is_valid and resolved then
        _is_valid = true
    end

    return resolved
end

--- Invalidate all cached spell IDs. Call this when talents change,
--- player levels up, or any event that could change spell availability.
function spell_resolver.invalidate_cache()
    for k in pairs(_cache) do
        _cache[k] = nil
    end
    _is_valid = false
end

--- Validate the cache. Call this once after initial load,
--- or after talents are confirmed stable.
function spell_resolver.validate_cache()
    _is_valid = true
end

--- Check if cache is currently valid.
---@return boolean
function spell_resolver.is_cache_valid()
    return _is_valid
end

return spell_resolver
