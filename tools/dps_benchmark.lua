local dps_meter = require("eax_shared/dps_meter")

local M = {}

local SPECS = {
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

local HEALER_SPECS = {
    EAXDruidRestoration = true,
    EAXPaladinHoly = true,
    EAXPriestDiscipline = true,
    EAXPriestHoly = true,
    EAXShamanRestoration = true,
}

local TANK_SPECS = {
    EAXDruidFeral = true,
    EAXPaladinProtection = true,
    EAXWarriorProtection = true,
}

local HEALER_DRY_RUN_SIGNALS = {
    { role_signal = "tank_save", role_target_kind = "tank" },
    { role_signal = "triage_save", role_target_kind = "ally" },
    { role_signal = "group_stabilize", role_target_kind = "ally" },
}

local function dry_run_role_fields(spec, index)
    if HEALER_SPECS[spec] then
        local sample = HEALER_DRY_RUN_SIGNALS[((index - 1) % #HEALER_DRY_RUN_SIGNALS) + 1]
        return sample.role_signal, sample.role_target_kind
    end

    if TANK_SPECS[spec] then
        return "threat_recovery", "hostile"
    end

    return "danger_hold", "hostile"
end

local function as_number(value)
    return tonumber(value) or 0
end

local function parse_args(argv)
    local args = {
        dry_run = false,
    }
    for _, value in ipairs(argv or {}) do
        if value == "--dry-run" then
            args.dry_run = true
        end
    end
    return args
end

local function mock_snapshot(index)
    local duration_s = 60 + (index * 3)
    local damage_total = 10000 + (index * 125)
    local healing_total = 1500 + (index * 25)
    local spec = SPECS[index]
    local role_signal, role_target_kind = dry_run_role_fields(spec, index)
    return {
        damage_total = damage_total,
        healing_total = healing_total,
        duration_s = duration_s,
        dps = damage_total / duration_s,
        hps = healing_total / duration_s,
        reactive_action = "none",
        reason_code = "NO_ACTION",
        reactive_status = "none",
        role_signal = role_signal,
        role_target_kind = role_target_kind,
    }
end

local function snapshot_field(snapshot, key, fallback)
    if type(snapshot) ~= "table" then
        return fallback
    end

    local value = snapshot[key]
    if value == nil or value == "" then
        return fallback
    end

    return value
end

local function benchmark_rows(args)
    local rows = {}
    if args.dry_run then
        for i, spec in ipairs(SPECS) do
            rows[#rows + 1] = {
                spec = spec,
                snapshot = mock_snapshot(i),
            }
        end
        return rows
    end

    rows[#rows + 1] = {
        spec = "CURRENT_SPEC",
        snapshot = dps_meter.get_snapshot(),
    }
    return rows
end

function M.run_benchmark(argv)
    local args = parse_args(argv)
    local rows = benchmark_rows(args)

    print("schema: spec,damage_total,healing_total,dps,hps,duration_s,reactive_action,reason_code,reactive_status,role_signal,role_target_kind")
    print("spec,damage_total,healing_total,dps,hps,duration_s,reactive_action,reason_code,reactive_status,role_signal,role_target_kind")
    for _, row in ipairs(rows) do
        local snapshot = row.snapshot
        print(string.format(
            "%s,%.0f,%.0f,%.2f,%.2f,%.2f,%s,%s,%s,%s,%s",
            row.spec,
            as_number(snapshot.damage_total),
            as_number(snapshot.healing_total),
            as_number(snapshot.dps),
            as_number(snapshot.hps),
            as_number(snapshot.duration_s),
            tostring(snapshot_field(snapshot, "reactive_action", snapshot_field(snapshot, "action_id", "none"))),
            tostring(snapshot_field(snapshot, "reason_code", "NO_ACTION")),
            tostring(snapshot_field(snapshot, "reactive_status", "none")),
            tostring(snapshot_field(snapshot, "role_signal", "none")),
            tostring(snapshot_field(snapshot, "role_target_kind", "none"))
        ))
    end

    return 0
end

local module_name = ...
if module_name ~= "tools.dps_benchmark" then
    os.exit(M.run_benchmark(arg or {}), true)
end

return M
