-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "shared/class_loader_sylvanas.lua"
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
-- DRY class loader for all class_sylvanas.lua modules.

local NS = _G.EaxRotations

local class_loader = {}

--- Get the enums module with same fallback guard as original pattern.
--- Falls back to { class_id = NS.CLASS_ID } if enums module isn't a valid table.
---@return table enums
function class_loader.get_enums()
    local ok, enums = pcall(require, "common/enums")
    if not ok or type(enums) ~= "table" or type(enums.class_id) ~= "table" then
        return { class_id = NS and NS.CLASS_ID or {} }
    end
    return enums
end

--- Create a load_child function bound to a specific class key.
--- The returned function safely requires modules from classes/<class_key>/<name>
--- and logs warnings with the class display name on failure.
---@param class_key string e.g. "warrior"
---@param class_display_name string e.g. "Warrior"
---@return fun(name: string): any load_child
function class_loader.create_loader(class_key, class_display_name)
    return function(name, optional)
        local ok, result = pcall(require, "classes/" .. class_key .. "/" .. name)
        if not ok then
            if optional then
                if NS then
                    NS.log_warning(class_display_name .. " optional module skipped: " .. tostring(name) .. " -> " .. tostring(result))
                end
                return nil
            end
            error(class_display_name .. " required module missing: " .. tostring(name) .. " : " .. tostring(result), 2)
        end
        return result
    end
end

--- Create an expansion-aware load_child function.
--- If NS.is_vanilla() is true, loads <name>_vanilla.lua; otherwise <name>_sylvanas.lua.
--- Falls back to the opposite expansion if the preferred one is missing.
---@param class_key string e.g. "warrior"
---@param class_display_name string e.g. "Warrior"
---@return fun(name_base: string): any load_child
function class_loader.create_expansion_loader(class_key, class_display_name)
    local expansion_suffix = (NS and NS.is_vanilla and NS.is_vanilla()) and "_vanilla" or "_sylvanas"
    return function(name_base, optional)
        local preferred_filename = name_base .. expansion_suffix
        local ok, result = pcall(require, "classes/" .. class_key .. "/" .. preferred_filename)
        if not ok then
            local fallback_suffix = (expansion_suffix == "_sylvanas") and "_vanilla" or "_sylvanas"
            local fallback_filename = name_base .. fallback_suffix
            local ok2, result2 = pcall(require, "classes/" .. class_key .. "/" .. fallback_filename)
            if ok2 then
                return result2
            end
            if optional then
                if NS then
                    NS.log_warning(class_display_name .. " optional module skipped: " .. tostring(name_base) .. " -> " .. tostring(result))
                end
                return nil
            end
            error(class_display_name .. " required module missing: " .. tostring(name_base) .. " : " .. tostring(result), 2)
        end
        return result
    end
end

return class_loader
