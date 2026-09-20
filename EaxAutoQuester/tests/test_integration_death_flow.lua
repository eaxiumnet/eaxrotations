-- What: Integration test for EaxAutoQuester death flow
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify death handling: IDLE → DEAD → IDLE, and that death is detected
--      BEFORE the guidance gate. A dead player with no current step — or with
--      Zygor absent entirely — must still reach DEAD, or corpse recovery never
--      runs and the machine parks in WAITING forever (the retired monolith
--      checked death before any guidance gate). Every case asserts an exact
--      state, so a regression fails this suite instead of sliding through.

-- Path setup for standalone run
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

local dead_state = require("quest_state/dead_state")
local idle_state = require("quest_state/idle_state")

local NO_STEP = { has_current_step = function() return false end }
local WITH_STEP = { has_current_step = function() return true end }

local function idle_result(opts, zygor)
    local player = mock.create_player(opts)
    local ctx = { zygor = zygor, now = 0, debug_log = function() end, me = player }
    local shared = { _interact_cooldown = 0, _last_cooldown_log = 0 }
    return idle_state.run(shared, ctx)
end

-- Death detection must precede the step/guidance gate.
local DEATH_CASES = {
    { name = "dead, no current step", opts = { dead = true, hp = 0 }, zygor = NO_STEP },
    { name = "dead, Zygor absent", opts = { dead = true, hp = 0 }, zygor = nil },
    { name = "dead, step present", opts = { dead = true, hp = 0 }, zygor = WITH_STEP },
    {
        name = "ghost form (buff 8326), no step",
        opts = { dead = false, hp = 100, buffs = { [8326] = true } },
        zygor = NO_STEP,
    },
}
for _, case in ipairs(DEATH_CASES) do
    local result = idle_result(case.opts, case.zygor)
    assert(result == "DEAD",
        "death flow: " .. case.name .. " must reach DEAD (got " .. tostring(result) .. ")")
end

-- Control: the guidance gate still parks an ALIVE player with no step in WAITING.
assert(idle_result({ dead = false }, NO_STEP) == "WAITING",
    "alive player with no step must still wait for guidance")

-- Test resurrection in dead_state
local alive_player = mock.create_player({ pos = {x=0, y=0, z=0}, dead = false })
local shared = { _nav_destination = nil, _nav_retries = 0, _nav_retry_timer = 0 }
local ctx = { now = 100, debug_log = function() end, me = alive_player, nav = nil }
assert(dead_state.run(shared, ctx) == "IDLE", "death flow dead detects resurrection")

print("PASS test_integration_death_flow")
os.exit(0)
