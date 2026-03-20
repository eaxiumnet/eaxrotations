local chunk, err = loadfile("tools/dps_benchmark.lua")
assert(chunk, "expected tools/dps_benchmark.lua to exist: " .. tostring(err))

local script = chunk("tools.dps_benchmark")
assert(type(script) == "table", "dps_benchmark should return a module table")
assert(type(script.run_benchmark) == "function", "run_benchmark must be defined")

local dps_meter = require("eax_shared/dps_meter")

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

output = {}
print = function(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(i, ...))
    end
    output[#output + 1] = table.concat(parts, " ")
end

dps_meter.reset()
dps_meter.set_reactive_state({
    reactive_action = "interrupt_control",
    action_id = "interrupt_control",
    reason_code = "INTERRUPT_DANGER",
    context_fail_safe = false,
})

ok, run_err = pcall(script.run_benchmark, {})
print = original_print

assert(ok, "run_benchmark live path should succeed: " .. tostring(run_err))
assert(output[3] == "CURRENT_SPEC,0,0,0.00,0.00,0.00,interrupt_control,INTERRUPT_DANGER", "live row should use runtime reactive telemetry")

output = {}
print = function(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(i, ...))
    end
    output[#output + 1] = table.concat(parts, " ")
end

local original_dps_meter = package.loaded["eax_shared/dps_meter"]
package.loaded["eax_shared/dps_meter"] = {
    get_snapshot = function()
        return {
            damage_total = 0,
            healing_total = 0,
            duration_s = 0,
            dps = 0,
            hps = 0,
            action_id = "anti_aggro",
            reason_code = "ANTI_AGGRO",
        }
    end,
}

local fallback_script = chunk("tools.dps_benchmark")
ok, run_err = pcall(fallback_script.run_benchmark, {})
print = original_print
package.loaded["eax_shared/dps_meter"] = original_dps_meter

assert(ok, "run_benchmark fallback path should succeed: " .. tostring(run_err))
assert(output[3] == "CURRENT_SPEC,0,0,0.00,0.00,0.00,anti_aggro,ANTI_AGGRO", "live row should fall back to action_id when reactive_action is absent")

print("dps_benchmark_spec: ok")
