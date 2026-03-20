local CANONICAL_SPECS = {
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

local REQUIRED_SUBSTRINGS = {
    'require("eax_shared/reactive_runtime")',
    'reactive_state = {}',
    'local reactive_adapter = {',
    'reactive_runtime.update_tick(me, target, {',
    'adapter = reactive_adapter',
}

local REQUIRED_ACTION_KEYS = {
    'life_save_self',
    'life_save_ally',
    'interrupt_control',
    'anti_overheal',
    'anti_aggro',
    'throughput_resume',
}

local BANNED_SUBSTRINGS = {
    'reason_code',
    'reactive_action',
}

local function read_file(path)
    local file = io.open(path, "r")
    assert(file, "expected file to exist: " .. path)
    local content = file:read("*a")
    file:close()
    return content
end

local rotation_validation = read_file("tools/rotation_validation.lua")

assert(#CANONICAL_SPECS == 27, "expected 27 canonical specs")
for _, spec in ipairs(CANONICAL_SPECS) do
    assert(
        rotation_validation:find('"' .. spec .. '"', 1, true),
        "rotation_validation canonical list missing " .. spec
    )

    local content = read_file(spec .. "/main.lua")
    for _, required in ipairs(REQUIRED_SUBSTRINGS) do
        assert(content:find(required, 1, true), spec .. " missing required wiring: " .. required)
    end

    for _, action_key in ipairs(REQUIRED_ACTION_KEYS) do
        assert(content:find(action_key, 1, true), spec .. " missing reactive action key: " .. action_key)
    end

    assert(content:find('noop = "unsupported"', 1, true), spec .. " missing explicit unsupported noop marker")

    for _, banned in ipairs(BANNED_SUBSTRINGS) do
        assert(not content:find(banned, 1, true), spec .. " leaked deferred HUD debug field: " .. banned)
    end
end

print("reactive_runtime_wiring_spec: ok")
