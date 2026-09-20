-- quest_state_sylvanas.lua — retired loader (Phase 1 state-machine unification).
-- WHAT:  pass-through; returns the modular state machine (quest_state/coordinator).
-- WHEN:  only reached if something still requires the old monolith name.
-- WHY:   main.lua loads the coordinator directly now; this keeps the retired name
--        resolving for one commit so removing it cannot break an unknown caller.
-- SAFETY: owns no state — the coordinator holds the single shared state table.
-- Decision: DELETED in the next commit. Never add logic here.

local ok, coordinator = pcall(require, "quest_state/coordinator")
if ok and type(coordinator) == "table" then
    return coordinator
end

local c = rawget(_G, "core")
if c and type(c.log) == "function" then
    pcall(c.log, "EaxAutoQuester: retired quest_state_sylvanas loader could not reach " ..
        "quest_state/coordinator: " .. tostring(coordinator))
end

return {}
