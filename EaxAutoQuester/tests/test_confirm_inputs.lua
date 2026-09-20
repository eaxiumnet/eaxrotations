-- test_confirm_inputs.lua — item 14: the confirm prompts the plugin's OWN actions raise.
-- What:  CONFIRM_BINDER follows the innkeeper bind gossip option service_gossip selects
--        itself; LOOT_BIND_CONFIRM follows the plugin's own loot pass and is pinned in
--        test_loot_manager S9. This suite pins the binder side, including the per-tick seam
--        that answers it.
-- Why:   Selecting the bind option closes the gossip frame, so no INTERACT tick runs while
--        the prompt is up — the answer has to come from a seam that runs in every state.
-- Safety: a prompt this plugin did NOT raise is never answered, and a selection is only good
--        for a bounded window, so an innkeeper prompt the player opened by hand is theirs.
-- API reference: .api/core.lua:1841-1845 (confirm_binder), .api/core.lua:2132 (loot_object).

package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.menu = { get = function() return nil end }

local bridge = require("quest_frame_events_sylvanas")
local sg = require("service_gossip_sylvanas")

--- How many input calls of one name the mock recorded.
local function count_calls(name)
    local n = 0
    for _, call in ipairs(mock._input_calls) do
        if call[1] == name then n = n + 1 end
    end
    return n
end

local function set_gossip(options)
    mock._frames.gossip = true
    mock._gossip_options = options or {}
end

-- ============================================================================
-- C1: a CONFIRM_BINDER this plugin did not raise is left for the player
-- ============================================================================
mock.set_time(10.0)
mock._input_calls = {}
bridge.on_game_event("CONFIRM_BINDER", { "Innkeeper Farley" })
sg.answer_bind_confirm()
assert(count_calls("confirm_binder") == 0,
    "C1 FAIL: a prompt the plugin did not raise must not be answered")
print("  C1 PASS: prompt nobody here raised -> not answered")

-- ============================================================================
-- C2: the plugin takes the bind option itself, so its prompt is answered
-- ============================================================================
set_gossip({
    { name = "Make this inn your home", gossip_option_id = 5 },
})
local token = sg.handle_service_gossip("Set your Hearthstone to Goldshire")
assert(token == "service:inn", "C2a FAIL: expected service:inn, got " .. tostring(token))
assert(sg._bind_confirm_pending(),
    "C2b FAIL: taking the bind option must record that this plugin raised the prompt")
mock._input_calls = {}
bridge.on_game_event("CONFIRM_BINDER", { "Innkeeper Farley" })
assert(sg.answer_bind_confirm() == true, "C2c FAIL: the prompt our own selection raised must be answered")
assert(count_calls("confirm_binder") == 1,
    "C2d FAIL: expected exactly one confirm_binder call, got " .. tostring(count_calls("confirm_binder")))
assert(not sg._bind_confirm_pending(), "C2e FAIL: answering must clear the outstanding prompt")
print("  C2 PASS: bind option taken -> its CONFIRM_BINDER is confirmed once")

-- ============================================================================
-- C3: a non-bind service option does not arm the answer
-- ============================================================================
mock.reset()
mock.set_time(20.0)
set_gossip({
    { name = "I would like to check my deposit box", gossip_option_id = 9 },
})
local bank_token = sg.handle_service_gossip("Set your Hearthstone to Goldshire", { "bank" })
assert(bank_token == "service:bank", "C3a FAIL: expected service:bank, got " .. tostring(bank_token))
assert(not sg._bind_confirm_pending(),
    "C3b FAIL: a bank option raises no bind prompt, so nothing may be armed")
bridge.on_game_event("CONFIRM_BINDER", { "Innkeeper Farley" })
assert(sg.answer_bind_confirm() == false, "C3c FAIL: no prompt of ours is outstanding")
print("  C3 PASS: only the bind option arms the answer")

-- ============================================================================
-- C4: a stale selection does not answer a later prompt
-- ============================================================================
mock.reset()
mock.set_time(30.0)
set_gossip({
    { name = "Make this inn your home", gossip_option_id = 5 },
})
sg.handle_service_gossip("Set your Hearthstone to Goldshire")
mock.set_time(mock.get_time() + 30.0)
bridge.on_game_event("CONFIRM_BINDER", { "Innkeeper Farley" })
assert(sg.answer_bind_confirm() == false,
    "C4 FAIL: a selection older than the answer window must not confirm a later prompt")
print("  C4 PASS: stale selection does not answer a later prompt")

-- ============================================================================
-- C5: the coordinator's per-tick seam answers it (this is the live wiring)
-- ============================================================================
mock.reset()
mock.set_time(100.0)
set_gossip({
    { name = "Make this inn your home", gossip_option_id = 5 },
})
local c5_token = sg.handle_service_gossip("Set your Hearthstone to Goldshire")
assert(c5_token == "service:inn", "C5a FAIL: bind option not taken, got " .. tostring(c5_token))
mock._player = mock.create_player({ pos = {x=0, y=0, z=0} })
mock._input_calls = {}
bridge.on_game_event("CONFIRM_BINDER", { "Innkeeper Farley" })
local coordinator = require("quest_state/coordinator")
coordinator.update()
assert(count_calls("confirm_binder") == 1,
    "C5 FAIL: coordinator.update() must answer the bind prompt this plugin raised, got " ..
    tostring(count_calls("confirm_binder")))
print("  C5 PASS: coordinator per-tick seam answers the plugin's own bind prompt")

print("PASS test_confirm_inputs")
