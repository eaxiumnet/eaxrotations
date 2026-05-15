-- Unit tests for Druid leveling rotation
-- Tests build_state, all 12 match functions, strategy ordering,
-- helper functions, and edge case handling

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
-- Mock environment builder
-- ============================================================================

local MOCK_DRUID_SPELLS = {
    MarkOfTheWild = { 26991 },
    Thorns = { 26992 },
    Moonfire = { 26988 },
    Wrath = { 26985 },
    Starfire = { 26986 },
    InsectSwarm = { 26989 },
    Hurricane = { 27000 },
    Rejuvenation = { 26982 },
    HealingTouch = { 26979 },
    Barkskin = { 27007 },
    EntanglingRoots = { 26990 },
    NaturesGrasp = { 26994 },
    FaerieFire = { 26993 },
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

    --- Shared state for mock player/target
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
        get_class = function() return 11 end,
        is_in_combat = function() return false end,
        get_target = function() return mock_target end,
        get_position = function() return { x = 0, y = 0, z = 0 } end,
    }

    NS.log = function() end
    NS.log_warning = function() end
    NS.spell_ready = function(spell_action)
        if not spell_action then return false end
        return true
    end
    NS.spell_exists = function(spell_id)
        if spell_id == 5019 then return true end
        return true
    end
    NS.try_cast = function(spell_action, target, label)
        if not spell_action then return false end
        return true
    end
    NS.get_local_player = function() return mock_player end
    NS.get_target = function() return mock_target end
    NS.get_distance = function() return 10 end
    NS.debuff_remains = function(target, debuff_ids)
        if not target then return 0 end
        if debuff_ids then
            -- Return remains based on what the match function needs
            -- Default: not active
            return 0
        end
        return 0
    end
    NS.buff_remains = function(unit, buff_ids) return 0 end
    NS.buff_up = function(unit, buff_ids) return false end

    -- rotation_registry mock that captures registrations
    NS.rotation_registry = {
        _registrations = {},
        register = function(self, key, strategies, opts)
            self._registrations[key] = { strategies = strategies, opts = opts }
        end,
        set_class_config = function(self, config) end,
    }

    NS.DruidSpells = {}
    for k, v in pairs(MOCK_DRUID_SPELLS) do
        NS.DruidSpells[k] = v
    end

    _G.core = core
    _G.EaxRotations = NS

    return NS, core, mock_player, mock_target, mock_state
end

--- Create a mock context with sensible defaults.
--- @param overrides table Optional overrides for context fields
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
            leveling_heal_hp = 40,
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
-- Load the Druid leveling module
-- ============================================================================

local NS, core, mock_player, mock_target, mock_state = build_mock_env()
local ok, module = pcall(dofile, "EaxRotations/classes/druid/leveling_sylvanas.lua")
if not ok then
    error("Failed to load Druid leveling module: " .. tostring(module))
end
if not module or type(module) ~= "table" then
    error("Druid leveling module should return a table")
end

-- Get the registration info
local reg = NS.rotation_registry._registrations["leveling"]
if not reg then
    error("Druid leveling module should register as 'leveling' in rotation_registry")
end
local strategies = reg.strategies
local get_state = reg.opts.get_state

print("=== Druid Leveling Unit Tests ===\n")
print("Loaded " .. tostring(#strategies) .. " strategies\n")

-- ============================================================================
-- Test: build_state
-- ============================================================================

test("build_state: nil context returns nil", function()
    assert_nil(get_state(nil), "nil context should return nil")
end)

test("build_state: minimal context returns full state table", function()
    local ctx = make_context()
    local state = get_state(ctx)
    assert_not_nil(state, "should return a table")
    assert_eq(state.in_combat, true, "in_combat from context")
    assert_eq(state.mana_pct, 80, "mana_pct from context")
    assert_eq(state.hp, 100, "hp from context")
    assert_eq(state.enemies, 1, "enemies from context")
    assert_false(state.is_moving, "is_moving from context")
    assert_not_nil(state.target, "target from context")
end)

test("build_state: missing context fields use defaults", function()
    local ctx = {
        is_solo = false,
        is_leveling = true,
        -- Minimal context, most fields missing
        me = { is_valid = function() return true end, has_buff = function() return false end, get_health = function() return 10000 end, get_max_health = function() return 10000 end },
        target = { is_valid = function() return true end, get_health = function() return 8000 end, get_max_health = function() return 10000 end, is_casting = function() return false end, is_alive = function() return true end, get_guid = function() return "mock-target" end, get_distance = function() return 5 end, get_health_percentage = function() return 80 end },
        settings = {},
    }
    local state = get_state(ctx)
    assert_not_nil(state, "should return a table")
    assert_eq(state.hp, 100, "default hp = 100")
    assert_eq(state.mana_pct, 100, "default mana_pct = 100")
    assert_eq(state.enemies, 0, "default enemies = 0")
    assert_false(state.is_moving, "default is_moving = false")
    assert_false(state.in_combat, "default in_combat = false")
end)

test("build_state: spell readiness fields populated", function()
    local ctx = make_context()
    local state = get_state(ctx)
    assert_true(state.mark_of_the_wild_ready, "mark_of_the_wild_ready should be true")
    assert_true(state.thorns_ready, "thorns_ready should be true")
    assert_true(state.moonfire_ready, "moonfire_ready should be true")
    assert_true(state.wrath_ready, "wrath_ready should be true")
    assert_true(state.starfire_ready, "starfire_ready should be true")
    assert_true(state.insect_swarm_ready, "insect_swarm_ready should be true")
    assert_true(state.hurricane_ready, "hurricane_ready should be true")
    assert_true(state.rejuvenation_ready, "rejuvenation_ready should be true")
    assert_true(state.healing_touch_ready, "healing_touch_ready should be true")
    assert_true(state.barkskin_ready, "barkskin_ready should be true")
    assert_true(state.entangling_roots_ready, "entangling_roots_ready should be true")
    assert_true(state.natures_grasp_ready, "natures_grasp_ready should be true")
    assert_true(state.faerie_fire_ready, "faerie_fire_ready should be true")
end)

test("build_state: custom thresholds from settings", function()
    local ctx = make_context()
    ctx.settings.leveling_wand_threshold = 15
    ctx.settings.leveling_heal_hp = 60
    local state = get_state(ctx)
    assert_eq(state.wand_threshold, 15, "wand_threshold from settings")
    assert_eq(state.heal_hp, 60, "heal_hp from settings")
end)

test("build_state: missing settings uses defaults", function()
    local ctx = make_context({settings = {}})
    local state = get_state(ctx)
    assert_eq(state.wand_threshold, 30, "default wand_threshold = 30")
    assert_eq(state.heal_hp, 40, "default heal_hp = 40")
end)

test("build_state: wand_learned from spell_exists", function()
    local ctx = make_context()
    local state = get_state(ctx)
    assert_true(state.wand_learned, "wand_learned should be true when Shoot exists")
end)

-- ============================================================================
-- Test: mark_of_the_wild_matches (strategy #1)
-- ============================================================================

test("motw_matches: OOC, ready, no buff -> true", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.has_mark_of_wild = false
    state.mark_of_the_wild_ready = true
    assert_true(strategies[1].matches(ctx, state), "should match OOC without buff")
end)

test("motw_matches: in combat -> false", function()
    local ctx = make_context({in_combat = true})
    local state = get_state(ctx)
    state.has_mark_of_wild = false
    state.mark_of_the_wild_ready = true
    assert_false(strategies[1].matches(ctx, state), "should not match in combat")
end)

test("motw_matches: already has buff -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.has_mark_of_wild = true
    state.mark_of_the_wild_ready = true
    assert_false(strategies[1].matches(ctx, state), "should not match if buff active")
end)

test("motw_matches: nil state -> does not crash", function()
    local ok, result = pcall(strategies[1].matches, make_context({in_combat = false}), nil)
    assert_true(ok, "nil state should not throw")
end)

-- ============================================================================
-- Test: thorns_matches (strategy #2)
-- ============================================================================

test("thorns_matches: OOC, ready, no buff -> true", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.has_thorns = false
    state.thorns_ready = true
    assert_true(strategies[2].matches(ctx, state), "should match OOC without buff")
end)

test("thorns_matches: in combat -> false", function()
    local ctx = make_context({in_combat = true})
    local state = get_state(ctx)
    state.has_thorns = false
    state.thorns_ready = true
    assert_false(strategies[2].matches(ctx, state), "should not match in combat")
end)

test("thorns_matches: already has buff -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.has_thorns = true
    state.thorns_ready = true
    assert_false(strategies[2].matches(ctx, state), "should not match if buff active")
end)

test("thorns_matches: nil state -> does not crash", function()
    local ok, result = pcall(strategies[2].matches, make_context({in_combat = false}), nil)
    assert_true(ok, "nil state should not throw")
end)

-- ============================================================================
-- Test: barkskin_matches (strategy #3)
-- ============================================================================

test("barkskin_matches: in combat, low HP, ready -> true", function()
    local ctx = make_context({hp = 35})
    local state = get_state(ctx)
    state.barkskin_ready = true
    state.hp = 35
    assert_true(strategies[3].matches(ctx, state), "low HP in combat should match")
end)

test("barkskin_matches: HP above 50 -> false", function()
    local ctx = make_context({hp = 80})
    local state = get_state(ctx)
    state.barkskin_ready = true
    state.hp = 80
    assert_false(strategies[3].matches(ctx, state), "HP above 50 should not match")
end)

test("barkskin_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false, hp = 35})
    local state = get_state(ctx)
    state.barkskin_ready = true
    state.in_combat = false
    state.hp = 35
    assert_false(strategies[3].matches(ctx, state), "OOC should not match")
end)

test("barkskin_matches: nil state -> does not crash", function()
    local ok, result = pcall(strategies[3].matches, make_context({hp = 35}), nil)
    assert_true(ok, "nil state should not throw")
end)

-- ============================================================================
-- Test: rejuvenation_matches (strategy #4)
-- ============================================================================

test("rejuvenation_matches: in combat, low HP, ready -> true", function()
    local ctx = make_context({hp = 30})
    local state = get_state(ctx)
    state.rejuvenation_ready = true
    state.hp = 30
    state.heal_hp = 40
    assert_true(strategies[4].matches(ctx, state), "low HP in combat should match")
end)

test("rejuvenation_matches: HP above heal_hp -> false", function()
    local ctx = make_context({hp = 80})
    local state = get_state(ctx)
    state.rejuvenation_ready = true
    state.hp = 80
    state.heal_hp = 40
    assert_false(strategies[4].matches(ctx, state), "HP above threshold should not match")
end)

test("rejuvenation_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false, hp = 30})
    local state = get_state(ctx)
    state.rejuvenation_ready = true
    state.in_combat = false
    state.hp = 30
    state.heal_hp = 40
    assert_false(strategies[4].matches(ctx, state), "OOC should not match")
end)

test("rejuvenation_matches: nil state -> does not crash", function()
    local ok, result = pcall(strategies[4].matches, make_context({hp = 30}), nil)
    assert_true(ok, "nil state should not throw")
end)

-- ============================================================================
-- Test: entangling_roots_matches (strategy #5)
-- ============================================================================

test("entangling_roots_matches: overwhelmed (3+ enemies, low HP) -> true", function()
    local ctx = make_context({enemies_count = 4, hp = 25})
    local state = get_state(ctx)
    state.entangling_roots_ready = true
    state.enemies = 4
    state.hp = 25
    assert_true(strategies[5].matches(ctx, state), "overwhelmed with 4 enemies and low HP should match")
end)

test("entangling_roots_matches: single enemy, high HP -> false", function()
    local ctx = make_context({enemies_count = 1, hp = 80})
    local state = get_state(ctx)
    state.entangling_roots_ready = true
    state.enemies = 1
    state.hp = 80
    assert_false(strategies[5].matches(ctx, state), "1 enemy high HP should not match")
end)

test("entangling_roots_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false, enemies_count = 4, hp = 25})
    local state = get_state(ctx)
    state.entangling_roots_ready = true
    state.in_combat = false
    state.enemies = 4
    state.hp = 25
    assert_false(strategies[5].matches(ctx, state), "OOC should not match")
end)

test("entangling_roots_matches: no target -> false", function()
    local ctx = make_context({target = nil, enemies_count = 4, hp = 25})
    local state = get_state(ctx)
    state.entangling_roots_ready = true
    state.target = nil
    state.enemies = 4
    state.hp = 25
    assert_false(strategies[5].matches(ctx, state), "no target should not match")
end)

test("entangling_roots_matches: nil state -> does not crash", function()
    local ok, result = pcall(strategies[5].matches, make_context({enemies_count = 4, hp = 25}), nil)
    assert_true(ok, "nil state should not throw")
end)

-- ============================================================================
-- Test: moonfire_matches (strategy #6)
-- ============================================================================

test("moonfire_matches: ready, target, DoT expiring -> true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.moonfire_ready = true
    NS.debuff_remains = function(target, ids) return 2 end
    assert_true(strategies[6].matches(ctx, state), "DoT expiring should match")
    NS.debuff_remains = function(target, ids) return 0 end
end)

test("moonfire_matches: DoT still active -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.moonfire_ready = true
    NS.debuff_remains = function(target, ids) return 8 end
    assert_false(strategies[6].matches(ctx, state), "DoT still active (8s > 4s) should not match")
    NS.debuff_remains = function(target, ids) return 0 end
end)

test("moonfire_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.moonfire_ready = true
    assert_false(strategies[6].matches(ctx, state), "OOC should not match")
end)

test("moonfire_matches: no target -> false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.moonfire_ready = true
    state.target = nil
    assert_false(strategies[6].matches(ctx, state), "no target should not match")
end)

test("moonfire_matches: nil state -> does not crash", function()
    local ok, result = pcall(strategies[6].matches, make_context(), nil)
    assert_true(ok, "nil state should not throw")
end)

-- ============================================================================
-- Test: insect_swarm_matches (strategy #7)
-- ============================================================================

test("insect_swarm_matches: ready, target, DoT expiring -> true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.insect_swarm_ready = true
    NS.debuff_remains = function(target, ids) return 2 end
    assert_true(strategies[7].matches(ctx, state), "DoT expiring should match")
    NS.debuff_remains = function(target, ids) return 0 end
end)

test("insect_swarm_matches: DoT still active -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.insect_swarm_ready = true
    NS.debuff_remains = function(target, ids) return 8 end
    assert_false(strategies[7].matches(ctx, state), "DoT still active (8s > 4s) should not match")
    NS.debuff_remains = function(target, ids) return 0 end
end)

test("insect_swarm_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.insect_swarm_ready = true
    assert_false(strategies[7].matches(ctx, state), "OOC should not match")
end)

test("insect_swarm_matches: no target -> false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.insect_swarm_ready = true
    state.target = nil
    assert_false(strategies[7].matches(ctx, state), "no target should not match")
end)

test("insect_swarm_matches: nil state -> does not crash", function()
    local ok, result = pcall(strategies[7].matches, make_context(), nil)
    assert_true(ok, "nil state should not throw")
end)

-- ============================================================================
-- Test: faerie_fire_matches (strategy #8)
-- ============================================================================

test("faerie_fire_matches: ready, target, no debuff -> true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.faerie_fire_ready = true
    NS.debuff_remains = function(target, ids) return 0 end
    assert_true(strategies[8].matches(ctx, state), "no debuff should match")
    NS.debuff_remains = function(target, ids) return 0 end
end)

test("faerie_fire_matches: debuff still active -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.faerie_fire_ready = true
    NS.debuff_remains = function(target, ids) return 20 end
    assert_false(strategies[8].matches(ctx, state), "debuff active (20s > 10s) should not match")
    NS.debuff_remains = function(target, ids) return 0 end
end)

test("faerie_fire_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.faerie_fire_ready = true
    assert_false(strategies[8].matches(ctx, state), "OOC should not match")
end)

test("faerie_fire_matches: no target -> false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.faerie_fire_ready = true
    state.target = nil
    assert_false(strategies[8].matches(ctx, state), "no target should not match")
end)

test("faerie_fire_matches: nil state -> does not crash", function()
    local ok, result = pcall(strategies[8].matches, make_context(), nil)
    assert_true(ok, "nil state should not throw")
end)

-- ============================================================================
-- Test: hurricane_matches (strategy #9)
-- ============================================================================

test("hurricane_matches: 3+ enemies, not moving, ready -> true", function()
    local ctx = make_context({enemies_count = 4, is_moving = false})
    local state = get_state(ctx)
    state.hurricane_ready = true
    state.enemies = 4
    state.is_moving = false
    assert_true(strategies[9].matches(ctx, state), "3+ enemies stationary should match")
end)

test("hurricane_matches: 1 enemy -> false", function()
    local ctx = make_context({enemies_count = 1})
    local state = get_state(ctx)
    state.hurricane_ready = true
    state.enemies = 1
    assert_false(strategies[9].matches(ctx, state), "1 enemy should not match")
end)

test("hurricane_matches: moving -> false", function()
    local ctx = make_context({enemies_count = 4, is_moving = true})
    local state = get_state(ctx)
    state.hurricane_ready = true
    state.enemies = 4
    state.is_moving = true
    assert_false(strategies[9].matches(ctx, state), "moving should not match")
end)

test("hurricane_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false, enemies_count = 4})
    local state = get_state(ctx)
    state.hurricane_ready = true
    state.in_combat = false
    state.enemies = 4
    assert_false(strategies[9].matches(ctx, state), "OOC should not match")
end)

test("hurricane_matches: no target -> false", function()
    local ctx = make_context({target = nil, enemies_count = 4})
    local state = get_state(ctx)
    state.hurricane_ready = true
    state.target = nil
    state.enemies = 4
    assert_false(strategies[9].matches(ctx, state), "no target should not match")
end)

test("hurricane_matches: nil state -> does not crash", function()
    local ok, result = pcall(strategies[9].matches, make_context({enemies_count = 4}), nil)
    assert_true(ok, "nil state should not throw")
end)

-- ============================================================================
-- Test: starfire_matches (strategy #10)
-- ============================================================================

test("starfire_matches: ready, target, not moving -> true", function()
    local ctx = make_context({is_moving = false})
    local state = get_state(ctx)
    state.starfire_ready = true
    state.is_moving = false
    assert_true(strategies[10].matches(ctx, state), "stationary should match")
end)

test("starfire_matches: moving -> false", function()
    local ctx = make_context({is_moving = true})
    local state = get_state(ctx)
    state.starfire_ready = true
    state.is_moving = true
    assert_false(strategies[10].matches(ctx, state), "moving should not match")
end)

test("starfire_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.starfire_ready = true
    state.in_combat = false
    assert_false(strategies[10].matches(ctx, state), "OOC should not match")
end)

test("starfire_matches: no target -> false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.starfire_ready = true
    state.target = nil
    assert_false(strategies[10].matches(ctx, state), "no target should not match")
end)

test("starfire_matches: nil state -> does not crash", function()
    local ok, result = pcall(strategies[10].matches, make_context(), nil)
    assert_true(ok, "nil state should not throw")
end)

-- ============================================================================
-- Test: wrath_matches (strategy #11)
-- ============================================================================

test("wrath_matches: ready, target, in combat -> true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.wrath_ready = true
    assert_true(strategies[11].matches(ctx, state), "ready with target should match")
end)

test("wrath_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.wrath_ready = true
    state.in_combat = false
    assert_false(strategies[11].matches(ctx, state), "OOC should not match")
end)

test("wrath_matches: no target -> false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.wrath_ready = true
    state.target = nil
    assert_false(strategies[11].matches(ctx, state), "no target should not match")
end)

test("wrath_matches: nil state -> does not crash", function()
    local ok, result = pcall(strategies[11].matches, make_context(), nil)
    assert_true(ok, "nil state should not throw")
end)

-- ============================================================================
-- Test: wand_matches (strategy #12) - uses create_wand_matches from shared module
-- ============================================================================

test("wand_matches: low mana, in combat, has target -> true", function()
    local ctx = make_context({mana_pct = 10})
    local state = get_state(ctx)
    state.mana_pct = 10
    state.wand_threshold = 30
    state.wand_learned = true
    assert_true(strategies[12].matches(ctx, state), "low mana should match")
end)

test("wand_matches: enough mana -> false", function()
    local ctx = make_context({mana_pct = 80})
    local state = get_state(ctx)
    state.mana_pct = 80
    state.wand_threshold = 30
    state.wand_learned = true
    assert_false(strategies[12].matches(ctx, state), "enough mana should not match")
end)

test("wand_matches: no target -> false", function()
    local ctx = make_context({mana_pct = 10})
    ctx.target = nil  -- pairs() skips nil, so set explicitly
    local state = get_state(ctx)
    state.mana_pct = 10
    state.target = nil
    state.wand_learned = true
    assert_false(strategies[12].matches(ctx, state), "no target should not match")
end)

test("wand_matches: wand not learned -> false", function()
    local ctx = make_context({mana_pct = 10})
    local state = get_state(ctx)
    state.mana_pct = 10
    state.wand_learned = false
    assert_false(strategies[12].matches(ctx, state), "wand not learned should not match")
end)

-- ============================================================================
-- Test: Strategy priority ordering
-- ============================================================================

test("strategies: 12 strategies in correct priority order", function()
    local expected = {
        "MarkOfTheWild",
        "Thorns",
        "Barkskin",
        "Rejuvenation",
        "EntanglingRoots",
        "Moonfire",
        "InsectSwarm",
        "FaerieFire",
        "Hurricane",
        "Starfire",
        "Wrath",
        "Wand",
    }
    assert_eq(#strategies, 12, "should have 12 strategies")
    for i, name in ipairs(expected) do
        assert_eq(strategies[i].name, name, "strategy[" .. i .. "] should be " .. name)
    end
end)

test("strategies: every strategy has name, matches, execute", function()
    for i, s in ipairs(strategies) do
        assert_true(type(s.name) == "string", "strategy[" .. i .. "] should have string name")
        assert_true(type(s.matches) == "function", "strategy[" .. i .. "] matches should be function")
        assert_true(type(s.execute) == "function", "strategy[" .. i .. "] execute should be function")
    end
end)

-- ============================================================================
-- Test: Execute functions (smoke tests - no crash)
-- ============================================================================

test("execute_MarkOfTheWild: does not crash", function()
    local ok, result = pcall(strategies[1].execute)
    assert_true(ok, "execute should not throw")
end)

test("execute_Wand: does not crash with context", function()
    local ctx = make_context()
    local ok, result = pcall(strategies[12].execute, ctx)
    assert_true(ok, "execute with context should not throw")
end)

test("execute_Wand: does not crash without context", function()
    local ok, result = pcall(strategies[12].execute)
    assert_true(ok, "execute without context should not throw")
end)

-- ============================================================================
-- Test: Nil guard - module returns nil when NS is nil
-- ============================================================================

test("module: returns nil when EaxRotations is nil", function()
    local _, c = build_mock_env()
    _G.EaxRotations = nil
    local nil_mod = dofile("EaxRotations/classes/druid/leveling_sylvanas.lua")
    assert_nil(nil_mod, "should return nil when NS is nil")
    _G.EaxRotations = NS
end)

-- ============================================================================
-- Test: All match functions handle nil context gracefully
-- ============================================================================

test("match_functions: all handle nil context -> false", function()
    for i, s in ipairs(strategies) do
        local ok, result = pcall(s.matches, nil, {})
        assert_true(ok, "strategy[" .. i .. "] (" .. s.name .. ") matches(nil, {}) should not throw")
    end
end)

test("match_functions: all handle nil state -> no crash", function()
    local ctx = make_context()
    for i, s in ipairs(strategies) do
        local ok, result = pcall(s.matches, ctx, nil)
        assert_true(ok, "strategy[" .. i .. "] (" .. s.name .. ") matches(ctx, nil) should not throw")
    end
end)

-- ============================================================================
-- Test: Scenario integration - full rotation cycle
-- ============================================================================

test("rotation: no crashes when evaluating all strategies in sequence", function()
    local ctx = make_context({in_combat = true, mana_pct = 80, hp = 100, enemies_count = 1, is_moving = false})
    local state = get_state(ctx)
    assert_not_nil(state, "state should be built")
    for i, s in ipairs(strategies) do
        local ok_match, matched = pcall(s.matches, ctx, state)
        assert_true(ok_match, "strategy[" .. i .. "] matches should not throw")
        local ok_exec, executed = pcall(s.execute, ctx)
        assert_true(ok_exec, "strategy[" .. i .. "] execute should not throw")
    end
end)

test("rotation: OOC scenario - OOC buffs should match first", function()
    local ctx = make_context({in_combat = false})
    ctx.me.has_buff = function(id) return false end
    local state = get_state(ctx)
    state.has_mark_of_wild = false
    state.mark_of_the_wild_ready = true
    state.has_thorns = false
    state.thorns_ready = true

    -- MarkOfTheWild should match OOC
    assert_true(strategies[1].matches(ctx, state), "MarkOfTheWild should match OOC without buff")
    -- Thorns should match OOC
    assert_true(strategies[2].matches(ctx, state), "Thorns should match OOC without buff")

    -- Combat abilities should not match OOC
    for i = 3, 11 do
        local ok, matched = pcall(strategies[i].matches, ctx, state)
        assert_true(ok, "strategy[" .. i .. "] matches should not throw")
        assert_false(matched, "strategy[" .. i .. "] should not match OOC")
    end
end)

test("rotation: low HP scenario - barkskin should match", function()
    local ctx = make_context({hp = 35, mana_pct = 80})
    local state = get_state(ctx)
    state.barkskin_ready = true
    state.hp = 35

    -- Barkskin should match when HP < 50
    assert_true(strategies[3].matches(ctx, state), "Barkskin should match when HP < 50")
end)

test("rotation: AoE scenario - hurricane should match with 3+ enemies", function()
    local ctx = make_context({enemies_count = 4, is_moving = false})
    local state = get_state(ctx)
    state.hurricane_ready = true
    state.enemies = 4
    state.is_moving = false

    -- Hurricane should match with 3+ enemies stationary
    assert_true(strategies[9].matches(ctx, state), "Hurricane should match with 3+ enemies")
end)

test("rotation: low mana scenario - wand should match", function()
    local ctx = make_context({mana_pct = 10})
    local state = get_state(ctx)
    state.mana_pct = 10
    state.wand_threshold = 30
    state.wand_learned = true

    -- Wand should match when mana below threshold
    assert_true(strategies[12].matches(ctx, state), "Wand should match when mana below threshold")
end)

-- ============================================================================
-- Summary
-- ============================================================================

print(string.format("\n=== Druid Leveling Unit Tests: %d passed, %d failed (%d assertions) ===\n", passed, failed, assertions))
if failed > 0 then
    error(string.format("Some tests FAILED (%d failures)", failed))
else
    print("All Druid leveling unit tests passed!")
end
