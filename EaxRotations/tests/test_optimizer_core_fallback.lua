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
