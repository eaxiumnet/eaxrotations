-- class_loader_sylvanas.lua -- factory that returns load_child/load_spec closures for class modules.
-- WHAT:   factory that returns load_child/load_spec closures for class modules
-- WHEN:   called once at Sylvanas plugin bootstrap
-- WHY:    removes boilerplate, single point of failure for spec resolution
-- SAFETY: invalid class_id returns nil; spec missing logs a single warning
-- DECISION: consumed by specs via require(); no on_update side-effects.

-- DRY class loader for all class_sylvanas.lua modules.

local NS = _G.EaxRotations

local class_loader = {}

class_loader.SOD_MANIFEST = {
    druid = {
        { key = "sod_druid_balance", module = "balance_sod", display_name = "Balance" },
        { key = "sod_druid_feral", module = "feral_sod", display_name = "Feral" },
        { key = "sod_druid_restoration", module = "restoration_sod", display_name = "Restoration" },
        { key = "sod_druid_tank", module = "tank_sod", display_name = "Tank" },
    },
    hunter = { { key = "sod_hunter_dps", module = "dps_hunter_sod", display_name = "DPS" } },
    mage = { { key = "sod_mage_dps", module = "dps_mage_sod", display_name = "DPS" } },
    paladin = {
        { key = "sod_paladin_protection", module = "protection_sod", display_name = "Protection" },
        { key = "sod_paladin_retribution", module = "retribution_sod", display_name = "Retribution" },
    },
    priest = {
        { key = "sod_priest_healing", module = "healing_sod", display_name = "Healing" },
        { key = "sod_priest_shadow", module = "shadow_sod", display_name = "Shadow" },
    },
    rogue = {
        { key = "sod_rogue_combat", module = "combat_sod", display_name = "DPS" },
        { key = "sod_rogue_tank", module = "tank_sod", display_name = "Tank" },
    },
    shaman = {
        { key = "sod_shaman_elemental", module = "elemental_sod", display_name = "Elemental" },
        { key = "sod_shaman_enhancement", module = "enhancement_sod", display_name = "Enhancement" },
        { key = "sod_shaman_restoration", module = "restoration_sod", display_name = "Restoration" },
        { key = "sod_shaman_warden", module = "warden_sod", display_name = "Warden" },
    },
    warlock = {
        { key = "sod_warlock_dps", module = "dps_sod", display_name = "DPS" },
        { key = "sod_warlock_tank", module = "tank_sod", display_name = "Tank" },
    },
    warrior = {
        { key = "sod_warrior_dps", module = "dps_warrior_sod", display_name = "DPS" },
        { key = "sod_warrior_tank", module = "tank_warrior_sod", display_name = "Tank" },
    },
}

function class_loader.sod_class_count()
    local count = 0
    for _ in pairs(class_loader.SOD_MANIFEST) do count = count + 1 end
    return count
end

function class_loader.sod_playstyles(class_key)
    local result = {}
    for _, entry in ipairs(class_loader.SOD_MANIFEST[class_key] or {}) do
        result[#result + 1] = { name = entry.key, display_name = entry.display_name }
    end
    return result
end

function class_loader.load_sod_specs(class_key, class_display_name)
    local current_ns = _G.EaxRotations or NS
    local registry = current_ns and current_ns.rotation_registry
    local original_register = registry and registry.register
    local entries = class_loader.SOD_MANIFEST[class_key]
    if not entries then return 0 end
    if type(original_register) ~= "function" then
        error((class_display_name or class_key) .. " SoD registry is unavailable", 2)
    end
    local loaded = 0
    for _, entry in ipairs(entries) do
        local registration_count = 0
        registry.register = function(self, _, strategies, options)
            registration_count = registration_count + 1
            if registration_count > 1 then
                error((class_display_name or class_key) .. " SoD module " .. entry.module
                    .. " registered more than once", 2)
            end
            return original_register(self, entry.key, strategies, options)
        end
        local ok, result = pcall(require, "classes/" .. class_key .. "/" .. entry.module)
        registry.register = original_register
        if not ok then
            error((class_display_name or class_key) .. " SoD module failed: " .. entry.module .. " : " .. tostring(result), 2)
        end
        if result == nil then
            error((class_display_name or class_key) .. " SoD module returned nil: " .. entry.module, 2)
        end
        if registration_count == 0 then
            error((class_display_name or class_key) .. " SoD module registered no playstyle: " .. entry.module, 2)
        end
        loaded = loaded + 1
    end
    return loaded
end

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
--- Resolves only <name>_sod.lua for SoD clients; otherwise resolves
--- cata -> sylvanas -> wotlk -> vanilla for Cata clients,
--- wotlk -> sylvanas -> vanilla for WotLK clients, vanilla -> sylvanas -> wotlk for Vanilla clients,
--- and sylvanas -> vanilla -> wotlk otherwise.
--- Falls back through the chain if the preferred expansion file is missing.
---@param class_key string e.g. "warrior"
---@param class_display_name string e.g. "Warrior"
---@return fun(name_base: string): any load_child
function class_loader.create_expansion_loader(class_key, class_display_name)
    return function(name_base, optional)
        local current_ns = _G.EaxRotations or NS
        local is_sod = current_ns.is_sod and current_ns.is_sod()
        local is_cata = current_ns.is_cata and current_ns.is_cata()
        local is_wotlk = current_ns.is_wotlk and current_ns.is_wotlk()
        local is_vanilla = current_ns.is_vanilla and current_ns.is_vanilla()

        local suffixes
        if is_sod then
            suffixes = { "_sod" }
        elseif is_cata then
            suffixes = { "_cata", "_sylvanas", "_wotlk", "_vanilla" }
        elseif is_wotlk then
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
