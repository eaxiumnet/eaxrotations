-- Readability notes:
--   What: regression test for DecisionCache diagnostics without a captured core table.
--   When: menu diagnostics call DecisionCache:get_stats().
--   Why: a nil core upvalue crashed render_menu and stopped settings/rotation flow.
--   Safety: local stub only; no game APIs or casts are called.

-- Decision notes:
--   Tests use local stubs instead of a live Sylvanas client so API-bound behavior remains reproducible.
--   Each case protects one previous failure mode or role rule; keep assertions narrow and descriptive.
--   No test should call real input/cast APIs because regression runs must be safe outside the game.
package.path = "EaxRotations/?.lua;" .. package.path

_G.core = nil
_G.EaxRotations = { log = function() end }
package.loaded.optimizer = nil

local optimizer = require("optimizer")
local stats = optimizer.DecisionCache:get_stats()

assert(type(stats) == "table", "stats table returned")
assert(type(stats.entries) == "number", "entries number")
assert(type(stats.generation) == "number", "generation number")
assert(type(stats.age) == "number", "age number")

print("PASS test_optimizer_core_fallback")
