-- =============================================================================
-- SETTINGS MANAGER - Working implementation for Sylvanas
-- Simplified version that uses core API for persistence
-- =============================================================================

local core = _G.core

local SettingsManager = {
    _attached = {},
    _file_name = nil,
    _settings = {},
    _defaults = {}
}

---Set the file name for saving/loading
---@param name string File name without extension
---@return boolean success
function SettingsManager:set_file_name(name)
    if not name or name == "" then
        return false
    end
    -- Check for invalid characters
    if name:match("[\\/:*?\"<>|]") then
        return false
    end
    self._file_name = name .. ".txt"
    return true
end

---Flatten a nested table into dot-separated keys
---@param tbl table Table to flatten
---@param prefix string|nil Current key prefix
---@param result table|nil Result table to populate
---@return table flat_tbl Flattened table
function SettingsManager:flatten_table(tbl, prefix, result)
    result = result or {}
    prefix = prefix or ""
    
    for k, v in pairs(tbl) do
        local key = prefix ~= "" and (prefix .. "." .. k) or k
        if type(v) == "table" then
            self:flatten_table(v, key, result)
        else
            result[key] = v
        end
    end
    
    return result
end

---Unflatten dot-separated keys into nested table
---@param flat_tbl table Flattened table
---@return table tbl Nested table
function SettingsManager:unflatten_table(flat_tbl)
    local result = {}
    
    for key, value in pairs(flat_tbl) do
        local parts = {}
        for part in key:gmatch("[^.]+") do
            table.insert(parts, part)
        end
        
        local current = result
        for i = 1, #parts - 1 do
            local part = parts[i]
            if not current[part] then
                current[part] = {}
            end
            current = current[part]
        end
        
        current[parts[#parts]] = value
    end
    
    return result
end

---Attach menu elements for automatic settings management
---@param element table|userdata Menu element or table of elements
---@param namespace string|nil Optional namespace prefix
function SettingsManager:attach(element, namespace)
    if type(element) == "table" then
        -- Handle nested tables
        for k, v in pairs(element) do
            if type(v) == "table" then
                if v.get_state or v.get or v.get_default then
                    -- This is a menu element
                    local key = namespace and (namespace .. "." .. k) or k
                    self._attached[key] = v
                    -- Store default value
                    if v.get_default then
                        self._defaults[key] = v:get_default()
                    elseif v.get then
                        self._defaults[key] = v:get()
                    end
                else
                    -- This is a nested table, recurse
                    local ns = namespace and (namespace .. "." .. k) or k
                    self:attach(v, ns)
                end
            end
        end
    elseif type(element) == "userdata" then
        -- Single element
        local key = namespace or "default"
        self._attached[key] = element
        if element.get_default then
            self._defaults[key] = element:get_default()
        elseif element.get then
            self._defaults[key] = element:get()
        end
    end
end

---Build default settings from all attached elements
---@return table defaults Default settings table
function SettingsManager:build_default_settings()
    return self._defaults
end

---Collect current values from all attached elements
---@return table settings Current settings
function SettingsManager:collect_attached_settings()
    local settings = {}
    
    for key, element in pairs(self._attached) do
        if element.get_state then
            settings[key] = element:get_state()
        elseif element.get then
            settings[key] = element:get()
        end
    end
    
    return self:unflatten_table(settings)
end

---Apply settings to all attached elements
---@param nested_settings table Settings to apply
function SettingsManager:apply_attached_settings(nested_settings)
    local flat = self:flatten_table(nested_settings)
    
    for key, value in pairs(flat) do
        local element = self._attached[key]
        if element and element.set then
            -- Convert type if needed
            local default = self._defaults[key]
            if type(default) == "number" and type(value) == "string" then
                value = tonumber(value) or default
            elseif type(default) == "boolean" and type(value) == "string" then
                value = value == "true" or value == "1"
            end
            element:set(value)
        end
    end
end

---Save settings to file using core.file_io
---@return boolean success
function SettingsManager:save()
    if not self._file_name then
        return false
    end
    
    local settings = self:collect_attached_settings()
    local flat = self:flatten_table(settings)
    
    -- Convert to string
    local lines = {}
    for k, v in pairs(flat) do
        table.insert(lines, k .. "=" .. tostring(v))
    end
    table.sort(lines)
    local content = table.concat(lines, "\n")
    
    -- Use core.file_io if available, otherwise use io
    if core and core.file_io and core.file_io.write then
        return core.file_io.write(self._file_name, content)
    else
        local file = io.open(self._file_name, "w")
        if file then
            file:write(content)
            file:close()
            return true
        end
    end
    
    return false
end

---Save without confirmation (internal)
---@return boolean success
function SettingsManager:save_int()
    return self:save()
end

---Load settings from file
---@return table|nil settings Loaded settings or nil
function SettingsManager:load()
    if not self._file_name then
        return nil
    end
    
    local content
    
    -- Use core.file_io if available
    if core and core.file_io and core.file_io.read then
        content = core.file_io.read(self._file_name)
    else
        local file = io.open(self._file_name, "r")
        if file then
            content = file:read("*all")
            file:close()
        end
    end
    
    if not content or content == "" then
        -- Return defaults
        return self:build_default_settings()
    end
    
    -- Parse content
    local flat = {}
    for line in content:gmatch("[^\r\n]+") do
        local key, value = line:match("^([^=]+)=(.*)$")
        if key and value then
            -- Convert value types
            if value == "true" then
                value = true
            elseif value == "false" then
                value = false
            elseif tonumber(value) then
                value = tonumber(value)
            end
            flat[key] = value
        end
    end
    
    local settings = self:unflatten_table(flat)
    
    -- Apply to elements
    self:apply_attached_settings(settings)
    
    return settings
end

---Initialize the settings manager
---Loads existing settings or builds defaults
---@return table settings Current settings
function SettingsManager:init()
    local settings = self:load()
    if not settings then
        settings = self:build_default_settings()
        self:apply_attached_settings(settings)
    end
    self._settings = settings
    return settings
end

---Reset all settings to defaults
---@param save boolean|nil Whether to save after reset
function SettingsManager:reset(save)
    local defaults = self:build_default_settings()
    self:apply_attached_settings(defaults)
    self._settings = defaults
    
    if save then
        self:save()
    end
end

---Reset UI only (same as reset without save)
function SettingsManager:resetUI()
    self:reset(false)
end

return SettingsManager
