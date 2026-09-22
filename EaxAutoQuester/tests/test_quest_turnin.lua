-- What: The quest reward frame — turn-in sequence and what happens when it will not close.
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Live loop this suite exists for (the log the user pasted): every second
--        INTERACT: handled (complete_quest+best_reward:1(10126c))
--        INTERACT: frame still open
--      for as long as the client kept the reward frame — and nothing could stop it, because the
--      reward path returned before the retry counter was ever charged, so the "give up after 3"
--      guard never engaged and the frame was re-selected forever. Two defects sat behind it:
--        1. The turn-in never called `complete_quest()`. The documented order is
--           get_quest_reward ("Selects a reward choice and completes the quest") and then
--           complete_quest ("...or AFTER selecting a reward with get_quest_reward") —
--           scraped_docs_md/dev/api/quests.md. The old branch selected the reward and called
--           close_quest() instead, and the frame stayed up.
--        2. The reward path was unbounded (see above).
--      The mock's reward frame clears only when the documented finisher is called, which is what
--      makes assertion S2 able to fail: a turn-in that skips complete_quest leaves the frame up.
-- Safety: uses the mock runtime; no client, no network, no writes.

-- Path setup for standalone run
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

local interaction = require("quest_interaction_sylvanas")

-- =============================================================================
-- Helpers
-- =============================================================================

local REWARD_LINK = "|cff1eff00|Hitem:23456:0:0:0:0:0:0:0|h[Signet of the Quest]|h|r"

-- Two pieces of module state outlive a scenario: the once-per-second throttle (so a scenario at
-- the same clock reading would be throttled by construction) and the give-up counter (so a
-- scenario that gives up leaves the next one pre-charged). Every scenario therefore starts at a
-- later clock, the way the live client's monotonic time always is.
local _clock = 1000
local function reset_at(t)
    mock.reset()
    -- Never step the clock backwards: the handler throttles on core.time(), and a scenario whose
    -- reading was lower than the last one would be throttled before it could do anything. An
    -- explicit base is therefore a floor, not an assignment.
    _clock = math.max(t or 0, _clock + 5)
    mock.set_time(_clock)
end

-- Move the clock without clearing the mock: the throttle test needs two calls inside one second
-- and one call after it, so it has to control time precisely rather than start over.
local function advance(dt)
    _clock = _clock + dt
    mock.set_time(_clock)
end

local function calls_named(name)
    local n = 0
    for _, c in ipairs(mock._input_calls) do
        if c[1] == name then n = n + 1 end
    end
    return n
end

local function index_of_call(name)
    for i, c in ipairs(mock._input_calls) do
        if c[1] == name then return i end
    end
    return nil
end

--- A reward frame that closes when the documented finisher arrives, the way the client behaves.
--- `close_quest` alone does NOT clear it: that is the observed client behaviour this suite is
--- pinned to, and the reason the old sequence looped.
local function open_reward_frame()
    mock._quest_rewards = { [1] = { link = REWARD_LINK } }
    mock._quest_money = 0
    mock._item_info[REWARD_LINK] = { name = "Signet of the Quest", quality = 3, sell_price = 10126 }
    local real_complete = core.quests.complete_quest
    core.quests.complete_quest = function()
        mock._input_calls[#mock._input_calls + 1] = { "complete_quest" }
        -- The dialog closes only when the quest is actually finished.
        mock._quest_rewards = {}
        mock._quest_money = 0
    end
    return real_complete
end

--- A reward frame that NEVER clears — the turn-in is refused (bags full, no room for the reward)
--- or the frame is a quest offer whose preview links look like reward choices.
local function open_stubborn_reward_frame()
    mock._quest_rewards = { [1] = { link = REWARD_LINK } }
    mock._quest_money = 0
    mock._item_info[REWARD_LINK] = { name = "Signet of the Quest", quality = 3, sell_price = 10126 }
    core.quests.complete_quest = function()
        mock._input_calls[#mock._input_calls + 1] = { "complete_quest" }
        -- Deliberately leaves the reward link in place.
    end
end

-- =============================================================================
-- S1 — happy path: the reward is selected, the dialog is FINISHED, and the frame clears
-- =============================================================================

do
    reset_at()
    open_reward_frame()

    local result = interaction.handle_quest_detail()
    assert(type(result) == "string" and result:find("complete_quest", 1, true),
        "S1a FAIL: a reward frame must report the completion (got " .. tostring(result) .. ")")
    assert(calls_named("get_quest_reward") == 1,
        "S1b FAIL: the reward choice must be selected once (got " ..
        tostring(calls_named("get_quest_reward")) .. ")")

    print("  S1 PASS: reward selected and the frame reported as completed")
end

-- =============================================================================
-- S2 — the documented finisher is what closes it: get_quest_reward, THEN complete_quest
-- =============================================================================

do
    reset_at()
    open_reward_frame()

    local result = interaction.handle_quest_detail()
    assert(result ~= nil, "S2a FAIL: the frame should have been handled")

    local select_at = index_of_call("get_quest_reward")
    local finish_at = index_of_call("complete_quest")
    assert(select_at, "S2b FAIL: get_quest_reward was never called")
    assert(finish_at, "S2c FAIL: complete_quest was never called — the documented finisher is " ..
        "missing, which is what left the reward frame open and re-selected it every second")
    assert(finish_at > select_at,
        "S2d FAIL: complete_quest must come AFTER the reward selection (docs: \"after selecting a " ..
        "reward with get_quest_reward\")")

    -- And the frame really is gone, so the handler stops: a second pass finds nothing.
    assert(interaction.handle_quest_detail() == nil,
        "S2e FAIL: a cleared reward frame must not be handled again")
    print("  S2 PASS: complete_quest follows the reward selection and clears the frame")
end

-- =============================================================================
-- S3 — a frame that never clears is given up on, not re-selected forever
-- =============================================================================

do
    reset_at()
    -- Start from a tick with nothing open: that observed absence is what gives the next frame a
    -- fresh budget of attempts (and it is the only thing that can, by design).
    assert(interaction.handle_quest_detail() == nil,
        "S3a FAIL: no frame should be handled when none is open")
    advance(2)          -- the pristine tick spent this second; passes below are real attempts
    open_stubborn_reward_frame()
    core.quests.close_quest = function() end   -- closing alone never clears it either
    core.quests.close_gossip = function() end

    local attempts, gave_up = 0, false
    for _ = 1, 12 do
        -- One INTERACT pass, driven the way the state machine drives it.
        local result = interaction.handle_any_frame("turn in the thing")
        if result == "quest_giveup" then
            gave_up = true
            break
        end
        attempts = attempts + 1
        -- The handler throttles itself to one attempt per second; advance the clock so the
        -- passes are the real ones rather than copies of a throttled no-op.
        advance(1.1)
    end

    assert(gave_up,
        "S3b FAIL: a reward frame that will not close must be given up on — the live loop " ..
        "re-selected the same reward forever because the retry counter was never charged")
    assert(attempts == 3,
        "S3c FAIL: giving up is documented as three attempts (took " ..
        tostring(attempts) .. ")")
    print("  S3 PASS: a stubborn reward frame is given up on after " .. tostring(attempts) ..
        " attempt(s) instead of looping")
end

-- =============================================================================
-- S7 — driven the way INTERACT drives it: the window is up on every pass, and it is given up on
-- =============================================================================
-- Live shape (the log): the reward frame is present on every pass, a completion is issued, the
-- window stays up. The budget is exactly the documented three attempts, established by observing
-- a tick with no frame open first, the same way the live client closes the previous one.

do
    reset_at(9000)
    assert(interaction.handle_quest_detail() == nil,
        "S7a FAIL: a tick with no frame open must clear the way for the next frame")
    advance(2)          -- the pristine tick spent this second; passes below are real attempts
    open_stubborn_reward_frame()
    core.quests.close_quest = function() end
    core.quests.close_gossip = function() end
    local window_open = function() return true end

    local attempts, gave_up = 0, false
    for _ = 1, 12 do
        local result = interaction.handle_any_frame("turn in the thing", window_open)
        if result == "quest_giveup" then
            gave_up = true
            break
        end
        attempts = attempts + 1
        advance(1.1)
    end

    assert(gave_up,
        "S7b FAIL: a window the caller still sees must be given up on " ..
        "(attempts=" .. tostring(attempts) .. ") — this is the live loop")
    assert(attempts == 3,
        "S7c FAIL: the give-up is documented as three attempts (got " ..
        tostring(attempts) .. ")")
    print("  S7 PASS: given up on after " .. tostring(attempts) .. " attempt(s), as documented")
end

-- =============================================================================
-- S8 — the caller's probe is the one that decides; a window it no longer sees is never "given up"
-- =============================================================================
-- The give-up is a statement about a window the CALLER is looking at. If the caller says the frame
-- is gone, the handler must not escalate — the frame is the caller's to judge, and a handler that
-- consults its own probe here would warn the player about a frame that is already closed. This is
-- the assertion that a hardcoded probe cannot satisfy: the links below never clear, so the
-- module's own probe says "open" for every pass.

do
    reset_at(12000)
    assert(interaction.handle_quest_detail() == nil, "S8a FAIL: expected no frame")
    open_stubborn_reward_frame()
    core.quests.close_quest = function() end
    core.quests.close_gossip = function() end
    local window_closed = function() return false end

    local gave_up = false
    for _ = 1, 6 do
        if interaction.handle_any_frame("turn in the thing", window_closed) == "quest_giveup" then
            gave_up = true
            break
        end
        advance(1.1)
    end

    assert(not gave_up,
        "S8b FAIL: the handler gave up on a frame its caller reports as closed — the give-up must " ..
        "defer to the caller's probe")
    print("  S8 PASS: a frame the caller reports closed is never escalated as stuck")
end

-- =============================================================================
-- S4 — a reward frame that clears as soon as the reward is taken is NOT given up on
-- (the guard must not fire on a turn-in that works)
-- =============================================================================

-- The frame this scenario turns in is a NEW frame, so it starts from a pristine budget: one tick
-- with nothing open. That absence tick is the documented reset (and the reason a turn-in that
-- works cannot inherit a give-up from a frame that did not).
do
    reset_at(6000)
    assert(interaction.handle_quest_detail() == nil,
        "S4a FAIL: no frame should be handled when none is open")
    advance(2)
    open_reward_frame()

    local result = interaction.handle_any_frame("turn in the thing")
    assert(result ~= "quest_giveup",
        "S4b FAIL: a turn-in that closes the frame must not be given up on (got " .. tostring(result) .. ")")
    assert(interaction.handle_any_frame("turn in the thing") ~= "quest_giveup",
        "S4c FAIL: nothing to handle is not a give-up either")
    print("  S4 PASS: a working turn-in never reaches the give-up path")
end

-- =============================================================================
-- S5 — an OFFER frame also publishes "choice" links. Attempting the reward must fall through to
-- the claim path rather than selecting the same "reward" forever.
-- =============================================================================

do
    reset_at()
    open_stubborn_reward_frame()
    mock._quest_rewards = { [1] = { link = REWARD_LINK } }   -- offer preview, verbatim the same probe

    local real_accept = core.quests.accept_quest
    core.quests.accept_quest = function()
        mock._input_calls[#mock._input_calls + 1] = { "accept_quest" }
        mock._quest_rewards = {}                  -- accepting closes the offer frame
    end

    local result = interaction.handle_quest_detail()
    assert(calls_named("accept_quest") == 1,
        "S5a FAIL: a frame that survives the reward attempt must still be claimed")
    assert(result == "accept_quest",
        "S5b FAIL: the claim should be reported (got " .. tostring(result) .. ")")
    assert(interaction.handle_quest_detail() == nil,
        "S5c FAIL: the accepted frame is closed, so there is nothing left to handle")
    print("  S5 PASS: a frame that survives the reward attempt falls through to the claim path")
end

-- =============================================================================
-- S6 — one attempt per second, and a probe that reports nothing handled returns nil
-- =============================================================================

do
    reset_at()
    assert(interaction.handle_quest_detail() == nil,
        "S6a FAIL: with no frame open, nothing may be handled")
    assert(calls_named("complete_quest") == 0 and calls_named("accept_quest") == 0,
        "S6b FAIL: no quest call may be issued when no frame is open")

    open_reward_frame()
    advance(2)                                          -- past the second S6a spent
    local first = interaction.handle_quest_detail()
    local second = interaction.handle_quest_detail()   -- same second: throttled
    assert(first ~= nil and second == nil,
        "S6c FAIL: the handler must attempt at most once per second " ..
        "(first=" .. tostring(first) .. ", second=" .. tostring(second) .. ")")
    print("  S6 PASS: no frame means no calls, and attempts stay throttled")
end

print("PASS test_quest_turnin")
os.exit(0)
