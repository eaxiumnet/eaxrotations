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
--- Resolves <name>_<expansion>.lua in order: wotlk -> sylvanas -> vanilla for WotLK clients,
--- vanilla -> sylvanas -> wotlk for Vanilla clients, and sylvanas -> vanilla -> wotlk otherwise.
--- Falls back through the chain if the preferred expansion file is missing.
---@param class_key string e.g. "warrior"
---@param class_display_name string e.g. "Warrior"
---@return fun(name_base: string): any load_child
function class_loader.create_expansion_loader(class_key, class_display_name)
    return function(name_base, optional)
        local current_ns = _G.EaxRotations or NS
        local is_wotlk = current_ns.is_wotlk and current_ns.is_wotlk()
        local is_vanilla = current_ns.is_vanilla and current_ns.is_vanilla()

        local suffixes
        if is_wotlk then
            suffixes = { "_wotlk", "_sylvanas", "_vanilla" }
        elseif is_vanilla then
            suffixes = { "_vanilla", "_sylvanas", "_wotlk" }
        else
            suffixes = { "_sylvanas", "_vanilla", "_wotlk" }
        end

        local first_error
        for _, suffix in ipairs(suffixes) do
            local filename = name_base .. suffix
            local path = "classes/" .. class_key .. "/" .. filename
            local ok, result = pcall(require, path)
            if ok then
                return result
            end

            local is_not_found = type(result) == "string" and result:match("module '" .. path .. "' not found")
            if not is_not_found then
                -- Real runtime error in a module -- rethrow, don't silently fallback
                error(class_display_name .. " required module error: " .. tostring(name_base) .. " : " .. tostring(result), 2)
            end

            if not first_error then
                first_error = result
            end
        end

        if optional then
            if NS then
                NS.log_warning(class_display_name .. " optional module skipped: " .. tostring(name_base) .. " -> " .. tostring(first_error))
            end
            return nil
        end
        error(class_display_name .. " required module missing: " .. tostring(name_base) .. " : " .. tostring(first_error), 2)
    end
end

return class_loader
