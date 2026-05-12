-- Readability notes:
--   What: runtime module.
--   When: loaded by bootstrap or tests when required.
--   Why: keeps related behavior in one auditable file.
--   Safety: use NS helpers, guard nil values, and avoid hot-path allocations.

-- Decision notes:
--   This support module keeps side effects explicit and routes runtime-sensitive work through NS helpers.
--   Comments emphasize intent and constraints so future edits preserve behavior without adding frame-costly checks.
--   When API data is missing, callers should skip unsafe work rather than guessing.
-- ============================================================================
-- Optimizer Bridge - Export/Import for rotation optimization
-- ============================================================================
-- Bridge between EaxRotations schema and an external RotationLoader.
-- Uses proto/sylvanas_rotation.proto format for JSON export/import.
--
-- Export Flow:
--   EaxRotations Schema → NS.export_rotation() → JSON (RotationExport proto)
--
-- Import Flow:
--   Optimized JSON → NS.import_rotation() → EaxRotations Settings
--
-- Usage:
--   local json = NS.export_rotation("warlock", "affliction", context.settings)
--   NS.import_rotation(json)
-- ============================================================================

local NS = _G.EaxRotations
if not NS then return end

-- ============================================================================
-- CONSTANTS (mirrors proto/sylvanas_rotation.proto enums)
-- ============================================================================
local RotationClass = {
    UNKNOWN = 0,
    DRUID = 1,
    HUNTER = 2,
    MAGE = 3,
    PALADIN = 4,
    PRIEST = 5,
    ROGUE = 6,
    SHAMAN = 7,
    WARLOCK = 8,
    WARRIOR = 9,
}

local RotationSpec = {
    UNKNOWN = 0,
    BALANCE_DRUID = 1,
    FERAL_CAT_DRUID = 2,
    FERAL_BEAR_DRUID = 3,
    RESTORATION_DRUID = 4,
    BEAST_MASTERY_HUNTER = 5,
    MARKSMANSHIP_HUNTER = 6,
    SURVIVAL_HUNTER = 7,
    ARCANE_MAGE = 8,
    FIRE_MAGE = 9,
    FROST_MAGE = 10,
    HOLY_PALADIN = 11,
    PROTECTION_PALADIN = 12,
    RETRIBUTION_PALADIN = 13,
    DISCIPLINE_PRIEST = 14,
    HOLY_PRIEST = 15,
    SHADOW_PRIEST = 16,
    ASSASSINATION_ROGUE = 17,
    COMBAT_ROGUE = 18,
    SUBTLETY_ROGUE = 19,
    ELEMENTAL_SHAMAN = 20,
    ENHANCEMENT_SHAMAN = 21,
    RESTORATION_SHAMAN = 22,
    AFFLICTION_WARLOCK = 23,
    DEMONOLOGY_WARLOCK = 24,
    DESTRUCTION_WARLOCK = 25,
    ARMS_WARRIOR = 26,
    FURY_WARRIOR = 27,
    PROTECTION_WARRIOR = 28,
}

-- ============================================================================
-- CLASS/SPEC MAPPING
-- ============================================================================
local ClassSpecMap = {
    warlock = {
        affliction = RotationSpec.AFFLICTION_WARLOCK,
        demonology = RotationSpec.DEMONOLOGY_WARLOCK,
        destruction = RotationSpec.DESTRUCTION_WARLOCK,
    },
    mage = {
        arcane = RotationSpec.ARCANE_MAGE,
        fire = RotationSpec.FIRE_MAGE,
        frost = RotationSpec.FROST_MAGE,
    },
    warrior = {
        arms = RotationSpec.ARMS_WARRIOR,
        fury = RotationSpec.FURY_WARRIOR,
        protection = RotationSpec.PROTECTION_WARRIOR,
    },
    shaman = {
        elemental = RotationSpec.ELEMENTAL_SHAMAN,
        enhancement = RotationSpec.ENHANCEMENT_SHAMAN,
        restoration = RotationSpec.RESTORATION_SHAMAN,
    },
    druid = {
        balance = RotationSpec.BALANCE_DRUID,
        cat = RotationSpec.FERAL_CAT_DRUID,
        bear = RotationSpec.FERAL_BEAR_DRUID,
        resto = RotationSpec.RESTORATION_DRUID,
    },
    priest = {
        shadow = RotationSpec.SHADOW_PRIEST,
        holy = RotationSpec.HOLY_PRIEST,
        discipline = RotationSpec.DISCIPLINE_PRIEST,
    },
    paladin = {
        holy = RotationSpec.HOLY_PALADIN,
        protection = RotationSpec.PROTECTION_PALADIN,
        retribution = RotationSpec.RETRIBUTION_PALADIN,
    },
    rogue = {
        assassination = RotationSpec.ASSASSINATION_ROGUE,
        combat = RotationSpec.COMBAT_ROGUE,
        subtlety = RotationSpec.SUBTLETY_ROGUE,
    },
    hunter = {
        beast_mastery = RotationSpec.BEAST_MASTERY_HUNTER,
        marksmanship = RotationSpec.MARKSMANSHIP_HUNTER,
        survival = RotationSpec.SURVIVAL_HUNTER,
    },
}

local ClassMap = {
    warlock = RotationClass.WARLOCK,
    mage = RotationClass.MAGE,
    warrior = RotationClass.WARRIOR,
    shaman = RotationClass.SHAMAN,
    druid = RotationClass.DRUID,
    priest = RotationClass.PRIEST,
    paladin = RotationClass.PALADIN,
    rogue = RotationClass.ROGUE,
    hunter = RotationClass.HUNTER,
}

-- ============================================================================
-- EXPORT: EaxRotations Settings → RotationExport JSON
-- ============================================================================
-- @param class string - Class name (e.g., "warlock")
-- @param spec string - Spec name (e.g., "affliction")
-- @param settings table - Current settings from context.settings
-- @return string - JSON string matching RotationExport proto format
function NS.export_rotation(class, spec, settings)
    if not class or not spec then
        NS.log("[OptimizerBridge] ERROR: class and spec required")
        return nil
    end

    local class_id = ClassMap[class] or 0
    local spec_id = (ClassSpecMap[class] and ClassSpecMap[class][spec]) or 0

    -- Build SettingBinding array from settings table
    local bindings = {}
    if settings then
        for key, value in pairs(settings) do
            local binding = {
                key = key,
            }
            if type(value) == "string" then
                binding.string_value = value
            elseif type(value) == "number" then
                binding.number_value = value
            elseif type(value) == "boolean" then
                binding.bool_value = value
            end
            table.insert(bindings, binding)
        end
    end

    -- Build RotationExport structure
    local export = {
        api_version = 1,
        export_version = "1.0",
        source_addon = "EaxRotations",
        addon_version = "Sylvanas-API",
        game_version = "TBC",
        exported_at = os.time(),
        rotations = {
            {
                id = class .. "_" .. spec,
                name = class .. " " .. spec,
                class = class_id,
                spec = spec_id,
                playstyle = spec,
                enabled = true,
                settings = bindings,
            }
        },
    }

    -- Serialize to JSON (manual implementation for Lua 5.1 compatibility)
    return NS._json_encode(export)
end

-- ============================================================================
-- IMPORT: Optimized JSON → EaxRotations Settings
-- @param json_string string - JSON from genetic optimizer
-- @return table|nil - Imported settings or nil on failure
function NS.import_rotation(json_string)
    if not json_string then
        NS.log("[OptimizerBridge] ERROR: json_string required")
        return nil
    end

    local ok, export = pcall(NS._json_decode, json_string)
    if not ok or not export then
        NS.log("[OptimizerBridge] ERROR: Failed to parse JSON")
        return nil
    end

    if not export.rotations or #export.rotations == 0 then
        NS.log("[OptimizerBridge] ERROR: No rotations in export")
        return nil
    end

    local settings = {}
    local rotation = export.rotations[1]

    if rotation.settings then
        for _, binding in ipairs(rotation.settings) do
            local key = binding.key
            if key then
                if binding.string_value then
                    settings[key] = binding.string_value
                elseif binding.number_value then
                    settings[key] = binding.number_value
                elseif binding.bool_value ~= nil then
                    settings[key] = binding.bool_value
                end
            end
        end
    end

    NS.log("[OptimizerBridge] Imported " .. #rotation.settings .. " settings for " .. rotation.name)
    return settings
end

-- ============================================================================
-- JSON ENCODING HELPER (Lua 5.1 compatible)
-- ============================================================================
function NS._json_encode(obj)
    local function encode(v)
        if type(v) == "nil" then return "null" end
        if type(v) == "boolean" then return v and "true" or "false" end
        if type(v) == "number" then return tostring(v) end
        if type(v) == "string" then
            local escaped = v:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
            return '"' .. escaped .. '"'
        end
        if type(v) == "table" then
            local is_array = #v > 0
            local parts = {}
            if is_array then
                for _, val in ipairs(v) do
                    table.insert(parts, encode(val))
                end
                return "[" .. table.concat(parts, ",") .. "]"
            else
                for k, val in pairs(v) do
                    if type(k) == "string" then
                        table.insert(parts, encode(k) .. ":" .. encode(val))
                    end
                end
                return "{" .. table.concat(parts, ",") .. "}"
            end
        end
        return "null"
    end
    return encode(obj)
end

-- ============================================================================
-- JSON DECODING HELPER (Lua 5.1 compatible - simplified)
-- ============================================================================
function NS._json_decode(json)
    local pos = 1
    local function skip_whitespace()
        while pos <= #json and json:match("^%s", pos) do
            pos = pos + 1
        end
    end
    local parse_object, parse_array, parse_string, parse_boolean, parse_null, parse_number  -- forward declarations (fixes W113)
    local function parse_value()
        skip_whitespace()
        local c = json:sub(pos, pos)
        if c == "{" then return parse_object()
        elseif c == "[" then return parse_array()
        elseif c == '"' then return parse_string()
        elseif c == "t" or c == "f" then return parse_boolean()
        elseif c == "n" then return parse_null()
        else return parse_number() end
    end
    -- luacheck: push ignore 231  -- parse_* are local helpers used by parse_value dispatch
    parse_object = function()
        pos = pos + 1 -- skip {
        local obj = {}
        skip_whitespace()
        if json:sub(pos, pos) == "}" then pos = pos + 1 return obj end
        while true do
            local key = parse_value()
            skip_whitespace()
            pos = pos + 1 -- skip :
            local val = parse_value()
            obj[key] = val
            skip_whitespace()
            local c = json:sub(pos, pos)
            pos = pos + 1
            if c == "}" then break end
        end
        return obj
    end
    parse_array = function()
        pos = pos + 1 -- skip [
        local arr = {}
        skip_whitespace()
        if json:sub(pos, pos) == "]" then pos = pos + 1 return arr end
        while true do
            table.insert(arr, parse_value())
            skip_whitespace()
            local c = json:sub(pos, pos)
            pos = pos + 1
            if c == "]" then break end
        end
        return arr
    end
    parse_string = function()
        pos = pos + 1 -- skip "
        local start = pos
        while pos <= #json do
            local c = json:sub(pos, pos)
            if c == '"' then
                local s = json:sub(start, pos - 1)
                pos = pos + 1
                return s:gsub("\\n", "\n"):gsub("\\t", "\t"):gsub('\\"', '"'):gsub("\\\\", "\\")
            end
            pos = pos + 1
        end
        return ""
    end
    parse_number = function()
        local start = pos
        while pos <= #json and json:match("[%d%.%-]", pos) do
            pos = pos + 1
        end
        return tonumber(json:sub(start, pos - 1)) or 0
    end
    parse_boolean = function()
        if json:sub(pos, pos + 3) == "true" then pos = pos + 4 return true end
        pos = pos + 5 return false
    end
    parse_null = function()
        pos = pos + 4 return nil
    end
    -- luacheck: pop
    skip_whitespace()
    return parse_value()
end

NS.log("Optimizer Bridge module loaded (export_rotation / import_rotation)")
return {
    export_rotation = NS.export_rotation,
    import_rotation = NS.import_rotation,
}
