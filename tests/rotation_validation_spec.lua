local chunk, err = loadfile("tools/rotation_validation.lua")
assert(chunk, "expected tools/rotation_validation.lua to exist: " .. tostring(err))

local script = chunk("tools.rotation_validation")
assert(type(script) == "table", "rotation_validation should return a module table")
assert(type(script.validate_spec) == "function", "validate_spec must be defined")
assert(type(script.validate_role_parity) == "function", "validate_role_parity must be defined")
assert(type(script.main) == "function", "main must be defined")

local function read_file(path)
    local file, read_err = io.open(path, "r")
    assert(file, "expected file to exist: " .. path .. " :: " .. tostring(read_err))
    local content = file:read("*a")
    file:close()
    return content
end

local function write_file(path, content)
    local file, write_err = io.open(path, "w")
    assert(file, "expected file to exist: " .. path .. " :: " .. tostring(write_err))
    file:write(content)
    file:close()
end

local function restore_file(path, content)
    write_file(path, content)
end

local function capture_print(fn)
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

local runtime_dir = "EAXApiGateSpec"
local runtime_path = runtime_dir .. "/main.lua"

os.execute("mkdir " .. runtime_dir .. " >nul 2>nul")
write_file(runtime_path, table.concat({
    "local visual_state = require('visual_state')",
    "local vendor_automation = require('vendor_automation')",
    "local consumables_manager = require('consumables_manager')",
    "local mount_manager = require('mount_manager')",
    "core.not_real_api()",
}, "\n"))

local blocked_code, blocked_lines = capture_print(function()
    return script.main()
end)

os.remove(runtime_path)
os.remove(runtime_dir)

assert(blocked_code == 1, "rotation_validation main should fail when API gate violations exist")

local blocked_output = table.concat(blocked_lines, "\n")
assert(blocked_output:find("FAIL: api hard gate ::", 1, true), "missing API hard gate failure summary")

local canonical_spec_path = "EAXWarriorArms/main.lua"
local canonical_original = read_file(canonical_spec_path)
local broken_adapter = canonical_original:gsub('throughput_resume = %b{},', '', 1)
assert(broken_adapter ~= canonical_original, "expected to remove throughput_resume from canonical fixture")

write_file(canonical_spec_path, broken_adapter)

local parity_code, parity_lines = capture_print(function()
    return script.main()
end)

restore_file(canonical_spec_path, canonical_original)

assert(parity_code == 1, "rotation_validation main should fail when reactive parity is broken")

local parity_output = table.concat(parity_lines, "\n")
assert(parity_output:find("FAIL: EAXWarriorArms ::", 1, true), "missing canonical reactive parity failure line")
assert(parity_output:find("FAIL: reactive parity ", 1, true), "missing reactive parity failure summary")

local code, lines = capture_print(function()
    return script.main()
end)

assert(code == 0, "rotation_validation main should succeed on a clean repo")

local output = table.concat(lines, "\n")
assert(output:find("PASS: api hard gate", 1, true), "missing API hard gate pass summary")
assert(output:find("PASS: reactive parity 27/27", 1, true), "missing reactive parity pass summary")
assert(output:find("PASS: role parity 27/27", 1, true), "missing role parity pass summary")

local checklist = read_file(".planning/phases/05-reactive-contract-api-gate/05-API-GATE-CHECKLIST.md")
assert(checklist:find("| Allowlist generation |", 1, true), "missing allowlist generation checklist row")
assert(checklist:find("| Runtime API scan |", 1, true), "missing runtime API scan checklist row")
assert(checklist:find("| Unified rotation validation |", 1, true), "missing unified validation checklist row")
assert(checklist:find("| Yes |", 1, true), "checklist rows must be blocking")

print("rotation_validation_spec: ok")
