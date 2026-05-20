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
    return function(name)
        local ok, result = pcall(require, "classes/" .. class_key .. "/" .. name)
        if not ok and NS then
            NS.log_warning(class_display_name .. " module skipped: " .. tostring(name) .. " -> " .. tostring(result))
        end
        return ok and result or nil
    end
end

return class_loader
