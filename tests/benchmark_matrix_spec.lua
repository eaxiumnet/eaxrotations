local function count_rows(rows)
    local total = 0
    for _ in ipairs(rows or {}) do
        total = total + 1
    end
    return total
end

local thresholds = require("tools/benchmark_thresholds")
local matrix = require("tools/benchmark_matrix")

assert(thresholds.MIN_LIVE_RUNS == 3, "MIN_LIVE_RUNS should be 3")
assert(thresholds.MAX_VARIANCE_PCT == 0.05, "MAX_VARIANCE_PCT should be 0.05")
assert(count_rows(matrix.CANONICAL_SPECS) == 27, "canonical spec catalog should contain 27 specs")

local function build_live_snapshot(metric_key, metric_value, extra)
    local snapshot = {
        damage_total = 10000,
        healing_total = 1000,
        threat_total = 500,
        duration_s = 100,
        dps = 100,
        hps = 10,
        tps = 5,
        sample_count = 30,
        reactive_event_count = 3,
        noop_unsupported_count = 0,
        unsafe_skip_count = 0,
        fail_safe_tick_count = 0,
    }
    snapshot[metric_key] = metric_value
    for key, value in pairs(extra or {}) do
        snapshot[key] = value
    end
    return snapshot
end

local function build_live_row(spec, metric_key, metric_value, extra_snapshot, extra_meta)
    return matrix.build_row(spec, build_live_snapshot(metric_key, metric_value, extra_snapshot), {
        evidence_mode = "live",
        run_id = extra_meta and extra_meta.run_id or (spec .. "-run"),
        thresholds = thresholds,
    })
end

local mock_row = matrix.build_row("EAXMageArcane", build_live_snapshot("dps", 120), {
    evidence_mode = "mock",
    run_id = "mock-row",
    thresholds = thresholds,
})
assert(mock_row.verdict == "schema_only", "mock rows should stay schema_only")

local missing_runs = matrix.summarize_spec_runs({
    build_live_row("EAXMageArcane", "dps", 120, nil, { run_id = "run-1" }),
    build_live_row("EAXMageArcane", "dps", 118, nil, { run_id = "run-2" }),
}, thresholds)
assert(missing_runs.verdict == "fail", "fewer than 3 live runs should fail")
assert(table.concat(missing_runs.blockers, " | "):find("3"), "missing run blocker should mention required run count")

local unstable = matrix.summarize_spec_runs({
    build_live_row("EAXMageArcane", "dps", 100, nil, { run_id = "run-1" }),
    build_live_row("EAXMageArcane", "dps", 150, nil, { run_id = "run-2" }),
    build_live_row("EAXMageArcane", "dps", 80, nil, { run_id = "run-3" }),
}, thresholds)
assert(unstable.verdict == "fail", "variance above 0.05 should fail")
assert(table.concat(unstable.blockers, " | "):find("variance"), "variance failure should name variance blocker")

local near_fail = matrix.summarize_spec_runs({
    build_live_row("EAXMageArcane", "dps", 97.5, nil, { run_id = "run-1" }),
    build_live_row("EAXMageArcane", "dps", 98.5, nil, { run_id = "run-2" }),
    build_live_row("EAXMageArcane", "dps", 99.0, nil, { run_id = "run-3" }),
}, thresholds)
assert(near_fail.verdict == "pass", "within the 3 percent margin should still pass")
assert(near_fail.near_fail == true, "passes close to threshold should be tagged near_fail")

local live_rows = {}
for spec, spec_meta in pairs(thresholds.CANONICAL_SPEC_ROLE_MAP) do
    local metric_key = spec_meta.primary_metric
    local metric_value = 120
    if metric_key == "hps" then
        metric_value = 110
    elseif metric_key == "tps" then
        metric_value = 140
    end
    for run_index = 1, 3 do
        live_rows[#live_rows + 1] = build_live_row(spec, metric_key, metric_value, nil, {
            run_id = spec .. "-" .. run_index,
        })
    end
end

local summary = matrix.summarize_matrix(live_rows, thresholds)
assert(summary.verdict == "PASS", "full live 27-spec matrix should pass deterministically")
assert(summary.pass_count == 27, "all 27 specs should pass")
assert(summary.fail_count == 0, "full healthy matrix should have zero failing specs")

print("benchmark_matrix_spec: ok")
