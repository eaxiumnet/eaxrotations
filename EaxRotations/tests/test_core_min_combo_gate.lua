-- test_core_min_combo_gate.lua - Dispatcher min_combo gate contract test.
-- WHAT:  Proves NS.action_matches treats a nil context.combo_points as "read failed,
--        skip the gate" instead of collapsing it to 0 and blocking every finisher.
-- WHEN:  rotation suite / standalone.
-- WHY:   core_sylvanas.lua:6084 used `(context.combo_points or 0)`, so a failed CP
--        read (main_sylvanas.lua returns nil by design) rejected all min_combo
--        strategies (Rip, Ferocious Bite, Maim) BEFORE their matches() ran.
--        This was the first test to ever exercise NS.action_matches.
-- SAFETY: fully mocked NS/context; no engine, no real API calls.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/shared/?.lua;./?.lua;api/?.lua;.api/?.lua;"
    .. package.path

local all_ok = true

local function assert_eq(got, want, msg)
    if got ~= want then
        print("FAIL " .. tostring(msg) .. ": got " .. tostring(got) .. " want " .. tostring(want))
        all_ok = false
        return
    end
    print("PASS " .. tostring(msg))
end

_G.EaxRotations = _G.EaxRotations or {}

local load_ok, load_err = pcall(function()
    if not package.loaded["common/izi_sdk"] then
        package.loaded["common/izi_sdk"] = {}
    end
    dofile("EaxRotations/core_sylvanas.lua")
end)

if not load_ok then
    print("core dofile note: " .. tostring(load_err))
end

local NS = _G.EaxRotations

if type(NS.action_matches) ~= "function" then
    print("FAIL NS.action_matches is not a function - cannot test the gate")
    os.exit(1)
end

-- action_matches ends with `return NS.spell_ready(action.spell, ...)`; stub it true so
-- the gate chain is the ONLY thing that can return false. Removing this yields a false RED.
NS.spell_ready = function() return true end
NS.get_spell_id = function() return 1079 end -- Rip

-- Minimal action that reaches the min_combo gate untouched by any earlier gate:
-- no setting/min_interval/combat/hp/level/ttd/enemy_count, and requires_target=false
-- so the post-gate target checks do not interfere.
local function finisher(min_combo)
    return { name = "Rip", min_combo = min_combo, requires_target = false }
end

local function ctx(combo_points)
    return { combo_points = combo_points, settings = {}, in_combat = true }
end

-- S1: the reported bug. CP read failed (nil) but the player genuinely has points.
-- The gate must NOT block; the spec's own build_state CP reader decides instead.
assert_eq(NS.action_matches(ctx(nil), finisher(3)), true,
    "S1 nil context.combo_points does not block min_combo=3 finisher")

-- S2: a real zero must still block.
assert_eq(NS.action_matches(ctx(0), finisher(3)), false,
    "S2 real 0 combo points blocks min_combo=3 finisher")

-- S3: sufficient points pass.
assert_eq(NS.action_matches(ctx(3), finisher(3)), true,
    "S3 combo_points=3 passes min_combo=3 finisher")

-- S4: insufficient points block.
assert_eq(NS.action_matches(ctx(2), finisher(3)), false,
    "S4 combo_points=2 blocks min_combo=3 finisher")

-- S1b: nil must also pass the highest finisher requirement (Rip snapshot / bite trick).
assert_eq(NS.action_matches(ctx(nil), finisher(5)), true,
    "S1b nil context.combo_points does not block min_combo=5 finisher")

if all_ok then
    print("ALL PASS test_core_min_combo_gate")
else
    print("FAILURES in test_core_min_combo_gate")
    os.exit(1)
end
