-- lazy_context_sylvanas.lua — Lazy, dependency-aware context proxy for EAX rotations.
-- WHAT:  Provides a context table that computes fields on demand and caches them per tick.
-- WHEN:  Used by main_sylvanas.lua build_context() to avoid eager computation of expensive fields.
-- WHY:   Many context fields (party scans, TTD, PvP scans) are expensive and not used by every spec every tick.
-- SAFETY: pcall-wrapped resolvers; nil-safe cache; dependency invalidation on root changes.
-- DECISION: Pure helper, no on_update side-effects. Lua 5.1 / LuaJIT compatible.

local M = {}

-- Create a new lazy context instance.
-- Each tick, main_sylvanas.lua creates a fresh instance to avoid stale caches.
function M.create()
    local cache = {}      -- resolved values
    local resolvers = {}  -- field -> resolver function
    local dependents = {} -- field -> list of fields that depend on it
    local resolved = {}   -- field -> true (handles nil values in cache)
    local ctx = {}

    -- Recursively invalidate fields that depend on `key`.
    local function invalidate(key)
        local deps = dependents[key]
        if not deps then return end
        for i = 1, #deps do
            local dep = deps[i]
            if resolved[dep] then
                resolved[dep] = nil
                cache[dep] = nil
                invalidate(dep)
            end
        end
    end

    local meta = {
        __index = function(_, key)
            if resolved[key] then
                return cache[key]
            end
            local resolver = resolvers[key]
            if resolver then
                local ok, val = pcall(resolver, ctx)
                if ok then
                    cache[key] = val
                    resolved[key] = true
                    return val
                else
                    if NS and type(NS.log_warning) == "function" then
                        NS.log_warning("[lazy_context] resolver '" .. tostring(key) .. "' error: " .. tostring(val))
                    end
                end
            end
            return nil
        end,
        __newindex = function(_, key, val)
            cache[key] = val
            resolved[key] = true
            invalidate(key)
        end,
        -- LuaJIT / Lua 5.2+ only: force-resolve all fields before iterating.
        -- NOTE: __pairs is LuaJIT/Lua 5.2+ only.  We do not rely on it;
        -- the proxy writes evaluated values back to the table via rawset,
        -- so pairs() sees fields that have already been accessed.  For tests
        -- that need to enumerate all fields, call ctx._resolve_all() first.
    }

    setmetatable(ctx, meta)

    -- Register a lazy field with optional dependencies.
    -- deps: list of field names that, when changed via _set_root/__newindex, invalidate this field.
    function ctx._register(key, deps, resolver)
        if resolvers[key] then
            -- Duplicate registration: remove stale dependency edges before re-adding.
            for dep_key, dep_list in pairs(dependents) do
                for i = #dep_list, 1, -1 do
                    if dep_list[i] == key then
                        table.remove(dep_list, i)
                    end
                end
                if #dep_list == 0 then
                    dependents[dep_key] = nil
                end
            end
        -- Clear cached value so the new resolver runs on next access.
        resolved[key] = nil
        cache[key] = nil
        -- Also invalidate any fields that depend on this key, since the
        -- resolver change may alter the value they observe.
        local deps_of_key = dependents[key]
        if deps_of_key then
            for i = 1, #deps_of_key do
                resolved[deps_of_key[i]] = nil
                cache[deps_of_key[i]] = nil
            end
        end
    end
        resolvers[key] = resolver
        if deps then
            for _, dep in ipairs(deps) do
                dependents[dep] = dependents[dep] or {}
                table.insert(dependents[dep], key)
            end
        end
    end

    -- Set a root value. If the value changed, invalidate all dependents.
    function ctx._set_root(key, val)
        local old = cache[key]
        cache[key] = val
        resolved[key] = true
        if old ~= val then
            invalidate(key)
        end
    end

    -- Force-resolve every registered field. Useful for tests or diagnostics.
    function ctx._resolve_all()
        for k in pairs(resolvers) do
            if not resolved[k] then
                local _ = ctx[k]
            end
        end
        return cache
    end

    return ctx
end

return M
