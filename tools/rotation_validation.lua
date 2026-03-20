local M = {}

local api_hard_gate_chunk = assert(loadfile("tools/api_hard_gate.lua"))
local api_hard_gate = api_hard_gate_chunk("tools.api_hard_gate")

local REQUIRED_IMPORTS = {
    "visual_state",
    "vendor_automation",
    "consumables_manager",
    "mount_manager",
}

local KNOWN_SPECS = {
    "EAXDruidBalance",
    "EAXDruidFeral",
    "EAXDruidRestoration",
    "EAXHunterBeastMastery",
    "EAXHunterMarksmanship",
    "EAXHunterSurvival",
    "EAXMageArcane",
    "EAXMageFire",
    "EAXMageFrost",
    "EAXPaladinHoly",
    "EAXPaladinProtection",
    "EAXPaladinRetribution",
    "EAXPriestDiscipline",
    "EAXPriestHoly",
    "EAXPriestShadow",
    "EAXRogueAssassination",
    "EAXRogueCombat",
    "EAXRogueSubtlety",
    "EAXShamanElemental",
    "EAXShamanEnhancement",
    "EAXShamanRestoration",
    "EAXWarlockAffliction",
    "EAXWarlockDemonology",
    "EAXWarlockDestruction",
    "EAXWarriorArms",
    "EAXWarriorFury",
    "EAXWarriorProtection",
}

local function file_exists(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    end
    return false
end

local function read_file(path)
    local f = io.open(path, "r")
    if not f then
        return nil
    end
    local content = f:read("*a")
    f:close()
    return content
end

local function command_ok(ok, code, status)
    if type(ok) == "number" then
        return ok == 0
    end
    if type(ok) == "boolean" then
        if ok and code == "exit" and status == 0 then
            return true
        end
        return false
    end
    return false
end

local function syntax_ok(main_file)
    local ok, code, status = os.execute(string.format('luac -p "%s"', main_file))
    return command_ok(ok, code, status)
end

local function discover_specs()
    local specs = {}
    for _, spec in ipairs(KNOWN_SPECS) do
        if file_exists(spec .. "/main.lua") then
            specs[#specs + 1] = spec
        end
    end
    return specs
end

function M.validate_spec(spec_dir)
    local failures = {}
    local main_file = spec_dir .. "/main.lua"

    if not file_exists(main_file) then
        failures[#failures + 1] = "missing main.lua"
        return false, failures
    end

    local content = read_file(main_file)
    if not content then
        failures[#failures + 1] = "unreadable main.lua"
        return false, failures
    end

    for _, required in ipairs(REQUIRED_IMPORTS) do
        if not content:find(required, 1, true) then
            failures[#failures + 1] = "missing import " .. required
        end
    end

    if not syntax_ok(main_file) then
        failures[#failures + 1] = "luac syntax check failed"
    end

    return #failures == 0, failures
end

function M.main()
    local specs = discover_specs()
    if #specs == 0 then
        print("FAIL: no EAX specs discovered")
        return 1
    end

    local failed = 0
    for _, spec in ipairs(specs) do
        local ok, failures = M.validate_spec(spec)
        if ok then
            print("PASS: " .. spec)
        else
            failed = failed + 1
            print("FAIL: " .. spec .. " :: " .. table.concat(failures, "; "))
        end
    end

    if failed > 0 then
        print(string.format("FAIL: %d/%d specs failed validation", failed, #specs))
    end

    local gate_ok, gate_failures = api_hard_gate.scan_paths(api_hard_gate.discover_runtime_paths())
    if gate_ok then
        print("PASS: api hard gate")
    else
        for _, violation in ipairs(gate_failures) do
            print(string.format("FAIL: %s:%d -> %s", violation.path, violation.line, violation.call))
        end
        print(string.format("FAIL: api hard gate :: %d violations", #gate_failures))
    end

    if failed > 0 or not gate_ok then
        return 1
    end

    print(string.format("PASS: %d/%d specs validated", #specs, #specs))
    return 0
end

local module_name = ...
if module_name ~= "tools.rotation_validation" then
    os.exit(M.main(), true)
end

return M
