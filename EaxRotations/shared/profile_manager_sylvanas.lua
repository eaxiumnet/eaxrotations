-- ============================================================================
-- What: Shared helper for loading, saving, copying, and switching profiles
-- When: On demand during profile management actions
-- Why: Persist character-specific rotation setups across sessions
-- Safety: Uses in-memory cache, nil-guards file state, and keeps writes conservative
-- ============================================================================
-- Shared Helper: Profile Manager
-- ============================================================================
local M = {}
local _G = _G
local NS = _G.EaxRotations

local PROFILES_FILE = "eaxrotations/profiles.json"

-- In-memory profile cache
local profile_cache = {}
local active_profile = nil

-- Get current time for metadata
local function now()
    return NS and NS.time_now and NS.time_now() or 0
end

-- Get character identifier
local function get_character_key()
    if not NS then return "unknown" end
    local me = NS.PLAYER_UNIT or NS.GetPlayer and NS.GetPlayer()
    if not me then return "unknown" end
    
    local name = nil
    local ok, val = pcall(function() return me:get_name() end)
    if ok then name = val end
    
    if not name then return "unknown" end
    return name
end

-- Get class identifier
local function get_class_key()
    if not NS then return "unknown" end
    local me = NS.PLAYER_UNIT or NS.GetPlayer and NS.GetPlayer()
    if not me then return "unknown" end
    
    local class = nil
    local ok, val = pcall(function() return me:get_class() end)
    if ok then class = val end
    
    return class or "unknown"
end

-- Load profiles from file
local function load_profiles_from_file()
    if not NS or not NS.core or not NS.core.read_data_file then return {} end
    
    local ok, data = pcall(NS.core.read_data_file, PROFILES_FILE)
    if not ok or not data then return {} end
    
    -- Decode JSON (Sylvanas may provide JSON decode)
    if NS.core.json_decode then
        local ok2, decoded = pcall(NS.core.json_decode, data)
        if ok2 and decoded then
            return decoded
        end
    end
    
    -- Fallback: assume Lua table serialization
    local ok3, func = pcall(loadstring, "return " .. data)
    if ok3 and func then
        local ok4, result = pcall(func)
        if ok4 and type(result) == "table" then
            return result
        end
    end
    
    return {}
end

-- Save profiles to file
local function save_profiles_to_file(profiles)
    if not NS or not NS.core then return false end
    
    -- Serialize to JSON or Lua table
    local serialized = nil
    
    if NS.core.json_encode then
        local ok, encoded = pcall(NS.core.json_encode, profiles)
        if ok then
            serialized = encoded
        end
    end
    
    -- Fallback: simple Lua table serialization
    if not serialized then
        local parts = {"{"}
        for char_key, char_profiles in pairs(profiles) do
            table.insert(parts, "[" .. string.format("%q", char_key) .. "] = {")
            for profile_name, profile_data in pairs(char_profiles) do
                table.insert(parts, "[" .. string.format("%q", profile_name) .. "] = {")
                if profile_data.class then
                    table.insert(parts, "class = " .. string.format("%q", profile_data.class) .. ",")
                end
                if profile_data.settings then
                    table.insert(parts, "settings = {")
                    for k, v in pairs(profile_data.settings) do
                        if type(v) == "string" then
                            table.insert(parts, "[" .. string.format("%q", k) .. "] = " .. string.format("%q", v) .. ",")
                        elseif type(v) == "number" then
                            table.insert(parts, "[" .. string.format("%q", k) .. "] = " .. tostring(v) .. ",")
                        elseif type(v) == "boolean" then
                            table.insert(parts, "[" .. string.format("%q", k) .. "] = " .. tostring(v) .. ",")
                        end
                    end
                    table.insert(parts, "},")
                end
                table.insert(parts, "},")
            end
            table.insert(parts, "},")
        end
        table.insert(parts, "}")
        serialized = table.concat(parts)
    end
    
    if NS.core.write_data_file then
        local ok = pcall(NS.core.write_data_file, PROFILES_FILE, serialized)
        return ok
    end
    
    return false
end

-- Save a profile
function M.save_profile(name, settings_table)
    if type(name) ~= "string" or name == "" then return false end
    if type(settings_table) ~= "table" then return false end
    
    -- Don't save during combat
    if NS and NS.in_combat and NS.in_combat() then
        return false, "cannot save during combat"
    end
    
    local char_key = get_character_key()
    local class_key = get_class_key()
    
    -- Load existing profiles
    local profiles = load_profiles_from_file()
    
    -- Ensure character entry exists
    if not profiles[char_key] then
        profiles[char_key] = {}
    end
    
    -- Save profile
    profiles[char_key][name] = {
        class = class_key,
        settings = settings_table,
        last_modified = now(),
    }
    
    -- Save to file
    local ok = save_profiles_to_file(profiles)
    
    -- Update cache
    if ok then
        profile_cache[char_key] = profile_cache[char_key] or {}
        profile_cache[char_key][name] = profiles[char_key][name]
    end
    
    return ok
end

-- Load a profile
function M.load_profile(name)
    if type(name) ~= "string" or name == "" then return nil end
    
    -- Don't load during combat
    if NS and NS.in_combat and NS.in_combat() then
        return nil, "cannot load during combat"
    end
    
    local char_key = get_character_key()
    
    -- Check cache first
    if profile_cache[char_key] and profile_cache[char_key][name] then
        active_profile = name
        return profile_cache[char_key][name].settings
    end
    
    -- Load from file
    local profiles = load_profiles_from_file()
    
    if not profiles[char_key] or not profiles[char_key][name] then
        return nil, "profile not found"
    end
    
    -- Update cache
    profile_cache[char_key] = profile_cache[char_key] or {}
    profile_cache[char_key][name] = profiles[char_key][name]
    
    active_profile = name
    return profiles[char_key][name].settings
end

-- Delete a profile
function M.delete_profile(name)
    if type(name) ~= "string" or name == "" then return false end
    
    local char_key = get_character_key()
    
    -- Load existing profiles
    local profiles = load_profiles_from_file()
    
    if not profiles[char_key] or not profiles[char_key][name] then
        return false, "profile not found"
    end
    
    -- Remove profile
    profiles[char_key][name] = nil
    
    -- Save updated profiles
    local ok = save_profiles_to_file(profiles)
    
    -- Update cache
    if ok and profile_cache[char_key] then
        profile_cache[char_key][name] = nil
    end
    
    return ok
end

-- List all profiles for current character
function M.list_profiles()
    local char_key = get_character_key()
    local class_key = get_class_key()
    
    -- Load from file
    local profiles = load_profiles_from_file()
    
    local result = {}
    if profiles[char_key] then
        for name, data in pairs(profiles[char_key]) do
            table.insert(result, {
                name = name,
                class = data.class,
                last_modified = data.last_modified,
                active = (name == active_profile),
            })
        end
    end
    
    -- Sort by name
    table.sort(result, function(a, b) return a.name < b.name end)
    
    return result
end

-- Copy a profile
function M.copy_profile(from_name, to_name)
    if type(from_name) ~= "string" or from_name == "" then return false end
    if type(to_name) ~= "string" or to_name == "" then return false end
    if from_name == to_name then return false end
    
    local char_key = get_character_key()
    
    -- Load existing profiles
    local profiles = load_profiles_from_file()
    
    -- Check source exists
    if not profiles[char_key] or not profiles[char_key][from_name] then
        return false, "source profile not found"
    end
    
    -- Copy
    profiles[char_key][to_name] = {}
    for k, v in pairs(profiles[char_key][from_name]) do
        if k == "settings" then
            -- Deep copy settings
            profiles[char_key][to_name][k] = {}
            for sk, sv in pairs(v) do
                profiles[char_key][to_name][k][sk] = sv
            end
        else
            profiles[char_key][to_name][k] = v
        end
    end
    
    -- Update last modified
    profiles[char_key][to_name].last_modified = now()
    
    -- Save to file
    local ok = save_profiles_to_file(profiles)
    
    return ok
end

-- Get active profile name
function M.get_active_profile()
    return active_profile
end

-- Set active profile
function M.set_active_profile(name)
    active_profile = name
end

-- Refresh cache from file
function M.refresh_cache()
    profile_cache = {}
    local profiles = load_profiles_from_file()
    
    for char_key, char_profiles in pairs(profiles) do
        profile_cache[char_key] = char_profiles
    end
end

-- Initialize on load
function M.init()
    M.refresh_cache()
end

if NS then
    NS.ProfileManager = M
    -- Auto-init
    M.init()
end

return M
