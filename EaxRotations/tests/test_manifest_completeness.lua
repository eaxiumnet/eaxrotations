-- test_manifest_completeness.lua — cross-runner test manifest contract.
-- WHAT: checks that every test_*.lua is registered or explicitly allowlisted.
-- WHEN: run with the rotation manifest from either documented cwd.
-- WHY: prevents newly added tests from becoming silent coverage gaps.
-- SAFETY: reads only test filenames and manifest source; the runner library is the sole exception.

local lfs = assert(require("lfs"), "lfs is required for manifest inventory")
local root_file = io.open("tests/run_rotation_tests.lua", "rb")
local root = root_file and "." or "EaxRotations"
if root_file then root_file:close() end
package.path = root .. "/tests/?.lua;" .. package.path
local runner = require("test_runner_lib")

local function read_file(path)
    local file = assert(io.open(path, "rb"))
    local content = file:read("*a")
    file:close()
    return content
end

local tests_dir = root .. "/tests"
local files = {}
for name in lfs.dir(tests_dir) do
    if name:match("^test_.*%.lua$") then files[#files + 1] = name end
end
table.sort(files)

local registered = {}
local registered_set = {}
for _, manifest in ipairs({ "run_rotation_tests.lua", "run_leveling_tests.lua" }) do
    for name in read_file(tests_dir .. "/" .. manifest):gmatch('"(test_[^"]+%.lua)"') do
        if not registered_set[name] then
            registered[#registered + 1] = name
            registered_set[name] = true
        end
    end
end

runner.assert_manifest_complete(files, registered, {
    "test_runner_lib.lua",
    "test_class_loader_cata_fallback.lua",
})
print("Manifest completeness: " .. #files .. " files covered")
