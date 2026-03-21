local benchmark_matrix = require("tools/benchmark_matrix")
local benchmark_thresholds = require("tools/benchmark_thresholds")
local dps_meter = require("eax_shared/dps_meter")

local M = {}

local CSV_HEADER = "spec,role,damage_total,healing_total,threat_total,dps,hps,tps,duration_s,reactive_action,reason_code,reactive_status,role_signal,role_target_kind,reactive_event_count,noop_unsupported_count,unsafe_skip_count,fail_safe_tick_count,sample_count,evidence_mode,run_label,run_index,variance_pct,near_fail,verdict"

local CSV_KEYS = {
    "spec",
    "role",
    "damage_total",
    "healing_total",
    "threat_total",
    "dps",
    "hps",
    "tps",
    "duration_s",
    "reactive_action",
    "reason_code",
    "reactive_status",
    "role_signal",
    "role_target_kind",
    "reactive_event_count",
    "noop_unsupported_count",
    "unsafe_skip_count",
    "fail_safe_tick_count",
    "sample_count",
    "evidence_mode",
    "run_label",
    "run_index",
    "variance_pct",
    "near_fail",
    "verdict",
}

local SPEC_ROLE_INDEX = benchmark_thresholds.CANONICAL_SPEC_ROLE_MAP
local RUNTIME_BASELINE_LABEL = "phase08-baseline"
local RUNTIME_DATA_PATH = "benchmarks/phase08_live_baseline.csv"
local RUNTIME_LOG_FILE = "phase08_live_baseline.log"
local runtime_capture_installed = false

local function as_number(value)
    return tonumber(value) or 0
end

local function bool_string(value)
    return value == true and "true" or "false"
end

local function csv_split(line)
    local fields = {}
    local source = tostring(line or "") .. ","
    for field in source:gmatch("(.-),") do
        fields[#fields + 1] = field
    end
    return fields
end

local function file_exists(path)
    if not path or path == "" then
        return false
    end

    local handle = io.open(path, "r")
    if handle then
        handle:close()
        return true
    end
    return false
end

local function has_runtime_data_api()
    return core
        and type(core.create_data_folder) == "function"
        and type(core.create_data_file) == "function"
        and type(core.write_data_file) == "function"
        and type(core.read_data_file) == "function"
end

local function has_runtime_log_api()
    return core and type(core.create_log_file) == "function" and type(core.write_log_file) == "function"
end

local function parent_dir(path)
    return tostring(path or ""):match("^(.*)[/\\][^/\\]+$")
end

local function ensure_parent_dir(path)
    local dir = parent_dir(path)
    if not dir or dir == "" or file_exists(dir) then
        return
    end

    local sep = package.config and package.config:sub(1, 1) or "/"
    local command
    if sep == "\\" then
        command = string.format('mkdir "%s" >NUL 2>NUL', dir)
    else
        command = string.format('mkdir -p "%s" >/dev/null 2>&1', dir)
    end
    os.execute(command)
end

local function format_number(value, decimals)
    return string.format("%." .. tostring(decimals) .. "f", as_number(value))
end

local function csv_value(row, key)
    if key == "damage_total" or key == "healing_total" or key == "threat_total" or key == "reactive_event_count" or key == "noop_unsupported_count" or key == "unsafe_skip_count" or key == "fail_safe_tick_count" or key == "sample_count" or key == "run_index" then
        return string.format("%.0f", as_number(row[key]))
    end
    if key == "dps" or key == "hps" or key == "tps" or key == "duration_s" or key == "variance_pct" then
        return format_number(row[key], 2)
    end
    if key == "near_fail" then
        return bool_string(row[key])
    end
    return tostring(row[key] or "")
end

local function row_to_csv(row)
    local values = {}
    for _, key in ipairs(CSV_KEYS) do
        values[#values + 1] = csv_value(row, key)
    end
    return table.concat(values, ",")
end

local function parse_args(argv)
    local args = {
        matrix = false,
        dry_run = false,
        live = false,
        runs = 1,
        label = "benchmark",
        output = nil,
        baseline = nil,
    }

    local index = 1
    while index <= #(argv or {}) do
        local value = argv[index]
        if value == "--matrix" then
            args.matrix = true
        elseif value == "--dry-run" then
            args.dry_run = true
        elseif value == "--live" then
            args.live = true
        elseif value == "--runs" then
            args.runs = math.max(1, math.floor(as_number(argv[index + 1])))
            if args.runs < 1 then
                args.runs = 1
            end
            index = index + 1
        elseif value == "--label" then
            args.label = tostring(argv[index + 1] or args.label)
            index = index + 1
        elseif value == "--output" then
            args.output = tostring(argv[index + 1] or "")
            if args.output == "" then
                args.output = nil
            end
            index = index + 1
        elseif value == "--baseline" then
            args.baseline = tostring(argv[index + 1] or "")
            if args.baseline == "" then
                args.baseline = nil
            end
            index = index + 1
        end
        index = index + 1
    end

    if not args.dry_run and not args.live then
        args.live = true
    end

    if args.dry_run then
        args.live = false
    end

    return args
end

local function mock_snapshot(index)
    local duration_s = 60 + (index * 3)
    local damage_total = 10000 + (index * 125)
    local healing_total = 1500 + (index * 25)
    local spec = benchmark_matrix.CANONICAL_SPECS[index].spec
    local role_meta = SPEC_ROLE_INDEX[spec] or { role = "dps", primary_metric = "dps" }
    local role_signal = "danger_hold"
    local role_target_kind = "hostile"

    if role_meta.role == "healer" then
        local signals = {
            { role_signal = "tank_save", role_target_kind = "tank" },
            { role_signal = "triage_save", role_target_kind = "ally" },
            { role_signal = "group_stabilize", role_target_kind = "ally" },
        }
        local sample = signals[((index - 1) % #signals) + 1]
        role_signal = sample.role_signal
        role_target_kind = sample.role_target_kind
    elseif role_meta.role == "tank" then
        role_signal = "threat_recovery"
        role_target_kind = "hostile"
    end

    return {
        spec = spec,
        damage_total = damage_total,
        healing_total = healing_total,
        threat_total = role_meta.primary_metric == "tps" and (duration_s * 4) or 0,
        duration_s = duration_s,
        dps = damage_total / duration_s,
        hps = healing_total / duration_s,
        tps = role_meta.primary_metric == "tps" and 4 or 0,
        reactive_action = "none",
        reason_code = "NO_ACTION",
        reactive_status = "none",
        role_signal = role_signal,
        role_target_kind = role_target_kind,
        reactive_event_count = 0,
        noop_unsupported_count = 0,
        unsafe_skip_count = 0,
        fail_safe_tick_count = 0,
        sample_count = benchmark_thresholds.MIN_SAMPLE_COUNT,
    }
end

local function canonical_spec_name(snapshot)
    local candidates = {
        snapshot and snapshot.spec,
        rawget(_G, "CURRENT_SPEC"),
        rawget(_G, "current_spec"),
    }

    for _, candidate in ipairs(candidates) do
        local name = tostring(candidate or "")
        if SPEC_ROLE_INDEX[name] then
            return name
        end
    end

    return nil
end

local function load_rows_from_file(path)
    if not file_exists(path) then
        return {}
    end

    local handle = assert(io.open(path, "r"))
    local content = handle:read("*a") or ""
    handle:close()
    return M.load_rows_from_string(content)
end

function M.load_rows_from_string(content)
    local rows = {}
    local first_line = true
    for line in (tostring(content or "") .. "\n"):gmatch("(.-)\r?\n") do
        if first_line and line == CSV_HEADER then
            first_line = false
        elseif line ~= "" and line ~= "schema: " .. CSV_HEADER then
            local values = csv_split(line)
            if values[1] and values[1] ~= "spec" then
                rows[#rows + 1] = {
                    spec = values[1],
                    role = values[2],
                    damage_total = as_number(values[3]),
                    healing_total = as_number(values[4]),
                    threat_total = as_number(values[5]),
                    dps = as_number(values[6]),
                    hps = as_number(values[7]),
                    tps = as_number(values[8]),
                    duration_s = as_number(values[9]),
                    reactive_action = values[10],
                    reason_code = values[11],
                    reactive_status = values[12],
                    role_signal = values[13],
                    role_target_kind = values[14],
                    reactive_event_count = as_number(values[15]),
                    noop_unsupported_count = as_number(values[16]),
                    unsafe_skip_count = as_number(values[17]),
                    fail_safe_tick_count = as_number(values[18]),
                    sample_count = as_number(values[19]),
                    evidence_mode = values[20],
                    run_label = values[21],
                    run_index = as_number(values[22]),
                    variance_pct = as_number(values[23]),
                    near_fail = values[24] == "true",
                    verdict = values[25],
                    primary_metric = SPEC_ROLE_INDEX[values[1]] and SPEC_ROLE_INDEX[values[1]].primary_metric or "dps",
                }
            end
            first_line = false
        else
            first_line = false
        end
    end
    return rows
end

local function set_row_metadata(row, run_label, run_index)
    row.run_label = run_label
    row.run_index = run_index
    row.variance_pct = as_number(row.variance_pct)
    row.near_fail = row.near_fail == true
    return row
end

local function with_snapshot_contract(row, snapshot)
    snapshot = snapshot or {}
    row.reactive_action = tostring(snapshot.reactive_action or snapshot.action_id or "none")
    row.reason_code = tostring(snapshot.reason_code or "NO_ACTION")
    row.reactive_status = tostring(snapshot.reactive_status or "none")
    row.role_signal = tostring(snapshot.role_signal or "none")
    row.role_target_kind = tostring(snapshot.role_target_kind or "none")
    return row
end

local function build_mock_rows(args)
    local rows = {}
    for index, spec_meta in ipairs(benchmark_matrix.CANONICAL_SPECS) do
        local row = benchmark_matrix.build_row(spec_meta.spec, mock_snapshot(index), {
            evidence_mode = "mock",
            thresholds = benchmark_thresholds,
            run_id = args.label .. "-" .. tostring(index),
        })
        rows[#rows + 1] = set_row_metadata(with_snapshot_contract(row, mock_snapshot(index)), args.label, 1)
    end
    return rows
end

local function build_live_rows(args)
    local snapshot = dps_meter.get_snapshot()
    local spec = canonical_spec_name(snapshot)
    assert(spec, "live benchmark requires a canonical spec name via snapshot.spec or CURRENT_SPEC")

    local rows = {}
    for run_index = 1, args.runs do
        local row = benchmark_matrix.build_row(spec, snapshot, {
            evidence_mode = "live",
            thresholds = benchmark_thresholds,
            run_id = args.label .. "-" .. tostring(run_index),
        })
        rows[#rows + 1] = set_row_metadata(with_snapshot_contract(row, snapshot), args.label, run_index)
    end
    return rows
end

local function collect_report_rows(args, current_rows)
    local persisted_rows = {}
    local baseline_rows = {}

    if args.output and file_exists(args.output) then
        persisted_rows = load_rows_from_file(args.output)
    end
    if args.baseline and args.baseline ~= args.output then
        baseline_rows = load_rows_from_file(args.baseline)
    end

    local report_rows = {}
    for _, row in ipairs(persisted_rows) do
        report_rows[#report_rows + 1] = row
    end
    for _, row in ipairs(baseline_rows) do
        report_rows[#report_rows + 1] = row
    end
    for _, row in ipairs(current_rows) do
        report_rows[#report_rows + 1] = row
    end

    return report_rows, persisted_rows
end

local function apply_summary_metadata(rows)
    if #rows == 0 then
        return {
            verdict = "FAIL",
            pass_count = 0,
            fail_count = 0,
            schema_only_count = 0,
            spec_summaries = {},
        }
    end

    local summary = benchmark_matrix.summarize_matrix(rows, benchmark_thresholds)
    local summaries_by_spec = {}
    for _, spec_summary in ipairs(summary.spec_summaries or {}) do
        summaries_by_spec[spec_summary.spec] = spec_summary
    end

    for _, row in ipairs(rows) do
        local spec_summary = summaries_by_spec[row.spec]
        if spec_summary then
            row.variance_pct = as_number(spec_summary.variance_pct)
            row.near_fail = spec_summary.near_fail == true
            row.verdict = spec_summary.verdict or row.verdict
        end
    end

    return summary
end

local function write_output(path, rows)
    ensure_parent_dir(path)
    local handle = assert(io.open(path, "w"))
    handle:write(CSV_HEADER, "\n")
    for _, row in ipairs(rows) do
        handle:write(row_to_csv(row), "\n")
    end
    handle:close()
end

local function rows_to_csv_text(rows)
    local lines = { CSV_HEADER }
    for _, row in ipairs(rows) do
        lines[#lines + 1] = row_to_csv(row)
    end
    return table.concat(lines, "\n") .. "\n"
end

local function runtime_log(message)
    if not has_runtime_log_api() then
        return
    end

    core.create_log_file(RUNTIME_LOG_FILE)
    core.write_log_file(RUNTIME_LOG_FILE, tostring(message) .. "\n")
end

local function read_runtime_rows(path)
    if not has_runtime_data_api() then
        return {}
    end
    return M.load_rows_from_string(core.read_data_file(path) or "")
end

local function write_runtime_rows(path, rows)
    core.create_data_folder("benchmarks")
    core.create_data_file(path)
    core.write_data_file(path, rows_to_csv_text(rows))
end

function M.capture_runtime_snapshot(snapshot, options)
    options = options or {}
    if not has_runtime_data_api() then
        return false, "runtime data file APIs are unavailable"
    end

    snapshot = snapshot or {}
    local spec = canonical_spec_name(snapshot)
    if not spec then
        runtime_log("skip runtime baseline capture: missing canonical spec")
        return false, "missing canonical spec"
    end
    if as_number(snapshot.sample_count) < benchmark_thresholds.MIN_SAMPLE_COUNT then
        runtime_log(string.format("skip runtime baseline capture for %s: sample_count below %d", spec, benchmark_thresholds.MIN_SAMPLE_COUNT))
        return false, "sample_count below minimum"
    end

    local label = tostring(options.label or RUNTIME_BASELINE_LABEL)
    local path = tostring(options.path or RUNTIME_DATA_PATH)
    local existing_rows = read_runtime_rows(path)
    local run_index = 1
    for _, row in ipairs(existing_rows) do
        if row.spec == spec and row.evidence_mode == "live" and row.run_label == label then
            run_index = math.max(run_index, as_number(row.run_index) + 1)
        end
    end

    if run_index > benchmark_thresholds.MIN_LIVE_RUNS then
        runtime_log(string.format("skip runtime baseline capture for %s: already have %d runs", spec, benchmark_thresholds.MIN_LIVE_RUNS))
        return false, "runs already complete"
    end

    local row = benchmark_matrix.build_row(spec, snapshot, {
        evidence_mode = "live",
        thresholds = benchmark_thresholds,
        run_id = label .. "-" .. tostring(run_index),
    })
    row = set_row_metadata(with_snapshot_contract(row, snapshot), label, run_index)
    existing_rows[#existing_rows + 1] = row

    local summary = apply_summary_metadata(existing_rows)
    write_runtime_rows(path, existing_rows)
    runtime_log(string.format(
        "captured %s run %d/%d -> %s (pass=%d fail=%d schema_only=%d)",
        spec,
        run_index,
        benchmark_thresholds.MIN_LIVE_RUNS,
        path,
        as_number(summary.pass_count),
        as_number(summary.fail_count),
        as_number(summary.schema_only_count)
    ))

    return true, {
        path = path,
        spec = spec,
        run_index = run_index,
        summary = summary,
    }
end

function M.install_runtime_capture()
    if runtime_capture_installed or type(dps_meter.register_combat_end_listener) ~= "function" then
        return false
    end

    dps_meter.register_combat_end_listener("phase08-runtime-capture", function(snapshot)
        M.capture_runtime_snapshot(snapshot, {
            label = RUNTIME_BASELINE_LABEL,
            path = RUNTIME_DATA_PATH,
        })
    end)
    runtime_capture_installed = true
    runtime_log("installed phase08 runtime baseline capture")
    return true
end

local function print_rows(rows)
    print("schema: " .. CSV_HEADER)
    print(CSV_HEADER)
    for _, row in ipairs(rows) do
        print(row_to_csv(row))
    end
end

local function print_summary(summary)
    print(string.format(
        "VERDICT: %s | pass=%d fail=%d schema_only=%d",
        tostring(summary.verdict or "FAIL"),
        as_number(summary.pass_count),
        as_number(summary.fail_count),
        as_number(summary.schema_only_count)
    ))

    print("BLOCKERS:")
    local blocker_count = 0
    for _, spec_summary in ipairs(summary.spec_summaries or {}) do
        if spec_summary.verdict ~= "pass" then
            blocker_count = blocker_count + 1
            print(string.format(" - %s: %s", spec_summary.spec, benchmark_matrix.format_blockers(spec_summary)))
        end
    end
    if blocker_count == 0 then
        print(" - none")
    end

    print("NEAR_FAIL:")
    local near_fail_count = 0
    for _, spec_summary in ipairs(summary.spec_summaries or {}) do
        if spec_summary.verdict == "pass" and spec_summary.near_fail == true then
            near_fail_count = near_fail_count + 1
            print(string.format(" - %s: variance_pct=%s", spec_summary.spec, format_number(spec_summary.variance_pct, 2)))
        end
    end
    if near_fail_count == 0 then
        print(" - none")
    end
end

function M.run_benchmark(argv)
    local args = parse_args(argv)
    local current_rows = args.dry_run and build_mock_rows(args) or build_live_rows(args)
    local report_rows, persisted_rows = collect_report_rows(args, current_rows)
    local summary = apply_summary_metadata(report_rows)

    local emitted_rows = current_rows
    if args.output then
        local output_rows = {}
        for _, row in ipairs(persisted_rows) do
            output_rows[#output_rows + 1] = row
        end
        for _, row in ipairs(current_rows) do
            output_rows[#output_rows + 1] = row
        end
        write_output(args.output, output_rows)
    end

    print_rows(emitted_rows)
    print_summary(summary)
    return 0
end

local module_name = ...
if module_name ~= "tools.dps_benchmark" then
    os.exit(M.run_benchmark(arg or {}), true)
end

return M
