-- test_cross_consistency.lua -- Phase 2 cross-consistency assertion.
-- WHAT:  verifies that three "source of truth" locations for playstyles agree:
--          (1) class_sylvanas.lua  -> playstyles = { { name = "x" }, ... }
--          (2) schema_sylvanas.lua -> playstyle dropdown options = { { value = "x" }, ... }
--          (3) *_sylvanas.lua files -> rotation_registry:register("x", ...)
--        Asserts: class_config playstyles == schema dropdown values
--                 class_config playstyles is a subset of registered rotation keys
-- WHEN:  run as a standalone test or via run_rotation_tests.lua.
-- WHY:   prevents drift between what the engine knows, what the UI shows,
--        and what rotations are actually implemented.
-- SAFETY: pure file-read static analysis via lfs.dir; no engine API calls.
-- NOTE: lfs is an optional dependency (LuaFileSystem). When it is unavailable
-- (e.g. the stock Windows Lua 5.4 used by the local test runner has no lfs.dll),
-- this test SKIPS cleanly and reports PASS rather than crashing the whole
-- rotation suite. Every other lfs-using test in this repo follows the same
-- pcall-guard + skip convention (see test_cross_expansion_spell_validation.lua,
-- EaxAutoQuester/tests/run_quester_tests.lua, EaxProfessions/tests/run_professions_tests.lua).

local has_lfs, lfs = pcall(require, "lfs")
if not has_lfs or type(lfs) ~= "table" or type(lfs.dir) ~= "function" then
  -- Graceful skip: lfs is a dev-environment only dependency for directory
  -- walking. Emit a clear message and pass so the 219-suite runner stays green.
  print("SKIP test_cross_consistency (lfs unavailable — directory walk disabled)")
  return
end

local function read_file(path)
    local f = assert(io.open(path, "rb"), "open failed: " .. path)
    local text = f:read("*a") or ""
    f:close()
    return text
end

-- Extract playstyle names from class_sylvanas.lua's playstyles block.
local function extract_class_playstyles(text)
    local ps_start = text:find("playstyles%s*=%s*{")
    if not ps_start then return nil, "playstyles block not found" end
    local ps_end = text:find("\n    }", ps_start)
    if not ps_end then return nil, "playstyles block not terminated" end
    local block = text:sub(ps_start, ps_end)
    local names = {}
    for name in block:gmatch('{ name%s*=%s*"([^"]+)"') do
        names[#names + 1] = name
    end
    if #names == 0 then return nil, "no playstyle entries found in block" end
    return names
end

-- Extract playstyle dropdown values from schema_sylvanas.lua.
-- Uses brace-counting to find the matching } for the options = { block.
-- The old greedy regex }%s*}%s*, could span across multiple dropdown
-- entries (e.g. warlock's curse_mode block after playstyle), causing
-- wrong values to be extracted.
local function extract_schema_playstyles(text)
    local ps_key = text:find('key%s*=%s*"playstyle"')
    if not ps_key then return nil, "playstyle dropdown not found" end
    local opts_start = text:find("options%s*=%s*{", ps_key)
    if not opts_start then return nil, "options block not found after playstyle key" end
    -- Find the opening { of the options table
    local brace_start = text:find("%{", opts_start)
    if not brace_start then return nil, "options opening brace not found" end
    -- Count braces to find matching close (depth hits 0)
    local depth = 0
    local opts_end = nil
    for i = brace_start, #text do
        local c = text:sub(i, i)
        if c == "{" then
            depth = depth + 1
        elseif c == "}" then
            depth = depth - 1
            if depth == 0 then
                opts_end = i
                break
            end
        end
    end
    if not opts_end then return nil, "options block not terminated" end
    local block = text:sub(opts_start, opts_end)
    local values = {}
    for value in block:gmatch('value%s*=%s*"([^"]+)"') do
        values[#values + 1] = value
    end
    if #values == 0 then return nil, "no option values found" end
    return values
end

-- Extract registered rotation keys from spec files in a class directory.
local function extract_registered_keys(class_dir)
    local keys = {}
    local seen = {}
    for filename in lfs.dir(class_dir) do
        if filename ~= "." and filename ~= ".." then
            if (filename:match("_sylvanas%.lua$") or filename:match("_vanilla%.lua$"))
               and not filename:match("^class_")
               and not filename:match("^middleware_") then
                local path = class_dir .. "/" .. filename
                local text = read_file(path)
                for line in text:gmatch("[^\r\n]+") do
                    if not line:match("^%s*%-%-") then
                        local key = line:match('rotation_registry:register%s*%(%s*"([^"]+)"')
                        if key and not seen[key] then
                            seen[key] = true
                            keys[#keys + 1] = key
                        end
                    end
                end
            end
        end
    end
    return keys
end

local function to_set(list)
    local set = {}
    for _, v in ipairs(list) do set[v] = true end
    return set
end

local function set_to_string(set)
    local list = {}
    for k in pairs(set) do list[#list + 1] = k end
    table.sort(list)
    return "{" .. table.concat(list, ", ") .. "}"
end

local function set_difference(a, b)
    local diff = {}
    for k in pairs(a) do
        if not b[k] then diff[k] = true end
    end
    return diff
end

local classes = {
    { key = "druid",   dir = "EaxRotations/classes/druid" },
    { key = "hunter",  dir = "EaxRotations/classes/hunter" },
    { key = "mage",    dir = "EaxRotations/classes/mage" },
    { key = "paladin", dir = "EaxRotations/classes/paladin" },
    { key = "priest",  dir = "EaxRotations/classes/priest" },
    { key = "rogue",   dir = "EaxRotations/classes/rogue" },
    { key = "shaman",  dir = "EaxRotations/classes/shaman" },
    { key = "warlock", dir = "EaxRotations/classes/warlock" },
    { key = "warrior", dir = "EaxRotations/classes/warrior" },
}

local issues = {}

local function add_issue(class, rule, detail)
    issues[#issues + 1] = string.format("%-10s :: %s :: %s", class, rule, detail)
end

for _, class in ipairs(classes) do
    local class_text = read_file(class.dir .. "/class_sylvanas.lua")
    local class_ps, err1 = extract_class_playstyles(class_text)
    if not class_ps then
        add_issue(class.key, "class-config", err1 or "unknown error")
    else
        local class_set = to_set(class_ps)
        local schema_text = read_file(class.dir .. "/schema_sylvanas.lua")
        local schema_ps, err2 = extract_schema_playstyles(schema_text)
        if not schema_ps then
            add_issue(class.key, "schema", err2 or "unknown error")
        else
            local schema_set = to_set(schema_ps)
            local reg_keys = extract_registered_keys(class.dir)
            local reg_set = to_set(reg_keys)
            local missing_in_schema = set_difference(class_set, schema_set)
            local extra_in_schema = set_difference(schema_set, class_set)
            if next(missing_in_schema) then
                add_issue(class.key, "class-not-in-schema",
                    "In class_config but not schema: " .. set_to_string(missing_in_schema))
            end
            if next(extra_in_schema) then
                add_issue(class.key, "schema-not-in-class",
                    "In schema but not class_config: " .. set_to_string(extra_in_schema))
            end
            -- Filter out meta-playstyles that aren't rotations: "auto" means
            -- talent-based detection, "leveling" IS a registered rotation.
            local class_rotations = {}
            for _, k in ipairs(class_ps) do
                if k ~= "auto" then class_rotations[#class_rotations + 1] = k end
            end
            local class_rot_set = to_set(class_rotations)
            local missing_in_reg = set_difference(class_rot_set, reg_set)
            if next(missing_in_reg) then
                add_issue(class.key, "class-not-registered",
                    "In class_config but no rotation registered: " .. set_to_string(missing_in_reg))
            end
        end
    end
end

if #issues > 0 then
    print("FAIL test_cross_consistency")
    for _, issue in ipairs(issues) do
        print("  - " .. issue)
    end
    error("test_cross_consistency failed (" .. #issues .. " issues)", 0)
else
    print("PASS test_cross_consistency (9 classes, all 3 sources agree)")
end
