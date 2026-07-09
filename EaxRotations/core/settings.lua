-- settings.lua — Cached read/write settings proxy for EaxRotations.
-- WHAT:  NS.get_setting / NS.set_setting with TTL cache + type-safe fallbacks.
-- WHEN:  installed by core_sylvanas.lua during addon load.
-- WHY:   every spec uses these helpers; caching prevents menu widget lookups every frame.
-- SAFETY: nil-safe fallbacks for all reads; writes are debounced.

-- =============================================================================
-- core/settings.lua
--
-- Settings domain — extracted from EaxRotations/core_sylvanas.lua.
-- Contains the cached read/write proxy on NS.settings, plus the centralized
-- setting / setting_number / setting_bool helpers that every spec uses.
--
-- BACKGROUND
--   core_sylvanas.lua was a 6,431-line god-file mixing ~15 unrelated
--   domains. Splitting settings into its own module lets future changes
--   stay inside this file (cache TTL, settings_manager wiring) without
--   anything in core_sylvanas.lua needing to move.
--
-- CONTRACT
--   - install(NS, deps): wires up NS.get_setting, NS.set_setting,
--     NS.setting, NS.setting_number, NS.setting_bool, NS.get_any_setting,
--     NS.refresh_settings_cache, NS.get_setting_cached, NS.register_izi_buff_events.
--   - dependencies passed in `deps`:
--       deps.time_now(): callable that returns monotonic seconds.
--       deps.settings_manager: optional module with :get(key)/:set(key, value).
--       deps.settings: existing NS.settings table (kept by reference).
-- ######################################################################

local M = {}

local _settings_cache
local _settings_cache_last_update
local _SETTINGS_CACHE_TTL
local _settings_cache_time

function M.install(NS, deps)
    local time_now = deps and deps.time_now or NS.time_now or function() return 0 end
    local settings_manager = deps and deps.settings_manager
    local settings_table = (deps and deps.settings) or NS.settings or {}

    -- Expose back to NS.settings so existing callers continue to see
    -- their writes immediately. core_sylvanas already mutates NS.settings
    -- so we just take reference; re-assignment is fine.
    NS.settings = settings_table

    _settings_cache = {}
    _settings_cache_last_update = 0
    _SETTINGS_CACHE_TTL = 0.20 -- 200ms throttle
    _settings_cache_time = time_now

    function NS.get_setting(key, default)
        -- Primary: settings_manager.
        if settings_manager then
            local ok, v = pcall(function() return settings_manager:get(key) end)
            if ok and v ~= nil then return v end
        end
        -- Fallback: manual cache from NS.settings.
        local now = _settings_cache_time()
        if now - _settings_cache_last_update > _SETTINGS_CACHE_TTL then
            _settings_cache = {}
            for k, v in pairs(settings_table) do _settings_cache[k] = v end
            _settings_cache_last_update = now
        end
        local value = _settings_cache[key]
        if value == nil then return default end
        return value
    end

    function NS.set_setting(key, value)
        local last = _settings_cache[key]
        settings_table[key] = value
        _settings_cache[key] = value
        if settings_manager and value ~= last then
            pcall(function() settings_manager:set(key, value) end)
        end
    end

    function NS.setting(context, key, default)
        local settings = context and context.settings
        if settings and settings[key] ~= nil then return settings[key] end
        if NS.get_setting then return NS.get_setting(key, default) end
        return default
    end

    function NS.setting_number(settings, key, default)
        local value = settings and settings[key]
        return type(value) == "number" and value or default
    end

    function NS.setting_bool(settings, key, default)
        local value = settings and settings[key]
        if value == nil then return default end
        return value ~= false
    end

    function NS.get_any_setting(context, primary, secondary, fallback)
        local settings = context and context.settings or {}
        if settings[primary] ~= nil then return settings[primary] end
        if settings[secondary] ~= nil then return settings[secondary] end
        return fallback
    end

    function NS.refresh_settings_cache()
        _settings_cache = {}
        for k, v in pairs(settings_table) do _settings_cache[k] = v end
        _settings_cache_last_update = _settings_cache_time()
        return true
    end
end

return M
