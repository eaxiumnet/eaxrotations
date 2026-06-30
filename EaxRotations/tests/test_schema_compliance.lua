-- test_schema_compliance.lua -- Schema standardization compliance test (Phase 1).
-- WHAT:  validates that all 9 class schema files follow the standard structure:
--          (a) Required tabs present: General, Leveling, Consumables
--          (b) Tab order: General -> [spec tabs] -> Leveling -> Consumables
--          (c) Required common keys in General -> Rotation section
--          (d) Consumables tab uses the shared module (when migrated)
-- WHEN:  run as a standalone test or via run_rotation_tests.lua.
-- WHY:   locks the schema standardization contract so new schemas conform and
--        existing schemas don't regress. Part of the open-source readability effort.
-- SAFETY: pure file-read static analysis; no engine API calls; no module loading.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function read_file(path)
    local f = assert(io.open(path, "rb"), "open failed: " .. path)
    local text = f:read("*a") or ""
    f:close()
    return text
end

-- All 9 class schema files.
local schema_files = {
    "EaxRotations/classes/druid/schema_sylvanas.lua",
    "EaxRotations/classes/hunter/schema_sylvanas.lua",
    "EaxRotations/classes/mage/schema_sylvanas.lua",
    "EaxRotations/classes/paladin/schema_sylvanas.lua",
    "EaxRotations/classes/priest/schema_sylvanas.lua",
    "EaxRotations/classes/rogue/schema_sylvanas.lua",
    "EaxRotations/classes/shaman/schema_sylvanas.lua",
    "EaxRotations/classes/warlock/schema_sylvanas.lua",
    "EaxRotations/classes/warrior/schema_sylvanas.lua",
}

-- Required tabs that must be present in all schemas.
local REQUIRED_TABS = { "General", "Leveling", "Consumables" }

-- Required common keys in General -> Rotation section.
local REQUIRED_KEYS = {
    "playstyle",
    "use_cooldowns",
    "use_interrupt",
    "use_threat_drop",
    "aoe_threshold",
}

local function add_issue(issues, path, rule, detail)
    issues[#issues + 1] = string.format("%s :: %s :: %s", path, rule, detail)
end

local function basename(path)
    return path:match("([^/]+)$") or path
end

-- Extract tab names from the schema file.
local function extract_tabs(text)
    local tabs = {}
    for name in text:gmatch('name%s*=%s*"([^"]+)"') do
        tabs[#tabs + 1] = name
    end
    return tabs
end

-- Check if a key is present in the file (using pattern matching, not literal).
local function has_key(text, key)
    return text:find('key%s*=%s*"' .. key .. '"') ~= nil
end

-- Check if the file uses the shared consumables module.
local function uses_shared_consumables(text)
    return text:find('require%("shared/schema_consumables_sylvanas"%)') ~= nil or
           text:find("require('shared/schema_consumables_sylvanas')") ~= nil
end

local issues = {}
local migrated_count = 0
local legacy_count = 0

for _, path in ipairs(schema_files) do
    local text = read_file(path)
    local fname = basename(path)
    
    -- (a) Check required tabs are present.
    local tabs = extract_tabs(text)
    for _, required_tab in ipairs(REQUIRED_TABS) do
        local found = false
        for _, tab in ipairs(tabs) do
            if tab == required_tab then
                found = true
                break
            end
        end
        if not found then
            add_issue(issues, path, "missing-tab", "Required tab '" .. required_tab .. "' not found. Found: " .. table.concat(tabs, ", "))
        end
    end
    
    -- (b) Check tab order: General should be first, Consumables should be last.
    if #tabs >= 2 then
        if tabs[1] ~= "General" then
            add_issue(issues, path, "wrong-tab-order", "General tab should be first, but found '" .. tabs[1] .. "'")
        end
        if tabs[#tabs] ~= "Consumables" then
            add_issue(issues, path, "wrong-tab-order", "Consumables tab should be last, but found '" .. tabs[#tabs] .. "'")
        end
    end
    
    -- (c) Check required common keys in General -> Rotation section.
    for _, key in ipairs(REQUIRED_KEYS) do
        if not has_key(text, key) then
            add_issue(issues, path, "missing-required-key", "Required key '" .. key .. "' not found in General -> Rotation section")
        end
    end
    
    -- (d) Check if the file uses the shared consumables module.
    if uses_shared_consumables(text) then
        migrated_count = migrated_count + 1
    else
        legacy_count = legacy_count + 1
    end
end

if #issues > 0 then
    error("schema compliance failed:\n- " .. table.concat(issues, "\n- "), 0)
end

print(string.format("PASS test_schema_compliance (%d migrated to shared module, %d legacy)", migrated_count, legacy_count))
