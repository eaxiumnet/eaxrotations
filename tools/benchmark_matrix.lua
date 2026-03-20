local default_thresholds = require("tools/benchmark_thresholds")

local M = {}

local function copy_list(values)
    local out = {}
    for i, value in ipairs(values or {}) do
        out[i] = value
    end
    return out
end

local function as_number(value)
    return tonumber(value) or 0
end

local function effective_thresholds(thresholds)
    return thresholds or default_thresholds
end

local function metric_threshold(thresholds, metric_key)
    local limits = thresholds.MIN_PRIMARY_METRIC or default_thresholds.MIN_PRIMARY_METRIC
    return as_number(limits[metric_key])
end

local function canonical_specs()
    local specs = {}
    for spec, meta in pairs(default_thresholds.CANONICAL_SPEC_ROLE_MAP) do
        specs[#specs + 1] = {
            spec = spec,
            role = meta.role,
            primary_metric = meta.primary_metric,
        }
    end
    table.sort(specs, function(a, b)
        return a.spec < b.spec
    end)
    return specs
end

local function variance_pct(values, mean)
    if #values == 0 or mean <= 0 then
        return 0
    end

    local max_delta = 0
    for _, value in ipairs(values) do
        local delta = math.abs(value - mean) / mean
        if delta > max_delta then
            max_delta = delta
        end
    end
    return max_delta
end

local function add_blocker(blockers, message)
    blockers[#blockers + 1] = message
end

M.CANONICAL_SPECS = canonical_specs()

function M.build_row(spec, snapshot, meta)
    meta = meta or {}
    snapshot = snapshot or {}

    local thresholds = effective_thresholds(meta.thresholds)
    local spec_meta = thresholds.CANONICAL_SPEC_ROLE_MAP[spec]
    assert(spec_meta, "unknown canonical spec: " .. tostring(spec))

    local evidence_mode = meta.evidence_mode
    assert(evidence_mode == "live" or evidence_mode == "mock", "evidence_mode must be exactly live or mock")

    local row = {
        spec = spec,
        role = spec_meta.role,
        primary_metric = spec_meta.primary_metric,
        evidence_mode = evidence_mode,
        run_id = tostring(meta.run_id or "run-1"),
        damage_total = as_number(snapshot.damage_total),
        healing_total = as_number(snapshot.healing_total),
        threat_total = as_number(snapshot.threat_total),
        duration_s = as_number(snapshot.duration_s),
        dps = as_number(snapshot.dps),
        hps = as_number(snapshot.hps),
        tps = as_number(snapshot.tps),
        sample_count = as_number(snapshot.sample_count),
        reactive_event_count = as_number(snapshot.reactive_event_count),
        noop_unsupported_count = as_number(snapshot.noop_unsupported_count),
        unsafe_skip_count = as_number(snapshot.unsafe_skip_count),
        fail_safe_tick_count = as_number(snapshot.fail_safe_tick_count),
    }

    row.primary_value = row[row.primary_metric] or 0
    row.verdict = evidence_mode == "mock" and "schema_only" or "pending"
    row.near_fail = false
    return row
end

function M.summarize_spec_runs(rows, thresholds)
    thresholds = effective_thresholds(thresholds)
    rows = rows or {}
    assert(#rows > 0, "summarize_spec_runs requires at least one row")

    local first = rows[1]
    local summary = {
        spec = first.spec,
        role = first.role,
        primary_metric = first.primary_metric,
        evidence_mode = first.evidence_mode,
        run_count = #rows,
        blockers = {},
        rows = copy_list(rows),
        near_fail = false,
    }

    if first.evidence_mode == "mock" then
        summary.verdict = "schema_only"
        add_blocker(summary.blockers, "mock evidence is schema_only and cannot pass the release gate")
        return summary
    end

    local total = 0
    local values = {}
    local min_samples = math.huge
    local noop_total = 0
    local unsafe_total = 0
    local fail_safe_total = 0
    for _, row in ipairs(rows) do
        assert(row.spec == first.spec, "all summarized rows must target the same spec")
        assert(row.evidence_mode == "live", "live summaries cannot mix evidence modes")
        local value = as_number(row[row.primary_metric])
        values[#values + 1] = value
        total = total + value
        if row.sample_count < min_samples then
            min_samples = row.sample_count
        end
        noop_total = noop_total + row.noop_unsupported_count
        unsafe_total = unsafe_total + row.unsafe_skip_count
        fail_safe_total = fail_safe_total + row.fail_safe_tick_count
    end

    local average = total / #rows
    local variance = variance_pct(values, average)
    local threshold_value = metric_threshold(thresholds, first.primary_metric)

    summary.average_primary = average
    summary.threshold_value = threshold_value
    summary.variance_pct = variance
    summary.sample_count = min_samples == math.huge and 0 or min_samples
    summary.noop_unsupported_count = noop_total
    summary.unsafe_skip_count = unsafe_total
    summary.fail_safe_tick_count = fail_safe_total

    if #rows < thresholds.MIN_LIVE_RUNS then
        add_blocker(summary.blockers, string.format("requires at least %d live runs", thresholds.MIN_LIVE_RUNS))
    end
    if variance > thresholds.MAX_VARIANCE_PCT then
        add_blocker(summary.blockers, string.format("variance %.4f exceeds %.4f", variance, thresholds.MAX_VARIANCE_PCT))
    end
    if summary.sample_count < thresholds.MIN_SAMPLE_COUNT then
        add_blocker(summary.blockers, string.format("sample_count %d below minimum %d", summary.sample_count, thresholds.MIN_SAMPLE_COUNT))
    end
    if noop_total > thresholds.MAX_NOOP_UNSUPPORTED then
        add_blocker(summary.blockers, string.format("noop_unsupported_count %d exceeds max %d", noop_total, thresholds.MAX_NOOP_UNSUPPORTED))
    end
    if unsafe_total > thresholds.MAX_UNSAFE_SKIP then
        add_blocker(summary.blockers, string.format("unsafe_skip_count %d exceeds max %d", unsafe_total, thresholds.MAX_UNSAFE_SKIP))
    end
    if fail_safe_total > thresholds.MAX_FAIL_SAFE_TICKS then
        add_blocker(summary.blockers, string.format("fail_safe_tick_count %d exceeds max %d", fail_safe_total, thresholds.MAX_FAIL_SAFE_TICKS))
    end
    if first.primary_metric == "tps" and average <= 0 then
        add_blocker(summary.blockers, "tank rows require positive tps")
    end
    if average < threshold_value then
        add_blocker(summary.blockers, string.format("%s %.2f below threshold %.2f", first.primary_metric, average, threshold_value))
    end

    summary.near_fail = average >= threshold_value and average <= (threshold_value * (1 + thresholds.NEAR_FAIL_MARGIN_PCT))
    summary.verdict = #summary.blockers == 0 and "pass" or "fail"
    return summary
end

function M.summarize_matrix(rows, thresholds)
    thresholds = effective_thresholds(thresholds)
    rows = rows or {}

    local grouped = {}
    for _, row in ipairs(rows) do
        grouped[row.spec] = grouped[row.spec] or {}
        grouped[row.spec][#grouped[row.spec] + 1] = row
    end

    local summaries = {}
    local verdict = "PASS"
    local pass_count = 0
    local fail_count = 0
    local schema_only_count = 0
    local blockers = {}

    for _, entry in ipairs(M.CANONICAL_SPECS) do
        local spec_rows = grouped[entry.spec] or {}
        local summary
        if #spec_rows == 0 then
            summary = {
                spec = entry.spec,
                role = entry.role,
                primary_metric = entry.primary_metric,
                verdict = "fail",
                blockers = { "missing benchmark rows" },
                near_fail = false,
            }
        else
            summary = M.summarize_spec_runs(spec_rows, thresholds)
        end
        summaries[#summaries + 1] = summary

        if summary.verdict == "pass" then
            pass_count = pass_count + 1
            if summary.near_fail then
                blockers[#blockers + 1] = string.format("%s near_fail", summary.spec)
            end
        elseif summary.verdict == "schema_only" then
            schema_only_count = schema_only_count + 1
            verdict = "FAIL"
            blockers[#blockers + 1] = string.format("%s schema_only", summary.spec)
        else
            fail_count = fail_count + 1
            verdict = "FAIL"
            blockers[#blockers + 1] = string.format("%s: %s", summary.spec, M.format_blockers(summary))
        end
    end

    return {
        verdict = verdict,
        pass_count = pass_count,
        fail_count = fail_count,
        schema_only_count = schema_only_count,
        spec_summaries = summaries,
        blockers = blockers,
    }
end

function M.format_blockers(summary)
    return table.concat((summary or {}).blockers or {}, "; ")
end

return M
