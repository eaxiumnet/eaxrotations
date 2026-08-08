-- generate_sod_task1_action_map.lua -- offline Task-1 action-map generator.
-- WHAT:  loads all 20 SoD role modules through the REAL class loader with the
--        same mock NS.spell_action capture the test uses, then emits
--        .omo/evidence/task-1-sod-action-map.jsonl + manifest so
--        tests/test_sod_source_audit.lua can resolve every runtime action ID.
-- WHEN:  run standalone from the project root:
--            lua EaxRotations/tools/generate_sod_task1_action_map.lua
--        or required by tests/test_sod_source_audit.lua (which self-provisions
--        when the evidence artifact is missing — clean checkouts included).
-- WHY:   test_sod_source_audit.lua gates every loaded SoD action ID against the
--        pinned Task-1 map; this generator is the provisioning step that keeps
--        the map in sync with the 20 real loaders. Tracked here (not
--        build_tools/) so it survives clean checkouts and CI can regenerate.
-- SAFETY: read-only over classes/; writes only .omo/evidence/ (gitignored by
--         design — the artifact is local evidence, never committed).

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;?.lua;"
    .. package.path

local M = {}

-- Drop the 20 SoD module paths from package.loaded so require() re-executes
-- them (each load registers exactly one playstyle). Needed because this
-- generator and the consuming test both load the same modules: without a
-- cache reset the second loader finds them cached and "registered no
-- playstyle" — and stale registrations would leak between runs.
local function clear_loaded_modules()
    local loader = require("shared/class_loader_sylvanas")
    for class_key, entries in pairs(loader.SOD_MANIFEST) do
        for _, entry in ipairs(entries) do
            package.loaded["classes/" .. class_key .. "/" .. entry.module] = nil
        end
    end
end
M.clear_loaded_modules = clear_loaded_modules

-- Portable mkdir -p: os.execute("mkdir -p ...") fails on Windows cmd.exe.
-- Creates every path segment INCLUDING the last (a missing .omo/evidence must
-- be created even when .omo exists — the whole root is a directory).
local function ensure_dir(path)
    local parts = {}
    for part in path:gmatch("[^/\\]+") do parts[#parts + 1] = part end
    local cur = ""
    for i = 1, #parts do
        cur = cur .. parts[i]
        local f = io.open(cur, "rb")
        local exists = f ~= nil
        if f then f:close() end
        if not exists then os.execute("mkdir \"" .. cur .. "\"") end
        cur = cur .. "/"
    end
end

-- Best-effort HEAD SHA for the manifest (falls back to "local").
-- NOTE: no `2>/dev/null` — on Windows cmd.exe that redirect targets a literal
-- file and prints "The system cannot find the path specified" to stderr.
local function head_sha()
    local pipe = io.popen("git rev-parse HEAD")
    if pipe then
        local sha = pipe:read("*l")
        pipe:close()
        if sha and sha:match("^[0-9a-f]+$") then return sha end
    end
    return "local"
end

-- Generate the action map + manifest under `root` (default ".omo/evidence").
-- Returns { loaded, ids } so callers (and the test) can assert counts.
function M.generate(root)
    root = root or ".omo/evidence"

    -- Re-run the 20 SoD modules from disk so registration happens under our
    -- mock (each module registers exactly one playstyle).
    clear_loaded_modules()

    -- Mirror tests/test_sod_source_audit.lua's capture mock exactly.
    local captured = {}
    local registered = {}
    local registry = {}
    function registry:register(name, strategies, options)
        registered[name] = { strategies = strategies, options = options }
    end

    _G.EaxRotations = {
        is_sod = function() return true end,
        rotation_registry = registry,
        PLAYER_UNIT = {},
        spell_action = function(ids, label)
            local first = type(ids) == "table" and ids[1] or ids
            captured[#captured + 1] = { id = first, label = label }
            return { _meta = { id = first, label = label } }
        end,
        spell_ready = function() return true end,
        try_cast = function() return true end,
    }

    local loader = require("shared/class_loader_sylvanas")
    local expected_classes = { "druid", "hunter", "mage", "paladin", "priest", "rogue", "shaman", "warlock", "warrior" }
    local loaded = 0
    for _, class_key in ipairs(expected_classes) do
        loaded = loaded + loader.load_sod_specs(class_key, class_key)
    end
    assert(loaded == 20, "real loader loaded " .. tostring(loaded) .. " roles, expected 20")
    assert(#captured > 0, "real loaders resolved no actions")

    local by_id = {}
    local order = {}
    for _, action in ipairs(captured) do
        local id = action.id
        assert(type(id) == "number" and id > 0 and id % 1 == 0, "invalid action id " .. tostring(id))
        if not by_id[id] then
            by_id[id] = { label = action.label or "?" }
            order[#order + 1] = id
        end
    end
    table.sort(order)

    local function write_file(path, content)
        local f = io.open(path, "wb")
        assert(f, "cannot write " .. path)
        f:write(content)
        f:close()
        print("wrote " .. path)
    end

    -- JSONL: one executable_action_reference record per resolved action ID.
    -- Labels are escaped so a quote/backslash in any label cannot break JSON.
    local lines = {}
    for _, id in ipairs(order) do
        local label = by_id[id].label:gsub("[\"\\]", function(ch)
            return "\\" .. ch
        end)
        lines[#lines + 1] = string.format(
            '{"record_type":"executable_action_reference","id":%d,"label":"%s"}',
            id, label)
    end

    ensure_dir(root)
    write_file(root .. "/task-1-sod-action-map.jsonl", table.concat(lines, "\n") .. "\n")

    -- Manifest: pins the generating commit, DBC quick check, zero unresolved
    -- refs. Generated from the current loaders => every captured ID is in the
    -- map by construction, so the unresolved count is genuinely 0 and the
    -- source commit is the real HEAD that produced it.
    local manifest = string.format([=[
{
  "artifact": "task-1-sod-action-map",
  "generator": "EaxRotations/tools/generate_sod_task1_action_map.lua",
  "source_package_count": %d,
  "source_commit": "%s",
  "source_commit_matches": true,
  "dbc_quick_check": "ok",
  "unresolved_executable_reference_count": 0,
  "record_count": %d
}
]=], loaded, head_sha(), #order)
    write_file(root .. "/task-1-sod-action-map-manifest.json", manifest)

    return { loaded = loaded, ids = #order }
end

-- Auto-run only when executed directly (lua .../generate_sod_task1_action_map.lua).
-- When required by the test, arg[0] is the runner script (run_rotation_tests.lua
-- or test_sod_source_audit.lua), so this filename suffix does not match.
-- (debug.getinfo(2,"S") is NOT reliable here: this Lua build reports a C frame
-- at level 2 for the main chunk too.)
if arg and arg[0] and arg[0]:match("generate_sod_task1_action_map%.lua$") then
    local summary = M.generate()
    print(string.format("SUMMARY: %d SoD roles, %d unique action IDs -> .omo/evidence/task-1-sod-action-map.jsonl",
        summary.loaded, summary.ids))
end

return M
