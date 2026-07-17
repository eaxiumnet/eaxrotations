-- test_leveling_hunter.lua -- Hunter leveling rotation tests.
-- WHAT:  Hunter leveling rotation tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Protects against regressions in rotation logic and state handling.
-- SAFETY: Pure unit tests with mocked API context.

-- Unit tests for Hunter leveling rotation
-- Tests build_state, all 11 match functions, strategy ordering,
-- helper functions, and edge case handling

local EAXROTATIONS_DIR = "EaxRotations"
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
    AimedShot = { 19434 },
    ConcussiveShot = { 27019 },
    WingClip = { 27020 },
    RapidFire = { 3045 },
    ScareBeast = { 14327 },
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
    NS.time_now = function() return 100 end
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
if (not strategies or #strategies == 0) and type(module) == "table" then
    strategies = (type(mod) == "table" and (mod.strategies or mod)) or strategiesule.strategies or module
end
local get_state = reg.opts and reg.opts.get_state
if (not get_state) and type(module) == "table" then
    get_state = module.build_state or module.get_state
end

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
    assert_true(state.aimed_shot_ready, "aimed_shot_ready")
    assert_true(state.mend_pet_ready, "mend_pet_ready")
    assert_true(state.call_pet_ready, "call_pet_ready")
    assert_true(state.aspect_hawk_ready, "aspect_hawk_ready")
    assert_true(state.concussive_shot_ready, "concussive_shot_ready")
    assert_true(state.wing_clip_ready, "wing_clip_ready")
    assert_true(state.rapid_fire_ready, "rapid_fire_ready")
    assert_true(state.scare_beast_ready, "scare_beast_ready")
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

-- ============================================================================-- Test: aimed_shot_matches (strategy #5)
-- ============================================================================
test("aimed_shot_matches: in combat, not moving, ready -> true", function()
    local ctx = make_context({in_combat = true, is_moving = false})
    local state = get_state(ctx)
    state.aimed_shot_ready = true
    state.is_moving = false
    assert_true(strategies[5].matches(ctx, state), "ready and stationary should match")
end)

test("aimed_shot_matches: moving -> false", function()
    local ctx = make_context({is_moving = true})
    local state = get_state(ctx)
    state.aimed_shot_ready = true
    state.is_moving = true
    assert_false(strategies[5].matches(ctx, state), "moving should not match")
end)

test("aimed_shot_matches: not ready -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.aimed_shot_ready = false
    assert_false(strategies[5].matches(ctx, state), "not ready should not match")
end)

test("aimed_shot_matches: no target -> false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.aimed_shot_ready = true
    state.target = nil
    assert_false(strategies[5].matches(ctx, state), "no target should not match")
end)

test("aimed_shot_matches: nil state -> false", function()
    local ctx = make_context()
    assert_false(strategies[5].matches(ctx, nil), "nil state returns false")
end)

-- ============================================================================
-- Test: rapid_fire_matches (strategy #4)
-- ============================================================================
test("rapid_fire_matches: in combat, ready -> true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.rapid_fire_ready = true
    assert_true(strategies[4].matches(ctx, state), "in combat ready should match")
end)

test("rapid_fire_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.rapid_fire_ready = true
    assert_false(strategies[4].matches(ctx, state), "OOC should not match")
end)

test("rapid_fire_matches: no target -> false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.rapid_fire_ready = true
    state.target = nil
    assert_false(strategies[4].matches(ctx, state), "no target should not match")
end)

test("rapid_fire_matches: nil state -> false", function()
    local ctx = make_context()
    assert_false(strategies[4].matches(ctx, nil), "nil state returns false")
end)

-- ============================================================================
-- Test: mend_pet_matches (strategy #6)
-- ============================================================================
test("mend_pet_matches: in combat, pet low HP, ready -> true", function()
    local ctx = make_context()
    ctx.pet = { get_health_percentage = function() return 40 end }
    local state = get_state(ctx)
    state.mend_pet_ready = true
    state.pet_hp = 40
    assert_true(strategies[6].matches(ctx, state), "low pet HP should match")
end)

test("mend_pet_matches: pet HP above 60 -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.mend_pet_ready = true
    state.pet_hp = 80
    assert_false(strategies[6].matches(ctx, state), "high pet HP should not match")
end)

test("mend_pet_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false})
    ctx.pet = { get_health_percentage = function() return 40 end }
    local state = get_state(ctx)
    state.mend_pet_ready = true
    state.pet_hp = 40
    assert_false(strategies[6].matches(ctx, state), "OOC should not match")
end)

test("mend_pet_matches: no pet -> false", function()
    local ctx = make_context({pet = nil})
    local state = get_state(ctx)
    state.mend_pet_ready = true
    assert_false(strategies[6].matches(ctx, state), "no pet should not match")
end)

-- ============================================================================-- Test: freezing_trap_matches (strategy #10)
-- ============================================================================
test("freezing_trap_matches: in combat, 2+ enemies, ready -> true", function()
    local ctx = make_context({enemies_count = 3})
    local state = get_state(ctx)
    state.freezing_trap_ready = true
    state.enemies = 3
    assert_true(strategies[10].matches(ctx, state), "2+ enemies should match")
end)

test("freezing_trap_matches: single enemy -> false", function()
    local ctx = make_context({enemies_count = 1})
    local state = get_state(ctx)
    state.freezing_trap_ready = true
    state.enemies = 1
    assert_false(strategies[10].matches(ctx, state), "1 enemy should not match")
end)

test("freezing_trap_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false, enemies_count = 3})
    local state = get_state(ctx)
    state.freezing_trap_ready = true
    state.enemies = 3
    assert_false(strategies[10].matches(ctx, state), "OOC should not match")
end)

test("freezing_trap_matches: no target -> false", function()
    local ctx = make_context({target = nil, enemies_count = 3})
    local state = get_state(ctx)
    state.freezing_trap_ready = true
    state.enemies = 3
    state.target = nil
    assert_false(strategies[10].matches(ctx, state), "no target should not match")
end)

-- ============================================================================-- Test: feign_death_matches (strategy #11)
-- ============================================================================
test("feign_death_matches: in combat, low HP, ready -> true", function()
    local ctx = make_context({hp = 20})
    local state = get_state(ctx)
    state.feign_death_ready = true
    state.hp = 20
    assert_true(strategies[11].matches(ctx, state), "low HP in combat should match")
end)

test("feign_death_matches: HP above 30 -> false", function()
    local ctx = make_context({hp = 80})
    local state = get_state(ctx)
    state.feign_death_ready = true
    state.hp = 80
    assert_false(strategies[11].matches(ctx, state), "HP above 30 should not match")
end)

test("feign_death_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false, hp = 20})
    local state = get_state(ctx)
    state.feign_death_ready = true
    state.hp = 20
    assert_false(strategies[11].matches(ctx, state), "OOC should not match")
end)

-- ============================================================================-- Test: serpent_sting_matches (strategy #12)
-- ============================================================================
test("serpent_sting_matches: in combat, DoT expired, ready -> true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.serpent_sting_ready = true
    state.serpent_sting_use = true
    NS.debuff_remains = function(target, spell) return 0 end
    assert_true(strategies[12].matches(ctx, state), "DoT expired should match")
end)

test("serpent_sting_matches: DoT still active -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.serpent_sting_ready = true
    state.serpent_sting_use = true
    NS.debuff_remains = function(target, spell) return 10 end
    assert_false(strategies[12].matches(ctx, state), "active DoT should not match")
    NS.debuff_remains = function(target, spell) return 0 end
end)

test("serpent_sting_matches: disabled -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.serpent_sting_ready = true
    state.serpent_sting_use = false
    assert_false(strategies[12].matches(ctx, state), "disabled should not match")
end)

test("serpent_sting_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.serpent_sting_ready = true
    state.serpent_sting_use = true
    assert_false(strategies[12].matches(ctx, state), "OOC should not match")
end)

test("serpent_sting_matches: no target -> false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.serpent_sting_ready = true
    state.serpent_sting_use = true
    state.target = nil
    assert_false(strategies[12].matches(ctx, state), "no target should not match")
end)

-- ============================================================================-- Test: arcane_shot_matches (strategy #13)
-- ============================================================================
test("arcane_shot_matches: in combat, ready -> true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.arcane_shot_ready = true
    assert_true(strategies[13].matches(ctx, state), "in combat ready should match")
end)

test("arcane_shot_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.arcane_shot_ready = true
    assert_false(strategies[13].matches(ctx, state), "OOC should not match")
end)

test("arcane_shot_matches: no target -> false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.arcane_shot_ready = true
    state.target = nil
    assert_false(strategies[13].matches(ctx, state), "no target should not match")
end)

test("arcane_shot_matches: not ready -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.arcane_shot_ready = false
    assert_false(strategies[13].matches(ctx, state), "not ready should not match")
end)

-- ============================================================================-- Test: multi_shot_matches (strategy #14)
-- ============================================================================
test("multi_shot_matches: in combat, 2+ enemies, ready -> true", function()
    local ctx = make_context({enemies_count = 3})
    local state = get_state(ctx)
    state.multi_shot_ready = true
    state.enemies = 3
    assert_true(strategies[14].matches(ctx, state), "2+ enemies should match")
end)

test("multi_shot_matches: single enemy -> false", function()
    local ctx = make_context({enemies_count = 1})
    local state = get_state(ctx)
    state.multi_shot_ready = true
    state.enemies = 1
    assert_false(strategies[14].matches(ctx, state), "1 enemy should not match")
end)

test("multi_shot_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false, enemies_count = 3})
    local state = get_state(ctx)
    state.multi_shot_ready = true
    state.enemies = 3
    assert_false(strategies[14].matches(ctx, state), "OOC should not match")
end)

test("multi_shot_matches: no target -> false", function()
    local ctx = make_context({target = nil, enemies_count = 3})
    local state = get_state(ctx)
    state.multi_shot_ready = true
    state.enemies = 3
    state.target = nil
    assert_false(strategies[14].matches(ctx, state), "no target should not match")
end)

-- ============================================================================-- Test: steady_shot_matches (strategy #15)
-- ============================================================================
test("steady_shot_matches: in combat, not moving, ready -> true", function()
    local ctx = make_context({is_moving = false})
    local state = get_state(ctx)
    state.steady_shot_ready = true
    state.is_moving = false
    assert_true(strategies[16].matches(ctx, state), "stationary should match")
end)

test("steady_shot_matches: moving -> false", function()
    local ctx = make_context({is_moving = true})
    local state = get_state(ctx)
    state.steady_shot_ready = true
    state.is_moving = true
    assert_false(strategies[16].matches(ctx, state), "moving should not match")
end)

test("steady_shot_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.steady_shot_ready = true
    assert_false(strategies[16].matches(ctx, state), "OOC should not match")
end)

test("steady_shot_matches: no target -> false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.steady_shot_ready = true
    state.target = nil
    assert_false(strategies[16].matches(ctx, state), "no target should not match")
end)

-- ============================================================================
-- Test: Strategy priority ordering
-- ============================================================================

test("strategies: 16 strategies in correct priority order", function()
    local expected = {
        "AspectHawk",
        "CallPet",
        "HuntersMark",
        "RapidFire",
        "AimedShot",
        "MendPet",
        "ConcussiveShot",
        "WingClip",
        "ScareBeast",
        "FreezingTrap",
        "FeignDeath",
        "SerpentSting",
        "ArcaneShot",
        "MultiShot",
        "RaptorStrike",
        "SteadyShot",
    }
    assert_eq(#strategies, 16, "should have 16 strategies")
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

test("execute_AimedShot: does not crash with context", function()
    local ctx = make_context()
    local ok, result = pcall(strategies[5].execute, ctx)
    assert_true(ok, "AimedShot execute with context should not throw")
end)

test("execute_ConcussiveShot: does not crash with context", function()
    local ctx = make_context({enemies_count = 3, hp = 30})
    local ok, result = pcall(strategies[7].execute, ctx)
    assert_true(ok, "ConcussiveShot execute with context should not throw")
end)

test("execute_ScareBeast: does not crash with context", function()
    local ctx = make_context({enemies_count = 3})
    local ok, result = pcall(strategies[9].execute, ctx)
    assert_true(ok, "ScareBeast execute with context should not throw")
end)

test("execute_ArcaneShot: does not crash with context", function()
    local ctx = make_context()
    local ok, result = pcall(strategies[13].execute, ctx)
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
    -- Reload module to reset throttled cast timers (previous test may have executed AspectHawk)
    local ok, mod = pcall(dofile, "EaxRotations/classes/hunter/leveling_sylvanas.lua")
    if not ok then error("Failed to reload leveling module for OOC test: " .. tostring(mod)) end
    strategies = (type(mod) == "table" and (mod.strategies or mod)) or strategies
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

    -- RapidFire (4) is combat-gated, AimedShot (5) is OOC-compatible opener
    assert_false(strategies[4].matches(ctx, state), "RapidFire should not match OOC")
    -- Combat abilities (6-15) should not match OOC
    for i = 6, 15 do
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

    assert_true(strategies[14].matches(ctx, state), "MultiShot should match with 3 enemies")
end)

test("rotation: low HP scenario - feign_death should match", function()
    local ctx = make_context({hp = 20})
    local state = get_state(ctx)
    state.feign_death_ready = true
    state.hp = 20

    assert_true(strategies[11].matches(ctx, state), "FeignDeath should match when HP < 30")
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
    assert_true(strategies[6].matches(ctx, state), "pet HP = 60 should match (not > 60)")
end)

test("edge_pet: mend_pet HP at 61 just above boundary", function()
    local ctx = make_context()
    ctx.pet = { get_health_percentage = function() return 61 end }
    local state = get_state(ctx)
    state.mend_pet_ready = true
    state.pet_hp = 61
    assert_false(strategies[6].matches(ctx, state), "pet HP = 61 should NOT match (> 60)")
end)

test("edge_pet: mend_pet HP = 0 (dead pet) should match", function()
    local ctx = make_context()
    ctx.pet = { get_health_percentage = function() return 0 end }
    local state = get_state(ctx)
    state.mend_pet_ready = true
    state.pet_hp = 0
    assert_true(strategies[6].matches(ctx, state), "pet HP = 0 should match (needs mend)")
end)

test("edge_pet: mend_pet no pet should not match", function()
    local ctx = make_context({pet = nil})
    local state = get_state(ctx)
    state.mend_pet_ready = true
    state.pet_hp = 100
    assert_false(strategies[6].matches(ctx, state), "no pet should not match mend_pet")
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
    assert_false(strategies[12].matches(ctx, state), "remains = 4 should NOT match (4 >= 4 means DoT still active)")
    NS.debuff_remains = saved
end)

test("edge_debuff: serpent_sting remains at 3 should refresh", function()
    local saved = NS.debuff_remains
    NS.debuff_remains = function(target, spell) return 3 end
    local ctx = make_context()
    local state = get_state(ctx)
    state.serpent_sting_ready = true
    state.serpent_sting_use = true
    assert_true(strategies[12].matches(ctx, state), "remains = 3 should match")
    NS.debuff_remains = saved
end)

test("edge_debuff: hunters_mark remains at exactly 30 boundary should not reapply", function()
    local saved = NS.debuff_remains
    NS.debuff_remains = function(target, spell) return 30 end
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.hunters_mark_ready = true
    state.hunters_mark_use = true
    assert_true(strategies[3].matches(ctx, state), "remains = 30 should match (30 is not > 30, so reapply)")
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
    assert_true(strategies[10].matches(ctx, state), "freezing_trap with 2 enemies should match")
end)

test("edge_aoe: freezing_trap with exactly 1 enemy does not match", function()
    local ctx = make_context({enemies_count = 1})
    local state = get_state(ctx)
    state.freezing_trap_ready = true
    state.enemies = 1
    assert_false(strategies[10].matches(ctx, state), "freezing_trap with 1 enemy should NOT match")
end)

test("edge_aoe: multi_shot with exactly 2 enemies matches", function()
    local ctx = make_context({enemies_count = 2})
    local state = get_state(ctx)
    state.multi_shot_ready = true
    state.enemies = 2
    assert_true(strategies[14].matches(ctx, state), "multi_shot with 2 enemies should match")
end)

test("edge_aoe: multi_shot with 1 enemy does not match", function()
    local ctx = make_context({enemies_count = 1})
    local state = get_state(ctx)
    state.multi_shot_ready = true
    state.enemies = 1
    assert_false(strategies[14].matches(ctx, state), "multi_shot with 1 enemy should NOT match")
end)

-- ============================================================================
-- Edge Case: Feign Death boundaries
-- ============================================================================

test("edge_feign: HP exactly at 30 boundary should match", function()
    local ctx = make_context({hp = 30})
    local state = get_state(ctx)
    state.feign_death_ready = true
    state.hp = 30
    assert_true(strategies[11].matches(ctx, state), "hp = 30 should match (not > 30)")
end)

test("edge_feign: HP = 31 just above boundary should not match", function()
    local ctx = make_context({hp = 31})
    local state = get_state(ctx)
    state.feign_death_ready = true
    state.hp = 31
    assert_false(strategies[11].matches(ctx, state), "hp = 31 should NOT match (> 30)")
end)

test("edge_feign: HP = 0 (just barely alive) should match", function()
    local ctx = make_context({hp = 0})
    local state = get_state(ctx)
    state.feign_death_ready = true
    state.hp = 0
    assert_true(strategies[11].matches(ctx, state), "hp = 0 should match")
end)

-- ============================================================================
-- Edge Case: Movement / Steady Shot
-- ============================================================================

test("edge_movement: steady_shot while stationary matches", function()
    local ctx = make_context({is_moving = false})
    local state = get_state(ctx)
    state.steady_shot_ready = true
    state.is_moving = false
    assert_true(strategies[16].matches(ctx, state), "steady_shot stationary should match")
end)

test("edge_movement: steady_shot while moving does not match", function()
    local ctx = make_context({is_moving = true})
    local state = get_state(ctx)
    state.steady_shot_ready = true
    state.is_moving = true
    assert_false(strategies[16].matches(ctx, state), "steady_shot moving should NOT match")
end)

test("edge_movement: arcane_shot still works while moving (no movement restriction)", function()
    local ctx = make_context({is_moving = true})
    local state = get_state(ctx)
    state.arcane_shot_ready = true
    state.is_moving = true
    assert_true(strategies[13].matches(ctx, state), "arcane_shot works while moving")
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
    local ok, result = pcall(strategies[12].matches, ctx, state)
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
    local ok, result = pcall(strategies[12].matches, ctx, state)
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
    state.aimed_shot_ready = false
    state.rapid_fire_ready = false
    state.concussive_shot_ready = false
    state.wing_clip_ready = false
    state.scare_beast_ready = false
    state.serpent_sting_ready = false
    state.arcane_shot_ready = false
    state.steady_shot_ready = false
    state.multi_shot_ready = false
    state.freezing_trap_ready = false
    state.feign_death_ready = false
    state.mend_pet_ready = false
    for i = 6, 15 do
        local ok, matched = pcall(strategies[i].matches, ctx, state)
        assert_true(ok, "strategy[" .. i .. "] matches should not throw")
        assert_false(matched, "strategy[" .. i .. "] should not match when not ready")
    end
    -- RapidFire (4) and AimedShot (5) also checked separately
    assert_false(strategies[4].matches(ctx, state), "strategy[4] (RapidFire) should not match when not ready")
    assert_false(strategies[5].matches(ctx, state), "strategy[5] (AimedShot) should not match when not ready")
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
    assert_false(strategies[12].matches(ctx, state), "disabled serpent sting should not match")
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
    assert_true(strategies[12].matches(ctx, state), "serpent sting works at melee range")
    assert_true(strategies[13].matches(ctx, state), "arcane shot works at melee range")
    assert_true(strategies[16].matches(ctx, state), "steady shot works at melee range")
end)

test("edge_range: utility matches work when target in melee range", function()
    local ctx = make_context({enemies_count = 2})
    local state = get_state(ctx)
    state.freezing_trap_ready = true
    state.enemies = 2
    state.feign_death_ready = true
    state.hp = 20
    assert_true(strategies[10].matches(ctx, state), "freezing trap works at melee range")
    assert_true(strategies[11].matches(ctx, state), "feign death works at any range")
end)

test("edge_range: execute functions do not crash at any target distance", function()
    local ctx = make_context()
    for i = 4, 15 do
        local ok, result = pcall(strategies[i].execute, ctx)
        assert_true(ok, "strategy[" .. i .. "] execute at range should not throw")
    end
end)

-- ============================================================================
-- ============================================================================
-- Edge case: HP boundaries
-- ============================================================================
do
    -- ConcussiveShot: enemies < 2 AND hp > 40 -> no match
    -- So match when: enemies >= 2 OR hp <= 40
    local ctx = make_context({ hp = 40, enemies_count = 1 })
    local state = get_state(ctx)
    state.concussive_shot_ready = true
    state.arcane_shot_ready = true
    state.steady_shot_ready = true
    state.aimed_shot_ready = true
    state.raptor_strike_ready = true
    assert_true(strategies[7].matches(ctx, state), "concussive hp=40 enemies=1 -> match (hp <= 40)")

    local ctx2 = make_context({ hp = 41, enemies_count = 1 })
    local state2 = get_state(ctx2)
    state2.concussive_shot_ready = true
    state2.arcane_shot_ready = true
    state2.steady_shot_ready = true
    state2.aimed_shot_ready = true
    state2.raptor_strike_ready = true
    assert_false(strategies[7].matches(ctx2, state2), "concussive hp=41 enemies=1 -> no match (hp > 40)")

    -- WingClip: hp > 50 -> no match
    local ctx3 = make_context({ hp = 50, enemies_count = 1 })
    ctx3.target = {
        is_valid = function() return true end,
        get_health = function() return 5000 end,
        get_max_health = function() return 10000 end,
        is_casting = function() return false end,
        is_alive = function() return true end,
        get_guid = function() return "mock-target" end,
        get_distance = function(other) return 5 end,
        get_health_percentage = function() return 50 end,
    }
    ctx3.in_melee_range = true
    local state3 = get_state(ctx3)
    state3.wing_clip_ready = true
    state3.raptor_strike_ready = true
    assert_true(strategies[8].matches(ctx3, state3), "wingclip hp=50 -> match (hp <= 50)")

    local ctx4 = make_context({ hp = 51, enemies_count = 1 })
    ctx4.target = {
        is_valid = function() return true end,
        get_health = function() return 5100 end,
        get_max_health = function() return 10000 end,
        is_casting = function() return false end,
        is_alive = function() return true end,
        get_guid = function() return "mock-target" end,
        get_distance = function(other) return 5 end,
        get_health_percentage = function() return 51 end,
    }
    ctx4.in_melee_range = true
    local state4 = get_state(ctx4)
    state4.wing_clip_ready = true
    state4.raptor_strike_ready = true
    assert_false(strategies[8].matches(ctx4, state4), "wingclip hp=51 -> no match (hp > 50)")

    -- FeignDeath: hp > 30 -> no match
    local ctx5 = make_context({ hp = 30 })
    local state5 = get_state(ctx5)
    state5.feign_death_ready = true
    assert_true(strategies[11].matches(ctx5, state5), "feign hp=30 -> match (hp <= 30)")

    local ctx6 = make_context({ hp = 31 })
    local state6 = get_state(ctx6)
    state6.feign_death_ready = true
    assert_false(strategies[11].matches(ctx6, state6), "feign hp=31 -> no match (hp > 30)")
end

-- ============================================================================
-- Edge case: Enemy thresholds
-- ============================================================================
do
    -- ConcussiveShot: enemies 2 hp 35 -> match (enemies >= 2)
    local ctx = make_context({ hp = 35, enemies_count = 2 })
    local state = get_state(ctx)
    state.concussive_shot_ready = true
    state.arcane_shot_ready = true
    state.steady_shot_ready = true
    state.aimed_shot_ready = true
    state.raptor_strike_ready = true
    assert_true(strategies[7].matches(ctx, state), "concussive enemies=2 hp=35 -> match (enemies >= 2)")

    -- ScareBeast: enemies < 2 -> no match
    local ctx2 = make_context({ enemies_count = 2 })
    local state2 = get_state(ctx2)
    state2.scare_beast_ready = true
    state2.arcane_shot_ready = true
    state2.steady_shot_ready = true
    state2.aimed_shot_ready = true
    state2.raptor_strike_ready = true
    assert_true(strategies[9].matches(ctx2, state2), "scarebeast enemies=2 -> match (enemies >= 2)")

    local ctx3 = make_context({ enemies_count = 1 })
    local state3 = get_state(ctx3)
    state3.scare_beast_ready = true
    assert_false(strategies[9].matches(ctx3, state3), "scarebeast enemies=1 -> no match (enemies < 2)")

    -- FreezingTrap: enemies < 2 -> no match
    local ctx4 = make_context({ enemies_count = 2 })
    local state4 = get_state(ctx4)
    state4.freezing_trap_ready = true
    state4.arcane_shot_ready = true
    state4.steady_shot_ready = true
    state4.aimed_shot_ready = true
    state4.raptor_strike_ready = true
    assert_true(strategies[10].matches(ctx4, state4), "freezingtrap enemies=2 -> match (enemies >= 2)")

    local ctx5 = make_context({ enemies_count = 1 })
    local state5 = get_state(ctx5)
    state5.freezing_trap_ready = true
    assert_false(strategies[10].matches(ctx5, state5), "freezingtrap enemies=1 -> no match (enemies < 2)")

    -- MultiShot: enemies < 2 -> no match
    local ctx6 = make_context({ enemies_count = 2 })
    local state6 = get_state(ctx6)
    state6.multi_shot_ready = true
    state6.arcane_shot_ready = true
    state6.steady_shot_ready = true
    state6.aimed_shot_ready = true
    state6.raptor_strike_ready = true
    assert_true(strategies[14].matches(ctx6, state6), "multishot enemies=2 -> match (enemies >= 2)")

    local ctx7 = make_context({ enemies_count = 1 })
    local state7 = get_state(ctx7)
    state7.multi_shot_ready = true
    assert_false(strategies[14].matches(ctx7, state7), "multishot enemies=1 -> no match (enemies < 2)")
end

-- ============================================================================
-- Edge case: Pet management
-- ============================================================================
do
    -- MendPet: pet_hp > 60 -> no match
    local ctx = make_context({})
    ctx.pet = { guid = "mock-pet", get_health_percentage = function() return 60 end }
    local state = get_state(ctx)
    state.mend_pet_ready = true
    state.arcane_shot_ready = true
    state.steady_shot_ready = true
    state.aimed_shot_ready = true
    state.raptor_strike_ready = true
    assert_true(strategies[6].matches(ctx, state), "mendpet pet_hp=60 -> match (pet_hp <= 60)")

    local ctx2 = make_context({})
    ctx2.pet = { guid = "mock-pet", get_health_percentage = function() return 61 end }
    local state2 = get_state(ctx2)
    state2.mend_pet_ready = true
    assert_false(strategies[6].matches(ctx2, state2), "mendpet pet_hp=61 -> no match (pet_hp > 60)")

    -- MendPet: no pet -> no match
    local ctx3 = make_context({})
    ctx3.pet = nil
    local state3 = get_state(ctx3)
    state3.mend_pet_ready = true
    assert_false(strategies[6].matches(ctx3, state3), "mendpet no pet -> no match")

    -- CallPet: pet exists -> no match
    local ctx4 = make_context({ in_combat = false, enemies_count = 0 })
    ctx4.pet = { guid = "mock-pet", get_health_percentage = function() return 100 end }
    local state4 = get_state(ctx4)
    state4.call_pet_ready = true
    assert_false(strategies[2].matches(ctx4, state4), "callpet pet exists -> no match")
end

-- ============================================================================
-- Edge case: Aspect management
-- ============================================================================
do
    -- Reload module to reset `_last_aspect_hawk_cast` throttle (previous tests may have
    -- called execute_AspectHawk, setting the throttle to a near-current timestamp).
    local ok, mod = pcall(dofile, "EaxRotations/classes/hunter/leveling_sylvanas.lua")
    if not ok then error("Failed to reload for aspect edge test: " .. tostring(mod)) end
    strategies = (type(mod) == "table" and (mod.strategies or mod)) or strategies
    -- Refresh get_state from registry (reload sets up a new registration)
    local reg = NS.rotation_registry._registrations["leveling"]
    if reg and reg.opts and reg.opts.get_state then
        get_state = reg.opts.get_state
    end

    -- AspectHawk: already has buff -> no match
    local ctx = make_context({ in_combat = false, enemies_count = 0 })
    local state = get_state(ctx)
    state.has_aspect_hawk = true
    state.aspect_hawk_ready = true
    assert_false(strategies[1].matches(ctx, state), "aspect hawk buff active -> no match")

    -- AspectHawk: OOC, no buff, ready -> match
    local ctx2 = make_context({ in_combat = false, enemies_count = 0 })
    local state2 = get_state(ctx2)
    state2.has_aspect_hawk = false
    state2.aspect_hawk_ready = true
    assert_true(strategies[1].matches(ctx2, state2), "aspect hawk OOC no buff ready -> match")
end

-- ============================================================================
-- Edge case: Debuff refresh boundaries
-- ============================================================================
do
    -- SerpentSting: remains = 3 -> match (refresh)
    local ctx = make_context({})
    local state = get_state(ctx)
    state.serpent_sting_ready = true
    state.serpent_sting_use = true
    state.arcane_shot_ready = true
    state.steady_shot_ready = true
    state.aimed_shot_ready = true
    state.raptor_strike_ready = true
    local saved = NS.debuff_remains
    NS.debuff_remains = function(target, spell) return 3 end
    assert_true(strategies[12].matches(ctx, state), "serpent remains=3 -> match")
    NS.debuff_remains = saved

    local ctx2 = make_context({})
    local state2 = get_state(ctx2)
    state2.serpent_sting_ready = true
    state2.serpent_sting_use = true
    local saved2 = NS.debuff_remains
    NS.debuff_remains = function(target, spell) return 4 end
    assert_false(strategies[12].matches(ctx2, state2), "serpent remains=4 -> no match (>=4)")
    NS.debuff_remains = saved2

    -- HuntersMark: remains = 30 -> match (<=30)
    local ctx3 = make_context({ in_combat = false, enemies_count = 0 })
    local state3 = get_state(ctx3)
    state3.hunters_mark_ready = true
    state3.hunters_mark_use = true
    local saved3 = NS.debuff_remains
    NS.debuff_remains = function(target, spell) return 30 end
    assert_true(strategies[3].matches(ctx3, state3), "huntersmark remains=30 -> match")
    NS.debuff_remains = saved3

    local ctx4 = make_context({ in_combat = false, enemies_count = 0 })
    local state4 = get_state(ctx4)
    state4.hunters_mark_ready = true
    state4.hunters_mark_use = true
    local saved4 = NS.debuff_remains
    NS.debuff_remains = function(target, spell) return 31 end
    assert_false(strategies[3].matches(ctx4, state4), "huntersmark remains=31 -> no match (>30)")
    NS.debuff_remains = saved4
end

-- ============================================================================
-- Edge case: Movement and melee guards
-- ============================================================================
do
    -- AimedShot: is_moving -> no match
    local ctx = make_context({ is_moving = true })
    local state = get_state(ctx)
    state.aimed_shot_ready = true
    state.arcane_shot_ready = true
    state.steady_shot_ready = true
    state.raptor_strike_ready = true
    assert_false(strategies[5].matches(ctx, state), "aimed moving -> no match")

    -- SteadyShot: is_moving -> no match
    local ctx2 = make_context({ is_moving = true })
    local state2 = get_state(ctx2)
    state2.steady_shot_ready = true
    state2.arcane_shot_ready = true
    state2.raptor_strike_ready = true
    assert_false(strategies[16].matches(ctx2, state2), "steady moving -> no match")

    -- WingClip: not in melee -> no match
    local ctx3 = make_context({ hp = 40, enemies_count = 1 })
    ctx3.in_melee_range = false
    ctx3.target = {
        is_valid = function() return true end,
        get_health = function() return 5000 end,
        get_max_health = function() return 10000 end,
        is_casting = function() return false end,
        is_alive = function() return true end,
        get_guid = function() return "mock-target" end,
        get_distance = function(other) return 15 end,
        get_health_percentage = function() return 40 end,
    }
    local state3 = get_state(ctx3)
    state3.wing_clip_ready = true
    state3.raptor_strike_ready = true
    assert_false(strategies[8].matches(ctx3, state3), "wingclip not melee -> no match")

    -- RaptorStrike: not in melee -> no match
    local ctx4 = make_context({})
    ctx4.in_melee_range = false
    local state4 = get_state(ctx4)
    state4.raptor_strike_ready = true
    state4.arcane_shot_ready = true
    state4.steady_shot_ready = true
    state4.aimed_shot_ready = true
    assert_false(strategies[15].matches(ctx4, state4), "raptor not melee -> no match")
end

-- ============================================================================
-- Edge case: Settings toggle
-- ============================================================================
do
    -- SerpentSting: serpent_sting_use disabled -> no match
    local ctx = make_context({})
    ctx.settings.leveling_serpent_sting_use = false
    local state = get_state(ctx)
    state.serpent_sting_ready = true
    state.arcane_shot_ready = true
    state.steady_shot_ready = true
    state.aimed_shot_ready = true
    state.raptor_strike_ready = true
    assert_false(strategies[12].matches(ctx, state), "serpent sting setting disabled -> no match")

    -- HuntersMark: hunters_mark_use disabled -> no match
    local ctx2 = make_context({ in_combat = false, enemies_count = 0 })
    ctx2.settings.leveling_hunters_mark_use = false
    local state2 = get_state(ctx2)
    state2.hunters_mark_ready = true
    assert_false(strategies[3].matches(ctx2, state2), "hunters mark setting disabled -> no match")
end

-- ============================================================================
-- Edge case: OOC guards
-- ============================================================================
do
    -- RapidFire: OOC -> no match
    local ctx = make_context({ in_combat = false })
    local state = get_state(ctx)
    state.rapid_fire_ready = true
    assert_false(strategies[4].matches(ctx, state), "rapidfire OOC -> no match")

    -- AimedShot: no OOC guard, matches OOC for pulling
    local ctx2 = make_context({ in_combat = false })
    local state2 = get_state(ctx2)
    state2.aimed_shot_ready = true
    assert_true(strategies[5].matches(ctx2, state2), "aimed OOC -> match (no OOC guard)")

    -- ArcaneShot: OOC -> no match
    local ctx3 = make_context({ in_combat = false })
    local state3 = get_state(ctx3)
    state3.arcane_shot_ready = true
    assert_false(strategies[13].matches(ctx3, state3), "arcane OOC -> no match")

    -- MultiShot: OOC -> no match
    local ctx4 = make_context({ in_combat = false })
    local state4 = get_state(ctx4)
    state4.multi_shot_ready = true
    assert_false(strategies[14].matches(ctx4, state4), "multishot OOC -> no match")

    -- RaptorStrike: OOC -> no match
    local ctx5 = make_context({ in_combat = false })
    local state5 = get_state(ctx5)
    state5.raptor_strike_ready = true
    assert_false(strategies[15].matches(ctx5, state5), "raptor OOC -> no match")

    -- SteadyShot: OOC -> no match
    local ctx6 = make_context({ in_combat = false })
    local state6 = get_state(ctx6)
    state6.steady_shot_ready = true
    assert_false(strategies[16].matches(ctx6, state6), "steady OOC -> no match")
end

-- ============================================================================
-- API crash: NS.try_cast nil/throwing
-- ============================================================================
do
    local saved = NS.try_cast
    local ctx = make_context({})
    local state = get_state(ctx)
    state.arcane_shot_ready = true
    state.steady_shot_ready = true
    state.aimed_shot_ready = true
    state.raptor_strike_ready = true
    state.wing_clip_ready = true
    state.concussive_shot_ready = true
    state.scare_beast_ready = true
    state.freezing_trap_ready = true
    state.mend_pet_ready = true
    state.hunters_mark_ready = true
    state.call_pet_ready = true
    state.aspect_hawk_ready = true
    state.rapid_fire_ready = true
    state.feign_death_ready = true
    state.serpent_sting_ready = true
    state.multi_shot_ready = true

    -- NS.try_cast = nil -> execute should not crash
    NS.try_cast = nil
    for i = 1, #strategies do
        local ok, result = pcall(strategies[i].execute, ctx)
        assert_true(ok, "try_cast=nil: strategy " .. i .. " execute did not crash")
    end

    -- NS.try_cast throws -> execute should not crash
    NS.try_cast = function() error("simulated throw") end
    for i = 1, #strategies do
        local ok, result = pcall(strategies[i].execute, ctx)
        assert_true(ok, "try_cast=throw: strategy " .. i .. " execute did not crash")
    end

    NS.try_cast = saved
end

-- ============================================================================
-- Rotation crash: nil context for all execute functions
-- ============================================================================
do
    for i = 1, #strategies do
        local ok, result = pcall(strategies[i].execute, nil)
        assert_true(ok, "execute nil ctx: strategy " .. i .. " did not crash")
    end
end

-- ============================================================================
-- Rotation crash: no-arg execute for all functions
-- ============================================================================
do
    for i = 1, #strategies do
        local ok, result = pcall(strategies[i].execute)
        assert_true(ok, "execute no-arg: strategy " .. i .. " did not crash")
    end
end

-- Summary
-- ============================================================================
-- Deep dive: ConcussiveShot - enemies 1/2 × HP 40/41 OR matrix
-- ============================================================================
do
    -- Condition: if (state.enemies or 0) < 2 and (state.hp or 100) > 40 then return false end
    -- So: enemies < 2 AND hp > 40 -> no match
    --     enemies >= 2 OR hp <= 40 -> match

    -- enemies=1, hp=50 -> both conditions true -> no match
    local ctx = make_context({in_combat = true, enemies_count = 1, hp = 50})
    local state = get_state(ctx)
    state.concussive_shot_ready = true
    state.hp = 50
    state.enemies = 1
    assert_false(strategies[7].matches(ctx, state), "concussive enemies=1 hp=50 -> no match")

    -- enemies=2, hp=50 -> enemies >= 2 -> match
    local ctx2 = make_context({in_combat = true, enemies_count = 2, hp = 50})
    local state2 = get_state(ctx2)
    state2.concussive_shot_ready = true
    state2.hp = 50
    state2.enemies = 2
    assert_true(strategies[7].matches(ctx2, state2), "concussive enemies=2 hp=50 -> match")

    -- enemies=1, hp=40 -> hp <= 40 -> match
    local ctx3 = make_context({in_combat = true, enemies_count = 1, hp = 40})
    local state3 = get_state(ctx3)
    state3.concussive_shot_ready = true
    state3.hp = 40
    state3.enemies = 1
    assert_true(strategies[7].matches(ctx3, state3), "concussive enemies=1 hp=40 -> match")

    -- enemies=2, hp=40 -> both satisfy -> match
    local ctx4 = make_context({in_combat = true, enemies_count = 2, hp = 40})
    local state4 = get_state(ctx4)
    state4.concussive_shot_ready = true
    state4.hp = 40
    state4.enemies = 2
    assert_true(strategies[7].matches(ctx4, state4), "concussive enemies=2 hp=40 -> match")

    -- enemies=0, hp=100 -> no enemies, high hp -> no match
    local ctx5 = make_context({in_combat = true, enemies_count = 0, hp = 100})
    local state5 = get_state(ctx5)
    state5.concussive_shot_ready = true
    state5.hp = 100
    state5.enemies = 0
    assert_false(strategies[7].matches(ctx5, state5), "concussive enemies=0 hp=100 -> no match")

    -- OOC -> no match
    local ctx6 = make_context({in_combat = false})
    local state6 = get_state(ctx6)
    state6.concussive_shot_ready = true
    state6.hp = 20
    state6.enemies = 3
    assert_false(strategies[7].matches(ctx6, state6), "concussive OOC -> no match")

    -- not ready -> no match
    local ctx7 = make_context({in_combat = true, enemies_count = 3, hp = 20})
    local state7 = get_state(ctx7)
    state7.concussive_shot_ready = false
    state7.hp = 20
    state7.enemies = 3
    assert_false(strategies[7].matches(ctx7, state7), "concussive not ready -> no match")

    -- no target -> no match
    local ctx8 = make_context({in_combat = true, enemies_count = 3, hp = 20})
    ctx8.target = nil
    local state8 = get_state(ctx8)
    state8.concussive_shot_ready = true
    state8.hp = 20
    state8.enemies = 3
    state8.target = nil
    assert_false(strategies[7].matches(ctx8, state8), "concussive no target -> no match")
end

-- ============================================================================
-- Deep dive: WingClip - hp 50/51 + melee guard
-- ============================================================================
do
    -- Condition: in_melee required, hp <= 50

    -- hp=50, in_melee -> match
    local ctx = make_context({in_combat = true, hp = 50, in_melee_range = true})
    local state = get_state(ctx)
    state.wing_clip_ready = true
    state.hp = 50
    state.in_melee = true
    assert_true(strategies[8].matches(ctx, state), "wingclip hp=50 melee -> match")

    -- hp=51, in_melee -> no match (hp > 50)
    local ctx2 = make_context({in_combat = true, hp = 51, in_melee_range = true})
    local state2 = get_state(ctx2)
    state2.wing_clip_ready = true
    state2.hp = 51
    state2.in_melee = true
    assert_false(strategies[8].matches(ctx2, state2), "wingclip hp=51 melee -> no match")

    -- hp=30, not melee -> no match
    local ctx3 = make_context({in_combat = true, hp = 30, in_melee_range = false})
    local state3 = get_state(ctx3)
    state3.wing_clip_ready = true
    state3.hp = 30
    state3.in_melee = false
    assert_false(strategies[8].matches(ctx3, state3), "wingclip not melee -> no match")

    -- hp=20, in_melee, OOC -> no match
    local ctx4 = make_context({in_combat = false, hp = 20, in_melee_range = true})
    local state4 = get_state(ctx4)
    state4.wing_clip_ready = true
    state4.hp = 20
    state4.in_melee = true
    assert_false(strategies[8].matches(ctx4, state4), "wingclip OOC -> no match")

    -- not ready -> no match
    local ctx5 = make_context({in_combat = true, hp = 30, in_melee_range = true})
    local state5 = get_state(ctx5)
    state5.wing_clip_ready = false
    state5.hp = 30
    state5.in_melee = true
    assert_false(strategies[8].matches(ctx5, state5), "wingclip not ready -> no match")

    -- no target -> no match
    local ctx6 = make_context({in_combat = true, hp = 30, in_melee_range = true})
    ctx6.target = nil
    local state6 = get_state(ctx6)
    state6.wing_clip_ready = true
    state6.hp = 30
    state6.in_melee = true
    state6.target = nil
    assert_false(strategies[8].matches(ctx6, state6), "wingclip no target -> no match")
end

-- ============================================================================
-- Deep dive: ScareBeast - enemies threshold + guards
-- ============================================================================
do
    -- Condition: in_combat, target, enemies >= 2

    -- enemies=2 -> match
    local ctx = make_context({in_combat = true, enemies_count = 2})
    local state = get_state(ctx)
    state.scare_beast_ready = true
    state.enemies = 2
    assert_true(strategies[9].matches(ctx, state), "scarebeast enemies=2 -> match")

    -- enemies=1 -> no match
    local ctx2 = make_context({in_combat = true, enemies_count = 1})
    local state2 = get_state(ctx2)
    state2.scare_beast_ready = true
    state2.enemies = 1
    assert_false(strategies[9].matches(ctx2, state2), "scarebeast enemies=1 -> no match")

    -- OOC -> no match
    local ctx3 = make_context({in_combat = false, enemies_count = 3})
    local state3 = get_state(ctx3)
    state3.scare_beast_ready = true
    state3.enemies = 3
    assert_false(strategies[9].matches(ctx3, state3), "scarebeast OOC -> no match")

    -- no target -> no match
    local ctx4 = make_context({in_combat = true, enemies_count = 3})
    ctx4.target = nil
    local state4 = get_state(ctx4)
    state4.scare_beast_ready = true
    state4.enemies = 3
    state4.target = nil
    assert_false(strategies[9].matches(ctx4, state4), "scarebeast no target -> no match")

    -- not ready -> no match
    local ctx5 = make_context({in_combat = true, enemies_count = 3})
    local state5 = get_state(ctx5)
    state5.scare_beast_ready = false
    state5.enemies = 3
    assert_false(strategies[9].matches(ctx5, state5), "scarebeast not ready -> no match")
end

-- ============================================================================
-- Deep dive: FreezingTrap - extra guards beyond enemy threshold
-- ============================================================================
do
    -- OOC -> no match
    local ctx = make_context({in_combat = false, enemies_count = 3})
    local state = get_state(ctx)
    state.freezing_trap_ready = true
    state.enemies = 3
    assert_false(strategies[10].matches(ctx, state), "trap OOC -> no match")

    -- no target -> no match
    local ctx2 = make_context({in_combat = true, enemies_count = 3})
    ctx2.target = nil
    local state2 = get_state(ctx2)
    state2.freezing_trap_ready = true
    state2.enemies = 3
    state2.target = nil
    assert_false(strategies[10].matches(ctx2, state2), "trap no target -> no match")

    -- not ready -> no match
    local ctx3 = make_context({in_combat = true, enemies_count = 3})
    local state3 = get_state(ctx3)
    state3.freezing_trap_ready = false
    state3.enemies = 3
    assert_false(strategies[10].matches(ctx3, state3), "trap not ready -> no match")
end

-- ============================================================================
-- Deep dive: RapidFire - OOC + no target guards
-- ============================================================================
do
    -- In combat, has target -> match
    local ctx = make_context({in_combat = true})
    local state = get_state(ctx)
    state.rapid_fire_ready = true
    assert_true(strategies[4].matches(ctx, state), "rapidfire in combat -> match")

    -- OOC -> no match
    local ctx2 = make_context({in_combat = false})
    local state2 = get_state(ctx2)
    state2.rapid_fire_ready = true
    assert_false(strategies[4].matches(ctx2, state2), "rapidfire OOC -> no match")

    -- no target -> no match
    local ctx3 = make_context({in_combat = true})
    ctx3.target = nil
    local state3 = get_state(ctx3)
    state3.rapid_fire_ready = true
    state3.target = nil
    assert_false(strategies[4].matches(ctx3, state3), "rapidfire no target -> no match")

    -- not ready -> no match
    local ctx4 = make_context({in_combat = true})
    local state4 = get_state(ctx4)
    state4.rapid_fire_ready = false
    assert_false(strategies[4].matches(ctx4, state4), "rapidfire not ready -> no match")
end

-- ============================================================================
-- Deep dive: AimedShot + SteadyShot - movement guards
-- ============================================================================
do
    -- AimedShot: not moving -> match
    local ctx = make_context({in_combat = true, is_moving = false})
    local state = get_state(ctx)
    state.aimed_shot_ready = true
    assert_true(strategies[5].matches(ctx, state), "aimedshot stationary -> match")

    -- AimedShot: moving -> no match
    local ctx2 = make_context({in_combat = true, is_moving = true})
    local state2 = get_state(ctx2)
    state2.aimed_shot_ready = true
    assert_false(strategies[5].matches(ctx2, state2), "aimedshot moving -> no match")

    -- AimedShot: no target -> no match
    local ctx3 = make_context({in_combat = true})
    ctx3.target = nil
    local state3 = get_state(ctx3)
    state3.aimed_shot_ready = true
    state3.target = nil
    assert_false(strategies[5].matches(ctx3, state3), "aimedshot no target -> no match")

    -- AimedShot: not ready -> no match
    local ctx4 = make_context({in_combat = true, is_moving = false})
    local state4 = get_state(ctx4)
    state4.aimed_shot_ready = false
    assert_false(strategies[5].matches(ctx4, state4), "aimedshot not ready -> no match")

    -- SteadyShot: moving -> no match
    local ctx5 = make_context({in_combat = true, is_moving = true})
    local state5 = get_state(ctx5)
    state5.steady_shot_ready = true
    assert_false(strategies[16].matches(ctx5, state5), "steadyshot moving -> no match")

    -- SteadyShot: not moving -> match
    local ctx6 = make_context({in_combat = true, is_moving = false})
    local state6 = get_state(ctx6)
    state6.steady_shot_ready = true
    assert_true(strategies[16].matches(ctx6, state6), "steadyshot stationary -> match")

    -- SteadyShot: no target -> no match
    local ctx7 = make_context({in_combat = true})
    ctx7.target = nil
    local state7 = get_state(ctx7)
    state7.steady_shot_ready = true
    state7.target = nil
    assert_false(strategies[16].matches(ctx7, state7), "steadyshot no target -> no match")
end

-- ============================================================================
-- Deep dive: ArcaneShot + MultiShot - OOC + no target + enemies
-- ============================================================================
do
    -- ArcaneShot: OOC -> no match
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.arcane_shot_ready = true
    assert_false(strategies[13].matches(ctx, state), "arcaneshot OOC -> no match")

    -- ArcaneShot: no target -> no match
    local ctx2 = make_context({in_combat = true})
    ctx2.target = nil
    local state2 = get_state(ctx2)
    state2.arcane_shot_ready = true
    state2.target = nil
    assert_false(strategies[13].matches(ctx2, state2), "arcaneshot no target -> no match")

    -- ArcaneShot: not ready -> no match
    local ctx3 = make_context({in_combat = true})
    local state3 = get_state(ctx3)
    state3.arcane_shot_ready = false
    assert_false(strategies[13].matches(ctx3, state3), "arcaneshot not ready -> no match")

    -- MultiShot: OOC -> no match
    local ctx4 = make_context({in_combat = false, enemies_count = 3})
    local state4 = get_state(ctx4)
    state4.multi_shot_ready = true
    state4.enemies = 3
    assert_false(strategies[14].matches(ctx4, state4), "multishot OOC -> no match")

    -- MultiShot: no target -> no match
    local ctx5 = make_context({in_combat = true, enemies_count = 3})
    ctx5.target = nil
    local state5 = get_state(ctx5)
    state5.multi_shot_ready = true
    state5.enemies = 3
    state5.target = nil
    assert_false(strategies[14].matches(ctx5, state5), "multishot no target -> no match")

    -- MultiShot: enemies=0 -> no match
    local ctx6 = make_context({in_combat = true, enemies_count = 0})
    local state6 = get_state(ctx6)
    state6.multi_shot_ready = true
    state6.enemies = 0
    assert_false(strategies[14].matches(ctx6, state6), "multishot enemies=0 -> no match")
end

-- ============================================================================
-- Deep dive: RaptorStrike - melee range + OOC + no target
-- ============================================================================
do
    -- RaptorStrike: melee, in_combat -> match
    local ctx = make_context({in_combat = true, in_melee_range = true})
    local state = get_state(ctx)
    state.raptor_strike_ready = true
    state.in_melee = true
    assert_true(strategies[15].matches(ctx, state), "raptor melee combat -> match")

    -- RaptorStrike: not melee -> no match
    local ctx2 = make_context({in_combat = true, in_melee_range = false})
    local state2 = get_state(ctx2)
    state2.raptor_strike_ready = true
    state2.in_melee = false
    assert_false(strategies[15].matches(ctx2, state2), "raptor not melee -> no match")

    -- RaptorStrike: OOC -> no match
    local ctx3 = make_context({in_combat = false, in_melee_range = true})
    local state3 = get_state(ctx3)
    state3.raptor_strike_ready = true
    state3.in_melee = true
    assert_false(strategies[15].matches(ctx3, state3), "raptor OOC -> no match")

    -- RaptorStrike: no target -> no match
    local ctx4 = make_context({in_combat = true, in_melee_range = true})
    ctx4.target = nil
    local state4 = get_state(ctx4)
    state4.raptor_strike_ready = true
    state4.in_melee = true
    state4.target = nil
    assert_false(strategies[15].matches(ctx4, state4), "raptor no target -> no match")

    -- RaptorStrike: not ready -> no match
    local ctx5 = make_context({in_combat = true, in_melee_range = true})
    local state5 = get_state(ctx5)
    state5.raptor_strike_ready = false
    state5.in_melee = true
    assert_false(strategies[15].matches(ctx5, state5), "raptor not ready -> no match")
end

-- ============================================================================
-- Deep dive: Null target guards for all target-dependent strategies
-- ============================================================================
do
    local target_dependent = {3, 4, 5, 7, 8, 9, 10, 12, 13, 15, 16}
    -- indices: HuntersMark(3), RapidFire(4), AimedShot(5), Concussive(7),
    -- WingClip(8), ScareBeast(9), FreezingTrap(10),
    -- SerpentSting(11), ArcaneShot(12), MultiShot(13), RaptorStrike(15), SteadyShot(16)
    for _, idx in ipairs(target_dependent) do
        local ctx = make_context({in_combat = true})
        ctx.target = nil
        local state = get_state(ctx)
        -- Set all ready states to true
        for k, v in pairs(state) do
            if type(k) == "string" and k:match("_ready$") then
                state[k] = true
            end
        end
        state.hp = 30
        state.enemies = 5
        state.in_melee = true
        state.target = nil
        local ok, result = pcall(strategies[idx].matches, ctx, state)
        assert_false(result, strategies[idx].name .. " no target -> no match")
    end
end

-- ============================================================================
-- Deep dive: OOC guards for all combat strategies
-- ============================================================================
do
    local combat_strategies = {4, 7, 8, 9, 10, 11, 12, 13, 15, 16}
    -- RapidFire(4), Concussive(7), WingClip(8), ScareBeast(9),
    -- FreezingTrap(10), SerpentSting(11), ArcaneShot(12), MultiShot(13),
    -- RaptorStrike(15), SteadyShot(16)
    -- Note: AspectHawk(1), CallPet(2), HuntersMark(3) are OOC-only (already tested)
    -- MendPet(6) requires in_combat (already tested)
    -- FeignDeath(14) requires in_combat (already tested)
    for _, idx in ipairs(combat_strategies) do
        local ctx = make_context({in_combat = false})
        local state = get_state(ctx)
        for k, v in pairs(state) do
            if type(k) == "string" and k:match("_ready$") then
                state[k] = true
            end
        end
        state.hp = 20
        state.enemies = 5
        state.in_melee = true
        state.in_combat = false
        local ok, result = pcall(strategies[idx].matches, ctx, state)
        assert_false(result, strategies[idx].name .. " OOC -> no match")
    end
end

-- ============================================================================
-- Deep dive: Execute functions crash safety (NS.try_cast throwing)
-- ============================================================================
do
    local saved = NS.try_cast
    NS.try_cast = function() error('simulated throw') end
    local ctx = make_context()
    for i = 1, #strategies do
        local ok, result = pcall(strategies[i].execute, ctx)
        assert_true(ok, 'try_cast=throw: strategy ' .. i .. ' execute did not crash')
    end
    NS.try_cast = saved
end

-- ============================================================================
-- Deep dive: Execute functions nil context + no-arg
-- ============================================================================
do
    for i = 1, #strategies do
        local ok, result = pcall(strategies[i].execute, nil)
        assert_true(ok, 'execute nil ctx: strategy ' .. i .. ' did not crash')
    end
    for i = 1, #strategies do
        local ok, result = pcall(strategies[i].execute)
        assert_true(ok, 'execute no-arg: strategy ' .. i .. ' did not crash')
    end
end
-- ============================================================================


-- ============================================================================
-- DEEP DIVE: OOC guard loop (combat-gated strategies return false OOC)
-- ============================================================================

-- Combat-gated (have "if not state.in_combat then return false end"):
--   4 RapidFire, 6 MendPet, 7 ConcussiveShot, 8 WingClip, 9 ScareBeast,
--   10 FreezingTrap, 11 FeignDeath, 12 SerpentSting, 13 ArcaneShot,
--   14 MultiShot, 15 RaptorStrike, 16 SteadyShot
-- OOC-only {1,2,3} are tested separately below.
-- AimedShot (5) has NO combat gate (used for pulling).

local combat_gated = {4, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16}

do
    -- Reload module to reset `_last_aspect_hawk_cast` (AspectHawk throttle)
    local ok, mod = pcall(dofile, "EaxRotations/classes/hunter/leveling_sylvanas.lua")
    if not ok then error("Failed to reload for OOC guard test: " .. tostring(mod)) end
    strategies = (type(mod) == "table" and (mod.strategies or mod)) or strategies
    local reg = NS.rotation_registry._registrations["leveling"]
    if reg and reg.opts and reg.opts.get_state then
        get_state = reg.opts.get_state
    end

    local ctx = make_context({in_combat = false, enemies_count = 5, hp = 20})
    ctx.pet = { get_health_percentage = function() return 40 end }
    local state = get_state(ctx)
    -- Set all ready states to true
    for k, v in pairs(state) do
        if type(k) == "string" and k:match("_ready$") then
            state[k] = true
        end
    end
    state.hp = 20
    state.enemies = 5
    state.in_melee = true
    state.in_combat = false
    state.serpent_sting_use = true
    state.hunters_mark_use = true
    state.pet_hp = 40

    for _, idx in ipairs(combat_gated) do
        local ok, result = pcall(strategies[idx].matches, ctx, state)
        assert_false(result, strategies[idx].name .. " OOC -> no match")
    end

    -- OOC-only {1,2,3} should MATCH OOC (they check state.in_combat == false)
    state.has_aspect_hawk = false
    ctx.pet = nil
    state.call_pet_ready = true
    assert_true(strategies[1].matches(ctx, state), "AspectHawk OOC -> match")
    assert_true(strategies[2].matches(ctx, state), "CallPet OOC -> match")
end

-- OOC-only strategies {1,2,3} should NOT match in combat
do
    local ctx = make_context({in_combat = true})
    local state = get_state(ctx)
    state.has_aspect_hawk = false
    state.aspect_hawk_ready = true
    state.call_pet_ready = true
    state.hunters_mark_ready = true
    state.hunters_mark_use = true
    assert_false(strategies[1].matches(ctx, state), "AspectHawk in combat -> no match")
    assert_false(strategies[2].matches(ctx, state), "CallPet in combat -> no match")
    assert_false(strategies[3].matches(ctx, state), "HuntersMark in combat -> no match")
end

-- AimedShot (5) has NO combat gate — verified matches OOC
do
    local ctx = make_context({in_combat = false, is_moving = false})
    local state = get_state(ctx)
    state.aimed_shot_ready = true
    state.is_moving = false
    assert_true(strategies[5].matches(ctx, state), "AimedShot OOC -> match (no combat gate)")
end

-- ============================================================================
-- DEEP DIVE: Nil target guard loop (target-dependent strategies with nil target)
-- ============================================================================

-- Target-dependent (have "if not state.target then return false end"):
--   3 HuntersMark, 4 RapidFire, 5 AimedShot, 7 ConcussiveShot,
--   8 WingClip, 9 ScareBeast, 10 FreezingTrap, 12 SerpentSting,
--   13 ArcaneShot, 14 MultiShot, 15 RaptorStrike, 16 SteadyShot
-- No target check: {1,2,6,11}

local target_dependent = {3, 4, 5, 7, 8, 9, 10, 12, 13, 14, 15, 16}

do
    for _, idx in ipairs(target_dependent) do
        local ctx = make_context({in_combat = true, enemies_count = 5, hp = 20})
        ctx.target = nil
        local state = get_state(ctx)
        for k, v in pairs(state) do
            if type(k) == "string" and k:match("_ready$") then
                state[k] = true
            end
        end
        state.hp = 20
        state.enemies = 5
        state.in_melee = true
        state.serpent_sting_use = true
        state.hunters_mark_use = true
        state.is_moving = false
        state.target = nil
        local ok, result = pcall(strategies[idx].matches, ctx, state)
        assert_false(result, strategies[idx].name .. " nil target -> no match")
    end
end

-- ============================================================================
-- DEEP DIVE: Missing ready=false guards for individual strategies
-- ============================================================================

do
    -- HuntersMark (3): not ready -> no match
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.hunters_mark_use = true
    state.hunters_mark_ready = false
    NS.debuff_remains = function(target, spell) return 0 end
    assert_false(strategies[3].matches(ctx, state), "HuntersMark not ready -> no match")

    -- MendPet (6): not ready -> no match
    local ctx2 = make_context({in_combat = true})
    ctx2.pet = { get_health_percentage = function() return 40 end }
    local state2 = get_state(ctx2)
    state2.mend_pet_ready = false
    state2.pet_hp = 40
    assert_false(strategies[6].matches(ctx2, state2), "MendPet not ready -> no match")

    -- FeignDeath (11): not ready -> no match
    local ctx3 = make_context({in_combat = true, hp = 20})
    local state3 = get_state(ctx3)
    state3.feign_death_ready = false
    state3.hp = 20
    assert_false(strategies[11].matches(ctx3, state3), "FeignDeath not ready -> no match")

    -- SerpentSting (12): not ready -> no match
    local ctx4 = make_context({in_combat = true})
    local state4 = get_state(ctx4)
    state4.serpent_sting_ready = false
    state4.serpent_sting_use = true
    NS.debuff_remains = function(target, spell) return 0 end
    assert_false(strategies[12].matches(ctx4, state4), "SerpentSting not ready -> no match")

    -- MultiShot (14): not ready -> no match
    local ctx5 = make_context({in_combat = true, enemies_count = 3})
    local state5 = get_state(ctx5)
    state5.multi_shot_ready = false
    state5.enemies = 3
    assert_false(strategies[14].matches(ctx5, state5), "MultiShot not ready -> no match")

    -- SteadyShot (16): not ready -> no match
    local ctx6 = make_context({in_combat = true, is_moving = false})
    local state6 = get_state(ctx6)
    state6.steady_shot_ready = false
    state6.is_moving = false
    assert_false(strategies[16].matches(ctx6, state6), "SteadyShot not ready -> no match")
end

-- ============================================================================
-- DEEP DIVE: API crash safety — additional coverage
-- ============================================================================

-- NS.debuff_remains throws in hunters_mark_matches (already has nil test)
do
    local saved = NS.debuff_remains
    NS.debuff_remains = function() error("simulated throw") end
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.hunters_mark_ready = true
    state.hunters_mark_use = true
    local ok, result = pcall(strategies[3].matches, ctx, state)
    assert_true(ok, "throwing NS.debuff_remains in HuntersMark should not crash")
    NS.debuff_remains = saved
end

-- pet.get_health_percentage throws in mend_pet build_state
do
    local ctx = make_context({in_combat = true})
    ctx.pet = { get_health_percentage = function() error("simulated throw") end }
    local state = get_state(ctx)
    assert_eq(state.pet_hp, 100, "pet.get_health_percentage throwing -> pet_hp defaults to 100")
end

-- NS.try_cast returns false (not just nil/throw) for execute functions
do
    local saved = NS.try_cast
    NS.try_cast = function() return false end
    local ctx = make_context()
    for i = 1, #strategies do
        local ok, result = pcall(strategies[i].execute, ctx)
        assert_true(ok, "try_cast=false: strategy " .. i .. " execute did not crash")
    end
    NS.try_cast = saved
end

-- MendPet: NS.spell_ready nil/throw protection in build_state
do
    local saved = NS.spell_ready
    NS.spell_ready = nil
    local ctx = make_context({in_combat = true})
    ctx.pet = { get_health_percentage = function() return 40 end }
    local state = get_state(ctx)
    assert_false(state.mend_pet_ready, "nil NS.spell_ready -> mend_pet_ready false")
    NS.spell_ready = saved
end

-- ============================================================================
-- DEEP DIVE: All execute with try_cast returning false
-- ============================================================================

do
    local saved = NS.try_cast
    NS.try_cast = function() return false end
    local ctx = make_context()
    for i = 1, #strategies do
        local ok, result = pcall(strategies[i].execute, ctx)
        assert_true(ok, "try_cast=false: strategy " .. i .. " execute safe")
    end
    NS.try_cast = saved
end

-- ============================================================================
-- DEEP DIVE: Nil state safety for all match functions
-- ============================================================================

do
    local ctx = make_context()
    for i = 1, #strategies do
        local ok, result = pcall(strategies[i].matches, ctx, nil)
        assert_true(ok, "strategy " .. i .. " matches(ctx, nil) did not crash")
    end
end

-- ============================================================================
-- DEEP DIVE: ConcussiveShot enemies×HP OR matrix — full coverage
-- ============================================================================

do
    -- Condition: if (state.enemies or 0) < 2 and (state.hp or 100) > 40 then return false end
    -- Matrix: (enemies=1,hp=50) -> no match; (enemies=2,hp=50) -> match;
    --         (enemies=1,hp=40) -> match; (enemies=2,hp=40) -> match;
    --         (enemies=0,hp=100) -> no match

    -- Already covered by existing tests, add remainder:
    -- enemies=3, hp=100 -> match (enemies >= 2)
    local ctx = make_context({in_combat = true, enemies_count = 3, hp = 100})
    local state = get_state(ctx)
    state.concussive_shot_ready = true
    state.hp = 100
    state.enemies = 3
    assert_true(strategies[7].matches(ctx, state), "concussive enemies=3 hp=100 -> match (enemies >= 2)")

    -- enemies=1, hp=41 -> no match (both conditions hold)
    local ctx2 = make_context({in_combat = true, enemies_count = 1, hp = 41})
    local state2 = get_state(ctx2)
    state2.concussive_shot_ready = true
    state2.hp = 41
    state2.enemies = 1
    assert_false(strategies[7].matches(ctx2, state2), "concussive enemies=1 hp=41 -> no match")
end

-- ============================================================================
-- DEEP DIVE: WingClip hp=50/51 + melee + OOC + no target
-- ============================================================================

do
    -- Condition: in_combat, target, in_melee, hp <= 50

    -- hp=51, in_melee -> no match (hp > 50)
    local ctx = make_context({in_combat = true, hp = 51, in_melee_range = true})
    local state = get_state(ctx)
    state.wing_clip_ready = true
    state.hp = 51
    state.in_melee = true
    assert_false(strategies[8].matches(ctx, state), "wingclip hp=51 -> no match")

    -- hp=30, not melee -> no match
    local ctx2 = make_context({in_combat = true, hp = 30, in_melee_range = false})
    local state2 = get_state(ctx2)
    state2.wing_clip_ready = true
    state2.hp = 30
    state2.in_melee = false
    assert_false(strategies[8].matches(ctx2, state2), "wingclip not melee -> no match")

    -- hp=30, in_melee -> match
    local ctx3 = make_context({in_combat = true, hp = 30, in_melee_range = true})
    local state3 = get_state(ctx3)
    state3.wing_clip_ready = true
    state3.hp = 30
    state3.in_melee = true
    assert_true(strategies[8].matches(ctx3, state3), "wingclip hp=30 melee -> match")
end

-- ============================================================================
-- DEEP DIVE: ScareBeast enemies threshold + guards
-- ============================================================================

do
    -- enemies=3 -> match
    local ctx = make_context({in_combat = true, enemies_count = 3})
    local state = get_state(ctx)
    state.scare_beast_ready = true
    state.enemies = 3
    assert_true(strategies[9].matches(ctx, state), "scarebeast enemies=3 -> match")

    -- not ready -> no match
    local ctx2 = make_context({in_combat = true, enemies_count = 3})
    local state2 = get_state(ctx2)
    state2.scare_beast_ready = false
    state2.enemies = 3
    assert_false(strategies[9].matches(ctx2, state2), "scarebeast not ready -> no match")
end

-- ============================================================================
-- DEEP DIVE: SerpentSting debuff refresh boundary (remains 3/4/5) + setting + OOC
-- ============================================================================

do
    -- remains < 4: should match
    local saved = NS.debuff_remains
    NS.debuff_remains = function(target, spell) return 3 end
    local ctx = make_context({in_combat = true})
    local state = get_state(ctx)
    state.serpent_sting_ready = true
    state.serpent_sting_use = true
    assert_true(strategies[12].matches(ctx, state), "serpent remains=3 -> match")
    NS.debuff_remains = saved

    -- remains = 4: should NOT match
    local saved2 = NS.debuff_remains
    NS.debuff_remains = function(target, spell) return 4 end
    local ctx2 = make_context({in_combat = true})
    local state2 = get_state(ctx2)
    state2.serpent_sting_ready = true
    state2.serpent_sting_use = true
    assert_false(strategies[12].matches(ctx2, state2), "serpent remains=4 -> no match")
    NS.debuff_remains = saved2

    -- remains = 5: should NOT match
    local saved3 = NS.debuff_remains
    NS.debuff_remains = function(target, spell) return 5 end
    local ctx3 = make_context({in_combat = true})
    local state3 = get_state(ctx3)
    state3.serpent_sting_ready = true
    state3.serpent_sting_use = true
    assert_false(strategies[12].matches(ctx3, state3), "serpent remains=5 -> no match")
    NS.debuff_remains = saved3
end

-- ============================================================================
-- DEEP DIVE: HuntersMark debuff refresh boundary (remains 30/31) + all guards
-- ============================================================================

do
    -- remains = 30 -> match (not > 30)
    local saved = NS.debuff_remains
    NS.debuff_remains = function(target, spell) return 30 end
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.hunters_mark_ready = true
    state.hunters_mark_use = true
    assert_true(strategies[3].matches(ctx, state), "huntersmark remains=30 -> match")
    NS.debuff_remains = saved

    -- remains = 31 -> no match
    local saved2 = NS.debuff_remains
    NS.debuff_remains = function(target, spell) return 31 end
    local ctx2 = make_context({in_combat = false})
    local state2 = get_state(ctx2)
    state2.hunters_mark_ready = true
    state2.hunters_mark_use = true
    assert_false(strategies[3].matches(ctx2, state2), "huntersmark remains=31 -> no match")
    NS.debuff_remains = saved2

    -- not ready -> no match
    local ctx3 = make_context({in_combat = false})
    local state3 = get_state(ctx3)
    state3.hunters_mark_ready = false
    state3.hunters_mark_use = true
    NS.debuff_remains = function(target, spell) return 0 end
    assert_false(strategies[3].matches(ctx3, state3), "huntersmark not ready -> no match")

    -- disabled -> no match
    local ctx4 = make_context({in_combat = false})
    local state4 = get_state(ctx4)
    state4.hunters_mark_ready = true
    state4.hunters_mark_use = false
    NS.debuff_remains = function(target, spell) return 0 end
    assert_false(strategies[3].matches(ctx4, state4), "huntersmark disabled -> no match")

    -- in combat -> no match
    local ctx5 = make_context({in_combat = true})
    local state5 = get_state(ctx5)
    state5.hunters_mark_ready = true
    state5.hunters_mark_use = true
    NS.debuff_remains = function(target, spell) return 0 end
    assert_false(strategies[3].matches(ctx5, state5), "huntersmark in combat -> no match")
end

-- ============================================================================
-- DEEP DIVE: AimedShot + SteadyShot is_moving guard + no combat gate
-- ============================================================================

do
    -- AimedShot: is_moving -> no match
    local ctx = make_context({in_combat = true, is_moving = true})
    local state = get_state(ctx)
    state.aimed_shot_ready = true
    state.is_moving = true
    assert_false(strategies[5].matches(ctx, state), "aimedshot moving -> no match")

    -- AimedShot: stationary, in_combat -> match
    local ctx2 = make_context({in_combat = true, is_moving = false})
    local state2 = get_state(ctx2)
    state2.aimed_shot_ready = true
    state2.is_moving = false
    assert_true(strategies[5].matches(ctx2, state2), "aimedshot stationary combat -> match")

    -- AimedShot: stationary, OOC -> match (pull ability)
    local ctx3 = make_context({in_combat = false, is_moving = false})
    local state3 = get_state(ctx3)
    state3.aimed_shot_ready = true
    state3.is_moving = false
    assert_true(strategies[5].matches(ctx3, state3), "aimedshot stationary OOC -> match (no combat gate)")

    -- SteadyShot: not ready -> no match
    local ctx4 = make_context({in_combat = true, is_moving = false})
    local state4 = get_state(ctx4)
    state4.steady_shot_ready = false
    state4.is_moving = false
    assert_false(strategies[16].matches(ctx4, state4), "steadyshot not ready -> no match")
end

-- ============================================================================
-- DEEP DIVE: AspectHawk buff_up nil/throw + all guards
-- ============================================================================

do
    -- In combat -> no match (already tested)
    -- Already has buff -> no match (already tested)
    -- Not ready -> no match (already tested)
    -- has_aspect_hawk = false, OOC, ready -> match (already tested)

    -- All guards verified
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.has_aspect_hawk = false
    state.aspect_hawk_ready = true
    assert_true(strategies[1].matches(ctx, state), "aspecthawk all guards pass -> match")
end

-- ============================================================================
-- DEEP DIVE: RaptorStrike melee + in_combat + ready + target guards
-- ============================================================================

do
    -- in_melee, in_combat, ready -> match
    local ctx = make_context({in_combat = true, in_melee_range = true})
    local state = get_state(ctx)
    state.raptor_strike_ready = true
    state.in_melee = true
    assert_true(strategies[15].matches(ctx, state), "raptor all guards pass -> match")

    -- not ready -> no match
    local ctx2 = make_context({in_combat = true, in_melee_range = true})
    local state2 = get_state(ctx2)
    state2.raptor_strike_ready = false
    state2.in_melee = true
    assert_false(strategies[15].matches(ctx2, state2), "raptor not ready -> no match")
end

-- ============================================================================
-- DEEP DIVE: FreezingTrap enemies threshold + all guards
-- ============================================================================

do
    -- enemies=3 -> match
    local ctx = make_context({in_combat = true, enemies_count = 3})
    local state = get_state(ctx)
    state.freezing_trap_ready = true
    state.enemies = 3
    assert_true(strategies[10].matches(ctx, state), "trap enemies=3 -> match")

    -- not ready -> no match
    local ctx2 = make_context({in_combat = true, enemies_count = 3})
    local state2 = get_state(ctx2)
    state2.freezing_trap_ready = false
    state2.enemies = 3
    assert_false(strategies[10].matches(ctx2, state2), "trap not ready -> no match")
end

-- ============================================================================
-- DEEP DIVE: MendPet pet_hp boundary (60/61) + no pet + not ready
-- ============================================================================

do
    -- pet_hp=60 -> match
    local ctx = make_context({in_combat = true})
    ctx.pet = { get_health_percentage = function() return 60 end }
    local state = get_state(ctx)
    state.mend_pet_ready = true
    state.pet_hp = 60
    assert_true(strategies[6].matches(ctx, state), "mendpet pet_hp=60 -> match")

    -- pet_hp=61 -> no match
    local ctx2 = make_context({in_combat = true})
    ctx2.pet = { get_health_percentage = function() return 61 end }
    local state2 = get_state(ctx2)
    state2.mend_pet_ready = true
    state2.pet_hp = 61
    assert_false(strategies[6].matches(ctx2, state2), "mendpet pet_hp=61 -> no match")

    -- no pet -> no match
    local ctx3 = make_context({in_combat = true, pet = nil})
    local state3 = get_state(ctx3)
    state3.mend_pet_ready = true
    assert_false(strategies[6].matches(ctx3, state3), "mendpet no pet -> no match")
end

-- ============================================================================
-- DEEP DIVE: MultiShot enemies boundary (2/1) + all guards
-- ============================================================================

do
    -- enemies=2 -> match
    local ctx = make_context({in_combat = true, enemies_count = 2})
    local state = get_state(ctx)
    state.multi_shot_ready = true
    state.enemies = 2
    assert_true(strategies[14].matches(ctx, state), "multishot enemies=2 -> match")

    -- enemies=1 -> no match
    local ctx2 = make_context({in_combat = true, enemies_count = 1})
    local state2 = get_state(ctx2)
    state2.multi_shot_ready = true
    state2.enemies = 1
    assert_false(strategies[14].matches(ctx2, state2), "multishot enemies=1 -> no match")

    -- OOC -> no match
    local ctx3 = make_context({in_combat = false, enemies_count = 3})
    local state3 = get_state(ctx3)
    state3.multi_shot_ready = true
    state3.enemies = 3
    assert_false(strategies[14].matches(ctx3, state3), "multishot OOC -> no match")
end

-- ============================================================================
-- DEEP DIVE: CallPet no pet + OOC-only + not ready
-- ============================================================================

do
    -- OOC, no pet, ready -> match
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    ctx.pet = nil
    state.call_pet_ready = true
    assert_true(strategies[2].matches(ctx, state), "callpet OOC no pet ready -> match")

    -- has pet -> no match
    local ctx2 = make_context({in_combat = false})
    local state2 = get_state(ctx2)
    state2.call_pet_ready = true
    assert_false(strategies[2].matches(ctx2, state2), "callpet has pet -> no match")
end

-- ============================================================================
-- DEEP DIVE: FeignDeath hp boundary (30/31) + all guards
-- ============================================================================

do
    -- hp=30 -> match
    local ctx = make_context({in_combat = true, hp = 30})
    local state = get_state(ctx)
    state.feign_death_ready = true
    state.hp = 30
    assert_true(strategies[11].matches(ctx, state), "feign hp=30 -> match")

    -- hp=31 -> no match
    local ctx2 = make_context({in_combat = true, hp = 31})
    local state2 = get_state(ctx2)
    state2.feign_death_ready = true
    state2.hp = 31
    assert_false(strategies[11].matches(ctx2, state2), "feign hp=31 -> no match")

    -- OOC -> no match
    local ctx3 = make_context({in_combat = false, hp = 20})
    local state3 = get_state(ctx3)
    state3.feign_death_ready = true
    state3.hp = 20
    assert_false(strategies[11].matches(ctx3, state3), "feign OOC -> no match")
end

-- ============================================================================
-- DEEP DIVE: NS.try_cast returning false for individual strategies
-- ============================================================================

do
    local saved = NS.try_cast
    NS.try_cast = function() return false end
    local ctx = make_context()
    for i = 1, #strategies do
        local ok, result = pcall(strategies[i].execute, ctx)
        assert_true(ok, "try_cast ret=false: strategy " .. i .. " safe")
    end
    NS.try_cast = saved
end

-- Restore clean NS.debuff_remains
do
    NS.debuff_remains = function(target, spell)
        if not target or not spell then return 0 end
        return 0
    end
end

-- ============================================================================
print(string.format("\n=== Hunter Leveling Unit Tests: %d passed, %d failed (%d assertions) ===\n", passed, failed, assertions))
if failed > 0 then
    error(string.format("Some tests FAILED (%d failures)", failed))
else
    print("All Hunter leveling unit tests passed!")
end
