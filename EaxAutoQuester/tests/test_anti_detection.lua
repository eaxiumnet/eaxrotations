-- What: Unit tests for EaxAutoQuester/anti_detection_sylvanas.lua proximity handling.
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why:  A player standing next to the bot used to freeze it forever. The old
--       check_player_proximity() re-armed a 2-5s pause on EVERY tick it was called
--       (and the coordinator turned each one into shared._action_pause_timer = now + 3.0),
--       so IDLE returned early for as long as that player stayed within 30yd. Live logs
--       show two separate runs of 15 minutes with the same three lines repeating and no
--       quest progress. This suite pins the replacement: a rate-limited look-around that
--       cannot block anything.
-- Safety: assertions are on call counts and on the absence of the stall API, both of which
--       fail if the pause comes back in any form.

-- Path setup for standalone run
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

local ad = require("anti_detection_sylvanas")

-- S1 — the stall API is gone. check_player_proximity() was the thing every caller had to
-- remember not to turn into a pause, and the coordinator did turn it into one. Its absence is
-- the regression pin: reintroducing any "should I stop working?" signal here fails this line.
assert(ad.check_player_proximity == nil,
    "S1 FAIL: anti_detection must not expose a proximity pause signal again")
assert(type(ad.react_to_nearby_player) == "function",
    "S1 FAIL: react_to_nearby_player is the supported proximity entry point")
print("  S1 PASS: no proximity pause API; proximity reaction replaces it")

-- S2 — a nearby player produces a bounded number of reactions, never a sustained stall.
do
    mock.reset()
    mock.create_player({ pos = { x = 0, y = 0, z = 0 }, class = 5 })
    local stranger = mock.create_object({
        pos = { x = 10, y = 0, z = 0 }, name = "Stranger",
        unit = true, player = true, valid = true, guid = "stranger_1",
    })
    mock._objects = { stranger }

    mock.set_time(0)
    local first = ad.react_to_nearby_player(30)
    assert(first == true, "S2 FAIL: a player 10yd away should produce one reaction")

    -- 300 simulated seconds at the plugin's tick rate with the player never leaving range.
    local reactions = 1
    for t = 0, 300, 0.05 do
        mock.set_time(t)
        if ad.react_to_nearby_player(30) then reactions = reactions + 1 end
    end
    assert(reactions >= 2, "S2 FAIL: reactions stopped entirely (got " .. reactions .. ")")
    assert(reactions <= 16,
        "S2 FAIL: reactions must be rate limited to one per cooldown; 300s produced " ..
        tostring(reactions) .. " (the old code paused on every tick)")
    print("  S2 PASS: 300s beside a player → " .. tostring(reactions) .. " reactions, not a stall")
end

-- S3 — a party member is not a stranger to hide from.
do
    mock.reset()
    mock.create_player({ pos = { x = 0, y = 0, z = 0 }, class = 5 })
    local mate = mock.create_object({
        pos = { x = 5, y = 0, z = 0 }, name = "Party Mate",
        unit = true, player = true, valid = true, guid = "mate_1",
    })
    mock._objects = { mate }
    mock._party = { mate }

    local reactions = 0
    for t = 1000, 1060, 0.05 do
        mock.set_time(t)
        if ad.react_to_nearby_player(30) then reactions = reactions + 1 end
    end
    assert(reactions == 0,
        "S3 FAIL: a party member must not trigger a reaction (got " .. reactions .. ")")

    -- Same object, no longer grouped: the roster refresh must pick that up.
    mock._party = {}
    local after_leave = false
    for t = 1200, 1260, 0.05 do
        mock.set_time(t)
        if ad.react_to_nearby_player(30) then after_leave = true end
    end
    assert(after_leave, "S3 FAIL: a stranger was ignored after the party roster shrank")
    print("  S3 PASS: party member ignored; the same player becomes a stranger when ungrouped")
end

-- S4 — nobody nearby: nothing happens at all.
do
    mock.reset()
    mock.create_player({ pos = { x = 0, y = 0, z = 0 }, class = 5 })
    mock._objects = {}
    local reactions = 0
    for t = 2000, 2100, 0.05 do
        mock.set_time(t)
        if ad.react_to_nearby_player(30) then reactions = reactions + 1 end
    end
    assert(reactions == 0, "S4 FAIL: empty world must not react (got " .. reactions .. ")")
    print("  S4 PASS: no players in range → no reactions")
end

print("PASS test_anti_detection")
os.exit(0)
