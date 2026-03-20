local chunk, err = loadfile("tools/rotation_validation.lua")
assert(chunk, "expected tools/rotation_validation.lua to exist: " .. tostring(err))

local script = chunk("tools.rotation_validation")
assert(type(script) == "table", "rotation_validation should return a module table")
assert(type(script.validate_spec) == "function", "validate_spec must be defined")
assert(type(script.main) == "function", "main must be defined")

local function read_file(path)
    local file, read_err = io.open(path, "r")
    assert(file, "expected file to exist: " .. path .. " :: " .. tostring(read_err))
    local content = file:read("*a")
    file:close()
    return content
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

local code, lines = capture_print(function()
    return script.main()
end)

assert(code == 0, "rotation_validation main should succeed on a clean repo")

local output = table.concat(lines, "\n")
assert(output:find("PASS: api hard gate", 1, true), "missing API hard gate pass summary")

local checklist = read_file(".planning/phases/05-reactive-contract-api-gate/05-API-GATE-CHECKLIST.md")
assert(checklist:find("| Allowlist generation |", 1, true), "missing allowlist generation checklist row")
assert(checklist:find("| Runtime API scan |", 1, true), "missing runtime API scan checklist row")
assert(checklist:find("| Unified rotation validation |", 1, true), "missing unified validation checklist row")
assert(checklist:find("| Yes |", 1, true), "checklist rows must be blocking")

print("rotation_validation_spec: ok")
