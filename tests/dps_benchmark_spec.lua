local chunk, err = loadfile("tools/dps_benchmark.lua")
assert(chunk, "expected tools/dps_benchmark.lua to exist: " .. tostring(err))

local dps_meter = require("eax_shared/dps_meter")

local EXPECTED_SCHEMA = "spec,role,damage_total,healing_total,threat_total,dps,hps,tps,duration_s,reactive_action,reason_code,reactive_status,role_signal,role_target_kind,reactive_event_count,noop_unsupported_count,unsafe_skip_count,fail_safe_tick_count,sample_count,evidence_mode,run_label,run_index,variance_pct,near_fail,verdict"

local function split_csv(line)
    local fields = {}
    for field in tostring(line):gmatch("([^,]+)") do
        fields[#fields + 1] = field
    end
    return fields
end

local function capture_run(argv, injected_meter)
    local original_print = print
    local original_meter = package.loaded["eax_shared/dps_meter"]
    local output = {}

    print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do
            parts[#parts + 1] = tostring(select(i, ...))
        end
        output[#output + 1] = table.concat(parts, " ")
    end

    if injected_meter then
        package.loaded["eax_shared/dps_meter"] = injected_meter
    end

    local script = chunk("tools.dps_benchmark")
    local ok, run_err = pcall(script.run_benchmark, argv)

    print = original_print
    package.loaded["eax_shared/dps_meter"] = original_meter

    return ok, run_err, output
end

local function collect_data_rows(lines)
    local rows = {}
    for _, line in ipairs(lines or {}) do
        if tostring(line):match("^EAX") or tostring(line):match("^CURRENT_SPEC,") then
            rows[#rows + 1] = line
        end
    end
    return rows
end

local ok, run_err, output = capture_run({ "--dry-run", "--matrix", "--label", "phase08-dry" })
assert(ok, "run_benchmark dry-run matrix should succeed: " .. tostring(run_err))
assert(output[1] == "schema: " .. EXPECTED_SCHEMA, "schema line should expose the full Phase 08 matrix contract")
assert(output[2] == EXPECTED_SCHEMA, "csv header should expose the full Phase 08 matrix contract")

local dry_rows = collect_data_rows(output)
assert(#dry_rows == 27, "--dry-run --matrix should emit exactly 27 canonical spec rows")

local first_dry_fields = split_csv(dry_rows[1])
assert(first_dry_fields[20] == "mock", "dry-run rows should tag evidence_mode=mock")
assert(first_dry_fields[21] == "phase08-dry", "dry-run rows should include the provided run_label")
assert(first_dry_fields[22] == "1", "dry-run rows should include run_index metadata")
assert(first_dry_fields[23] == "0.00", "dry-run rows should emit variance_pct metadata")
assert(first_dry_fields[25] == "schema_only", "dry-run rows should remain schema_only")

local blockers_line_index
local near_fail_line_index
for index, line in ipairs(output) do
    if tostring(line):match("^BLOCKERS:") then
        blockers_line_index = index
    elseif tostring(line):match("^NEAR_FAIL:") then
        near_fail_line_index = index
    end
end
assert(blockers_line_index, "summary output should include a blockers section")
assert(near_fail_line_index, "summary output should include a near_fail section")
assert(blockers_line_index < near_fail_line_index, "blockers should print before near_fail rows")

dps_meter.reset()
ok, run_err, output = capture_run({ "--matrix", "--live", "--runs", "2", "--label", "phase08-live" }, {
    get_snapshot = function()
        return {
            damage_total = 24000,
            healing_total = 3000,
            threat_total = 1200,
            dps = 400,
            hps = 50,
            tps = 20,
            duration_s = 60,
            reactive_action = "interrupt_control",
            reason_code = "INTERRUPT_DANGER",
            reactive_status = "handled",
            role_signal = "danger_hold",
            role_target_kind = "hostile",
            reactive_event_count = 4,
            noop_unsupported_count = 0,
            unsafe_skip_count = 1,
            fail_safe_tick_count = 2,
            sample_count = 40,
        }
    end,
})

assert(ok, "run_benchmark live matrix should succeed: " .. tostring(run_err))

local live_rows = collect_data_rows(output)
assert(#live_rows == 2, "--runs 2 should emit two live rows for the current spec")

local first_live_fields = split_csv(live_rows[1])
assert(first_live_fields[1] == "CURRENT_SPEC", "live mode should emit the current spec row")
assert(first_live_fields[5] == "1200", "live rows should export threat_total from the shared meter contract")
assert(first_live_fields[8] == "20.00", "live rows should export tps from the shared meter contract")
assert(first_live_fields[15] == "4", "live rows should export reactive_event_count")
assert(first_live_fields[17] == "1", "live rows should export unsafe_skip_count")
assert(first_live_fields[18] == "2", "live rows should export fail_safe_tick_count")
assert(first_live_fields[20] == "live", "live rows should tag evidence_mode=live")
assert(first_live_fields[21] == "phase08-live", "live rows should carry the provided run_label")
assert(first_live_fields[22] == "1", "live rows should carry run_index metadata")
assert(first_live_fields[23] == "0.00", "live rows should include variance_pct metadata")

print("dps_benchmark_spec: ok")
