-- test_schema_duplicate_widget_ids.lua — Guards the menu unique-id contract.
-- WHAT:  loads all 9 class schemas and verifies every menu setting key that
--        appears more than once within a class is defined identically each time,
--        using the SAME comparator main.lua's initialize_schema_menu runs at
--        boot. Identical re-declarations are the sanctioned shared-setting
--        pattern (silent control reuse — warning-free boots); conflicting ones
--        are accidental collisions the loader warns about once per key.
-- WHEN:  run standalone or via run_rotation_tests.lua.
-- WHY:   core.menu.checkbox/slider_int(..., id) require a UNIQUE id, and settings
--        resolve by string key. The menu builder (main.lua initialize_schema_menu)
--        reuses the FIRST control created for a repeated key, so a key reused with
--        a conflicting definition (different type/bounds/default/options) would
--        silently render the wrong control and bind the wrong value. Schemas may
--        share a key across tabs (e.g. priest Smart Casting in Discipline+Holy,
--        hunter Shot Weaving in General + each spec tab), but every occurrence
--        MUST be structurally identical. This suite doubles as the pin for the
--        warning-free-boot guarantee: because the runtime warns exactly when
--        this comparator reports a conflict and every duplicated key in every
--        schema is conflict-free, no schema can log a duplicate-key warning at
--        boot (regression: the priest Holy/Smart Casting five-key set used to
--        log five 'Duplicate schema key' warnings every boot).
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

-- Shared comparator: the exact function main.lua's initialize_schema_menu
-- uses to decide whether a duplicate key is a silent identical re-declaration
-- or a warning-worthy conflict. Single source of truth so the data guarantee
-- this suite proves is the runtime guarantee by construction.
local incompatibility = require("shared/schema_def_compat_sylvanas").incompatibility

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

-- Loader-contract pin: main.lua warns once per boot for a duplicated schema key
-- ONLY when this comparator reports a conflict. Every duplicated key across the
-- nine schemas is identical, so the boot warning set for every class is empty.
-- The priest Holy/Smart Casting five-key set (stopcast_enabled,
-- stopcast_threshold, tank_hp_bias, heal_pets, pet_weight) is the regression
-- this protects: it is declared under both the Discipline and Holy playstyle
-- tabs (identical copies, so both tabs render the section backed by one widget)
-- and must never log a duplicate-key warning at boot.
local warned_keys = {}
for _, mod in ipairs(schema_modules) do
    package.loaded[mod] = nil
    local ok, schema = pcall(require, mod)
    if ok then
        local by_key = collect_defs(schema)
        for key, defs in pairs(by_key) do
            if #defs > 1 then
                local base = defs[1]
                for i = 2, #defs do
                    if incompatibility(base, defs[i]) then
                        warned_keys[#warned_keys + 1] = string.format("%s :: '%s' occurrence #%d", mod, key, i)
                    end
                end
            end
        end
    end
end
if #warned_keys > 0 then
    error("loader-contract pin failed: conflicting duplicate keys would log warnings at boot:\n- " .. table.concat(warned_keys, "\n- "), 0)
end

-- Loader-behavior pin (static): main.lua's initialize_schema_menu must warn
-- only for CONFLICTING duplicate keys via the shared comparator — not for every
-- identical re-declaration (which is what logged five 'Duplicate schema key'
-- warnings every boot for the priest Holy/Smart Casting set). main.lua is a
-- runtime top-level file (not require-able), so assert on its source.
local loader_ok = true
local loader_reason = ""
local fh = io.open("EaxRotations/main.lua", "r")
if not fh then
    loader_ok = false
    loader_reason = "could not read EaxRotations/main.lua for the loader pin"
else
    local src = fh:read("*a")
    fh:close()
    if not src:find("schema_def_conflict", 1, true) then
        loader_ok = false
        loader_reason = "main.lua no longer references schema_def_conflict (conflict-only duplicate warning)"
    end
    if src:find("Duplicate schema key '", 1, true) then
        loader_ok = false
        loader_reason = "main.lua still contains the unconditional 'Duplicate schema key' warning (identical re-declarations would log every boot)"
    end
end
if not loader_ok then
    error("loader-behavior pin failed: " .. loader_reason, 0)
end

print(string.format("PASS test_schema_duplicate_widget_ids (%d shared keys validated as identical duplicates; loader warns on none; loader uses conflict-only rule)", shared_key_count))
