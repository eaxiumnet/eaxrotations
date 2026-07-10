-- test_affliction_summon_felhunter.lua -- Affliction summon logic felhunter summon tests.
-- WHAT:  Affliction summon logic felhunter summon tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Protects against regressions in rotation logic and state handling.
-- SAFETY: Pure unit tests with mocked API context.

-- unit tests for affliction_sylvanas SummonFelhunter strategy.
-- Verifies: OOC-only, DS aura gate, execute calls try_cast with correct spell + target.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_eq, assert_false

local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_eq = function(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
end
setup_asserts()

local try_cast_calls = {}
_G.EaxRotations = {
    WarlockSpells = {
        SummonFelhunter = { ids = { 691 }, name = "SummonFelhunter" },
    },
    PLAYER_UNIT = "player",
    spell_action = function(tbl) return tbl end,
    log = function() end,
    spell_ready = function(spell, target, opts) return true end,
    try_cast = function(spell, target, label, opts)
        try_cast_calls[#try_cast_calls + 1] = { spell = spell, target = target, label = label, opts = opts }
        return true
    end,
    is_spell_learned = function(id) return id == 691 end,
    rotation_registry = { register = function() end },
}

-- Override pcall and require for shared modules so affliction_sylvanas loads
local orig_pcall = _G.pcall
_G.pcall = function(fn, path, ...)
    if type(path) == "string" and path:find("pet_manager") then return true, nil end
    if type(path) == "string" and path:find("tbc_data_sylvanas") then return true, { ITEMS = { potions = {} } } end
    if type(path) == "string" and path:find("izi_sdk") then return false, nil end
    if type(path) == "string" and path:find("active_fight_tracker_sylvanas") then return true, { find_undotted_target = function() return nil end } end
    return orig_pcall(fn, path, ...)
end
local orig_require = _G.require
_G.require = function(path)
    if type(path) == "string" and path:find("pet_manager") then return {} end
    if type(path) == "string" and path:find("tbc_data_sylvanas") then return { ITEMS = { potions = {} } } end
    if type(path) == "string" and path:find("izi_sdk") then return nil end
    if type(path) == "string" and path:find("active_fight_tracker_sylvanas") then return { find_undotted_target = function() return nil end } end
    return orig_require(path)
end

local result = dofile("EaxRotations/classes/warlock/affliction_sylvanas.lua")
assert_true(result, "affliction module should load")
local strategies = result.strategies
assert_true(strategies, "strategies table should load from result")

_G.require = orig_require
_G.pcall = orig_pcall

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then
            return strategies[i]
        end
    end
    error("strategy not found: " .. name)
end

-- ============================================================================
-- Test 1: SummonFelhunter strategy exists with matches and execute
-- ============================================================================

local felhunter = find_strategy("SummonFelhunter")
assert_true(type(felhunter.matches) == "function", "SummonFelhunter should have matches function")
assert_true(type(felhunter.execute) == "function", "SummonFelhunter should have execute function")

-- ============================================================================
-- Test 2: Fails when in combat
-- ============================================================================

assert_false(felhunter.matches({ in_combat = true }, { has_pet = false, has_demonic_sacrifice = false }),
    "should NOT match when in combat")

-- ============================================================================
-- Test 3: Fails when pet already active
-- ============================================================================

assert_false(felhunter.matches({ in_combat = false, has_valid_enemy_target = false }, { has_pet = true, has_demonic_sacrifice = false }),
    "should NOT match when pet already active")

-- ============================================================================
-- Test 4: Fails when DS aura active (regression: the loop bug fix)
-- ============================================================================

assert_false(felhunter.matches({ in_combat = false, has_valid_enemy_target = false }, { has_pet = false, has_demonic_sacrifice = true }),
    "should NOT match when Demonic Sacrifice aura active")

-- ============================================================================
-- Test 5: Matches when OOC, no pet, no DS, spell learned
-- ============================================================================

assert_true(felhunter.matches({ in_combat = false, has_valid_enemy_target = false }, { has_pet = false, has_demonic_sacrifice = false }),
    "should match when OOC, no pet, no DS, learned")

-- ============================================================================
-- Test 6: Execute calls try_cast with SummonFelhunter on self
-- ============================================================================

try_cast_calls = {}
local ok = felhunter.execute({})
assert_true(ok, "execute should return true")

local last_call = try_cast_calls[1]
assert_true(last_call ~= nil, "execute should call try_cast")
assert_true(last_call.spell == _G.EaxRotations.WarlockSpells.SummonFelhunter
    or (type(last_call.spell) == "table" and last_call.spell.name == "SummonFelhunter"),
    "execute should cast SummonFelhunter spell")
assert_eq(last_call.target, _G.EaxRotations.PLAYER_UNIT, "execute should target self")
assert_true(last_call.label and last_call.label:find("Summon Felhunter") ~= nil,
    "execute label should reference Summon Felhunter")

print("PASS test_affliction_summon_felhunter")
