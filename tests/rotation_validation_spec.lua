local chunk, err = loadfile("tools/rotation_validation.lua")
assert(chunk, "expected tools/rotation_validation.lua to exist: " .. tostring(err))

local script = chunk()
assert(type(script) == "table", "rotation_validation should return a module table")
assert(type(script.validate_spec) == "function", "validate_spec must be defined")
assert(type(script.main) == "function", "main must be defined")

print("rotation_validation_spec: ok")
