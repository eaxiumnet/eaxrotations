-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "tests/test_optimizer_core_fallback.lua"
local __eax_version = "1.1.1"
local __eax_modified = "2026-05-27"
local __eax_change = "File version stamp for runtime load verification"
local __eax_versions = rawget(_G, "EaxRotationsFileVersions") or {}
_G.EaxRotationsFileVersions = __eax_versions
__eax_versions[__eax_file] = { version = __eax_version, modified = __eax_modified, change = __eax_change }
local __eax_core = rawget(_G, "core")
if type(__eax_core) == "table" and type(__eax_core.log) == "function" then
    pcall(__eax_core.log, "[EaxRotations] Loaded " .. __eax_file .. " v" .. __eax_version)
end
local __eax_ns = rawget(_G, "EaxRotations")
if type(__eax_ns) == "table" then __eax_ns.file_versions = __eax_versions end
-- regression test for DecisionCache diagnostics without a captured core table.

package.path = "EaxRotations/?.lua;" .. package.path

_G.core = nil
_G.EaxRotations = { log = function() end }
package.loaded.optimizer = nil

local optimizer = require("optimizer")
local stats = optimizer.DecisionCache:get_stats()

assert(type(stats) == "table", "stats table returned")
assert(stats.entries == nil, "entries removed in Phase 0 refactor (memoize deleted)")
assert(type(stats.generation) == "number", "generation number")
assert(type(stats.age) == "number", "age number")

print("PASS test_optimizer_core_fallback")
