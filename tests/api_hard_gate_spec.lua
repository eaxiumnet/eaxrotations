local function write_file(path, content)
    local file, err = io.open(path, "w")
    assert(file, "expected to create file " .. path .. ": " .. tostring(err))
    file:write(content)
    file:close()
end

local function remove_file(path)
    os.remove(path)
end

local function with_captured_print(fn)
    local lines = {}
    local original_print = print
    print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do
            parts[i] = tostring(select(i, ...))
        end
        lines[#lines + 1] = table.concat(parts, " ")
    end

    local ok, result = pcall(fn)
    print = original_print
    assert(ok, result)
    return result, lines
end

local chunk, err = loadfile("tools/api_hard_gate.lua")
assert(chunk, "expected tools/api_hard_gate.lua to exist: " .. tostring(err))

local script = chunk("tools.api_hard_gate")
assert(type(script) == "table", "api_hard_gate should return a module table")
assert(type(script.scan_paths) == "function", "scan_paths must be defined")
assert(type(script.main) == "function", "main must be defined")

local runtime_dir = "EAXApiGateSpec"
local runtime_path = runtime_dir .. "/main.lua"
local ignored_path = "tests/api_gate_ignored_fixture.lua"

os.execute("mkdir " .. runtime_dir .. " >nul 2>nul")

write_file(runtime_path, table.concat({
    "local me = core.object_manager.get_local_player()",
    "core.log('allowed rooted call')",
    "core.input.use_item(6948)",
    "local health = me:get_health()",
    "local target = me:get_target()",
    "core.not_real_api()",
    "local secret = me:get_secret_value()",
    "ffi.C.printf('boom')",
    "os.execute('dir')",
}, "\n"))

write_file(ignored_path, "debug.traceback('ignored outside runtime scan')\n")

local ok_scan, violations = script.scan_paths({ runtime_path })
assert(ok_scan == false, "scan_paths should fail for banned runtime patterns")
assert(type(violations) == "table", "scan_paths should return violations")
assert(#violations >= 4, "expected rooted, method, and banned pattern violations")

local code, output = with_captured_print(function()
    return script.main()
end)

remove_file(runtime_path)
remove_file(ignored_path)
os.remove(runtime_dir)

assert(code == 1, "main should return non-zero for runtime violations")

local joined = table.concat(output, "\n")
assert(joined:find("FAIL: " .. runtime_path .. ":6 -> core.not_real_api", 1, true), "expected rooted allowlist violation output")
assert(joined:find("FAIL: " .. runtime_path .. ":7 -> :get_secret_value", 1, true), "expected method allowlist violation output")
assert(joined:find("FAIL: " .. runtime_path .. ":8 -> ffi.C", 1, true), "expected ffi violation output")
assert(joined:find("FAIL: " .. runtime_path .. ":9 -> os.execute", 1, true), "expected os.execute violation output")
assert(not joined:find("core.log", 1, true), "allowlisted rooted calls should not be reported")
assert(not joined:find(":get_health", 1, true), "allowlisted methods should not be reported")
assert(not joined:find(ignored_path, 1, true), "default runtime scan should ignore non-runtime files")

print("api_hard_gate_spec: ok")
