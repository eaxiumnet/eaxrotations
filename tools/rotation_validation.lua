local M = {}

local api_hard_gate_chunk = assert(loadfile("tools/api_hard_gate.lua"))
local api_hard_gate = api_hard_gate_chunk("tools.api_hard_gate")

local REQUIRED_IMPORTS = {
    "visual_state",
    "vendor_automation",
    "consumables_manager",
    "mount_manager",
}

local REQUIRED_REACTIVE_SUBSTRINGS = {
    'local reactive_adapter = {',
    'adapter = reactive_adapter',
}

local REQUIRED_REACTIVE_ACTIONS = {
    "life_save_self",
    "life_save_ally",
    "interrupt_control",
    "anti_overheal",
    "anti_aggro",
    "throughput_resume",
}

local ROLE_FAMILIES = {
    healer = {
        specs = {
            EAXDruidRestoration = true,
            EAXPaladinHoly = true,
            EAXPriestDiscipline = true,
            EAXPriestHoly = true,
            EAXShamanRestoration = true,
        },
        required = {
            {
                label = "shared healer_triage import",
                kind = "substring",
                value = 'local healer_triage = require("eax_shared/healer_triage")',
            },
            {
                label = "non-noop life_save_ally handler",
                kind = "non_noop_block",
                action = "life_save_ally",
            },
        },
    },
    tank = {
        specs = {
            EAXDruidFeral = true,
            EAXPaladinProtection = true,
            EAXWarriorProtection = true,
        },
        required = {
            {
                label = "shared tank_recovery import",
                kind = "substring",
                value = 'local tank_recovery = require("eax_shared/tank_recovery")',
            },
            {
                label = "non-noop anti_aggro handler",
                kind = "non_noop_block",
                action = "anti_aggro",
            },
        },
    },
    dps = {
        required = {
            {
                label = "shared dps_risk import",
                kind = "substring",
                value = 'local dps_risk = require("eax_shared/dps_risk")',
            },
            {
                label = "danger-window hold or abort surface",
                kind = "any_substring",
                values = {
                    'should_hold_offense',
                    'should_abort_commit',
                },
            },
        },
    },
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

local function role_family_for_spec(spec_dir)
    if ROLE_FAMILIES.healer.specs[spec_dir] then
        return "healer"
    end
    if ROLE_FAMILIES.tank.specs[spec_dir] then
        return "tank"
    end
    return "dps"
end

local function extract_action_block(content, action)
    local marker = action .. " = {"
    local start_index = content:find(marker, 1, true)
    if not start_index then
        return nil
    end

    local block_start = content:find("{", start_index, true)
    if not block_start then
        return nil
    end

    local depth = 0
    for i = block_start, #content do
        local ch = content:sub(i, i)
        if ch == "{" then
            depth = depth + 1
        elseif ch == "}" then
            depth = depth - 1
            if depth == 0 then
                return content:sub(block_start, i)
            end
        end
    end

    return nil
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

function M.validate_reactive_parity(spec_dir)
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

    for _, required in ipairs(REQUIRED_REACTIVE_SUBSTRINGS) do
        if not content:find(required, 1, true) then
            failures[#failures + 1] = "missing reactive wiring " .. required
        end
    end

    for _, action_key in ipairs(REQUIRED_REACTIVE_ACTIONS) do
        if not content:find(action_key, 1, true) then
            failures[#failures + 1] = "missing reactive action " .. action_key
        end
    end

    if not content:find('noop = "unsupported"', 1, true) then
        failures[#failures + 1] = "missing explicit reactive noop marker"
    end

    return #failures == 0, failures
end

function M.validate_role_parity(spec_dir)
    local failures = {}
    local main_file = spec_dir .. "/main.lua"
    local family = role_family_for_spec(spec_dir)

    if not file_exists(main_file) then
        failures[#failures + 1] = "missing main.lua"
        return false, failures, family
    end

    local content = read_file(main_file)
    if not content then
        failures[#failures + 1] = "unreadable main.lua"
        return false, failures, family
    end

    for _, rule in ipairs(ROLE_FAMILIES[family].required) do
        if rule.kind == "substring" then
            if not content:find(rule.value, 1, true) then
                failures[#failures + 1] = "missing " .. rule.label
            end
        elseif rule.kind == "any_substring" then
            local matched = false
            for _, value in ipairs(rule.values) do
                if content:find(value, 1, true) then
                    matched = true
                    break
                end
            end
            if not matched then
                failures[#failures + 1] = "missing " .. rule.label
            end
        elseif rule.kind == "non_noop_block" then
            local block = extract_action_block(content, rule.action)
            if not block then
                failures[#failures + 1] = "missing " .. rule.action .. " action block"
            elseif block:find('noop = "unsupported"', 1, true) then
                failures[#failures + 1] = rule.action .. " regressed to noop = \"unsupported\""
            end
        end
    end

    return #failures == 0, failures, family
end

function M.main()
    local specs = discover_specs()
    if #specs == 0 then
        print("FAIL: no EAX specs discovered")
        return 1
    end

    local failed = 0
    local reactive_passed = 0
    local role_passed = 0
    local role_family_totals = {
        healer = 0,
        tank = 0,
        dps = 0,
    }
    local role_family_passed = {
        healer = 0,
        tank = 0,
        dps = 0,
    }
    for _, spec in ipairs(specs) do
        local ok, failures = M.validate_spec(spec)
        if ok then
            print("PASS: " .. spec)
        else
            failed = failed + 1
            print("FAIL: " .. spec .. " :: " .. table.concat(failures, "; "))
        end

        local reactive_ok, reactive_failures = M.validate_reactive_parity(spec)
        if reactive_ok then
            reactive_passed = reactive_passed + 1
            print("PASS: " .. spec .. " :: reactive parity")
        else
            print("FAIL: " .. spec .. " :: " .. table.concat(reactive_failures, "; "))
        end

        local role_ok, role_failures, role_family = M.validate_role_parity(spec)
        role_family_totals[role_family] = role_family_totals[role_family] + 1
        if role_ok then
            role_passed = role_passed + 1
            role_family_passed[role_family] = role_family_passed[role_family] + 1
            print(string.format("PASS: %s :: role parity (%s)", spec, role_family))
        else
            print("FAIL: " .. spec .. " :: " .. table.concat(role_failures, "; "))
        end
    end

    if failed > 0 then
        print(string.format("FAIL: %d/%d specs failed validation", failed, #specs))
    end

    if reactive_passed == #specs then
        print(string.format("PASS: reactive parity %d/%d", reactive_passed, #specs))
    else
        print(string.format("FAIL: reactive parity %d/%d", reactive_passed, #specs))
    end

    for _, family in ipairs({ "healer", "tank", "dps" }) do
        local passed = role_family_passed[family]
        local total = role_family_totals[family]
        if passed == total then
            print(string.format("PASS: %s role parity %d/%d", family, passed, total))
        else
            print(string.format("FAIL: %s role parity %d/%d", family, passed, total))
        end
    end

    if role_passed == #specs then
        print(string.format("PASS: role parity %d/%d", role_passed, #specs))
    else
        print(string.format("FAIL: role parity %d/%d", role_passed, #specs))
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

    if failed > 0 or reactive_passed ~= #specs or role_passed ~= #specs or not gate_ok then
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
