local chunk, err = loadfile("tools/dps_benchmark.lua")
assert(chunk, "expected tools/dps_benchmark.lua to exist: " .. tostring(err))

local script = chunk("tools.dps_benchmark")
assert(type(script) == "table", "dps_benchmark should return a module table")
assert(type(script.run_benchmark) == "function", "run_benchmark must be defined")

local output = {}
local original_print = print
print = function(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(i, ...))
    end
    output[#output + 1] = table.concat(parts, " ")
end

local ok, run_err = pcall(script.run_benchmark, { "--dry-run" })
print = original_print

assert(ok, "run_benchmark dry-run should succeed: " .. tostring(run_err))
assert(output[1] == "schema: spec,damage_total,healing_total,dps,hps,duration_s,reactive_action,reason_code", "schema should expose reactive telemetry columns")
assert(output[2] == "spec,damage_total,healing_total,dps,hps,duration_s,reactive_action,reason_code", "csv header should expose reactive telemetry columns")
assert(output[3] and output[3]:match(",none,NO_ACTION$"), "dry-run rows should emit deterministic reactive placeholders")

print("dps_benchmark_spec: ok")
