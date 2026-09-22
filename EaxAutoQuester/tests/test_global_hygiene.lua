-- test_global_hygiene.lua — no production module may leak a global or read an undeclared one.
-- WHAT:  the defect class the navigation A/B proved real — an undeclared `_stuck_attempts`
--        crashed the fallback stuck ladder with "attempt to perform arithmetic on global", and
--        the coordinator's combat override read `next_state` as a global nil, so the branch
--        tested nil instead of the state. Four checks:
--          A1 static   no bare `function NAME(` definition in a production file
--          A2 static   no statement-level global assignment for a name the file never declares
--          B  runtime  loading every production module adds no new global key
--          C  runtime  a coordinator combat tick READS no undeclared global, and the override
--                      does not depend on one (the poisoned-global pin)
-- WHEN:  part of the plugin battery (`run_quester_tests.lua`), so it runs in tools/pre-commit
--        step 20 and the CI quester step.
-- WHY:   a name that is read but never declared resolves to nil silently: no parse error, no
--        test failure, no log line, until the tick that depends on it. `luac -p` and the 5.1
--        compat gate both pass it, and a grep cannot see it — the same name is often a
--        legitimate local declared further down the function.
-- SAFETY: read-only. The runtime half installs a metatable on _G for the duration of one call
--        and removes it immediately (every write is still performed with rawset, so nothing
--        observable changes). No io.popen/os.execute/ffi.C/debug.*/math.sqrt.
-- Decision: the runtime half is instrumentation, not a source lexer, because only the runtime
--        can see *scope*. `next_state` IS a real local in coordinator.lua, two hundred lines
--        below the read that was broken; a text scan cannot tell those two apart, and the
--        bytecode can. The static half covers exactly the shapes text sees unambiguously.

package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local lfs_ok, lfs = pcall(require, "lfs")
assert(lfs_ok and lfs, "luafilesystem is required to enumerate the plugin for the hygiene gate")

-- Globals the host/API provides, plus base-library names a statement could legitimately reuse.
local KEYWORDS = {}
for _, name in ipairs({
    "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if",
    "in", "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while",
}) do KEYWORDS[name] = true end

local ALLOWED = {}
for _, name in ipairs({
    "core", "_G", "_VERSION", "arg", "menu",
    "assert", "collectgarbage", "coroutine", "debug", "dofile", "error", "getfenv",
    "getmetatable", "io", "ipairs", "load", "loadfile", "loadstring", "math", "module",
    "newproxy", "next", "os", "package", "pairs", "pcall", "print", "rawequal",
    "rawget", "rawset", "require", "select", "setfenv", "setmetatable", "string",
    "table", "tonumber", "tostring", "type", "unpack", "xpcall",
}) do ALLOWED[name] = true end

-- The one global the plugin is allowed to create: its documented namespace.
local ALLOWED_WRITES = { EaxAutoQuester = true }

-- The names this pass fixed. Any of them appearing as a read or a write means the class is back.
local PINNED_BAD = {
    "next_state", "nearby_count", "wp", "_get_item_info",
    "_stuck_level", "_stuck_attempts", "_stuck_recovery_timer",
}

local ROOT = "EaxAutoQuester/"

local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    return data
end

--- Recursively collect production .lua files (everything under the plugin except tests/).
local function production_files()
    local files = {}
    local function walk(dir)
        local ok, iter, state = pcall(lfs.dir, dir)
        if not ok then return end
        for entry in iter, state do
            if entry ~= "." and entry ~= ".." then
                local full = dir .. "/" .. entry
                local mode = lfs.attributes(full, "mode")
                if mode == "directory" then
                    if entry ~= "tests" then walk(full) end
                elseif mode == "file" and entry:sub(-4) == ".lua" then
                    files[#files + 1] = full
                end
            end
        end
    end
    walk(ROOT:sub(1, -2))
    table.sort(files)
    return files
end

local FILES = production_files()
assert(#FILES >= 40, "expected the production tree to be enumerable, found " .. #FILES .. " files")

--- Strip comments and quoted strings from one line so the checks see code only.
--- The comment start must be escaped (%-%-): a bare `-` is Lua's lazy-repetition modifier,
--- so `--[^\n]*$` matches the whole line and would blank every line in the file.
local function code_only(line)
    line = line:gsub("%-%-[^\n]*$", "")
    line = line:gsub('"[^"]*"', '""')
    line = line:gsub("'[^']*'", "''")
    return line
end

--- Every name a file can assign at statement level without touching a global: locals,
--- function parameters (reassigning a parameter is a local write — `range = range or 50` is
--- the shape that produced most of this check's initial noise) and for-loop variables.
--- File-wide and over-inclusive on purpose: erring permissive keeps A2 from failing on
--- ordinary code. The cost is that A2 cannot see a global write to a name that ALSO has a
--- legitimate local somewhere in the file (that was `wp` in idle_state.lua) — that shape is
--- only visible in the bytecode, so it is covered by the inventory in
--- docs/global_hygiene_inventory.md and by the runtime tripwires here, not by this text scan.
local function declared_locals(masked)
    local names = {}
    local function add(list)
        for name in list:gmatch("([A-Za-z_][%w_]*)") do names[name] = true end
    end

    -- `local a, b = ...` / `local function f(...)` — whatever sits between `local` and the
    -- first `=`, which covers multi-line declarations (`local t = {` on its own line).
    for line in (masked .. "\n"):gmatch("(.-)\n") do
        local decl = line:match("^%s*local%s+(.-)%s*$")
        if decl then
            local head = decl:match("^(.-)=") or decl
            add((head:gsub("^function%s+", "")))
        end
    end

    -- parameter lists of named, local and anonymous functions (may span lines)
    for params in masked:gmatch("function%s*[%w_%.:]*%s*%(([^%)]*)%)") do add(params) end

    -- for-loop variables, numeric (`for i = 1, n`) and generic (`for i, v in pairs(t)`)
    for header in masked:gmatch("for%s+([^=\n]-)=") do add(header) end
    for header in masked:gmatch("for%s+([^\n]-)%s+in%s") do add(header) end

    return names
end

-- ============================================================================
-- A1 + A2 — static
-- ============================================================================

local static_violations = {}
local scanned = 0

for _, path in ipairs(FILES) do        local src = read_file(path)
        if src then
            scanned = scanned + 1
            -- A whole-file mask for declaration gathering (newlines preserved so line
            -- splitting still works), and a per-line mask for the two statement checks.
            local masked = src:gsub("%-%-[^\n]*", function(m) return m:gsub("[^\n]", " ") end)
            local locals = declared_locals(masked)
        local depth = 0
        local line_no = 0
        for line in (src .. "\n"):gmatch("(.-)\n") do
            line_no = line_no + 1
            local code = code_only(line)

            -- A1: a bare global function definition. Every legitimate export is `function M.x(`
            -- or `function NS.x(`, so the allowlist here is empty by construction.
            -- A forward-declared local (`local parse_value` then `function parse_value(...)`)
            -- assigns the local, not a global — the bytecode shows GETUPVAL for it.
            local fn = code:match("^function%s+([A-Za-z_][%w_]*)%s*%(")
            if fn and not ALLOWED[fn] and not KEYWORDS[fn] and not locals[fn] then
                static_violations[#static_violations + 1] = string.format(
                    "%s:%d global function definition '%s' (declare it local)", path, line_no, fn)
            end

            -- A2: a statement-level assignment to a bare name, at brace depth 0 so table
            -- constructor keys (which are at depth >= 1) are not mistaken for assignments.
            if depth == 0 then
                local name = code:match("^%s*([A-Za-z_][%w_]*)%s*=[^=]")
                if not name then
                    name = code:match("^%s*([A-Za-z_][%w_]*)%s*,[^=]-=[^=]")
                end
                if name and not locals[name] and not ALLOWED[name] and not KEYWORDS[name] then
                    static_violations[#static_violations + 1] = string.format(
                        "%s:%d global assignment to '%s' (declare it local)", path, line_no, name)
                end
            end

            local opens = select(2, code:gsub("{", ""))
            local closes = select(2, code:gsub("}", ""))
            depth = depth + opens - closes
            if depth < 0 then depth = 0 end
        end
    end
end

assert(scanned >= 40, "expected every production file to be readable, scanned " .. scanned)
assert(#static_violations == 0,
    "A static check FAILED — " .. #static_violations .. " accidental global(s):\n    " ..
    table.concat(static_violations, "\n    "))
print("A PASS: " .. scanned .. " production files carry no bare global definition or assignment")

-- ============================================================================
-- Runtime tripwires
-- ============================================================================

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

--- Run fn with _G instrumented. kind = "write" records global writes, "read" records reads of
--- globals that do not exist (a nil read — exactly the defect class).
local function with_tripwire(kind, fn)
    local hits = {}
    local mt = {}
    if kind == "write" then
        mt.__newindex = function(t, k, v) hits[#hits + 1] = k; rawset(t, k, v) end
    else
        mt.__index = function(_, k) hits[#hits + 1] = k; return nil end
    end
    setmetatable(_G, mt)
    local ok, err = pcall(fn)
    setmetatable(_G, nil)
    return hits, ok, err
end

local function unexpected(hits)
    local bad = {}
    for _, name in ipairs(hits) do
        if not ALLOWED_WRITES[name] and not ALLOWED[name] then bad[#bad + 1] = name end
    end
    return bad
end

-- B: loading every production module must not add a global key.
local MODULES = {
    "anti_detection_sylvanas", "combat_helper_sylvanas", "death_tracker_sylvanas",
    "diagnostic_dump_sylvanas", "dungeon_detector_sylvanas", "equipment_compare_sylvanas",
    "flight_path_sylvanas", "goal_filter_sylvanas", "goal_resolver_sylvanas", "json_loader",
    "loot_manager_sylvanas", "menu_sylvanas", "mount_manager_sylvanas", "navigation_sylvanas",
    "npc_db_sylvanas", "npc_manager_sylvanas", "npc_spawns", "object_scanner",
    "progress_tracker_sylvanas", "quest_blacklist_sylvanas", "quest_frame_events_sylvanas",
    "quest_interaction_sylvanas", "quest_item_manager_sylvanas",
    "questie_reader_sylvanas", "safe_api_wrapper", "service_gossip_sylvanas",
    "static_popup_sylvanas", "utils_sylvanas", "vendor_manager_sylvanas",
    "waypoint_fixer_sylvanas", "zygor_reader_sylvanas", "shared/corpse_loot",
    "quest_state/coordinator", "quest_state/dead_state", "quest_state/do_action_state",
    "quest_state/idle_state", "quest_state/interact_state", "quest_state/nav_state",
    "quest_state/waiting_state",
}
do
    mock.reset()
    local load_errors = {}
    local writes = with_tripwire("write", function()
        for _, name in ipairs(MODULES) do
            package.loaded[name] = nil
            local ok, err = pcall(require, name)
            if not ok then load_errors[#load_errors + 1] = name .. " (" .. tostring(err) .. ")" end
        end
    end)
    assert(#load_errors == 0,
        "B FAIL: production module(s) failed to load under the mock: " ..
        table.concat(load_errors, ", "))
    local bad = unexpected(writes)
    assert(#bad == 0,
        "B FAIL: loading the plugin created global(s): " .. table.concat(bad, ", "))
    print("B PASS: " .. #MODULES .. " production modules load and create no global")
end

-- C: a coordinator combat tick must read no undeclared global, and the combat override must
-- work whatever a stray global of the old name happens to contain.
local coordinator = require("quest_state/coordinator")
do
    mock.reset()
    mock.create_player({ pos = { x = 0, y = 0, z = 0 }, combat = false })
    coordinator.update()
    local pre = coordinator._test_inspect()
    assert(pre == "WAITING",
        "C FAIL: expected a first idle tick to park in WAITING, got " .. tostring(pre))

    -- The poison: the old code read exactly this name as a global, so a stray global holding
    -- "IDLE" silently disabled the combat override.
    _G.next_state = "IDLE"
    mock.create_player({ pos = { x = 0, y = 0, z = 0 }, combat = true })
    local reads = with_tripwire("read", function() coordinator.update() end)
    local state = coordinator._test_inspect()

    for _, name in ipairs(PINNED_BAD) do
        for _, seen in ipairs(reads) do
            assert(seen ~= name,
                "C FAIL: the combat tick READ undeclared global '" .. name .. "'")
        end
    end
    assert(state == "IDLE",
        "C FAIL: combat must override " .. tostring(pre) .. " to IDLE even with _G.next_state " ..
        "poisoned; state is " .. tostring(state))
    assert(_G.next_state == "IDLE",
        "C FAIL: the coordinator must not write _G.next_state (found " ..
        tostring(_G.next_state) .. ")")
    _G.next_state = nil

    -- And with no poison at all, the same override still happens.
    mock.reset()
    mock.create_player({ pos = { x = 0, y = 0, z = 0 }, combat = false })
    coordinator.update()
    mock.create_player({ pos = { x = 0, y = 0, z = 0 }, combat = true })
    local reads2 = with_tripwire("read", function() coordinator.update() end)
    assert(coordinator._test_inspect() == "IDLE",
        "C FAIL: combat override must not need any global to fire")
    assert(#reads2 == 0,
        "C FAIL: a combat tick should read no missing global at all, read: " ..
        table.concat(reads2, ", "))
    print("C PASS: combat tick reads no undeclared global; override survives a poisoned _G")
end

print("PASS test_global_hygiene")
os.exit(0)
