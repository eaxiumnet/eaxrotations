local chunk, err = loadfile("tools/rotation_validation.lua")
assert(chunk, "expected tools/rotation_validation.lua to exist: " .. tostring(err))

local script = chunk("tools.rotation_validation")
assert(type(script) == "table", "rotation_validation should return a module table")
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

local function with_temp_file(path, mutate, assertions)
    local original = read_file(path)
    local updated = mutate(original)
    assert(updated ~= original, "expected fixture mutation for " .. path)
    write_file(path, updated)

    local ok, result = pcall(assertions)
    restore_file(path, original)
    assert(ok, result)
end

with_temp_file("EAXPriestHoly/main.lua", function(content)
    local without_import = content:gsub('local healer_triage = require%("eax_shared/healer_triage"%)\n', '', 1)
    return without_import:gsub('life_save_ally = %b{},', 'life_save_ally = { noop = "unsupported" },', 1)
end, function()
    local code, lines = capture_print(function()
        return script.main()
    end)

    assert(code == 1, "expected role parity failure when healer triage support regresses")

    local output = table.concat(lines, "\n")
    assert(output:find("FAIL: EAXPriestHoly ::", 1, true), "missing healer failure line")
    assert(output:find("FAIL: healer role parity 4/5", 1, true), "missing healer family summary")
end)

with_temp_file("EAXWarriorProtection/main.lua", function(content)
    return content:gsub('anti_aggro = %b{},', 'anti_aggro = { noop = "unsupported" },', 1)
end, function()
    local code, lines = capture_print(function()
        return script.main()
    end)

    assert(code == 1, "expected role parity failure when tank anti_aggro regresses")

    local output = table.concat(lines, "\n")
    assert(output:find("FAIL: EAXWarriorProtection ::", 1, true), "missing tank failure line")
    assert(output:find("FAIL: tank role parity 2/3", 1, true), "missing tank family summary")
end)

with_temp_file("EAXWarriorArms/main.lua", function(content)
    return content:gsub('local dps_risk = require%("eax_shared/dps_risk"%)\n', '', 1)
end, function()
    local code, lines = capture_print(function()
        return script.main()
    end)

    assert(code == 1, "expected role parity failure when dps risk import regresses")

    local output = table.concat(lines, "\n")
    assert(output:find("FAIL: EAXWarriorArms ::", 1, true), "missing dps failure line")
    assert(output:find("FAIL: dps role parity 18/19", 1, true), "missing dps family summary")
end)

local code, lines = capture_print(function()
    return script.main()
end)

assert(code == 0, "rotation_validation main should succeed on a clean repo")

local output = table.concat(lines, "\n")
assert(output:find("PASS: healer role parity 5/5", 1, true), "missing healer family pass summary")
assert(output:find("PASS: tank role parity 3/3", 1, true), "missing tank family pass summary")
assert(output:find("PASS: dps role parity 19/19", 1, true), "missing dps family pass summary")
assert(output:find("PASS: role parity 27/27", 1, true), "missing final role parity pass summary")

print("role_validation_spec: ok")
