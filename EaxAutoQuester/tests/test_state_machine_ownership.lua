-- What: Pins the Phase 1 unification of the quest state machine (one machine, one owner).
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: The plugin shipped TWO state machines — production ran a 1,823-line monolith that no
--      suite loaded, while the suites covered a modular machine nothing required. This
--      suite fails if that fork ever returns: main.lua must load only the modular machine,
--      the retired loader must stay deleted, exactly one file may own the shared state
--      table, every handler must keep the run(shared, ctx) contract, and no suite may load
--      a private copy of a module production uses.
-- Safety: read-only source scans (io.open) plus require identity checks. Requires modules by
--      their bare production identity, so a suite can never pass against a duplicate table.

-- Path setup for standalone run
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

-- =============================================================================
-- Helpers — plugin root, source reads, suite discovery
-- =============================================================================

--- Locate the plugin root so this suite runs from the repo root or the plugin root.
local function plugin_root()
    for _, prefix in ipairs({ "EaxAutoQuester/", "" }) do
        local f = io.open(prefix .. "main.lua", "r")
        if f then
            f:close()
            return prefix
        end
    end
    return nil
end

local ROOT = plugin_root()
assert(ROOT, "EaxAutoQuester root not found (expected main.lua in ./ or ./EaxAutoQuester/)")

local function read_source(rel)
    local f = io.open(ROOT .. rel, "r")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    return data
end

local function exists(rel)
    local f = io.open(ROOT .. rel, "r")
    if not f then return false end
    f:close()
    return true
end

local function lines_of(src)
    return src:gmatch("[^\r\n]+")
end

-- Assembled from parts so that this file's own text is never a reference to the old loader.
local RETIRED = "quest_state_" .. "sylvanas"
-- Same trick for the path prefix suites must not use (only the module identity is asserted).
local PREFIX = "EaxAuto" .. "Quester/"

--- Every suite the runner can discover: lfs when present, else the runner's own list.
local function list_suites()
    local ok, lfs = pcall(require, "lfs")
    if ok and lfs and lfs.dir then
        local names = {}
        for entry in lfs.dir(ROOT .. "tests") do
            if entry:match("^test_.*%.lua$") then names[#names + 1] = entry end
        end
        if #names > 0 then
            table.sort(names)
            return names, "lfs"
        end
    end
    -- Fallback: the names the runner itself lists, so the scan still covers the battery
    -- where lfs is unavailable.
    local runner = read_source("tests/run_quester_tests.lua")
    assert(runner, "runner source must be readable")
    local names = {}
    for name in runner:gmatch('"(test_[%w_]+%.lua)"') do names[#names + 1] = name end
    table.sort(names)
    return names, "runner-list"
end

local QS_FILES = {
    "coordinator", "idle_state", "nav_state", "interact_state",
    "do_action_state", "waiting_state", "dead_state",
}
local HANDLERS = {
    "idle_state", "nav_state", "interact_state",
    "do_action_state", "waiting_state", "dead_state",
}

local suites, discovery = list_suites()
assert(#suites >= 30,
    "expected the suite list to cover the battery, saw " .. tostring(#suites) .. " (" .. discovery .. ")")

-- =============================================================================
-- 1. main.lua loads exactly one state machine
-- =============================================================================

local main_src = read_source("main.lua")
assert(main_src, "main.lua must exist")
assert(main_src:find('require, "quest_state/coordinator"', 1, true),
    'main.lua must load the modular machine (require, "quest_state/coordinator")')
assert(not main_src:find(RETIRED, 1, true),
    "main.lua must not reference the retired state-machine loader")

-- =============================================================================
-- 2. The retired loader stays deleted and unreferenced
-- =============================================================================

assert(not exists(RETIRED .. ".lua"),
    "the retired state machine must stay deleted — the plugin has exactly one")

local scan_targets = { "main.lua" }
for _, name in ipairs(suites) do scan_targets[#scan_targets + 1] = "tests/" .. name end
for _, name in ipairs(QS_FILES) do scan_targets[#scan_targets + 1] = "quest_state/" .. name .. ".lua" end
do
    local ok, lfs = pcall(require, "lfs")
    if ok and lfs and lfs.dir then
        for entry in lfs.dir(ROOT) do
            if entry:match("%.lua$") then scan_targets[#scan_targets + 1] = entry end
        end
    end
end

local referenced = {}
for _, rel in ipairs(scan_targets) do
    local src = read_source(rel)
    if src and src:find(RETIRED, 1, true) then referenced[#referenced + 1] = rel end
end
assert(#referenced == 0,
    "retired loader still referenced by: " .. table.concat(referenced, ", "))

-- =============================================================================
-- 3. Exactly one owner of the shared state table, one dispatch contract
-- =============================================================================

local owners = {}
for _, name in ipairs(QS_FILES) do
    local src = read_source("quest_state/" .. name .. ".lua")
    assert(src, "quest_state/" .. name .. ".lua must exist")
    for line in lines_of(src) do
        if line:match("^local shared%s*=%s*{") then
            owners[#owners + 1] = name
            break
        end
    end
end
assert(#owners == 1,
    "exactly one module may own the shared state table, found " .. tostring(#owners) ..
    ": " .. table.concat(owners, ", "))
assert(owners[1] == "coordinator",
    "the coordinator must own the shared state table, not " .. tostring(owners[1]))

for _, name in ipairs(HANDLERS) do
    local src = read_source("quest_state/" .. name .. ".lua")
    assert(src:find("function M.run(shared, ctx)", 1, true),
        "quest_state/" .. name .. ".lua must define function M.run(shared, ctx)")
end

local api_owners = {}
for _, name in ipairs(QS_FILES) do
    local src = read_source("quest_state/" .. name .. ".lua")
    for line in lines_of(src) do
        if line:match("^function M%.update%(%)") or line:match("^function M%.stop_navigation%(%)") then
            api_owners[#api_owners + 1] = name
            break
        end
    end
end
assert(#api_owners == 1 and api_owners[1] == "coordinator",
    "only the coordinator may define update()/stop_navigation(); found: " ..
    table.concat(api_owners, ", "))

-- =============================================================================
-- 4. No suite loads a private copy of a production module
-- =============================================================================

local offenders = {}
for _, name in ipairs(suites) do
    local src = read_source("tests/" .. name)
    if src then
        for line in lines_of(src) do
            local is_require = line:match("require%s*%(%s*\"" .. PREFIX) or
                               line:match("require%s*,%s*\"" .. PREFIX)
            local is_stub = line:match("package%.loaded%[%s*\"" .. PREFIX)
            local keeps_tests = line:match(PREFIX .. "tests/")
            if (is_require or is_stub) and not keeps_tests then
                offenders[#offenders + 1] = name .. " :: " .. line:gsub("^%s+", "")
                break
            end
        end
    end
end
assert(#offenders == 0,
    "suites must load plugin modules by their production identity (bare name); " ..
    "duplicate-identity loads found: " .. table.concat(offenders, " | "))

-- Runtime side: the machine the suites reach is the machine production loads.
local coordinator = require("quest_state/coordinator")
assert(type(coordinator.update) == "function", "coordinator.update must be a function")
assert(_G.EaxAutoQuester and _G.EaxAutoQuester.quest_state == coordinator,
    "the global quest_state export must be the same table the suites load")

for _, name in ipairs(HANDLERS) do
    assert(package.loaded["quest_state/" .. name] ~= nil,
        "quest_state/" .. name .. " must be resident under the production identity")
    assert(package.loaded[PREFIX .. "quest_state/" .. name] == nil,
        "quest_state/" .. name .. " must not be resident under a second identity")
end
assert(package.loaded[PREFIX .. "quest_state/coordinator"] == nil,
    "the coordinator must not be resident under a second identity")

print("state machine: 1 owner, " .. tostring(#QS_FILES) .. " modules, " ..
    tostring(#suites) .. " suites on the production identity (" .. discovery .. " discovery)")
