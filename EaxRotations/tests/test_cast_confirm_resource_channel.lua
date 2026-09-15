-- test_cast_confirm_resource_channel.lua -- UI_ERROR_MESSAGE refusal channel.
-- WHAT:  pins the resource-class refusal hold in shared/cast_confirm_sylvanas.
-- WHY:   "Not enough rage" / "Spell not learned" arrive as UI_ERROR_MESSAGE
--        with NO spell id. Before this channel nothing consumed the event
--        (live: Battle Shout re-queued at 0 rage every ~0.5s, the event log
--        showing "UI_ERROR_MESSAGE: NO handlers registered" on repeat), so
--        the 0.6s FAILED-family hold never applied and the lane re-matched
--        every frame. Attribution goes through the outstanding offer
--        (_pending_id): an error while WE have an unresolved cast in flight
--        holds THAT cast for RESOURCE_HOLD_SEC (1.5s).
-- SAFETY: pure unit tests; the module is fail-open by design (a host that
--        never delivers events sees byte-for-byte the pre-channel behavior).

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local pass_count, test_count = 0, 0
local function assert_true(v, label)
    test_count = test_count + 1
    if not v then error("FAIL: " .. (label or "assert_true"), 2) end
    pass_count = pass_count + 1
end
local function assert_false(v, label)
    test_count = test_count + 1
    if v then error("FAIL: " .. (label or "assert_false"), 2) end
    pass_count = pass_count + 1
end
local function assert_eq(a, b, label)
    test_count = test_count + 1
    if a ~= b then error("FAIL: " .. (label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end
    pass_count = pass_count + 1
end

local T = 1000
local clock = T
local events = {}
_G.EaxRotations = {
    time_now = function() return clock end,
    register_on_game_event = function(name, cb) events[name] = cb return true end,
}

local M = require("shared/cast_confirm_sylvanas")
M.install(_G.EaxRotations)

assert_true(M.RESOURCE_HOLD_SEC ~= nil and M.RESOURCE_HOLD_SEC > M.HOLD_SEC,
    "resource hold is public and longer than the default hold")

-- E1: registration happened on install
assert_true(type(events["UI_ERROR_MESSAGE"]) == "function",
    "UI_ERROR_MESSAGE is subscribed by install()")

-- E2: error with a pending offer holds THAT spell for ~RESOURCE_HOLD_SEC
M.reset(); M.install(_G.EaxRotations)
M.note_queued(2048)  -- Battle Shout issued, engine silent
events["UI_ERROR_MESSAGE"]("UI_ERROR_MESSAGE", { "Not enough rage." })
local rem = M.remaining(2048)
assert_true(rem > M.HOLD_SEC and rem <= M.RESOURCE_HOLD_SEC,
    "resource refusal holds the offered spell longer than the default hold")

-- E3: the UI-error channel never clears the pending offer (it is not an ack)
assert_eq(M.pending_id(), 2048, "resource refusal leaves the offer outstanding")

-- E4: ...and never arms the never-confirmed machinery
assert_false(M.armed(), "UI error alone does not arm the machine")

-- E5: an error with NO outstanding offer holds nothing (unattributable)
M.reset(); M.install(_G.EaxRotations)
local before = M.count()
events["UI_ERROR_MESSAGE"]("UI_ERROR_MESSAGE", { "Some unrelated error." })
assert_eq(M.count(), before, "unattributable UI error records no hold")

-- E6: an engine acknowledgement still resolves the offer normally
M.reset(); M.install(_G.EaxRotations)
M.note_queued(469)
events["UI_ERROR_MESSAGE"]("UI_ERROR_MESSAGE", { "Internal bag error." })  -- would hold 469
events["UNIT_SPELLCAST_SUCCEEDED"]("UNIT_SPELLCAST_SUCCEEDED", { "player", nil, 469 })
assert_eq(M.pending_id(), nil, "SUCCEEDED resolves the offer")
-- the recorded resource hold decays on the clock (no per-event undo): 1.5s
-- max, vs the engine-verdict hold which this event already ended cleanly
clock = T + M.RESOURCE_HOLD_SEC + 0.01
assert_false(M.is_held(469), "resource hold decays; engine ack resolved the offer")
clock = T

-- E7: the FAILED family (spell-id channel) is unchanged: 0.6s, offer resolved
M.reset(); M.install(_G.EaxRotations)
M.note_queued(2048)
events["UNIT_SPELLCAST_FAILED"]("UNIT_SPELLCAST_FAILED", { "player", nil, 2048 })
assert_true(M.is_held(2048) and M.remaining(2048) < M.HOLD_SEC + 0.01,
    "FAILED keeps its 0.6s hold")
assert_eq(M.pending_id(), nil, "FAILED resolves the offer")
assert_true(M.armed(), "engine cast events arm the machine")

-- E8: hold expiry (stored as an absolute expiry timestamp now)
M.reset(); M.install(_G.EaxRotations)
M.note_queued(71)
events["UNIT_SPELLCAST_FAILED"]("UNIT_SPELLCAST_FAILED", { "player", nil, 71 })
clock = T + M.HOLD_SEC + 0.01
assert_false(M.is_held(71), "hold expires at verdict + HOLD_SEC")
clock = T

-- E9: resource hold expiry at RESOURCE_HOLD_SEC
M.reset(); M.install(_G.EaxRotations)
M.note_queued(5242)
events["UI_ERROR_MESSAGE"]("UI_ERROR_MESSAGE", { "Spell not learned." })
clock = T + M.RESOURCE_HOLD_SEC - 0.05
assert_true(M.is_held(5242), "still held just inside the resource window")
clock = T + M.RESOURCE_HOLD_SEC + 0.01
assert_false(M.is_held(5242), "released at verdict + RESOURCE_HOLD_SEC")
clock = T

print(string.format("PASS test_cast_confirm_resource_channel (%d/%d assertions)", pass_count, test_count))
