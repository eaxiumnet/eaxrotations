-- leveling edge case unit tests.
-- Tests resilience against nil NS.get_local_player, pcall failures,
-- edge inputs, execute stability, and shared state hazards.
-- References Mage and Rogue patterns to cover all shared + per-class paths.

local EAXROTATIONS_DIR = "C:/newbot/scripts/EaxRotations"
if not package.path:find(EAXROTATIONS_DIR, 1, true) then
    package.path = package.path .. ";" .. EAXROTATIONS_DIR .. "/?.lua"
end

local passed = 0
local failed = 0
local assertions = 0

local function assert_true(v, label)
    assertions = assertions + 1
    if not v then error(label or "assert_true failed", 2) end
end

local function assert_false(v, label)
    assertions = assertions + 1
    if v then error(label or "assert_false failed: expected false", 2) end
end

local function assert_eq(a, b, label)
    assertions = assertions + 1
    if a ~= b then
        error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2)
    end
end

local function assert_nil(v, label)
    assertions = assertions + 1
    if v ~= nil then error(label or "assert_nil failed: expected nil got " .. tostring(v), 2) end
end

local function assert_not_nil(v, label)
    assertions = assertions + 1
    if v == nil then error(label or "assert_not_nil failed: expected non-nil", 2) end
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
-- Mock helpers (reusable across multiple module reloads)
-- ============================================================================

local MOCK_MAGE_SPELLS = {
    Frostbolt = { 27070 },
    FireBlast = { 27078 },
    Scorch = { 27080 },
    ArcaneMissiles = { 27075 },
    FrostNova = { 27088 },
    Blizzard = { 27085 },
    Polymorph = { 12826 },
    Counterspell = { 2139 },
    Evocation = { 12051 },
    IceBarrier = { 27134 },
    ManaShield = { 27142 },
    ArcaneIntellect = { 27126 },
    RemoveCurse = { 475 },
    Shoot = { 5019 },
}

--- Create a fresh mock environment. Returns (NS, core, mock_player, mock_target).
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

    core.input = {
        cast_target_spell = function(spell_id, target)
            return spell_id ~= nil and target ~= nil
        end,
    }

    local mock_state = {
        health = 8000,
        max_health = 10000,
        mana = 5000,
        max_mana = 10000,
        buffs = {},
        debuffs = {},
        is_casting = false,
        target_guid = "mock-target",
    }

    local mock_target = {
        is_valid = function() return true end,
        get_health = function() return 8000 end,
        get_max_health = function() return 10000 end,
        is_casting = function() return mock_state.is_casting end,
        is_alive = function() return true end,
        get_guid = function() return mock_state.target_guid end,
        get_distance = function(other) return 5 end,
        get_health_percentage = function() return 80 end,
    }

    local mock_player = {
        is_valid = function() return true end,
        get_health = function() return mock_state.health end,
        get_max_health = function() return mock_state.max_health end,
        get_mana = function() return mock_state.mana end,
        get_max_mana = function() return mock_state.max_mana end,
        has_buff = function(id)
            if not id then return false end
            local remains = mock_state.buffs[id]
            return remains ~= nil and remains > 0
        end,
        has_debuff = function(id) return false end,
        get_class = function() return 8 end,
        is_in_combat = function() return false end,
        get_target = function() return mock_target end,
        get_position = function() return { x = 0, y = 0, z = 0 } end,
    }

    NS.log = function() end
    NS.log_warning = function() end
    NS.spell_ready = function(spell_action, target, opts)
        if not spell_action then return false end
        return true
    end
    NS.spell_exists = function(spell_id) return true end
    NS.try_cast = function(spell_action, target, label)
        if not spell_action then return false end
        return true
    end
    NS.get_local_player = function() return mock_player end
    NS.get_target = function() return mock_target end
    NS.get_distance = function() return 10 end
    NS.debuff_remains = function(target, spell) return 0 end
    NS.buff_up = function(unit, buff_ids) return false end
    NS.buff_remains = function(unit, buff_ids) return 0 end

    -- rotation_registry mock that captures registrations
    NS.rotation_registry = {
        _registrations = {},
        register = function(self, key, strategies, opts)
            self._registrations[key] = { strategies = strategies, opts = opts }
        end,
        set_class_config = function(self, config) end,
    }

    NS.MageSpells = {}
    for k, v in pairs(MOCK_MAGE_SPELLS) do
        NS.MageSpells[k] = v
    end

    _G.core = core
    _G.EaxRotations = NS

    return NS, core, mock_player, mock_target, mock_state
end

--- Create a mock context with sensible defaults.
local function make_context(overrides)
    local ctx = {
        is_solo = false,
        is_leveling = true,
        in_combat = true,
        mana_pct = 80,
        hp = 100,
        enemies_count = 1,
        is_moving = false,
        me = {
            is_valid = function() return true end,
            get_health = function() return 10000 end,
            get_max_health = function() return 10000 end,
            has_buff = function(id) return false end,
            get_position = function() return { x = 0, y = 0, z = 0 } end,
        },
        target = {
            is_valid = function() return true end,
            get_health = function() return 8000 end,
            get_max_health = function() return 10000 end,
            is_casting = function() return false end,
            is_alive = function() return true end,
            get_guid = function() return "mock-target" end,
            get_distance = function(other) return 5 end,
            get_health_percentage = function() return 80 end,
        },
        pet = { guid = "mock-pet" },
        settings = {
            playstyle = "leveling",
            active_playstyle = "leveling",
            use_interrupt = true,
            leveling_wand_threshold = 30,
            leveling_polymorph_hp = 40,
            leveling_arcane_missiles_use = true,
            leveling_scorch_use = true,
            leveling_fire_blast_use = true,
        },
    }
    if overrides then
        for k, v in pairs(overrides) do
            ctx[k] = v
        end
    end
    return ctx
end

-- ============================================================================
-- Section 1: Edge cases on the shared leveling module
-- ============================================================================

print("\n--- Edge Cases: Shared Module ---\n")
local NS, core = build_mock_env()
local leveling = dofile("EaxRotations/shared/leveling_sylvanas.lua")
assert_not_nil(leveling, "shared module should load")

test("build_common_state: nil context does not crash and returns state as-is", function()
    local state = {}
    local result = leveling.build_common_state(nil, state)
    assert_true(result == state, "should return the state table (same identity)")
    -- Fields not set because function returned early
end)

test("build_common_state: nil state returns nil (pcall catches)", function()
    local ok, result = pcall(leveling.build_common_state, {in_combat = true}, nil)
    assert_true(ok, "should not throw")
end)

test("build_common_state: missing settings does not crash", function()
    local state = leveling.build_common_state({in_combat = true, settings = nil}, {})
    assert_eq(state.use_interrupt, true, "should default to true")
end)

test("build_common_state: settings.wand_learned does not crash when spell_exists is nil", function()
    local saved = NS.spell_exists
    NS.spell_exists = nil
    local state = leveling.build_common_state({in_combat = true, settings = {}}, {})
    assert_false(state.wand_learned, "wand_learned should be false when spell_exists is nil")
    NS.spell_exists = saved
end)

test("create_wand_matches: nil context handles gracefully", function()
    local wand_matches = leveling.create_wand_matches()
    assert_false(wand_matches(nil, {}), "nil context should return false")
    assert_false(wand_matches(nil, nil), "both nil should return false")
end)

test("create_interrupt_matches: is_casting throws error gracefully", function()
    local int_matches = leveling.create_interrupt_matches("kick_ready")
    local bad_target = { is_casting = function() error("pcall catch test") end }
    local state = { target = bad_target, use_interrupt = true, kick_ready = true }
    assert_false(int_matches({}, state), "throwing is_casting should return false")
end)

test("create_interrupt_matches: target without is_catching method", function()
    local int_matches = leveling.create_interrupt_matches("kick_ready")
    local state = { target = {guid = "missing_methods"}, use_interrupt = true, kick_ready = true }
    local ok, result = pcall(int_matches, {}, state)
    assert_true(ok, "should not throw on missing method")
end)

test("dot_needs_refresh: nil debuff_remains does not crash", function()
    local saved = NS.debuff_remains
    NS.debuff_remains = nil
    local ok, result = pcall(leveling.dot_needs_refresh, {guid="t"}, {100}, 4)
    assert_true(ok, "should not throw when debuff_remains is nil")
    assert_true(result, "should return true (default remains=0 <= threshold)")
    NS.debuff_remains = saved
end)

test("dot_needs_refresh: debuff_remains throws error gracefully", function()
    local saved = NS.debuff_remains
    NS.debuff_remains = function() error("boom") end
    local ok, result = pcall(leveling.dot_needs_refresh, {guid="t"}, {100}, 4)
    assert_true(ok, "should not throw")
    NS.debuff_remains = saved
end)

test("create_aoe_matches: nil state.enemies defaults to 0", function()
    local aoe = leveling.create_aoe_matches(3)
    assert_false(aoe({}, { target = {}, in_combat = true, enemies = nil, is_moving = false }), "nil enemies should be < 3")
end)

test("create_context_guard: nil settings does not crash", function()
    local guard = leveling.create_context_guard()
    assert_false(guard({is_solo = false, settings = nil}), "nil settings should return false")
end)

-- ============================================================================
-- Section 2: Edge cases on Mage leveling rotation (representative class)
-- ============================================================================

print("\n--- Edge Cases: Mage Leveling Rotation ---\n")
local NS2, core2, mock_player2, mock_target2, mock_state2 = build_mock_env()
local ok2, mage_module = pcall(dofile, "EaxRotations/classes/mage/leveling_sylvanas.lua")
if not ok2 then
    error("Failed to load Mage leveling module: " .. tostring(mage_module))
end
local reg2 = NS2.rotation_registry._registrations["leveling"]
if not reg2 then
    error("Mage leveling: should register as 'leveling' in rotation_registry")
end
local mage_strategies = reg2.strategies
local mage_get_state = reg2.opts.get_state
print("Loaded " .. tostring(#mage_strategies) .. " Mage strategies")

-- Test: build_state with nil context.me (nil NS.get_local_player equivalent)
test("mage build_state: nil context.me does not crash", function()
    local ctx = make_context({
        me = nil,
        target = { is_valid = function() return true end },
    })
    local state = mage_get_state(ctx)
    assert_not_nil(state, "should return state table")
    assert_false(state.has_ai, "has_ai should be false without me")
    assert_false(state.has_molten_armor, "has_molten_armor should be false without me")
    assert_false(state.has_mana_shield, "has_mana_shield should be false without me")
end)

test("mage build_state: nil context returns nil", function()
    assert_nil(mage_get_state(nil), "nil context should return nil")
end)

test("mage build_state: context.me with missing has_buff method", function()
    local ctx = make_context({
        me = { is_valid = function() return true end },  -- no has_buff
    })
    local ok, state = pcall(mage_get_state, ctx)
    assert_true(ok, "should not throw")
    assert_false(state.has_ai, "has_ai should be false (buff_up on nil)")
end)

test("mage build_state: spell_ready returning nil does not crash", function()
    local saved = NS2.spell_ready
    NS2.spell_ready = function() return nil end
    local ctx = make_context()
    local ok, state = pcall(mage_get_state, ctx)
    assert_true(ok, "should not throw when spell_ready returns nil")
    assert_false(state.frostbolt_ready, "frostbolt_ready should be false")
    NS2.spell_ready = saved
end)

test("mage build_state: spell_ready throwing error does not crash", function()
    local saved = NS2.spell_ready
    NS2.spell_ready = function() error("spell_ready threw") end
    local ctx = make_context()
    local ok, state = pcall(mage_get_state, ctx)
    assert_true(ok, "should not throw")
    -- All spell readiness fields should be false
    assert_false(state.frostbolt_ready, "frostbolt_ready should be false")
    assert_false(state.couterspell_ready or false, "counterspell_ready should be false")
    NS2.spell_ready = saved
end)

test("mage build_state: spell_exists throwing error does not crash", function()
    local saved = NS2.spell_exists
    NS2.spell_exists = function() error("spell_exists threw") end
    local ctx = make_context()
    local ok, state = pcall(mage_get_state, ctx)
    assert_true(ok, "should not throw")
    assert_false(state.wand_learned, "wand_learned should be false")
    NS2.spell_exists = saved
end)

test("mage build_state: shared leveling_state table - no stale state", function()
    -- Mage uses a module-level 'leveling_state' table.
    -- First call: set many fields
    local ctx1 = make_context({in_combat = true, mana_pct = 80, hp = 100, enemies_count = 5})
    local state1 = mage_get_state(ctx1)
    assert_eq(state1.mana_pct, 80, "first call mana_pct")
    assert_eq(state1.enemies, 5, "first call enemies")
    assert_eq(state1.in_combat, true, "first call in_combat")

    -- Second call: with different values, should fully refresh
    local ctx2 = make_context({in_combat = false, mana_pct = 30, hp = 50, enemies_count = 0})
    local state2 = mage_get_state(ctx2)
    assert_eq(state2.mana_pct, 30, "second call mana_pct refreshed")
    assert_eq(state2.enemies, 0, "second call enemies refreshed")
    assert_eq(state2.in_combat, false, "second call in_combat refreshed")
    -- Verify no stale data from first call
    assert_eq(state2.hp, 50, "hp should be from second call, not first")
end)

-- Test: context.target methods that throw
test("mage match: target:is_casting error caught by pcall", function()
    local ctx = make_context({
        target = {
            is_valid = function() return true end,
            is_casting = function() error("is_casting threw") end,
            get_health = function() return 8000 end,
            get_max_health = function() return 10000 end,
            get_guid = function() return "mock-target" end,
            get_distance = function() return 5 end,
            get_health_percentage = function() return 80 end,
        }
    })
    local state = mage_get_state(ctx)
    state.counterspell_ready = true
    state.use_interrupt = true
    state.target = ctx.target
    -- counterspell_matches uses pcall on target:is_casting
    local ok, result = pcall(mage_strategies[3].matches, ctx, state)
    assert_true(ok, "should not throw")
    assert_false(result, "should return false when is_casting throws")
end)

test("mage match: target missing get_health_percentage (nil target in state)", function()
    local ctx = make_context({target = nil})
    local state = mage_get_state(ctx)
    state.polymorph_ready = true
    state.target = nil
    -- polymorph_matches checks state.target, should return false
    local ok, result = pcall(mage_strategies[2].matches, ctx, state)
    assert_true(ok, "no target should not throw")
    assert_false(result, "should return false without target")
end)

test("mage match: target:get_distance throws error", function()
    local ctx = make_context({
        target = {
            is_valid = function() return true end,
            is_casting = function() return false end,
            get_health = function() return 8000 end,
            get_max_health = function() return 10000 end,
            get_guid = function() return "mock-target" end,
            get_distance = function() error("get_distance threw") end,
            get_health_percentage = function() return 80 end,
        }
    })
    local state = mage_get_state(ctx)
    state.frost_nova_ready = true
    state.in_combat = true
    state.target = ctx.target
    -- frost_nova_matches calls target:get_distance with pcall
    local ok, result = pcall(mage_strategies[6].matches, ctx, state)
    assert_true(ok, "should not throw")
    assert_false(result, "should return false when get_distance throws")
end)

test("mage match: nil context.me in frost_nova (me check)", function()
    -- Lua pairs() skips nil, so set me explicitly after make_context
    local ctx = make_context({
        in_combat = true,
        target = {
            is_valid = function() return true end,
            is_casting = function() return false end,
            get_health = function() return 8000 end,
            get_max_health = function() return 10000 end,
            get_guid = function() return "mock-target" end,
            get_distance = function(other) return 3 end,
            get_health_percentage = function() return 80 end,
        }
    })
    ctx.me = nil  -- frost_nova_matches checks context.me
    local state = mage_get_state(ctx)
    state.frost_nova_ready = true
    state.in_combat = true
    state.target = ctx.target
    local ok, result = pcall(mage_strategies[6].matches, ctx, state)
    assert_true(ok, "nil context.me should not throw")
    assert_false(result, "should return false without me")
end)

-- Test: Edge input values
test("mage match: mana_pct extremes (0 and 100)", function()
    -- Mana 0: wand should match (below 30 threshold)
    local ctx0 = make_context({mana_pct = 0})
    local state0 = mage_get_state(ctx0)
    state0.wand_threshold = 30
    state0.wand_learned = true
    assert_true(mage_strategies[13].matches(ctx0, state0), "wand matches at mana_pct 0")

    -- Mana 100: wand should not match
    local ctx100 = make_context({mana_pct = 100})
    local state100 = mage_get_state(ctx100)
    state100.wand_threshold = 30
    state100.wand_learned = true
    assert_false(mage_strategies[13].matches(ctx100, state100), "wand does not match at mana_pct 100")

    -- Mana exactly at threshold: should not match (>=)
    local ctx30 = make_context({mana_pct = 30})
    local state30 = mage_get_state(ctx30)
    state30.wand_threshold = 30
    state30.wand_learned = true
    assert_false(mage_strategies[13].matches(ctx30, state30), "wand does not match at mana_pct == threshold")
end)

test("mage match: enemies_count extremes (0, large)", function()
    -- 0 enemies: blizzard should not match
    local ctx0 = make_context({enemies_count = 0})
    local state0 = mage_get_state(ctx0)
    state0.blizzard_ready = true
    assert_false(mage_strategies[7].matches(ctx0, state0), "blizzard does not match with 0 enemies")
end)

test("mage match: hp extremes (0, 100)", function()
    -- HP 0: mana shield should match (0 < 40)
    local ctx0 = make_context({hp = 0})
    local state0 = mage_get_state(ctx0)
    state0.mana_shield_ready = true
    state0.hp = 0
    state0.has_mana_shield = false
    assert_true(mage_strategies[4].matches(ctx0, state0), "mana shield matches at hp 0")

    -- HP 100: mana shield should not match
    local ctx100 = make_context({hp = 100})
    local state100 = mage_get_state(ctx100)
    state100.mana_shield_ready = true
    state100.hp = 100
    state100.has_mana_shield = false
    assert_false(mage_strategies[4].matches(ctx100, state100), "mana shield does not match at hp 100")
end)

-- ============================================================================
-- Section 3: Execute function resilience
-- ============================================================================

print("\n--- Edge Cases: Execute Function Resilience ---\n")

test("mage execute: all strategies handle nil context gracefully", function()
    for i, s in ipairs(mage_strategies) do
        local ok, result = pcall(s.execute, nil)
        assert_true(ok, "strategy[" .. i .. "] (" .. s.name .. ") execute(nil) should not throw")
    end
end)

test("mage execute: all strategies handle no args gracefully", function()
    for i, s in ipairs(mage_strategies) do
        local ok, result = pcall(s.execute)
        assert_true(ok, "strategy[" .. i .. "] (" .. s.name .. ") execute() should not throw")
    end
end)

test("mage execute: wand handles nil context.target", function()
    local ok, result = pcall(mage_strategies[13].execute, {target = nil})
    assert_true(ok, "execute with nil target should not throw")
end)

test("mage execute: wand handles nil context entirely", function()
    local ok, result = pcall(mage_strategies[13].execute, nil)
    assert_true(ok, "execute with nil context should not throw")
end)

test("mage execute: all strategies work when NS.try_cast is nil", function()
    local saved = NS2.try_cast
    NS2.try_cast = nil
    for i, s in ipairs(mage_strategies) do
        -- Skip wand (strategy 13) which uses core.input, not NS.try_cast
        if s.name ~= "Wand" and s.name ~= "FrostNova" then
            local ok, result = pcall(s.execute, make_context())
            assert_true(ok, "strategy[" .. i .. "] (" .. s.name .. ") should not throw when NS.try_cast is nil")
        end
    end
    NS2.try_cast = saved
end)

test("mage execute: wand works when core.input is nil", function()
    local saved = _G.core.input
    _G.core.input = nil
    local ok, result = pcall(mage_strategies[13].execute, make_context())
    assert_true(ok, "wand execute should not throw when core.input is nil")
    _G.core.input = saved
end)

test("mage execute: frost_nova works when NS.try_cast is nil", function()
    local saved = NS2.try_cast
    NS2.try_cast = nil
    local ok, result = pcall(mage_strategies[6].execute)
    assert_true(ok, "frost_nova execute should not throw when NS.try_cast is nil")
    NS2.try_cast = saved
end)

test("mage execute: rotation cycle with all nil NS APIs", function()
    -- Worst-case scenario: every NS API returns nil
    local saved_spell_ready = NS2.spell_ready
    local saved_try_cast = NS2.try_cast
    local saved_spell_exists = NS2.spell_exists
    local saved_buff_up = NS2.buff_up
    local saved_debuff_remains = NS2.debuff_remains

    NS2.spell_ready = nil
    NS2.try_cast = nil
    NS2.spell_exists = nil
    NS2.buff_up = nil
    NS2.debuff_remains = nil

    local ctx = make_context({in_combat = true, mana_pct = 80, hp = 100})
    local state = mage_get_state(ctx)
    assert_not_nil(state, "state should build even with nil APIs")

    for i, s in ipairs(mage_strategies) do
        local ok_match, matched = pcall(s.matches, ctx, state)
        assert_true(ok_match, "strategy[" .. i .. "] matches should not throw with nil APIs")

        local ok_exec, executed = pcall(s.execute, ctx)
        assert_true(ok_exec, "strategy[" .. i .. "] execute should not throw with nil APIs")
    end

    NS2.spell_ready = saved_spell_ready
    NS2.try_cast = saved_try_cast
    NS2.spell_exists = saved_spell_exists
    NS2.buff_up = saved_buff_up
    NS2.debuff_remains = saved_debuff_remains
end)

-- ============================================================================
-- Section 4: Edge cases on Rogue leveling (different class patterns)
-- ============================================================================

print("\n--- Edge Cases: Rogue Leveling Rotation ---\n")
-- Need fresh NS because rogue uses different spell tables
local NS3, core3, mock_player3, mock_target3, mock_state3 = build_mock_env()
-- Hijack: replace MageSpells with RogueSpells
local MOCK_ROGUE_SPELLS = {
    SinisterStrike = { 1752 },
    Eviscerate = { 2098 },
    SliceAndDice = { 5171 },
    Rupture = { 1943 },
    Garrote = { 863 },
    Kick = { 1766 },
    Gouge = { 1776 },
    Evasion = { 5277 },
    Sprint = { 2983 },
    BladeFlurry = { 13877 },
    AdrenalineRush = { 13750 },
    ColdBlood = { 14177 },
    Vanish = { 1856 },
    Stealth = { 1784 },
    Sap = { 6770 },
    Blind = { 2094 },
    ExposeArmor = { 8647 },
}
NS3.MageSpells = nil
NS3.RogueSpells = {}
for k, v in pairs(MOCK_ROGUE_SPELLS) do
    NS3.RogueSpells[k] = v
end
-- Also needs rogue-specific fields
NS3.combo_points = 0
NS3.energy = 100
NS3.buff_up = function(unit, buff_ids) return false end
NS3.debuff_stacks = function(target, spell) return 0 end

-- Load rogue module in fresh env
local ok3, rogue_module = pcall(dofile, "EaxRotations/classes/rogue/leveling_sylvanas.lua")
if not ok3 then
    error("Failed to load Rogue leveling module: " .. tostring(rogue_module))
end
local reg3 = NS3.rotation_registry._registrations["leveling"]
if not reg3 then
    error("Rogue leveling: should register as 'leveling'")
end
local rogue_strategies = reg3.strategies
local rogue_get_state = reg3.opts.get_state
print("Loaded " .. tostring(#rogue_strategies) .. " Rogue strategies")

test("rogue build_state: nil context.me does not crash", function()
    local ctx = make_context({me = nil})
    local state = rogue_get_state(ctx)
    assert_not_nil(state, "should return state table")
    -- Rogue checks me:has_buff for slice_and_dice
    assert_false(state.has_slice_and_dice or false, "default no snd buff")
end)

test("rogue build_state: nil context returns nil", function()
    assert_nil(rogue_get_state(nil), "nil context should return nil")
end)

test("rogue build_state: missing context fields use defaults", function()
    local ctx = {
        is_solo = false,
        is_leveling = true,
        me = { is_valid = function() return true end, has_buff = function() return false end, get_health = function() return 10000 end, get_max_health = function() return 10000 end, get_power = function() return 100 end },
        target = { is_valid = function() return true end, get_health = function() return 8000 end, get_max_health = function() return 10000 end, is_casting = function() return false end, is_alive = function() return true end, get_guid = function() return "mock-target" end, get_distance = function() return 5 end, get_health_percentage = function() return 80 end },
        settings = {},
    }
    local state = rogue_get_state(ctx)
    assert_not_nil(state, "should return a table")
    assert_eq(state.hp, 100, "default hp = 100")
    assert_eq(state.mana_pct, 100, "default mana_pct = 100")
    assert_eq(state.enemies, 0, "default enemies = 0")
    assert_false(state.is_moving, "default is_moving = false")
    assert_false(state.in_combat, "default in_combat = false")
end)

test("rogue spell_ready: nil spell_ready does not crash build_state", function()
    local saved = NS3.spell_ready
    NS3.spell_ready = nil
    local ctx = make_context()
    local ok, state = pcall(rogue_get_state, ctx)
    assert_true(ok, "should not throw")
    assert_false(state.sinister_strike_ready, "should default to false")
    NS3.spell_ready = saved
end)

test("rogue match: nil state.target for combat abilities", function()
    local ctx = make_context({target = nil})
    local state = rogue_get_state(ctx)
    state.target = nil
    for i = 2, 13 do  -- Skip Stealth (OOC, doesn't need target)
        local ok, result = pcall(rogue_strategies[i].matches, ctx, state)
        assert_true(ok, "strategy[" .. i .. "] should not throw with nil target")
    end
end)

test("rogue execute: all strategies handle no args", function()
    for i, s in ipairs(rogue_strategies) do
        local ok, result = pcall(s.execute)
        assert_true(ok, "strategy[" .. i .. "] (" .. s.name .. ") execute() should not throw")
    end
end)

test("rogue execute: NS.try_cast nil for all execute functions", function()
    local saved = NS3.try_cast
    NS3.try_cast = nil
    for i, s in ipairs(rogue_strategies) do
        local ok, result = pcall(s.execute, make_context())
        assert_true(ok, "strategy[" .. i .. "] (" .. s.name .. ") should not throw when NS.try_cast is nil")
    end
    NS3.try_cast = saved
end)

test("rogue match: extreme combo points (0 and 5)", function()
    -- 0 CP: sinister strike should match (0 < 5)
    NS3.combo_points = 0
    local state0 = rogue_get_state(make_context())
    state0.sinister_strike_ready = true
    state0.combo_points = 0
    assert_true(rogue_strategies[13].matches(make_context(), state0), "sinister strike matches at 0 CP")

    -- 5 CP: eviscerate should match
    NS3.combo_points = 5
    local state5 = rogue_get_state(make_context())
    state5.eviscerate_ready = true
    state5.combo_points = 5
    assert_true(rogue_strategies[12].matches(make_context(), state5), "eviscerate matches at 5 CP")

    -- 5 CP: sinister strike should NOT match
    state5.sinister_strike_ready = true
    assert_false(rogue_strategies[13].matches(make_context(), state5), "sinister strike does not match at 5 CP")
end)

test("rogue match: debuff_remains throws error in rupture", function()
    local saved = NS3.debuff_remains
    NS3.debuff_remains = function() error("debuff_remains threw") end
    local state = rogue_get_state(make_context())
    state.rupture_ready = true
    state.combo_points = 3
    local ok, result = pcall(rogue_strategies[10].matches, make_context(), state)
    assert_true(ok, "rupture should not throw")
    NS3.debuff_remains = saved
end)

test("rogue match: debuff_stacks throws error in expose_armor", function()
    local saved = NS3.debuff_stacks
    NS3.debuff_stacks = function() error("debuff_stacks threw") end
    local state = rogue_get_state(make_context())
    state.expose_armor_ready = true
    state.combo_points = 3
    local ok, result = pcall(rogue_strategies[11].matches, make_context(), state)
    assert_true(ok, "expose_armor should not throw")
    NS3.debuff_stacks = saved
end)

test("rogue match: nil NS.buff_up for slice_and_dice", function()
    local saved = NS3.buff_up
    NS3.buff_up = nil
    local state = rogue_get_state(make_context())
    state.slice_and_dice_ready = true
    state.has_slice_and_dice = false
    state.combo_points = 2
    local ok, result = pcall(rogue_strategies[9].matches, make_context(), state)
    assert_true(ok, "slice_and_dice should not throw")
    NS3.buff_up = saved
end)

-- ============================================================================
-- Section 5: Full rotation resilience (all classes via shared patterns)
-- ============================================================================

print("\n--- Edge Cases: Full Rotation Resilience ---\n")

test("full rotation: all nil NS APIs + nil context + nil state = no crash", function()
    -- This is the ultimate stress test: everything is nil
    local ctx = make_context({
        me = nil,
        target = nil,
        settings = nil,
    })
    local state = mage_get_state(ctx)
    for i, s in ipairs(mage_strategies) do
        local ok1, _ = pcall(s.matches, nil, nil)
        assert_true(ok1, "strategy[" .. i .. "] matches(nil, nil) should not throw")
        local ok2, _ = pcall(s.matches, ctx, nil)
        assert_true(ok2, "strategy[" .. i .. "] matches(ctx, nil) should not throw")
        local ok3, _ = pcall(s.matches, nil, state)
        assert_true(ok3, "strategy[" .. i .. "] matches(nil, state) should not throw")
        local ok4, _ = pcall(s.execute, nil)
        assert_true(ok4, "strategy[" .. i .. "] execute(nil) should not throw")
    end
end)

test("full rotation: rapid fire cycle (100 iterations) no state leak", function()
    -- Simulate rapid rotation cycles to catch state mutation bugs
    local ctx = make_context({in_combat = true, mana_pct = 80, hp = 100, enemies_count = 1})
    for iter = 1, 100 do
        local state = mage_get_state(ctx)
        for i, s in ipairs(mage_strategies) do
            local ok1, _ = pcall(s.matches, ctx, state)
            assert_true(ok1, "strategy[" .. i .. "] matches threw at iteration " .. iter)
            local ok2, _ = pcall(s.execute, ctx)
            assert_true(ok2, "strategy[" .. i .. "] execute threw at iteration " .. iter)
        end
        -- Alternate context to simulate state changes
        if iter % 2 == 0 then
            ctx.in_combat = false
        else
            ctx.in_combat = true
        end
        ctx.mana_pct = iter % 100
    end
end)

-- ============================================================================
-- Summary
-- ============================================================================

print(string.format("\n=== Leveling Edge Case Tests: %d passed, %d failed (%d assertions) ===\n", passed, failed, assertions))
if failed > 0 then
    error(string.format("Some tests FAILED (%d failures)", failed))
else
    print("All leveling edge case tests passed!")
end
