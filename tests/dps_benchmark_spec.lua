local chunk, err = loadfile("tools/dps_benchmark.lua")
assert(chunk, "expected tools/dps_benchmark.lua to exist: " .. tostring(err))

local script = chunk("tools.dps_benchmark")
assert(type(script) == "table", "dps_benchmark should return a module table")
assert(type(script.run_benchmark) == "function", "run_benchmark must be defined")

print("dps_benchmark_spec: ok")
