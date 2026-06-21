-- RED test: verify Imp Machine Gun (imp_firebolt_pacing) strategy does NOT yet exist in Warlock specs.
-- This test asserts EXISTENCE → currently FAILS (RED) because the strategy hasn't been implemented.
-- After GREEN implementation (adding the strategy), this test will PASS.
--
-- Expected state fields when implemented:
--   state.pet_type_imp        — boolean, true when current pet is an Imp
--   state.pet_casting_firebolt — boolean, true when Imp is casting Firebolt
--   IMP_FIREBOLT_IDS           — table of Firebolt spell IDs (pet spells)
--
-- Specs tested: demonology, affliction, destruction

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_eq, assert_false
local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_eq = function(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
end
setup_asserts()

-- Track registry registrations
local registered_strategies = {}
local registered_names = {}

-- Mock NS
_G.EaxRotations = {
    WarlockSpells = {},
    spell_action = function(tbl) return tbl end,
    log = function() end,
    rotation_registry = {
        register = function(self, name, strategies, options)
            registered_names[#registered_names + 1] = name
            registered_strategies[name] = strategies
            self.playstyles = self.playstyles or {}
            self.playstyles[name] = strategies
            self.options = self.options or {}
            self.options[name] = options or {}
            return true
        end,
        playstyles = {},
        options = {},
    },
}

-- Helper to find a strategy by name in a strategies table
local function find_strategy(strategies, name)
    for i = 1, #strategies do
        if strategies[i].name == name then
            return strategies[i]
        end
    end
    return nil
end

-- ============================================================================
-- Test 1: Demonology — imp_firebolt_pacing should exist
-- ============================================================================

do
    -- Reset and load
    registered_names = {}
    registered_strategies = {}
    _G.EaxRotations.rotation_registry.playstyles = {}
    _G.EaxRotations.rotation_registry.options = {}

    local strategies = dofile("EaxRotations/classes/warlock/demonology_sylvanas.lua")
    assert_true(type(strategies) == "table", "demonology_sylvanas should return strategies table")

    -- Assert: imp_firebolt_pacing strategy MUST exist
    local strategy = find_strategy(strategies, "imp_firebolt_pacing")
    assert_true(strategy ~= nil, "demonology: imp_firebolt_pacing strategy should exist")
    assert_true(type(strategy.matches) == "function", "demonology: imp_firebolt_pacing should have a matches function")
    assert_true(type(strategy.execute) == "function", "demonology: imp_firebolt_pacing should have an execute function")

    -- Also verify the registry was called
    local registered_name = registered_names[1]
    assert_eq(registered_name, "demonology", "demonology should register as 'demonology'")
end

-- ============================================================================
-- Test 2: Affliction — imp_firebolt_pacing should exist
-- ============================================================================

do
    registered_names = {}
    registered_strategies = {}
    _G.EaxRotations.rotation_registry.playstyles = {}
    _G.EaxRotations.rotation_registry.options = {}

    local result = dofile("EaxRotations/classes/warlock/affliction_sylvanas.lua")
    assert_true(type(result) == "table", "affliction_sylvanas should return a table")
    local strategies = result.strategies
    assert_true(type(strategies) == "table", "affliction_sylvanas should return strategies table")

    -- Assert: imp_firebolt_pacing strategy MUST exist
    local strategy = find_strategy(strategies, "imp_firebolt_pacing")
    assert_true(strategy ~= nil, "affliction: imp_firebolt_pacing strategy should exist")
    assert_true(type(strategy.matches) == "function", "affliction: imp_firebolt_pacing should have a matches function")
    assert_true(type(strategy.execute) == "function", "affliction: imp_firebolt_pacing should have an execute function")

    -- Verify registry
    local registered_name = registered_names[1]
    assert_eq(registered_name, "affliction", "affliction should register as 'affliction'")
end

-- ============================================================================
-- Test 3: Destruction — imp_firebolt_pacing should exist
-- ============================================================================

do
    registered_names = {}
    registered_strategies = {}
    _G.EaxRotations.rotation_registry.playstyles = {}
    _G.EaxRotations.rotation_registry.options = {}

    local strategies = dofile("EaxRotations/classes/warlock/destruction_sylvanas.lua")
    assert_true(type(strategies) == "table", "destruction_sylvanas should return strategies table")

    -- Assert: imp_firebolt_pacing strategy MUST exist
    local strategy = find_strategy(strategies, "imp_firebolt_pacing")
    assert_true(strategy ~= nil, "destruction: imp_firebolt_pacing strategy should exist")
    assert_true(type(strategy.matches) == "function", "destruction: imp_firebolt_pacing should have a matches function")
    assert_true(type(strategy.execute) == "function", "destruction: imp_firebolt_pacing should have an execute function")

    -- Verify registry
    local registered_name = registered_names[1]
    assert_eq(registered_name, "destruction", "destruction should register as 'destruction'")
end

print("PASS test_warlock_imp_machine_gun_2026_06")
