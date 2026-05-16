-- Unit tests for Hunter leveling rotation
-- Tests build_state, all 10 match functions, strategy ordering,
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

local MOCK_HUNTER_SPELLS = {
    SerpentSting = { 27016 },
    HuntersMark = { 14325 },
    ArcaneShot = { 27019 },
    SteadyShot = { 34120 },
    MultiShot = { 27021 },
    MendPet = { 27046 },
    CallPet = { 27028 },
    AspectOfTheHawk = { 27044 },
    FeignDeath = { 5384 },
    FreezingTrap = { 1499 },
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
        get_class = function() return 3 end,
        is_in_combat = function() return false end,
        get_target = function() return mock_target end,
        get_position = function() return { x = 0, y = 0, z = 0 } end,
    }

    NS.PLAYER_UNIT = "player"
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
    NS.buff_up = function(unit, buff_ids)
        if not unit or not buff_ids then return false end
        if type(buff_ids) == "table" then
            for _, id in ipairs(buff_ids) do
                if unit.has_buff and unit:has_buff(id) then return true end
            end
            return false
        end
        return unit.has_buff and unit:has_buff(buff_ids) or false
    end
    NS.get_local_player = function() return mock_player end
    NS.get_target = function() return mock_target end
    NS.get_distance = function(target)
        if not target then return nil end
        return 10
    end
    NS.debuff_remains = function(target, spell)
        if not target or not spell then return 0 end
        return 0
    end
    NS.buff_remains = function(unit, buff_ids) return 0 end
    NS.game_time_ms = function() return 100000 end

    -- rotation_registry mock
    NS.rotation_registry = {
        _registrations = {},
        register = function(self, key, strategies, opts)
            self._registrations[key] = { strategies = strategies, opts = opts }
        end,
        set_class_config = function(self, config) end,
    }

    NS.HunterSpells = {}
    for k, v in pairs(MOCK_HUNTER_SPELLS) do
        NS.HunterSpells[k] = v
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
        pet = { guid = "mock-pet", get_health_percentage = function() return 100 end },
        settings = {
            playstyle = "leveling",
            active_playstyle = "leveling",
            use_interrupt = true,
            leveling_wand_threshold = 30,
            leveling_serpent_sting_use = true,
            leveling_hunters_mark_use = true,
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
-- Load the Hunter leveling module
-- ============================================================================

local NS, core, mock_player, mock_target, mock_state = build_mock_env()
local ok, module = pcall(dofile, "EaxRotations/classes/hunter/leveling_sylvanas.lua")
if not ok then
    error("Failed to load Hunter leveling module: " .. tostring(module))
end
if not module or type(module) ~= "table" then
    error("Hunter leveling module should return a table of strategies")
end

local reg = NS.rotation_registry._registrations["leveling"]
if not reg then
    error("Hunter leveling module should register as 'leveling' in rotation_registry")
end
local strategies = reg.strategies
local get_state = reg.opts.get_state

print("=== Hunter Leveling Unit Tests ===\n")
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
        me = { is_valid = function() return true end, has_buff = function(id) return false end, get_health = function() return 10000 end, get_max_health = function() return 10000 end },
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
    assert_true(state.serpent_sting_ready, "serpent_sting_ready")
    assert_true(state.hunters_mark_ready, "hunters_mark_ready")
    assert_true(state.arcane_shot_ready, "arcane_shot_ready")
    assert_true(state.steady_shot_ready, "steady_shot_ready")
    assert_true(state.multi_shot_ready, "multi_shot_ready")
    assert_true(state.mend_pet_ready, "mend_pet_ready")
    assert_true(state.call_pet_ready, "call_pet_ready")
    assert_true(state.aspect_hawk_ready, "aspect_hawk_ready")
    assert_true(state.feign_death_ready, "feign_death_ready")
    assert_true(state.freezing_trap_ready, "freezing_trap_ready")
end)

test("build_state: custom settings from context", function()
    local ctx = make_context()
    ctx.settings.leveling_serpent_sting_use = false
    ctx.settings.leveling_hunters_mark_use = false
    local state = get_state(ctx)
    assert_false(state.serpent_sting_use, "serpent_sting_use from settings")
    assert_false(state.hunters_mark_use, "hunters_mark_use from settings")
end)

test("build_state: missing settings uses defaults", function()
    local ctx = make_context({settings = {}})
    local state = get_state(ctx)
    assert_true(state.serpent_sting_use, "default serpent_sting_use = true")
    assert_true(state.hunters_mark_use, "default hunters_mark_use = true")
end)

test("build_state: pet HP defaults when no pet", function()
    local ctx = make_context({pet = nil})
    local state = get_state(ctx)
    assert_eq(state.pet_hp, 100, "pet_hp should default to 100 when no pet")
end)

test("build_state: pet HP from pet object", function()
    local ctx = make_context()
    ctx.pet = { get_health_percentage = function() return 45 end }
    local state = get_state(ctx)
    assert_eq(state.pet_hp, 45, "pet_hp from pet object")
end)

test("build_state: wand_learned and use_interrupt from common state", function()
    local ctx = make_context()
    local state = get_state(ctx)
    assert_true(state.use_interrupt, "use_interrupt defaults to true")
    assert_true(state.wand_learned, "wand_learned from spell_exists")
end)

-- ============================================================================
-- Test: aspect_hawk_matches (strategy #1)
-- ============================================================================

test("aspect_hawk_matches: OOC, no buff, ready -> true", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.has_aspect_hawk = false
    state.aspect_hawk_ready = true
    assert_true(strategies[1].matches(ctx, state), "OOC without buff should match")
end)

test("aspect_hawk_matches: in combat -> false", function()
    local ctx = make_context({in_combat = true})
    local state = get_state(ctx)
    state.has_aspect_hawk = false
    state.aspect_hawk_ready = true
    assert_false(strategies[1].matches(ctx, state), "in combat should not match")
end)

test("aspect_hawk_matches: already has buff -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.has_aspect_hawk = true
    state.aspect_hawk_ready = true
    assert_false(strategies[1].matches(ctx, state), "already has buff should not match")
end)

test("aspect_hawk_matches: not ready -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.has_aspect_hawk = false
    state.aspect_hawk_ready = false
    assert_false(strategies[1].matches(ctx, state), "not ready should not match")
end)

-- ============================================================================
-- Test: call_pet_matches (strategy #2)
-- ============================================================================

test("call_pet_matches: OOC, no pet, ready -> true", function()
    local ctx = make_context({in_combat = false})
    ctx.pet = nil  -- override pet after make_context (pairs skips nil)
    local state = get_state(ctx)
    state.call_pet_ready = true
    assert_true(strategies[2].matches(ctx, state), "OOC without pet should match")
end)

test("call_pet_matches: in combat -> false", function()
    local ctx = make_context({in_combat = true, pet = nil})
    local state = get_state(ctx)
    state.call_pet_ready = true
    assert_false(strategies[2].matches(ctx, state), "in combat should not match")
end)

test("call_pet_matches: already has pet -> false", function()
    local ctx = make_context({in_combat = false})
    assert_not_nil(ctx.pet, "pet should exist")
    local state = get_state(ctx)
    state.call_pet_ready = true
    assert_false(strategies[2].matches(ctx, state), "already has pet should not match")
end)

test("call_pet_matches: not ready -> false", function()
    local ctx = make_context({in_combat = false, pet = nil})
    local state = get_state(ctx)
    state.call_pet_ready = false
    assert_false(strategies[2].matches(ctx, state), "not ready should not match")
end)

-- ============================================================================
-- Test: hunters_mark_matches (strategy #3)
-- ============================================================================

test("hunters_mark_matches: OOC, mark expired, ready -> true", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.hunters_mark_ready = true
    state.hunters_mark_use = true
    NS.debuff_remains = function(target, spell) return 0 end
    assert_true(strategies[3].matches(ctx, state), "OOC with expired mark should match")
end)

test("hunters_mark_matches: in combat -> false", function()
    local ctx = make_context({in_combat = true})
    local state = get_state(ctx)
    state.hunters_mark_ready = true
    state.hunters_mark_use = true
    assert_false(strategies[3].matches(ctx, state), "in combat should not match")
end)

test("hunters_mark_matches: mark still active -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.hunters_mark_ready = true
    state.hunters_mark_use = true
    NS.debuff_remains = function(target, spell) return 60 end
    assert_false(strategies[3].matches(ctx, state), "active mark should not match")
    NS.debuff_remains = function(target, spell) return 0 end
end)

test("hunters_mark_matches: disabled -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.hunters_mark_ready = true
    state.hunters_mark_use = false
    assert_false(strategies[3].matches(ctx, state), "disabled should not match")
end)

test("hunters_mark_matches: no target -> false", function()
    local ctx = make_context({in_combat = false, target = nil})
    local state = get_state(ctx)
    state.hunters_mark_ready = true
    state.hunters_mark_use = true
    state.target = nil
    assert_false(strategies[3].matches(ctx, state), "no target should not match")
end)

-- ============================================================================
-- Test: mend_pet_matches (strategy #4)
-- ============================================================================

test("mend_pet_matches: in combat, pet low HP, ready -> true", function()
    local ctx = make_context()
    ctx.pet = { get_health_percentage = function() return 40 end }
    local state = get_state(ctx)
    state.mend_pet_ready = true
    state.pet_hp = 40
    assert_true(strategies[4].matches(ctx, state), "low pet HP should match")
end)

test("mend_pet_matches: pet HP above 60 -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.mend_pet_ready = true
    state.pet_hp = 80
    assert_false(strategies[4].matches(ctx, state), "high pet HP should not match")
end)

test("mend_pet_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false})
    ctx.pet = { get_health_percentage = function() return 40 end }
    local state = get_state(ctx)
    state.mend_pet_ready = true
    state.pet_hp = 40
    assert_false(strategies[4].matches(ctx, state), "OOC should not match")
end)

test("mend_pet_matches: no pet -> false", function()
    local ctx = make_context({pet = nil})
    local state = get_state(ctx)
    state.mend_pet_ready = true
    assert_false(strategies[4].matches(ctx, state), "no pet should not match")
end)

-- ============================================================================
-- Test: freezing_trap_matches (strategy #5)
-- ============================================================================

test("freezing_trap_matches: in combat, 2+ enemies, ready -> true", function()
    local ctx = make_context({enemies_count = 3})
    local state = get_state(ctx)
    state.freezing_trap_ready = true
    state.enemies = 3
    assert_true(strategies[5].matches(ctx, state), "2+ enemies should match")
end)

test("freezing_trap_matches: single enemy -> false", function()
    local ctx = make_context({enemies_count = 1})
    local state = get_state(ctx)
    state.freezing_trap_ready = true
    state.enemies = 1
    assert_false(strategies[5].matches(ctx, state), "1 enemy should not match")
end)

test("freezing_trap_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false, enemies_count = 3})
    local state = get_state(ctx)
    state.freezing_trap_ready = true
    state.enemies = 3
    assert_false(strategies[5].matches(ctx, state), "OOC should not match")
end)

test("freezing_trap_matches: no target -> false", function()
    local ctx = make_context({target = nil, enemies_count = 3})
    local state = get_state(ctx)
    state.freezing_trap_ready = true
    state.enemies = 3
    state.target = nil
    assert_false(strategies[5].matches(ctx, state), "no target should not match")
end)

-- ============================================================================
-- Test: feign_death_matches (strategy #6)
-- ============================================================================

test("feign_death_matches: in combat, low HP, ready -> true", function()
    local ctx = make_context({hp = 20})
    local state = get_state(ctx)
    state.feign_death_ready = true
    state.hp = 20
    assert_true(strategies[6].matches(ctx, state), "low HP in combat should match")
end)

test("feign_death_matches: HP above 30 -> false", function()
    local ctx = make_context({hp = 80})
    local state = get_state(ctx)
    state.feign_death_ready = true
    state.hp = 80
    assert_false(strategies[6].matches(ctx, state), "HP above 30 should not match")
end)

test("feign_death_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false, hp = 20})
    local state = get_state(ctx)
    state.feign_death_ready = true
    state.hp = 20
    assert_false(strategies[6].matches(ctx, state), "OOC should not match")
end)

-- ============================================================================
-- Test: serpent_sting_matches (strategy #7)
-- ============================================================================

test("serpent_sting_matches: in combat, DoT expired, ready -> true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.serpent_sting_ready = true
    state.serpent_sting_use = true
    NS.debuff_remains = function(target, spell) return 0 end
    assert_true(strategies[7].matches(ctx, state), "DoT expired should match")
end)

test("serpent_sting_matches: DoT still active -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.serpent_sting_ready = true
    state.serpent_sting_use = true
    NS.debuff_remains = function(target, spell) return 10 end
    assert_false(strategies[7].matches(ctx, state), "active DoT should not match")
    NS.debuff_remains = function(target, spell) return 0 end
end)

test("serpent_sting_matches: disabled -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.serpent_sting_ready = true
    state.serpent_sting_use = false
    assert_false(strategies[7].matches(ctx, state), "disabled should not match")
end)

test("serpent_sting_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.serpent_sting_ready = true
    state.serpent_sting_use = true
    assert_false(strategies[7].matches(ctx, state), "OOC should not match")
end)

test("serpent_sting_matches: no target -> false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.serpent_sting_ready = true
    state.serpent_sting_use = true
    state.target = nil
    assert_false(strategies[7].matches(ctx, state), "no target should not match")
end)

-- ============================================================================
-- Test: arcane_shot_matches (strategy #8)
-- ============================================================================

test("arcane_shot_matches: in combat, ready -> true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.arcane_shot_ready = true
    assert_true(strategies[8].matches(ctx, state), "in combat ready should match")
end)

test("arcane_shot_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.arcane_shot_ready = true
    assert_false(strategies[8].matches(ctx, state), "OOC should not match")
end)

test("arcane_shot_matches: no target -> false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.arcane_shot_ready = true
    state.target = nil
    assert_false(strategies[8].matches(ctx, state), "no target should not match")
end)

test("arcane_shot_matches: not ready -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.arcane_shot_ready = false
    assert_false(strategies[8].matches(ctx, state), "not ready should not match")
end)

-- ============================================================================
-- Test: multi_shot_matches (strategy #9)
-- ============================================================================

test("multi_shot_matches: in combat, 2+ enemies, ready -> true", function()
    local ctx = make_context({enemies_count = 3})
    local state = get_state(ctx)
    state.multi_shot_ready = true
    state.enemies = 3
    assert_true(strategies[9].matches(ctx, state), "2+ enemies should match")
end)

test("multi_shot_matches: single enemy -> false", function()
    local ctx = make_context({enemies_count = 1})
    local state = get_state(ctx)
    state.multi_shot_ready = true
    state.enemies = 1
    assert_false(strategies[9].matches(ctx, state), "1 enemy should not match")
end)

test("multi_shot_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false, enemies_count = 3})
    local state = get_state(ctx)
    state.multi_shot_ready = true
    state.enemies = 3
    assert_false(strategies[9].matches(ctx, state), "OOC should not match")
end)

test("multi_shot_matches: no target -> false", function()
    local ctx = make_context({target = nil, enemies_count = 3})
    local state = get_state(ctx)
    state.multi_shot_ready = true
    state.enemies = 3
    state.target = nil
    assert_false(strategies[9].matches(ctx, state), "no target should not match")
end)

-- ============================================================================
-- Test: steady_shot_matches (strategy #10)
-- ============================================================================

test("steady_shot_matches: in combat, not moving, ready -> true", function()
    local ctx = make_context({is_moving = false})
    local state = get_state(ctx)
    state.steady_shot_ready = true
    state.is_moving = false
    assert_true(strategies[10].matches(ctx, state), "stationary should match")
end)

test("steady_shot_matches: moving -> false", function()
    local ctx = make_context({is_moving = true})
    local state = get_state(ctx)
    state.steady_shot_ready = true
    state.is_moving = true
    assert_false(strategies[10].matches(ctx, state), "moving should not match")
end)

test("steady_shot_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.steady_shot_ready = true
    assert_false(strategies[10].matches(ctx, state), "OOC should not match")
end)

test("steady_shot_matches: no target -> false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.steady_shot_ready = true
    state.target = nil
    assert_false(strategies[10].matches(ctx, state), "no target should not match")
end)

-- ============================================================================
-- Test: Strategy priority ordering
-- ============================================================================

test("strategies: 10 strategies in correct priority order", function()
    local expected = {
        "AspectHawk",
        "CallPet",
        "HuntersMark",
        "MendPet",
        "FreezingTrap",
        "FeignDeath",
        "SerpentSting",
        "ArcaneShot",
        "MultiShot",
        "SteadyShot",
    }
    assert_eq(#strategies, 10, "should have 10 strategies")
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
-- Test: Execute functions (smoke tests)
-- ============================================================================

test("execute_AspectHawk: does not crash", function()
    local ok, result = pcall(strategies[1].execute)
    assert_true(ok, "execute should not throw")
end)

test("execute_ArcaneShot: does not crash with context", function()
    local ctx = make_context()
    local ok, result = pcall(strategies[8].execute, ctx)
    assert_true(ok, "execute with context should not throw")
end)

-- ============================================================================
-- Test: Nil guard
-- ============================================================================

test("module: returns nil when EaxRotations is nil", function()
    local _, c = build_mock_env()
    _G.EaxRotations = nil
    local nil_mod = dofile("EaxRotations/classes/hunter/leveling_sylvanas.lua")
    assert_nil(nil_mod, "should return nil when NS is nil")
    _G.EaxRotations = NS
end)

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
-- Test: Scenario integration
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

test("rotation: OOC scenario - only OOC buffs should match", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.has_aspect_hawk = false
    state.aspect_hawk_ready = true
    state.hunters_mark_ready = true
    state.hunters_mark_use = true
    state.call_pet_ready = true

    -- OOC buffs should match
    assert_true(strategies[1].matches(ctx, state), "AspectHawk should match OOC")
    ctx.pet = nil  -- CallPet needs no pet to match
    assert_true(strategies[2].matches(ctx, state), "CallPet should match OOC")
    -- HuntersMark checks debuff remains, may or may not match depending on mock

    -- Combat abilities should not match OOC
    for i = 4, 10 do
        local ok, matched = pcall(strategies[i].matches, ctx, state)
        assert_true(ok, "strategy[" .. i .. "] matches should not throw")
        assert_false(matched, "strategy[" .. i .. "] should not match OOC")
    end
end)

test("rotation: AoE scenario - multi_shot should match with 2+ enemies", function()
    local ctx = make_context({enemies_count = 3})
    local state = get_state(ctx)
    state.multi_shot_ready = true
    state.enemies = 3

    assert_true(strategies[9].matches(ctx, state), "MultiShot should match with 3 enemies")
end)

test("rotation: low HP scenario - feign_death should match", function()
    local ctx = make_context({hp = 20})
    local state = get_state(ctx)
    state.feign_death_ready = true
    state.hp = 20

    assert_true(strategies[6].matches(ctx, state), "FeignDeath should match when HP < 30")
end)

-- ============================================================================
-- Edge Case: Aspect management — buff states, not ready, boundary
-- ============================================================================

test("edge_aspect: has buff with ready up should not rematch", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.has_aspect_hawk = true
    state.aspect_hawk_ready = true
    assert_false(strategies[1].matches(ctx, state), "already has aspect hawk should not match even if ready")
end)

test("edge_aspect: in combat should never apply aspect", function()
    local ctx = make_context({in_combat = true})
    local state = get_state(ctx)
    state.has_aspect_hawk = false
    state.aspect_hawk_ready = true
    assert_false(strategies[1].matches(ctx, state), "in combat should not match aspect hawk")
end)

test("edge_aspect: not ready does not match", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.has_aspect_hawk = false
    state.aspect_hawk_ready = false
    assert_false(strategies[1].matches(ctx, state), "not ready should not match aspect")
end)

test("edge_aspect: nil context false", function()
    assert_false(strategies[1].matches(nil, {}), "nil context returns false")
end)

test("edge_aspect: nil state false", function()
    local ctx = make_context()
    assert_false(strategies[1].matches(ctx, nil), "nil state returns false")
end)

-- ============================================================================
-- Edge Case: Pet management — HP boundaries, dead pet, pcall failure
-- ============================================================================

test("edge_pet: mend_pet HP at exactly 60 boundary (not > 60, so should match)", function()
    local ctx = make_context()
    ctx.pet = { get_health_percentage = function() return 60 end }
    local state = get_state(ctx)
    state.mend_pet_ready = true
    state.pet_hp = 60
    assert_true(strategies[4].matches(ctx, state), "pet HP = 60 should match (not > 60)")
end)

test("edge_pet: mend_pet HP at 61 just above boundary", function()
    local ctx = make_context()
    ctx.pet = { get_health_percentage = function() return 61 end }
    local state = get_state(ctx)
    state.mend_pet_ready = true
    state.pet_hp = 61
    assert_false(strategies[4].matches(ctx, state), "pet HP = 61 should NOT match (> 60)")
end)

test("edge_pet: mend_pet HP = 0 (dead pet) should match", function()
    local ctx = make_context()
    ctx.pet = { get_health_percentage = function() return 0 end }
    local state = get_state(ctx)
    state.mend_pet_ready = true
    state.pet_hp = 0
    assert_true(strategies[4].matches(ctx, state), "pet HP = 0 should match (needs mend)")
end)

test("edge_pet: mend_pet no pet should not match", function()
    local ctx = make_context({pet = nil})
    local state = get_state(ctx)
    state.mend_pet_ready = true
    state.pet_hp = 100
    assert_false(strategies[4].matches(ctx, state), "no pet should not match mend_pet")
end)

test("edge_pet: call_pet already has pet should not match", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.call_pet_ready = true
    assert_false(strategies[2].matches(ctx, state), "already have pet should not match CallPet")
end)

test("edge_pet: pet HP pcall failure returns default 100", function()
    local ctx = make_context()
    ctx.pet = {}
    local state = get_state(ctx)
    assert_eq(state.pet_hp, 100, "pet with no get_health_percentage defaults to 100")
end)

-- ============================================================================
-- Edge Case: Debuff refresh boundaries
-- ============================================================================

test("edge_debuff: serpent_sting remains at exactly 4 boundary should not refresh", function()
    local saved = NS.debuff_remains
    NS.debuff_remains = function(target, spell) return 4 end
    local ctx = make_context()
    local state = get_state(ctx)
    state.serpent_sting_ready = true
    state.serpent_sting_use = true
    assert_false(strategies[7].matches(ctx, state), "remains = 4 should NOT match (4 >= 4 means DoT still active)")
    NS.debuff_remains = saved
end)

test("edge_debuff: serpent_sting remains at 3 should refresh", function()
    local saved = NS.debuff_remains
    NS.debuff_remains = function(target, spell) return 3 end
    local ctx = make_context()
    local state = get_state(ctx)
    state.serpent_sting_ready = true
    state.serpent_sting_use = true
    assert_true(strategies[7].matches(ctx, state), "remains = 3 should match")
    NS.debuff_remains = saved
end)

test("edge_debuff: hunters_mark remains at exactly 30 boundary should not reapply", function()
    local saved = NS.debuff_remains
    NS.debuff_remains = function(target, spell) return 30 end
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.hunters_mark_ready = true
    state.hunters_mark_use = true
    assert_true(strategies[3].matches(ctx, state), "remains = 30 should match (> 30 is false, so 30 stays)")
    NS.debuff_remains = saved
end)

test("edge_debuff: hunters_mark remains at 31 should not reapply", function()
    local saved = NS.debuff_remains
    NS.debuff_remains = function(target, spell) return 31 end
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.hunters_mark_ready = true
    state.hunters_mark_use = true
    assert_false(strategies[3].matches(ctx, state), "remains = 31 should NOT match (> 30)")
    NS.debuff_remains = saved
end)

-- ============================================================================
-- Edge Case: Trap / AoE boundaries
-- ============================================================================

test("edge_aoe: freezing_trap with exactly 2 enemies matches", function()
    local ctx = make_context({enemies_count = 2})
    local state = get_state(ctx)
    state.freezing_trap_ready = true
    state.enemies = 2
    assert_true(strategies[5].matches(ctx, state), "freezing_trap with 2 enemies should match")
end)

test("edge_aoe: freezing_trap with exactly 1 enemy does not match", function()
    local ctx = make_context({enemies_count = 1})
    local state = get_state(ctx)
    state.freezing_trap_ready = true
    state.enemies = 1
    assert_false(strategies[5].matches(ctx, state), "freezing_trap with 1 enemy should NOT match")
end)

test("edge_aoe: multi_shot with exactly 2 enemies matches", function()
    local ctx = make_context({enemies_count = 2})
    local state = get_state(ctx)
    state.multi_shot_ready = true
    state.enemies = 2
    assert_true(strategies[9].matches(ctx, state), "multi_shot with 2 enemies should match")
end)

test("edge_aoe: multi_shot with 1 enemy does not match", function()
    local ctx = make_context({enemies_count = 1})
    local state = get_state(ctx)
    state.multi_shot_ready = true
    state.enemies = 1
    assert_false(strategies[9].matches(ctx, state), "multi_shot with 1 enemy should NOT match")
end)

-- ============================================================================
-- Edge Case: Feign Death boundaries
-- ============================================================================

test("edge_feign: HP exactly at 30 boundary should match", function()
    local ctx = make_context({hp = 30})
    local state = get_state(ctx)
    state.feign_death_ready = true
    state.hp = 30
    assert_true(strategies[6].matches(ctx, state), "hp = 30 should match (not > 30)")
end)

test("edge_feign: HP = 31 just above boundary should not match", function()
    local ctx = make_context({hp = 31})
    local state = get_state(ctx)
    state.feign_death_ready = true
    state.hp = 31
    assert_false(strategies[6].matches(ctx, state), "hp = 31 should NOT match (> 30)")
end)

test("edge_feign: HP = 0 (just barely alive) should match", function()
    local ctx = make_context({hp = 0})
    local state = get_state(ctx)
    state.feign_death_ready = true
    state.hp = 0
    assert_true(strategies[6].matches(ctx, state), "hp = 0 should match")
end)

-- ============================================================================
-- Edge Case: Movement / Steady Shot
-- ============================================================================

test("edge_movement: steady_shot while stationary matches", function()
    local ctx = make_context({is_moving = false})
    local state = get_state(ctx)
    state.steady_shot_ready = true
    state.is_moving = false
    assert_true(strategies[10].matches(ctx, state), "steady_shot stationary should match")
end)

test("edge_movement: steady_shot while moving does not match", function()
    local ctx = make_context({is_moving = true})
    local state = get_state(ctx)
    state.steady_shot_ready = true
    state.is_moving = true
    assert_false(strategies[10].matches(ctx, state), "steady_shot moving should NOT match")
end)

test("edge_movement: arcane_shot still works while moving (no movement restriction)", function()
    local ctx = make_context({is_moving = true})
    local state = get_state(ctx)
    state.arcane_shot_ready = true
    state.is_moving = true
    assert_true(strategies[8].matches(ctx, state), "arcane_shot works while moving")
end)

-- ============================================================================
-- Edge Case: Throwing API resilience — NS.buff_up, NS.debuff_remains, NS.spell_ready
-- ============================================================================

test("edge_api: NS.buff_up is nil in aspect_hawk build_state", function()
    local saved = NS.buff_up
    NS.buff_up = nil
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    assert_false(state.has_aspect_hawk, "nil NS.buff_up should produce false has_aspect_hawk")
    NS.buff_up = saved
end)

test("edge_api: NS.buff_up throws in build_state", function()
    local saved = NS.buff_up
    NS.buff_up = function() error("simulated throw") end
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    assert_false(state.has_aspect_hawk, "throwing NS.buff_up should produce false has_aspect_hawk")
    NS.buff_up = saved
end)

test("edge_api: NS.debuff_remains is nil in serpent_sting_matches", function()
    local saved = NS.debuff_remains
    NS.debuff_remains = nil
    local ctx = make_context()
    local state = get_state(ctx)
    state.serpent_sting_ready = true
    state.serpent_sting_use = true
    local ok, result = pcall(strategies[7].matches, ctx, state)
    assert_true(ok, "nil NS.debuff_remains should not throw")
    NS.debuff_remains = saved
end)

test("edge_api: NS.debuff_remains throws in serpent_sting_matches", function()
    local saved = NS.debuff_remains
    NS.debuff_remains = function() error("simulated throw") end
    local ctx = make_context()
    local state = get_state(ctx)
    state.serpent_sting_ready = true
    state.serpent_sting_use = true
    local ok, result = pcall(strategies[7].matches, ctx, state)
    assert_true(ok, "throwing NS.debuff_remains should not crash")
    NS.debuff_remains = saved
end)

test("edge_api: NS.debuff_remains nil in hunters_mark_matches", function()
    local saved = NS.debuff_remains
    NS.debuff_remains = nil
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.hunters_mark_ready = true
    state.hunters_mark_use = true
    local ok, result = pcall(strategies[3].matches, ctx, state)
    assert_true(ok, "nil NS.debuff_remains in hunters_mark should not throw")
    NS.debuff_remains = saved
end)

test("edge_api: NS.spell_ready nil in build_state", function()
    local saved = NS.spell_ready
    NS.spell_ready = nil
    local ctx = make_context()
    local state = get_state(ctx)
    assert_false(state.serpent_sting_ready, "nil NS.spell_ready should produce false ready")
    assert_false(state.arcane_shot_ready, "nil NS.spell_ready should produce false ready")
    NS.spell_ready = saved
end)

test("edge_api: NS.spell_ready throws in build_state", function()
    local saved = NS.spell_ready
    NS.spell_ready = function() error("simulated throw") end
    local ctx = make_context()
    local ok, state = pcall(get_state, ctx)
    assert_true(ok, "throwing NS.spell_ready should not crash build_state")
    NS.spell_ready = saved
end)

test("edge_api: NS.try_cast nil in execute functions", function()
    local saved = NS.try_cast
    NS.try_cast = nil
    local ok, result = pcall(strategies[1].execute)
    assert_true(ok, "nil NS.try_cast should not crash execute")
    NS.try_cast = saved
end)

-- ============================================================================
-- Edge Case: All-spells-unavailable scenario
-- ============================================================================

test("edge_all_disabled: all ready fields false, match functions still return false", function()
    local ctx = make_context({in_combat = true})
    local state = get_state(ctx)
    state.serpent_sting_ready = false
    state.arcane_shot_ready = false
    state.steady_shot_ready = false
    state.multi_shot_ready = false
    state.freezing_trap_ready = false
    state.feign_death_ready = false
    state.mend_pet_ready = false
    for i = 4, 10 do
        local ok, matched = pcall(strategies[i].matches, ctx, state)
        assert_true(ok, "strategy[" .. i .. "] matches should not throw")
        assert_false(matched, "strategy[" .. i .. "] should not match when not ready")
    end
end)

-- ============================================================================
-- Edge Case: Full rotation crash safety — all values nil/empty
-- ============================================================================

test("edge_rotation_crash: all match functions return false with nil context and nil state", function()
    for i, s in ipairs(strategies) do
        local ok, result = pcall(s.matches, nil, nil)
        assert_true(ok, "strategy[" .. i .. "] (" .. s.name .. ") matches(nil, nil) should not throw")
        assert_false(result, "strategy[" .. i .. "] should return false with nil arguments")
    end
end)

test("edge_rotation_crash: all execute functions handle nil context", function()
    for i, s in ipairs(strategies) do
        local ok, result = pcall(s.execute, nil)
        assert_true(ok, "strategy[" .. i .. "] (" .. s.name .. ") execute(nil) should not throw")
    end
end)

-- ============================================================================
-- Edge Case: Settings toggle edge cases
-- ============================================================================

test("edge_settings: serpent_sting disabled via settings", function()
    local ctx = make_context()
    ctx.settings.leveling_serpent_sting_use = false
    local state = get_state(ctx)
    state.serpent_sting_ready = true
    assert_false(strategies[7].matches(ctx, state), "disabled serpent sting should not match")
end)

test("edge_settings: hunters_mark disabled via settings", function()
    local ctx = make_context({in_combat = false})
    ctx.settings.leveling_hunters_mark_use = false
    local state = get_state(ctx)
    state.hunters_mark_ready = true
    state.hunters_mark_use = false
    assert_false(strategies[3].matches(ctx, state), "disabled hunters mark should not match")
end)

test("edge_settings: both serpent_sting and hunters_mark default to true when settings absent", function()
    local ctx = make_context({settings = {}})
    local state = get_state(ctx)
    assert_true(state.serpent_sting_use, "default serpent_sting_use should be true")
    assert_true(state.hunters_mark_use, "default hunters_mark_use should be true")
end)

-- ============================================================================
-- Edge Case: Ranged/melee switching — target distance extremes
-- ============================================================================

test("edge_range: all damage matches work when target in melee range", function()
    local ctx = make_context({in_combat = true})
    local state = get_state(ctx)
    state.serpent_sting_ready = true
    state.serpent_sting_use = true
    state.arcane_shot_ready = true
    state.steady_shot_ready = true
    state.multi_shot_ready = true
    state.is_moving = false
    state.enemies = 1
    io.stderr:write("DEBUG state.in_combat=" .. tostring(state.in_combat) .. "\\n")
    io.stderr:write("DEBUG state.target=" .. tostring(state.target) .. "\\n")
    io.stderr:write("DEBUG state.serpent_sting_use=" .. tostring(state.serpent_sting_use) .. "\\n")
    io.stderr:write("DEBUG state.serpent_sting_ready=" .. tostring(state.serpent_sting_ready) .. "\\n")
    io.stderr:write("DEBUG state.hp=" .. tostring(state.hp) .. "\\n")
    local match_ok, match_r = pcall(strategies[7].matches, ctx, state)
    io.stderr:write("DEBUG pcall match_ok=" .. tostring(match_ok) .. " match_r=" .. tostring(match_r) .. "\\n")
    assert_true(match_r, "serpent sting works at melee range")
    assert_true(strategies[8].matches(ctx, state), "arcane shot works at melee range")
    assert_true(strategies[10].matches(ctx, state), "steady shot works at melee range")
end)

test("edge_range: utility matches work when target in melee range", function()
    local ctx = make_context({enemies_count = 2})
    local state = get_state(ctx)
    state.freezing_trap_ready = true
    state.enemies = 2
    state.feign_death_ready = true
    state.hp = 20
    assert_true(strategies[5].matches(ctx, state), "freezing trap works at melee range")
    assert_true(strategies[6].matches(ctx, state), "feign death works at any range")
end)

test("edge_range: execute functions do not crash at any target distance", function()
    local ctx = make_context()
    for i = 3, 10 do
        local ok, result = pcall(strategies[i].execute, ctx)
        assert_true(ok, "strategy[" .. i .. "] execute at range should not throw")
    end
end)

-- ============================================================================
-- Summary
-- ============================================================================

print(string.format("\n=== Hunter Leveling Unit Tests: %d passed, %d failed (%d assertions) ===\n", passed, failed, assertions))
if failed > 0 then
    error(string.format("Some tests FAILED (%d failures)", failed))
else
    print("All Hunter leveling unit tests passed!")
end
