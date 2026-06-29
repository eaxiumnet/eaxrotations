-- class_loader_sylvanas.lua -- factory that returns load_child/load_spec closures for class modules.
-- WHAT:   factory that returns load_child/load_spec closures for class modules
-- WHEN:   called once at Sylvanas plugin bootstrap
-- WHY:    removes boilerplate, single point of failure for spec resolution
-- SAFETY: invalid class_id returns nil; spec missing logs a single warning
-- DECISION: consumed by specs via require(); no on_update side-effects.

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
    return function(name_base, optional)
        local current_ns = _G.EaxRotations or NS
        local expansion_suffix = (current_ns.is_vanilla and current_ns.is_vanilla()) and "_vanilla" or "_sylvanas"
        local preferred_filename = name_base .. expansion_suffix
        local preferred_path = "classes/" .. class_key .. "/" .. preferred_filename
        local ok, result = pcall(require, preferred_path)
        if not ok then
            -- Distinguish "module not found" from runtime errors
            local is_not_found = type(result) == "string" and result:match("module '" .. preferred_path .. "' not found")
            if not is_not_found then
                -- Real runtime error in the module -- rethrow, don't silently fallback
                error(class_display_name .. " required module error: " .. tostring(name_base) .. " : " .. tostring(result), 2)
            end

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
