local checklist_path = ".planning/phases/04-polish-competitive-features/04-REGRESSION-CHECKLIST.md"
local f = io.open(checklist_path, "r")
assert(f, "expected regression checklist file to exist")

local content = f:read("*a")
f:close()

assert(content:find("| Visual HUD |", 1, true), "missing Visual HUD column")
assert(content:find("| Automation |", 1, true), "missing Automation column")
assert(content:find("| Validation Script |", 1, true), "missing Validation Script column")
assert(content:find("| Benchmark |", 1, true), "missing Benchmark column")
assert(content:find("| Manual Notes |", 1, true), "missing Manual Notes column")

local count = 0
for _ in content:gmatch("\n| EAX") do
    count = count + 1
end
assert(count == 27, "expected exactly 27 EAX spec rows, got " .. tostring(count))

print("regression_checklist_spec: ok")
