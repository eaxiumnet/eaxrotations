-- test_burst_logic_integration.lua -- burst window integration tests.
-- WHAT:  burst window integration tests
-- WHEN:  During rotation test suite execution.
-- WHY:   End-to-end validation of multiple subsystems working together.
-- SAFETY: May require more setup; keep mocks lightweight.

-- ============================================================================
-- Test: Burst Logic Integration
-- ============================================================================
local NS = _G.EaxRotations or {}
_G.EaxRotations = NS

pcall(dofile, "EaxRotations/shared/burst_logic_sylvanas.lua")
local BL = _G.BurstLogic or {}

-- Test: bloodlust active -> burst
local ctx_bl = {
    in_combat = true,
    has_valid_enemy_target = true,
    combat_time = 10,
    ttd = 120,
    settings = { burst_on_bloodlust = true }
}
local result_bl = BL.should_auto_burst(ctx_bl, {
    is_bloodlust_active = function() return true end,
    is_drums_active = function() return false end,
})
assert(result_bl == true, "Should burst when bloodlust is active")
print("PASS burst_bloodlust_active")

-- Test: no bloodlust but timeout reached -> burst
local ctx_timeout = {
    in_combat = true,
    has_valid_enemy_target = true,
    combat_time = 50,
    ttd = 120,
    settings = { burst_on_bloodlust = true }
}
local result_timeout = BL.should_auto_burst(ctx_timeout, {
    is_bloodlust_active = function() return false end,
    is_drums_active = function() return false end,
})
assert(result_timeout == true, "Should burst after 45s timeout")
print("PASS burst_timeout")

-- Test: no valid enemy -> no burst
local ctx_no_enemy = {
    in_combat = true,
    has_valid_enemy_target = false,
    settings = { burst_on_bloodlust = true }
}
local result_no_enemy = BL.should_auto_burst(ctx_no_enemy, {})
assert(result_no_enemy == false, "Should not burst without valid enemy")
print("PASS burst_no_enemy")

-- Test: not in combat -> no burst
local ctx_no_combat = {
    in_combat = false,
    has_valid_enemy_target = true,
    settings = { burst_on_bloodlust = true }
}
local result_no_combat = BL.should_auto_burst(ctx_no_combat, {})
assert(result_no_combat == false, "Should not burst when not in combat")
print("PASS burst_no_combat")

print("PASS burst_logic_integration")
