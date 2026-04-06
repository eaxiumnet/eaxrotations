-- =============================================================================
-- SETTINGS BRIDGE - Connects core.menu to rotation logic
-- Replaces hardcoded defaults with live UI settings
-- =============================================================================

local core = _G.core
local settings_manager = require("common/modules/settings_manager")

-- =============================================================================
-- SETTINGS BRIDGE MODULE
-- =============================================================================
local SettingsBridge = {
    _manager = nil,
    _initialized = false,
    _file_name = nil,
    _cache = {}, -- Local cache for performance
    _cache_ttl = 0.1, -- 100ms cache TTL
    _cache_last_update = 0,
}

-- =============================================================================
-- INITIALIZATION
-- =============================================================================

---Initialize the settings bridge with a file name for persistence
---@param file_name string The settings file name (without extension)
---@return boolean success
function SettingsBridge:init(file_name)
    if self._initialized then
        return true
    end
    
    self._file_name = file_name or "rotation_settings"
    self._manager = settings_manager
    
    -- Set file name for persistence
    local success = self._manager:set_file_name(self._file_name)
    if not success then
        core.log_error("SettingsBridge: Failed to set file name: " .. tostring(file_name))
        return false
    end
    
    self._initialized = true
    return true
end

-- =============================================================================
-- MENU ATTACHMENT
-- =============================================================================

---Attach menu elements to the settings manager
---@param menu_elements table Nested table of menu elements
---@param namespace string|nil Optional namespace prefix
function SettingsBridge:attach(menu_elements, namespace)
    if not self._initialized then
        core.log_error("SettingsBridge: Cannot attach - not initialized")
        return
    end
    
    self._manager:attach(menu_elements, namespace)
end

---Complete initialization after all elements are attached
---@return table|boolean settings The loaded settings or false on failure
function SettingsBridge:finalize()
    if not self._initialized then
        core.log_error("SettingsBridge: Cannot finalize - not initialized")
        return false
    end
    
    local settings = self._manager:init()
    
    -- Build cache for fast access
    self:refresh_cache()
    
    return settings
end

-- =============================================================================
-- SETTINGS ACCESS
-- =============================================================================

---Get a setting value (with caching)
---@param key string Dot-separated key (e.g., "combat.enabled")
---@param default any Default value if setting not found
---@return any value
function SettingsBridge:get(key, default)
    if not self._initialized then
        return default
    end
    
    -- Check cache first
    local now = core.time()
    if now - self._cache_last_update < self._cache_ttl then
        if self._cache[key] ~= nil then
            return self._cache[key]
        end
    else
        -- Cache expired, refresh
        self:refresh_cache()
    end
    
    -- Get from settings manager
    local value = self._manager:get(key)
    if value == nil then
        value = default
    end
    
    -- Update cache
    self._cache[key] = value
    
    return value
end

---Set a setting value
---@param key string Dot-separated key
---@param value any Value to set
---@return boolean success
function SettingsBridge:set(key, value)
    if not self._initialized then
        return false
    end
    
    local success = self._manager:set(key, value)
    
    -- Update cache immediately
    if success then
        self._cache[key] = value
    end
    
    return success
end

-- =============================================================================
-- CACHE MANAGEMENT
-- =============================================================================

---Refresh the entire settings cache
function SettingsBridge:refresh_cache()
    self._cache = {}
    self._cache_last_update = core.time()
    
    -- Collect all attached settings
    local settings = self._manager:collect_attached_settings()
    
    -- Flatten into cache
    self:flatten_into_cache(settings, "")
end

---Recursively flatten nested settings table into cache
---@param tbl table Nested settings table
---@param prefix string Current key prefix
function SettingsBridge:flatten_into_cache(tbl, prefix)
    for key, value in pairs(tbl) do
        local full_key = prefix ~= "" and (prefix .. "." .. key) or key
        
        if type(value) == "table" then
            self:flatten_into_cache(value, full_key)
        else
            self._cache[full_key] = value
        end
    end
end

---Clear the cache (force refresh on next access)
function SettingsBridge:clear_cache()
    self._cache = {}
    self._cache_last_update = 0
end

-- =============================================================================
-- PERSISTENCE
-- =============================================================================

---Save current settings to file
---@return boolean success
function SettingsBridge:save()
    if not self._initialized then
        return false
    end
    
    return self._manager:save()
end

---Load settings from file
---@return table|boolean settings or false
function SettingsBridge:load()
    if not self._initialized then
        return false
    end
    
    local settings = self._manager:load()
    
    -- Refresh cache after load
    self:refresh_cache()
    
    return settings
end

---Reset to defaults
---@param save_to_file boolean|nil Also save defaults to file
function SettingsBridge:reset(save_to_file)
    if not self._initialized then
        return
    end
    
    self._manager:reset(save_to_file)
    self:refresh_cache()
end

-- =============================================================================
-- UTILITY FUNCTIONS
-- =============================================================================

---Get all settings as a flat table
---@return table flat_settings
function SettingsBridge:get_all()
    self:refresh_cache()
    return self._cache
end

---Check if a setting exists
---@param key string Setting key
---@return boolean exists
function SettingsBridge:has(key)
    if not self._initialized then
        return false
    end
    
    return self._manager:get(key) ~= nil
end

---Create a settings accessor function for rotation use
---@param default_key string|nil Optional default key prefix
---@return function accessor Function that takes key and default
function SettingsBridge:create_accessor(default_key)
    local prefix = default_key and (default_key .. ".") or ""
    
    return function(key, default)
        local full_key = prefix .. key
        return self:get(full_key, default)
    end
end

-- =============================================================================
-- EXPORT
-- =============================================================================

return SettingsBridge
