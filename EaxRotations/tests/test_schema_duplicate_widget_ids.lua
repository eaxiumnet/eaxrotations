-- test_schema_duplicate_widget_ids.lua — Guards the menu unique-id contract.
-- WHAT:  loads all 9 class schemas and verifies every menu setting key that
--        appears more than once within a class is defined identically each time.
-- WHEN:  run standalone or via run_rotation_tests.lua.
-- WHY:   core.menu.checkbox/slider_int(..., id) require a UNIQUE id, and settings
--        resolve by string key. The menu builder (main.lua initialize_schema_menu)
--        reuses the FIRST control created for a repeated key, so a key reused with
--        a conflicting definition (different type/bounds/default/options) would
--        silently render the wrong control and bind the wrong value. Schemas may
--        share a key across tabs (e.g. priest Smart Casting in Discipline+Holy,
--        hunter Shot Weaving in General + each spec tab), but every occurrence
--        MUST be structurally identical.
-- SAFETY: pure data loading; the schema files and their shared deps are plain
--         tables with no engine API calls, so no core.* mocking is required.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local schema_modules = {
    "classes/druid/schema_sylvanas",
    "classes/hunter/schema_sylvanas",
    "classes/mage/schema_sylvanas",
    "classes/paladin/schema_sylvanas",
    "classes/priest/schema_sylvanas",
    "classes/rogue/schema_sylvanas",
    "classes/shaman/schema_sylvanas",
    "classes/warlock/schema_sylvanas",
    "classes/warrior/schema_sylvanas",
}

-- Collect every setting definition keyed by its widget id, walking the
-- tab -> section -> settings structure of a schema.
local function collect_defs(schema)
    local by_key = {}  -- key -> array of def tables
    if type(schema) ~= "table" then return by_key end
    for _, tab in ipairs(schema) do
        for _, section in ipairs((type(tab) == "table" and tab.sections) or {}) do
            for _, def in ipairs((type(section) == "table" and section.settings) or {}) do
                if type(def) == "table" and def.key then
                    by_key[def.key] = by_key[def.key] or {}
                    local list = by_key[def.key]
                    list[#list + 1] = def
                end
            end
        end
    end
    return by_key
end

-- Compare two definitions for the same key. Returns nil when compatible,
-- or a string describing the first incompatibility found.
local function incompatibility(a, b)
    if (a.type or "") ~= (b.type or "") then
        return string.format("type mismatch (%s vs %s)", tostring(a.type), tostring(b.type))
    end
    if a.default ~= b.default then
        return string.format("default mismatch (%s vs %s)", tostring(a.default), tostring(b.default))
    end
    if a.type == "slider" then
        if a.min ~= b.min or a.max ~= b.max then
            return string.format("slider bounds mismatch (%s..%s vs %s..%s)",
                tostring(a.min), tostring(a.max), tostring(b.min), tostring(b.max))
        end
    end
    if a.type == "dropdown" or a.type == "combobox" then
        local ao, bo = a.options or {}, b.options or {}
        if #ao ~= #bo then
            return string.format("option count mismatch (%d vs %d)", #ao, #bo)
        end
        for i = 1, #ao do
            if tostring(ao[i].value) ~= tostring(bo[i].value) then
                return string.format("option[%d] value mismatch (%s vs %s)", i,
                    tostring(ao[i].value), tostring(bo[i].value))
            end
        end
    end
    return nil
end

local issues = {}
local shared_key_count = 0

for _, mod in ipairs(schema_modules) do
    package.loaded[mod] = nil
    local ok, schema = pcall(require, mod)
    if not ok then
        issues[#issues + 1] = string.format("%s :: load-failed :: %s", mod, tostring(schema))
    else
        local by_key = collect_defs(schema)
        for key, defs in pairs(by_key) do
            if #defs > 1 then
                shared_key_count = shared_key_count + 1
                local base = defs[1]
                for i = 2, #defs do
                    local why = incompatibility(base, defs[i])
                    if why then
                        issues[#issues + 1] = string.format(
                            "%s :: duplicate-key-conflict :: key '%s' occurrence #%d incompatible: %s",
                            mod, key, i, why)
                    end
                end
            end
        end
    end
end

if #issues > 0 then
    error("schema duplicate widget id check failed:\n- " .. table.concat(issues, "\n- "), 0)
end

print(string.format("PASS test_schema_duplicate_widget_ids (%d shared keys validated as identical duplicates)", shared_key_count))
