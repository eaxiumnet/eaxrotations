-- test_warrior_leveling_vanilla_spells.lua
-- WHAT:  verifies the Classic (vanilla) Warrior leveling rotation includes
--        BerserkerRage strategy and its match function behaves correctly.
-- WHEN:  run as standalone test or via run_leveling_tests.lua.
-- WHY:   BerserkerRage (18499) was missing from the vanilla leveling rotation
--        despite being a valid Classic spell used in arms/fury/prot vanilla specs.
-- SAFETY: pure mock-based; no engine API calls.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local passed = 0
local failed = 0

local function assert_true(v, label)
    if not v then error(label or "assert_true failed", 2) end
end

local function assert_false(v, label)
    if v then error(label or "assert_false failed: expected false", 2) end
end

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("  PASS: " .. name)
    else
        failed = failed + 1
        print("  FAIL: " .. name .. " -- " .. tostring(err))
    end
end

-- ============================================================================
-- Mock environment
-- ============================================================================

local MOCK_SPELLS = {
    Charge = { 100 }, Rend = { 772 }, HeroicStrike = { 78 },
    Overpower = { 7384 }, ThunderClap = { 6343 }, DemoralizingShout = { 1160 },
    Execute = { 5308 }, ShieldBash = { 72 }, BattleShout = { 6673 },
    Bloodrage = { 2687 }, BerserkerRage = { 18499 }, Cleave = { 845 },
    Whirlwind = { 1680 }, SweepingStrikes = { 12328 }, MortalStrike = { 12294 },
    SunderArmor = { 7386 }, Hamstring = { 1715 }, Slam = { 1464 },
    Disarm = { 676 }, DefensiveStance = { 71 }, ShieldWall = { 871 },
    IntimidatingShout = { 5246 },
}

local function build_mock_env()
    local NS = {}
    local core = {}
    core.time = function() return 100 end
    core.game_time = function() return 100000 end
    core.spell_book = {
        get_spell_cooldown = function() return 0 end,
        get_global_cooldown = function() return 0 end,
        is_spell_learned = function() return true end,
    }
    core.input = { cast_target_spell = function() return true end }

    NS.log = function() end
    NS.log_warning = function() end
    NS.spell_ready = function(spell) return spell ~= nil end
    NS.spell_exists = function() return true end
    NS.try_cast = function(spell) return spell ~= nil end
    NS.is_spell_learned = function() return true end

    local mock_player = {
        is_valid = function() return true end,
        is_alive = function() return true end,
        is_in_combat = function() return true end,
        get_health = function() return 8000 end,
        get_max_health = function() return 10000 end,
        get_health_percentage = function() return 80 end,
        get_mana = function() return 5000 end,
        get_max_mana = function() return 10000 end,
        get_mana_percentage = function() return 50 end,
        get_power = function() return 50 end,
        has_buff = function() return false end,
        get_position = function() return { x = 0, y = 0, z = 0 } end,
    }
    local mock_target = {
        is_valid = function() return true end,
        is_alive = function() return true end,
        is_casting = function() return false end,
        get_health = function() return 5000 end,
        get_max_health = function() return 10000 end,
        get_health_percentage = function() return 50 end,
        get_guid = function() return "mock-target" end,
        get_class = function() return 1 end,
    }

    NS.GetPlayer = function() return mock_player end
    NS.get_local_player = function() return mock_player end
    NS.get_target = function() return mock_target end
    NS.get_distance = function() return 10 end
    NS.debuff_remains = function() return 0 end
    NS.buff_remains = function() return 0 end
    NS.buff_up = function() return false end
    NS.debuff_stacks = function() return 0 end
    NS.POWER_RAGE = 1

    NS.rotation_registry = {
        _registrations = {},
        register = function(self, name, strategies, opts)
            self._registrations[name] = { strategies = strategies, opts = opts }
        end,
    }

    NS.WarriorSpells = {}
    for k, v in pairs(MOCK_SPELLS) do NS.WarriorSpells[k] = v end

    _G.core = core

-- ============================================================================
-- Load the vanilla Warrior leveling module
-- ============================================================================

local NS = build_mock_env()
local ok, module = pcall(dofile, "EaxRotations/classes/warrior/leveling_vanilla.lua")
if not ok then
    error("Failed to load vanilla Warrior leveling module: " .. tostring(module))
end
if not module or type(module) ~= "table" then
    error("Vanilla Warrior leveling module should return a table")
end

local reg = NS.rotation_registry._registrations["leveling"]
if not reg then
    error("Vanilla Warrior leveling module should register as 'leveling'")
end
local strategies = reg.strategies
local get_state = reg.opts.get_state

local function find_strategy(name)
    for i, s in ipairs(strategies) do
        if s.name == name then return s, i end
    end
    return nil
end

local function make_context(overrides)
    local ctx = {
        is_solo = false, is_leveling = true, in_combat = true,
        hp = 100, enemies_count = 1, is_moving = false,
        me = NS.GetPlayer(), target = NS.get_target(), settings = {},
    }
    for k, v in pairs(overrides or {}) do ctx[k] = v end
    return ctx
end

print("=== Warrior Vanilla Leveling Spell Tests ===")
print("Loaded " .. tostring(#strategies) .. " strategies")

-- ============================================================================
-- Tests: BerserkerRage strategy exists
-- ============================================================================

test("BerserkerRage strategy exists in vanilla leveling", function()
    local s = find_strategy("BerserkerRage")
    assert_true(s ~= nil, "BerserkerRage strategy should exist")
    assert_true(type(s.matches) == "function", "matches should be a function")
    assert_true(type(s.execute) == "function", "execute should be a function")
end)

test("BerserkerRage: state field berserker_rage_ready is set", function()
    local ctx = make_context()
    local state = get_state(ctx)
    assert_true(state.berserker_rage_ready ~= nil, "berserker_rage_ready should be set")
end)

test("BerserkerRage: 2+ enemies in combat -> match", function()
    local ctx = make_context({enemies_count = 2})
    local state = get_state(ctx)
    state.berserker_rage_ready = true
    state.enemies = 2
    state.in_combat = true
    local s = find_strategy("BerserkerRage")
    assert_true(s.matches(ctx, state), "2 enemies in combat should match")
end)

test("BerserkerRage: 1 enemy -> no match", function()
    local ctx = make_context({enemies_count = 1})
    local state = get_state(ctx)
    state.berserker_rage_ready = true
    state.enemies = 1
    state.in_combat = true
    local s = find_strategy("BerserkerRage")
    assert_false(s.matches(ctx, state), "1 enemy should not match (< 2)")
end)

test("BerserkerRage: not ready -> no match", function()
    local ctx = make_context({enemies_count = 3})
    local state = get_state(ctx)
    state.berserker_rage_ready = false
    state.enemies = 3
    state.in_combat = true
    local s = find_strategy("BerserkerRage")
    assert_false(s.matches(ctx, state), "not ready should not match")
end)

test("BerserkerRage: out of combat -> no match", function()
    local ctx = make_context({enemies_count = 3})
    local state = get_state(ctx)
    state.berserker_rage_ready = true
    state.enemies = 3
    state.in_combat = false
    local s = find_strategy("BerserkerRage")
    assert_false(s.matches(ctx, state), "OOC should not match")
end)

test("BerserkerRage: nil state -> no match", function()
    local s = find_strategy("BerserkerRage")
    assert_false(s.matches(make_context(), nil), "nil state should not match")
end)

test("BerserkerRage: execute calls try_cast", function()
    local cast_called = false
    local saved = NS.try_cast
    NS.try_cast = function(spell, target, label)
        cast_called = true
        assert_true(spell == MOCK_SPELLS.BerserkerRage, "should cast BerserkerRage")
        return true
    end
    local s = find_strategy("BerserkerRage")
    local result = s.execute(make_context())
    assert_true(cast_called, "try_cast should be called")
    assert_true(result, "execute should return true")
    NS.try_cast = saved
end)

-- ============================================================================
-- Tests: dead code removal verification
-- ============================================================================

test("No 'if false then' dead code in vanilla leveling file", function()
    local file = io.open("EaxRotations/classes/warrior/leveling_vanilla.lua", "r")
    if not file then error("Could not open vanilla leveling file") end
    local content = file:read("*a")
    file:close()
    local count = select(2, content:gsub("if false then", ""))
    assert_true(count == 0, "should have 0 'if false then' (found " .. tostring(count) .. ")")
end)

test("No 'Scanner marker' dead code in vanilla leveling file", function()
    local file = io.open("EaxRotations/classes/warrior/leveling_vanilla.lua", "r")
    if not file then error("Could not open vanilla leveling file") end
    local content = file:read("*a")
    file:close()
    local count = select(2, content:gsub("Scanner marker", ""))
    assert_true(count == 0, "should have 0 'Scanner marker' (found " .. tostring(count) .. ")")
end)

-- ============================================================================
-- Summary
-- ============================================================================

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then error("test_warrior_leveling_vanilla_spells failed", 0) end

    _G.EaxRotations = NS
    return NS, core, mock_player, mock_target
end
