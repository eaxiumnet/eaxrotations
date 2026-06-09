-- Unit tests for Warlock leveling rotation
-- Tests build_state, all 18 match functions, strategy ordering,
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

local MOCK_WARLOCK_SPELLS = {
    ShadowBolt = { 27209 },
    Corruption = { 27216 },
    Immolate = { 27215 },
    CurseOfAgony = { 27218 },
    LifeTap = { 27222 },
    Fear = { 6215 },
    DrainSoul = { 27217 },
    DeathCoil = { 27223 },
    HealthFunnel = { 27259 },
    FelArmor = { 28189 },
    CreateHealthstone = { 6201 },
    CreateSoulstone = { 20756 },
    HowlOfTerror = { 17928 },
    SiphonLife = { 30911 },
    DrainLife = { 27220 },
    SpellLock = { 19647 },
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
        get_class = function() return 9 end,
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

    NS.WarlockSpells = {}
    for k, v in pairs(MOCK_WARLOCK_SPELLS) do
        NS.WarlockSpells[k] = v
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
        },
        target = {
            is_valid = function() return true end,
            get_health = function() return 8000 end,
            get_max_health = function() return 10000 end,
            is_casting = function() return false end,
            is_alive = function() return true end,
            get_guid = function() return "mock-target" end,
            get_health_percentage = function() return 80 end,
        },
        pet = {
            guid = "mock-pet",
            is_valid = function() return true end,
            get_health_percentage = function() return 100 end,
        },
        settings = {
            playstyle = "leveling",
            active_playstyle = "leveling",
            use_interrupt = true,
            leveling_wand_threshold = 30,
            leveling_life_tap_mana = 30,
            leveling_drain_soul_execute = 25,
            leveling_use_immolate = true,
            leveling_use_corruption = true,
            leveling_use_curse_of_agony = true,
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
-- Load the Warlock leveling module
-- ============================================================================

local NS, core, mock_player, mock_target, mock_state = build_mock_env()
local ok, module = pcall(dofile, "EaxRotations/classes/warlock/leveling_sylvanas.lua")
if not ok then
    error("Failed to load Warlock leveling module: " .. tostring(module))
end
if not module or type(module) ~= "table" then
    error("Warlock leveling module should return a table of strategies")
end

-- Get the registration info
local reg = NS.rotation_registry._registrations["leveling"]
if not reg then
    error("Warlock leveling module should register as 'leveling' in rotation_registry")
end
local strategies = reg.strategies
local get_state = reg.opts.get_state

print("=== Warlock Leveling Unit Tests ===\n")
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
    assert_eq(state.pet_hp, 100, "pet_hp default from context.pet")
end)

test("build_state: missing context fields use defaults", function()
    local ctx = {
        is_solo = false,
        is_leveling = true,
        me = { is_valid = function() return true end, has_buff = function() return false end, get_health = function() return 10000 end, get_max_health = function() return 10000 end },
        target = { is_valid = function() return true end, get_health = function() return 8000 end, get_max_health = function() return 10000 end, is_casting = function() return false end, is_alive = function() return true end, get_guid = function() return "mock-target" end, get_health_percentage = function() return 80 end },
        settings = {},
    }
    local state = get_state(ctx)
    assert_not_nil(state, "should return a table")
    assert_eq(state.hp, 100, "default hp = 100")
    assert_eq(state.mana_pct, 100, "default mana_pct = 100")
    assert_eq(state.enemies, 0, "default enemies = 0")
    assert_false(state.is_moving, "default is_moving = false")
    assert_false(state.in_combat, "default in_combat = false")
    assert_nil(state.pet, "no pet when context.pet is nil")
    assert_eq(state.pet_hp, 100, "default pet_hp = 100")
end)

test("build_state: spell readiness fields populated", function()
    local ctx = make_context()
    local state = get_state(ctx)
    assert_true(state.shadow_bolt_ready, "shadow_bolt_ready should be true")
    assert_true(state.corruption_ready, "corruption_ready should be true")
    assert_true(state.immolate_ready, "immolate_ready should be true")
    assert_true(state.curse_of_agony_ready, "curse_of_agony_ready should be true")
    assert_true(state.life_tap_ready, "life_tap_ready should be true")
    assert_true(state.fear_ready, "fear_ready should be true")
    assert_true(state.drain_soul_ready, "drain_soul_ready should be true")
    assert_true(state.death_coil_ready, "death_coil_ready should be true")
    assert_true(state.health_funnel_ready, "health_funnel_ready should be true")
    assert_true(state.fel_armor_ready, "fel_armor_ready should be true")
    assert_true(state.healthstone_ready, "healthstone_ready should be true")
    assert_true(state.spell_lock_ready, "spell_lock_ready should be true")
end)

test("build_state: custom thresholds from settings", function()
    local ctx = make_context()
    ctx.settings.leveling_wand_threshold = 15
    ctx.settings.leveling_life_tap_mana = 20
    ctx.settings.leveling_drain_soul_execute = 35
    ctx.settings.leveling_use_immolate = false
    ctx.settings.leveling_use_corruption = false
    ctx.settings.leveling_use_curse_of_agony = false
    local state = get_state(ctx)
    assert_eq(state.wand_threshold, 15, "wand_threshold from settings")
    assert_eq(state.life_tap_mana, 20, "life_tap_mana from settings")
    assert_eq(state.drain_soul_execute, 35, "drain_soul_execute from settings")
    assert_false(state.use_immolate, "use_immolate from settings")
    assert_false(state.use_corruption, "use_corruption from settings")
    assert_false(state.use_curse_of_agony, "use_curse_of_agony from settings")
end)

test("build_state: missing settings uses defaults", function()
    local ctx = make_context({settings = {}})
    local state = get_state(ctx)
    assert_eq(state.wand_threshold, 30, "default wand_threshold = 30")
    assert_eq(state.life_tap_mana, 30, "default life_tap_mana = 30")
    assert_eq(state.drain_soul_execute, 25, "default drain_soul_execute = 25")
    assert_true(state.use_interrupt, "default use_interrupt = true")
    assert_true(state.use_immolate, "default use_immolate = true")
    assert_true(state.use_corruption, "default use_corruption = true")
    assert_true(state.use_curse_of_agony, "default use_curse_of_agony = true")
end)

test("build_state: buff checks populate correctly", function()
    local ctx = make_context()
    local state = get_state(ctx)
    assert_false(state.has_fel_armor, "no Fel Armor by default")
end)

test("build_state: pet HP tracking works", function()
    local ctx = make_context()
    ctx.pet.get_health_percentage = function() return 40 end
    local state = get_state(ctx)
    assert_eq(state.pet_hp, 40, "pet HP from get_health_percentage")
end)

test("build_state: no pet sets pet_hp to 100", function()
    local ctx = make_context({pet = nil})
    local state = get_state(ctx)
    assert_eq(state.pet_hp, 100, "default pet_hp = 100 when no pet")
end)

-- ============================================================================
-- Test: fel_armor_matches (strategy #1)
-- ============================================================================

test("fel_armor_matches: OOC, ready, no buff -> true", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.has_fel_armor = false
    state.fel_armor_ready = true
    assert_true(strategies[1].matches(ctx, state), "should match")
end)

test("fel_armor_matches: in combat -> false", function()
    local ctx = make_context({in_combat = true})
    local state = get_state(ctx)
    state.has_fel_armor = false
    state.fel_armor_ready = true
    assert_false(strategies[1].matches(ctx, state), "should not match in combat")
end)

test("fel_armor_matches: already has buff -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.has_fel_armor = true
    state.fel_armor_ready = true
    assert_false(strategies[1].matches(ctx, state), "should not match if buff active")
end)

test("fel_armor_matches: nil state -> false", function()
    assert_false(strategies[1].matches(make_context({in_combat = false}), nil), "nil state should return false")
end)

-- ============================================================================
-- Test: healthstone_matches (strategy #2)
-- ============================================================================

test("healthstone_matches: OOC, ready -> true", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.healthstone_ready = true
    assert_true(strategies[2].matches(ctx, state), "OOC should match")
end)

test("healthstone_matches: in combat -> false", function()
    local ctx = make_context({in_combat = true})
    local state = get_state(ctx)
    state.healthstone_ready = true
    assert_false(strategies[2].matches(ctx, state), "in combat should not match")
end)

-- ============================================================================
-- Test: spell_lock_matches (strategy #3)
-- ============================================================================

test("spell_lock_matches: ready, target casting -> true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.spell_lock_ready = true
    state.target = {
        is_valid = function() return true end,
        get_health = function() return 8000 end,
        get_max_health = function() return 10000 end,
        is_casting = function() return true end,
        is_alive = function() return true end,
        get_guid = function() return "mock-target" end,
        get_health_percentage = function() return 80 end,
    }
    assert_true(strategies[4].matches(ctx, state), "target casting should match")
end)

test("spell_lock_matches: target not casting -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.spell_lock_ready = true
    assert_false(strategies[4].matches(ctx, state), "target not casting should not match")
end)

test("spell_lock_matches: no target -> false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.spell_lock_ready = true
    state.target = nil
    assert_false(strategies[4].matches(ctx, state), "no target should return false")
end)

test("spell_lock_matches: interrupt disabled -> false", function()
    local ctx = make_context()
    ctx.settings.use_interrupt = false
    local state = get_state(ctx)
    state.spell_lock_ready = true
    state.use_interrupt = false
    state.target = {
        is_valid = function() return true end,
        is_casting = function() return true end,
        get_guid = function() return "mock-target" end,
    }
    assert_false(strategies[4].matches(ctx, state), "interrupt disabled should not match")
end)

-- ============================================================================
-- Test: health_funnel_matches (strategy #4)
-- ============================================================================

test("health_funnel_matches: ready, pet low HP, self HP ok -> true", function()
    local ctx = make_context({hp = 80})
    local state = get_state(ctx)
    state.health_funnel_ready = true
    state.pet_hp = 30
    state.hp = 80
    state.pet = { is_valid = function() return true end }
    assert_true(strategies[5].matches(ctx, state), "should match when pet needs healing")
end)

test("health_funnel_matches: pet HP > 50 -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.health_funnel_ready = true
    state.pet_hp = 80
    state.pet = { is_valid = function() return true end }
    assert_false(strategies[5].matches(ctx, state), "pet HP above 50 should not match")
end)

test("health_funnel_matches: self HP too low -> false", function()
    local ctx = make_context({hp = 30})
    local state = get_state(ctx)
    state.health_funnel_ready = true
    state.pet_hp = 30
    state.hp = 30
    state.pet = { is_valid = function() return true end }
    assert_false(strategies[5].matches(ctx, state), "self HP below 40 should not match")
end)

test("health_funnel_matches: no pet -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.health_funnel_ready = true
    state.pet = nil
    assert_false(strategies[5].matches(ctx, state), "no pet should not match")
end)

test("health_funnel_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.health_funnel_ready = true
    state.pet_hp = 30
    state.hp = 80
    state.pet = { is_valid = function() return true end }
    assert_false(strategies[5].matches(ctx, state), "OOC should not match")
end)

-- ============================================================================
-- Test: fear_matches (strategy #7)
-- ============================================================================

test("fear_matches: ready, 2+ enemies, debuff expiring -> true", function()
    local ctx = make_context({enemies_count = 3})
    local state = get_state(ctx)
    state.fear_ready = true
    state.enemies = 3
    assert_true(strategies[7].matches(ctx, state), "3 enemies should match")
end)

test("fear_matches: 1 enemy -> false", function()
    local ctx = make_context({enemies_count = 1})
    local state = get_state(ctx)
    state.fear_ready = true
    state.enemies = 1
    assert_false(strategies[7].matches(ctx, state), "1 enemy should not match")
end)

test("fear_matches: debuff still fresh -> false", function()
    local ctx = make_context({enemies_count = 3})
    local state = get_state(ctx)
    state.fear_ready = true
    state.enemies = 3
    NS.debuff_remains = function(target, ids) return 12 end
    assert_false(strategies[7].matches(ctx, state), "fresh fear should not match")
    NS.debuff_remains = function(target, ids) return 0 end
end)

test("fear_matches: no target -> false", function()
    local ctx = make_context({enemies_count = 3, target = nil})
    local state = get_state(ctx)
    state.fear_ready = true
    state.target = nil
    assert_false(strategies[7].matches(ctx, state), "no target should not match")
end)

-- ============================================================================
-- Test: death_coil_matches (strategy #9)
-- ============================================================================

test("death_coil_matches: ready, HP below 40% -> true", function()
    local ctx = make_context({hp = 30})
    local state = get_state(ctx)
    state.death_coil_ready = true
    state.hp = 30
    assert_true(strategies[9].matches(ctx, state), "low HP should match")
end)

test("death_coil_matches: HP above 40% -> false", function()
    local ctx = make_context({hp = 80})
    local state = get_state(ctx)
    state.death_coil_ready = true
    state.hp = 80
    assert_false(strategies[9].matches(ctx, state), "HP above 40 should not match")
end)

test("death_coil_matches: no target -> false", function()
    local ctx = make_context({target = nil, hp = 30})
    local state = get_state(ctx)
    state.death_coil_ready = true
    state.target = nil
    state.hp = 30
    assert_false(strategies[9].matches(ctx, state), "no target should not match")
end)

-- ============================================================================
-- Test: life_tap_matches (strategy #10)
-- ============================================================================

test("life_tap_matches: ready, low mana, self HP ok -> true", function()
    local ctx = make_context({mana_pct = 20, hp = 60})
    local state = get_state(ctx)
    state.life_tap_ready = true
    state.mana_pct = 20
    state.hp = 60
    state.life_tap_mana = 30
    assert_true(strategies[10].matches(ctx, state), "low mana with enough HP should match")
end)

test("life_tap_matches: mana above threshold -> false", function()
    local ctx = make_context({mana_pct = 50})
    local state = get_state(ctx)
    state.life_tap_ready = true
    state.mana_pct = 50
    state.life_tap_mana = 30
    assert_false(strategies[10].matches(ctx, state), "mana above threshold should not match")
end)

test("life_tap_matches: self HP too low -> false", function()
    local ctx = make_context({mana_pct = 20, hp = 20})
    local state = get_state(ctx)
    state.life_tap_ready = true
    state.mana_pct = 20
    state.hp = 20
    state.life_tap_mana = 30
    assert_false(strategies[10].matches(ctx, state), "HP below 30 should not match")
end)

test("life_tap_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false, mana_pct = 20, hp = 60})
    local state = get_state(ctx)
    state.life_tap_ready = true
    state.in_combat = false
    state.mana_pct = 20
    state.hp = 60
    assert_false(strategies[10].matches(ctx, state), "OOC should not match")
end)

-- ============================================================================
-- Test: corruption_matches (strategy #11)
-- ============================================================================

test("corruption_matches: ready, enabled, debuff expiring -> true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.corruption_ready = true
    state.use_corruption = true
    assert_true(strategies[11].matches(ctx, state), "expired corruption should match")
end)

test("corruption_matches: debuff fresh -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.corruption_ready = true
    state.use_corruption = true
    NS.debuff_remains = function(target, ids) return 10 end
    assert_false(strategies[11].matches(ctx, state), "fresh corruption should not match")
    NS.debuff_remains = function(target, ids) return 0 end
end)

test("corruption_matches: disabled -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.corruption_ready = true
    state.use_corruption = false
    assert_false(strategies[11].matches(ctx, state), "disabled should not match")
end)

test("corruption_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.corruption_ready = true
    state.use_corruption = true
    assert_false(strategies[11].matches(ctx, state), "OOC should not match")
end)

test("corruption_matches: no target -> false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.corruption_ready = true
    state.target = nil
    state.use_corruption = true
    assert_false(strategies[11].matches(ctx, state), "no target should not match")
end)

-- ============================================================================
-- Test: immolate_matches (strategy #12)
-- ============================================================================

test("immolate_matches: ready, enabled, not moving, debuff expiring -> true", function()
    local ctx = make_context({is_moving = false})
    local state = get_state(ctx)
    state.immolate_ready = true
    state.use_immolate = true
    state.is_moving = false
    assert_true(strategies[12].matches(ctx, state), "should match when ready and stationary")
end)

test("immolate_matches: moving -> false", function()
    local ctx = make_context({is_moving = true})
    local state = get_state(ctx)
    state.immolate_ready = true
    state.use_immolate = true
    state.is_moving = true
    assert_false(strategies[12].matches(ctx, state), "moving should not match")
end)

test("immolate_matches: disabled -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.immolate_ready = true
    state.use_immolate = false
    assert_false(strategies[12].matches(ctx, state), "disabled should not match")
end)

test("immolate_matches: debuff fresh -> false", function()
    local ctx = make_context({is_moving = false})
    local state = get_state(ctx)
    state.immolate_ready = true
    state.use_immolate = true
    state.is_moving = false
    NS.debuff_remains = function(target, ids) return 10 end
    assert_false(strategies[12].matches(ctx, state), "fresh immolate should not match")
    NS.debuff_remains = function(target, ids) return 0 end
end)

-- ============================================================================
-- Test: curse_of_agony_matches (strategy #13)
-- ============================================================================

test("curse_of_agony_matches: ready, enabled, debuff expiring -> true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.curse_of_agony_ready = true
    state.use_curse_of_agony = true
    assert_true(strategies[13].matches(ctx, state), "expired curse should match")
end)

test("curse_of_agony_matches: debuff fresh -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.curse_of_agony_ready = true
    state.use_curse_of_agony = true
    NS.debuff_remains = function(target, ids) return 10 end
    assert_false(strategies[13].matches(ctx, state), "fresh curse should not match")
    NS.debuff_remains = function(target, ids) return 0 end
end)

test("curse_of_agony_matches: disabled -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.curse_of_agony_ready = true
    state.use_curse_of_agony = false
    assert_false(strategies[13].matches(ctx, state), "disabled should not match")
end)

-- ============================================================================
-- Test: drain_soul_matches (strategy #16)
-- ============================================================================

test("drain_soul_matches: ready, execute range target -> true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.drain_soul_ready = true
    state.drain_soul_execute = 25
    ctx.target.get_health_percentage = function() return 15 end
    assert_true(strategies[16].matches(ctx, state), "execute range should match")
end)

test("drain_soul_matches: target above execute range but low mana -> true", function()
    local ctx = make_context({mana_pct = 20})
    local state = get_state(ctx)
    state.drain_soul_ready = true
    state.drain_soul_execute = 25
    state.mana_pct = 20
    ctx.target.get_health_percentage = function() return 50 end
    assert_true(strategies[16].matches(ctx, state), "low mana should match")
end)

test("drain_soul_matches: target above execute range, mana ok -> false", function()
    local ctx = make_context({mana_pct = 50})
    local state = get_state(ctx)
    state.drain_soul_ready = true
    state.drain_soul_execute = 25
    state.mana_pct = 50
    ctx.target.get_health_percentage = function() return 50 end
    assert_false(strategies[16].matches(ctx, state), "not execute range and enough mana should not match")
end)

test("drain_soul_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.drain_soul_ready = true
    assert_false(strategies[16].matches(ctx, state), "OOC should not match")
end)

-- ============================================================================
-- Test: shadow_bolt_matches (strategy #17)
-- ============================================================================

test("shadow_bolt_matches: ready, not moving, enough mana -> true", function()
    local ctx = make_context({is_moving = false, mana_pct = 50})
    local state = get_state(ctx)
    state.shadow_bolt_ready = true
    state.is_moving = false
    state.mana_pct = 50
    assert_true(strategies[17].matches(ctx, state), "should match when ready and stationary")
end)

test("shadow_bolt_matches: moving -> false", function()
    local ctx = make_context({is_moving = true})
    local state = get_state(ctx)
    state.shadow_bolt_ready = true
    state.is_moving = true
    assert_false(strategies[17].matches(ctx, state), "moving should not match")
end)

test("shadow_bolt_matches: low mana -> false", function()
    local ctx = make_context({mana_pct = 5})
    local state = get_state(ctx)
    state.shadow_bolt_ready = true
    state.mana_pct = 5
    assert_false(strategies[17].matches(ctx, state), "low mana should not match")
end)

test("shadow_bolt_matches: no target -> false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.shadow_bolt_ready = true
    state.target = nil
    assert_false(strategies[17].matches(ctx, state), "no target should not match")
end)

-- ============================================================================
-- Test: wand_matches_fn (strategy #18)
-- ============================================================================

test("wand_matches: low mana, in combat, wand learned -> true", function()
    local ctx = make_context({mana_pct = 10})
    local state = get_state(ctx)
    state.mana_pct = 10
    state.wand_threshold = 30
    state.wand_learned = true
    assert_true(strategies[18].matches(ctx, state), "low mana should match")
end)

test("wand_matches: enough mana -> false", function()
    local ctx = make_context({mana_pct = 80})
    local state = get_state(ctx)
    state.mana_pct = 80
    state.wand_threshold = 30
    state.wand_learned = true
    assert_false(strategies[18].matches(ctx, state), "enough mana should not match")
end)

test("wand_matches: no target -> false", function()
    local ctx = make_context({target = nil, mana_pct = 10})
    local state = get_state(ctx)
    state.mana_pct = 10
    state.target = nil
    state.wand_learned = true
    assert_false(strategies[18].matches(ctx, state), "no target should not match")
end)

test("wand_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false, mana_pct = 10})
    local state = get_state(ctx)
    state.mana_pct = 10
    state.wand_threshold = 30
    state.wand_learned = true
    state.in_combat = false
    assert_false(strategies[18].matches(ctx, state), "OOC should not match")
end)

test("wand_matches: wand not learned -> false", function()
    local ctx = make_context({mana_pct = 10})
    local state = get_state(ctx)
    state.mana_pct = 10
    state.wand_learned = false
    assert_false(strategies[18].matches(ctx, state), "wand not learned should not match")
end)

-- ============================================================================
-- Test: Strategy priority ordering
-- ============================================================================

test("strategies: 16 strategies in correct priority order", function()
    local expected = {
        "FelArmor",
        "CreateHealthstone",
        "CreateSoulstone",
        "SpellLock",
        "HealthFunnel",
        "SummonPet",
        "Fear",
        "HowlOfTerror",
        "DeathCoil",
        "LifeTap",
        "Corruption",
        "Immolate",
        "CurseOfAgony",
        "SiphonLife",
        "DrainLife",
        "DrainSoul",
        "ShadowBolt",
        "Wand",
    }
    assert_eq(#strategies, 18, "should have 18 strategies")
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

test("execute_FelArmor: does not crash", function()
    local ok, result = pcall(strategies[1].execute)
    assert_true(ok, "execute should not throw")
end)

test("execute_Wand: does not crash with context", function()
    local ctx = make_context()
    local ok, result = pcall(strategies[18].execute, ctx)
    assert_true(ok, "execute with context should not throw")
end)

test("execute_Wand: does not crash without context", function()
    local ok, result = pcall(strategies[18].execute)
    assert_true(ok, "execute without context should not throw")
end)

-- ============================================================================
-- Test: Nil guard - module returns nil when NS is nil
-- ============================================================================

test("module: returns nil when EaxRotations is nil", function()
    local _, c = build_mock_env()
    _G.EaxRotations = nil
    local nil_mod = dofile("EaxRotations/classes/warlock/leveling_sylvanas.lua")
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

test("match_functions: all handle nil state -> false", function()
    local ctx = make_context()
    for i, s in ipairs(strategies) do
        local ok, result = pcall(s.matches, ctx, nil)
        assert_true(ok, "strategy[" .. i .. "] (" .. s.name .. ") matches(ctx, nil) should not throw")
        assert_false(result, "strategy[" .. i .. "] (" .. s.name .. ") matches(ctx, nil) should return false")
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

test("rotation: OOC scenario - only OOC buffs should match", function()
    local ctx = make_context({in_combat = false})
    ctx.me.has_buff = function(id) return false end
    local state = get_state(ctx)
    state.has_fel_armor = false
    state.fel_armor_ready = true
    state.healthstone_ready = true

    -- FelArmor should match (OOC, no buff)
    assert_true(strategies[1].matches(ctx, state), "FelArmor should match OOC")

    -- Healthstone should match (OOC)
    assert_true(strategies[2].matches(ctx, state), "Healthstone should match OOC")

    -- Soulstone should match (OOC)
    assert_true(strategies[3].matches(ctx, state), "CreateSoulstone should match OOC")

    -- Combat abilities should not match OOC (start from SpellLock at index 4)
    for i = 4, 18 do
        local ok, matched = pcall(strategies[i].matches, ctx, state)
        assert_true(ok, "strategy[" .. i .. "] matches should not throw")
        assert_false(matched, "strategy[" .. i .. "] (" .. strategies[i].name .. ") should not match OOC")
    end
end)

test("rotation: low HP scenario - death coil should match", function()
    local ctx = make_context({hp = 30})
    local state = get_state(ctx)
    state.death_coil_ready = true
    state.hp = 30

    -- DeathCoil should match when HP < 40
    assert_true(strategies[9].matches(ctx, state), "DeathCoil should match when HP < 40")
end)

test("rotation: low mana scenario - life tap + wand should be possible", function()
    local ctx = make_context({mana_pct = 15, hp = 50})
    local state = get_state(ctx)
    state.life_tap_ready = true
    state.mana_pct = 15
    state.life_tap_mana = 30
    state.hp = 50
    state.wand_threshold = 30
    state.wand_learned = true

    -- LifeTap should match (low mana, enough HP)
    assert_true(strategies[10].matches(ctx, state), "LifeTap should match when low mana")

    -- Wand should also be a fallback option
    assert_true(strategies[18].matches(ctx, state), "Wand should match when mana below threshold")
end)

-- ============================================================================
-- Edge Case Tests: Corruption refresh boundaries
-- ============================================================================

do -- edge_corruption
    test("edge_corruption: debuff remains exactly 0 -> match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.corruption_ready = true
        state.use_corruption = true
        local saved = NS.debuff_remains
        NS.debuff_remains = function() return 0 end
        assert_true(strategies[11].matches(ctx, state), "remains 0 should match (<= 4)")
        NS.debuff_remains = saved
    end)

    test("edge_corruption: debuff remains exactly 5 -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.corruption_ready = true
        state.use_corruption = true
        local saved = NS.debuff_remains
        NS.debuff_remains = function() return 5 end
        assert_false(strategies[11].matches(ctx, state), "remains 5 should not match (> 4)")
        NS.debuff_remains = saved
    end)

    test("edge_corruption: use_corruption disabled -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.corruption_ready = true
        state.use_corruption = false
        assert_false(strategies[11].matches(ctx, state), "disabled should not match")
    end)
end

-- ============================================================================
-- Edge Case Tests: Immolate refresh boundaries
-- ============================================================================

do -- edge_immolate
    test("edge_immolate: debuff remains exactly 0 -> match", function()
        local ctx = make_context({is_moving = false})
        local state = get_state(ctx)
        state.immolate_ready = true
        state.use_immolate = true
        state.is_moving = false
        local saved = NS.debuff_remains
        NS.debuff_remains = function() return 0 end
        assert_true(strategies[12].matches(ctx, state), "remains 0 should match (<= 4)")
        NS.debuff_remains = saved
    end)

    test("edge_immolate: debuff remains exactly 5 -> no match", function()
        local ctx = make_context({is_moving = false})
        local state = get_state(ctx)
        state.immolate_ready = true
        state.use_immolate = true
        state.is_moving = false
        local saved = NS.debuff_remains
        NS.debuff_remains = function() return 5 end
        assert_false(strategies[12].matches(ctx, state), "remains 5 should not match (> 4)")
        NS.debuff_remains = saved
    end)

    test("edge_immolate: moving -> no match", function()
        local ctx = make_context({is_moving = true})
        local state = get_state(ctx)
        state.immolate_ready = true
        state.use_immolate = true
        state.is_moving = true
        assert_false(strategies[12].matches(ctx, state), "moving should not match")
    end)
end

-- ============================================================================
-- Edge Case Tests: Curse of Agony refresh boundaries
-- ============================================================================

do -- edge_curse
    test("edge_curse: debuff remains exactly 0 -> match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.curse_of_agony_ready = true
        state.use_curse_of_agony = true
        local saved = NS.debuff_remains
        NS.debuff_remains = function() return 0 end
        assert_true(strategies[13].matches(ctx, state), "remains 0 should match (<= 4)")
        NS.debuff_remains = saved
    end)

    test("edge_curse: debuff remains exactly 5 -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.curse_of_agony_ready = true
        state.use_curse_of_agony = true
        local saved = NS.debuff_remains
        NS.debuff_remains = function() return 5 end
        assert_false(strategies[13].matches(ctx, state), "remains 5 should not match (> 4)")
        NS.debuff_remains = saved
    end)
end

-- ============================================================================
-- Edge Case Tests: Life Tap boundaries
-- ============================================================================

do -- edge_life_tap
    test("edge_life_tap: mana exactly 30 (threshold) -> match", function()
        local ctx = make_context({mana_pct = 30, hp = 50})
        local state = get_state(ctx)
        state.life_tap_ready = true
        state.mana_pct = 30
        state.life_tap_mana = 30
        state.hp = 50
        assert_true(strategies[10].matches(ctx, state), "mana at threshold should match")
    end)

    test("edge_life_tap: mana exactly 31 (above threshold) -> no match", function()
        local ctx = make_context({mana_pct = 31, hp = 50})
        local state = get_state(ctx)
        state.life_tap_ready = true
        state.mana_pct = 31
        state.life_tap_mana = 30
        state.hp = 50
        assert_false(strategies[10].matches(ctx, state), "mana above threshold should not match")
    end)

    test("edge_life_tap: HP exactly 29 -> no match (< 30 guard)", function()
        local ctx = make_context({mana_pct = 20, hp = 29})
        local state = get_state(ctx)
        state.life_tap_ready = true
        state.mana_pct = 20
        state.life_tap_mana = 30
        state.hp = 29
        assert_false(strategies[10].matches(ctx, state), "HP 29 should not match (hp < 30 guard)")
    end)

    test("edge_life_tap: HP exactly 30 -> match", function()
        local ctx = make_context({mana_pct = 20, hp = 30})
        local state = get_state(ctx)
        state.life_tap_ready = true
        state.mana_pct = 20
        state.life_tap_mana = 30
        state.hp = 30
        assert_true(strategies[10].matches(ctx, state), "HP 30 should match (hp >= 30)")
    end)
end

-- ============================================================================
-- Edge Case Tests: Drain Soul execute boundaries
-- ============================================================================

do -- edge_drain_soul
    test("edge_drain_soul: target HP exactly 25 (execute threshold) -> match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.drain_soul_ready = true
        state.drain_soul_execute = 25
        state.mana_pct = 50
        local saved = ctx.target.get_health_percentage
        ctx.target.get_health_percentage = function() return 25 end
        -- Need to rebuild state to pick up target HP
        state.target_hp_override = 25
        -- Direct state override since build_state reads target at test time
        local target_ok, target_hp = pcall(ctx.target.get_health_percentage)
        if not (target_ok and target_hp and target_hp > state.drain_soul_execute) and state.mana_pct <= 30 then
            -- we need to set state via override
        end
        -- Production reads target HP directly, not from state. Need to mock target.get_health_percentage
        -- The test already set it above, now recreate state to pick it up
        state = get_state(ctx)
        state.drain_soul_ready = true
        state.drain_soul_execute = 25
        state.mana_pct = 50
        assert_true(strategies[16].matches(ctx, state), "target HP 25 should match (<= threshold)")
        ctx.target.get_health_percentage = saved
    end)

    test("edge_drain_soul: target HP exactly 26 (above execute threshold) -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.drain_soul_ready = true
        state.drain_soul_execute = 25
        state.mana_pct = 50
        local saved = ctx.target.get_health_percentage
        ctx.target.get_health_percentage = function() return 26 end
        state = get_state(ctx)
        state.drain_soul_ready = true
        state.drain_soul_execute = 25
        state.mana_pct = 50
        assert_false(strategies[16].matches(ctx, state), "target HP 26 should not match (> threshold)")
        ctx.target.get_health_percentage = saved
    end)

    test("edge_drain_soul: mana exactly 30 (low mana gate) -> match", function()
        local ctx = make_context({mana_pct = 30})
        local state = get_state(ctx)
        state.drain_soul_ready = true
        state.drain_soul_execute = 25
        state.mana_pct = 30
        local saved = ctx.target.get_health_percentage
        ctx.target.get_health_percentage = function() return 50 end
        state = get_state(ctx)
        state.drain_soul_ready = true
        state.drain_soul_execute = 25
        state.mana_pct = 30
        assert_true(strategies[16].matches(ctx, state), "mana 30 should match (<= 30)")
        ctx.target.get_health_percentage = saved
    end)

    test("edge_drain_soul: mana exactly 31 (above low mana gate) -> no match", function()
        local ctx = make_context({mana_pct = 31})
        local state = get_state(ctx)
        state.drain_soul_ready = true
        state.drain_soul_execute = 25
        state.mana_pct = 31
        local saved = ctx.target.get_health_percentage
        ctx.target.get_health_percentage = function() return 50 end
        state = get_state(ctx)
        state.drain_soul_ready = true
        state.drain_soul_execute = 25
        state.mana_pct = 31
        assert_false(strategies[16].matches(ctx, state), "mana 31 should not match (> 30)")
        ctx.target.get_health_percentage = saved
    end)
end

-- ============================================================================
-- Edge Case Tests: Death Coil HP boundary
-- ============================================================================

do -- edge_death_coil
    test("edge_death_coil: HP exactly 40 -> match", function()
        local ctx = make_context({hp = 40})
        local state = get_state(ctx)
        state.death_coil_ready = true
        state.hp = 40
        assert_true(strategies[9].matches(ctx, state), "HP 40 should match (<= 40)")
    end)

    test("edge_death_coil: HP exactly 41 -> no match", function()
        local ctx = make_context({hp = 41})
        local state = get_state(ctx)
        state.death_coil_ready = true
        state.hp = 41
        assert_false(strategies[9].matches(ctx, state), "HP 41 should not match (> 40)")
    end)
end

-- ============================================================================
-- Edge Case Tests: Fear enemy count boundary
-- ============================================================================

do -- edge_fear
    test("edge_fear: enemies exactly 2 -> match", function()
        local ctx = make_context({enemies_count = 2})
        local state = get_state(ctx)
        state.fear_ready = true
        state.enemies = 2
        local saved = NS.debuff_remains
        NS.debuff_remains = function() return 0 end
        assert_true(strategies[7].matches(ctx, state), "2 enemies should match (>= 2)")
        NS.debuff_remains = saved
    end)

    test("edge_fear: enemies exactly 1 -> no match", function()
        local ctx = make_context({enemies_count = 1})
        local state = get_state(ctx)
        state.fear_ready = true
        state.enemies = 1
        assert_false(strategies[7].matches(ctx, state), "1 enemy should not match (< 2)")
    end)

    test("edge_fear: debuff remains exactly 8 -> match", function()
        local ctx = make_context({enemies_count = 2})
        local state = get_state(ctx)
        state.fear_ready = true
        state.enemies = 2
        local saved = NS.debuff_remains
        NS.debuff_remains = function() return 8 end
        assert_true(strategies[7].matches(ctx, state), "remains 8 should match (<= 8)")
        NS.debuff_remains = saved
    end)

    test("edge_fear: debuff remains exactly 9 -> no match", function()
        local ctx = make_context({enemies_count = 2})
        local state = get_state(ctx)
        state.fear_ready = true
        state.enemies = 2
        local saved = NS.debuff_remains
        NS.debuff_remains = function() return 9 end
        assert_false(strategies[7].matches(ctx, state), "remains 9 should not match (> 8)")
        NS.debuff_remains = saved
    end)
end

-- ============================================================================
-- Edge Case Tests: Health Funnel boundaries
-- ============================================================================

do -- edge_health_funnel
    test("edge_health_funnel: pet HP exactly 50 -> match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.health_funnel_ready = true
        state.pet_hp = 50
        state.hp = 80
        assert_true(strategies[5].matches(ctx, state), "pet HP 50 should match (<= 50)")
    end)

    test("edge_health_funnel: pet HP exactly 51 -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.health_funnel_ready = true
        state.pet_hp = 51
        state.hp = 80
        assert_false(strategies[5].matches(ctx, state), "pet HP 51 should not match (> 50)")
    end)

    test("edge_health_funnel: player HP exactly 39 -> no match (hp < 40 guard)", function()
        local ctx = make_context({hp = 39})
        local state = get_state(ctx)
        state.health_funnel_ready = true
        state.pet_hp = 30
        state.hp = 39
        assert_false(strategies[5].matches(ctx, state), "player HP 39 should not match (hp < 40 guard)")
    end)

    test("edge_health_funnel: player HP exactly 40 -> match", function()
        local ctx = make_context({hp = 40})
        local state = get_state(ctx)
        state.health_funnel_ready = true
        state.pet_hp = 30
        state.hp = 40
        assert_true(strategies[5].matches(ctx, state), "player HP 40 should match (hp >= 40)")
    end)
end

-- ============================================================================
-- Edge Case Tests: Wand mana boundary
-- ============================================================================

do -- edge_wand
    test("edge_wand: mana exactly 29 (below threshold) -> match", function()
        local ctx = make_context({mana_pct = 29})
        local state = get_state(ctx)
        state.wand_learned = true
        state.wand_threshold = 30
        state.mana_pct = 29
        assert_true(strategies[18].matches(ctx, state), "mana 29 should match (< threshold)")
    end)

    test("edge_wand: mana exactly 30 (at threshold) -> no match", function()
        local ctx = make_context({mana_pct = 30})
        local state = get_state(ctx)
        state.wand_learned = true
        state.wand_threshold = 30
        state.mana_pct = 30
        assert_false(strategies[18].matches(ctx, state), "mana 30 should not match (>= threshold)")
    end)

    test("edge_wand: wand not learned -> no match", function()
        local ctx = make_context({mana_pct = 10})
        local state = get_state(ctx)
        state.wand_learned = false
        state.wand_threshold = 30
        state.mana_pct = 10
        assert_false(strategies[18].matches(ctx, state), "wand not learned should not match")
    end)
end

-- ============================================================================
-- Edge Case Tests: Shadow Bolt mana boundary
-- ============================================================================

do -- edge_shadow_bolt
    test("edge_shadow_bolt: mana exactly 9 -> no match (mana < 10 guard)", function()
        local ctx = make_context({mana_pct = 9, is_moving = false})
        local state = get_state(ctx)
        state.shadow_bolt_ready = true
        state.mana_pct = 9
        state.is_moving = false
        assert_false(strategies[17].matches(ctx, state), "mana 9 should not match (mana < 10 guard)")
    end)

    test("edge_shadow_bolt: mana exactly 10 -> match", function()
        local ctx = make_context({mana_pct = 10, is_moving = false})
        local state = get_state(ctx)
        state.shadow_bolt_ready = true
        state.mana_pct = 10
        state.is_moving = false
        assert_true(strategies[17].matches(ctx, state), "mana 10 should match (mana >= 10)")
    end)

    test("edge_shadow_bolt: moving -> no match", function()
        local ctx = make_context({mana_pct = 50, is_moving = true})
        local state = get_state(ctx)
        state.shadow_bolt_ready = true
        state.mana_pct = 50
        state.is_moving = true
        assert_false(strategies[17].matches(ctx, state), "moving should not match")
    end)
end

-- ============================================================================
-- Edge Case Tests: Fel Armor & Healthstone (OOC buffs)
-- ============================================================================

do -- edge_fel_armor
    test("edge_fel_armor: not buffed, OOC -> match", function()
        local ctx = make_context({in_combat = false})
        local state = get_state(ctx)
        state.has_fel_armor = false
        state.fel_armor_ready = true
        assert_true(strategies[1].matches(ctx, state), "unbuffed OOC should match")
    end)

    test("edge_fel_armor: already buffed -> no match", function()
        local ctx = make_context({in_combat = false})
        local state = get_state(ctx)
        state.has_fel_armor = true
        state.fel_armor_ready = true
        assert_false(strategies[1].matches(ctx, state), "buffed should not match")
    end)
end

do -- edge_healthstone
    test("edge_healthstone: ready, OOC -> match", function()
        local ctx = make_context({in_combat = false})
        local state = get_state(ctx)
        state.healthstone_ready = true
        assert_true(strategies[2].matches(ctx, state), "ready OOC should match")
    end)

    test("edge_healthstone: not ready -> no match", function()
        local ctx = make_context({in_combat = false})
        local state = get_state(ctx)
        state.healthstone_ready = false
        assert_false(strategies[2].matches(ctx, state), "not ready should not match")
    end)
end

-- ============================================================================
-- Edge Case Tests: Spell Lock (interrupt)
-- ============================================================================

do -- edge_spell_lock
    test("edge_spell_lock: target is casting -> match", function()
        local ctx = make_context()
        ctx.target.is_casting = function() return true end
        local state = get_state(ctx)
        state.spell_lock_ready = true
        state.target = ctx.target
        state.use_interrupt = true
        assert_true(strategies[4].matches(ctx, state), "target casting should match")
    end)

    test("edge_spell_lock: target not casting -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.spell_lock_ready = true
        state.target = ctx.target
        state.use_interrupt = true
        assert_false(strategies[4].matches(ctx, state), "target not casting should not match")
    end)
end

-- ============================================================================
-- Edge Case Tests: Build state API safety (nil/throwing NS functions)
-- ============================================================================

do -- edge_buff
    test("edge_buff: NS.buff_up nil in build_state -> no crash, has_fel_armor false", function()
        local saved = NS.buff_up
        NS.buff_up = nil
        local ctx = make_context()
        local state = get_state(ctx)
        NS.buff_up = saved
        assert_not_nil(state, "state should not be nil")
        assert_false(state.has_fel_armor, "has_fel_armor should be false when NS.buff_up is nil")
    end)

    test("edge_buff: NS.buff_up throws in build_state -> no crash, has_fel_armor false", function()
        local saved = NS.buff_up
        NS.buff_up = function() error("crash") end
        local ctx = make_context()
        local state = get_state(ctx)
        NS.buff_up = saved
        assert_not_nil(state, "state should not be nil")
        assert_false(state.has_fel_armor, "has_fel_armor should be false when NS.buff_up throws")
    end)
end

-- ============================================================================
-- Edge Case Tests: API crash safety (spell_ready, try_cast)
-- ============================================================================

do -- edge_api
    test("edge_api: NS.spell_ready nil in build_state -> no crash, all ready flags false", function()
        local saved = NS.spell_ready
        NS.spell_ready = nil
        local ctx = make_context()
        local state = get_state(ctx)
        NS.spell_ready = saved
        assert_not_nil(state, "state should not be nil")
        assert_false(state.shadow_bolt_ready, "shadow_bolt_ready should be false")
        assert_false(state.corruption_ready, "corruption_ready should be false")
        assert_false(state.immolate_ready, "immolate_ready should be false")
    end)

    test("edge_api: NS.spell_ready throws in build_state -> no crash, all ready flags false", function()
        local saved = NS.spell_ready
        NS.spell_ready = function() error("crash") end
        local ctx = make_context()
        local state = get_state(ctx)
        NS.spell_ready = saved
        assert_not_nil(state, "state should not be nil")
        assert_false(state.shadow_bolt_ready, "shadow_bolt_ready should be false")
        assert_false(state.corruption_ready, "corruption_ready should be false")
    end)

    test("edge_api: NS.try_cast nil does not crash execute functions", function()
        local saved = NS.try_cast
        NS.try_cast = nil
        local ctx = make_context()
        for i = 1, #strategies do
            local ok, result = pcall(strategies[i].execute, ctx)
            assert_true(ok, string.format("strategies[%d].execute should not crash with NS.try_cast nil", i))
        end
        NS.try_cast = saved
    end)
end

-- ============================================================================
-- Edge Case Tests: Rotation crash safety
-- ============================================================================

do -- edge_rotation_crash
    test("edge_rotation_crash: all execute functions handle nil context", function()
        for i = 1, #strategies do
            local ok, result = pcall(strategies[i].execute)
            assert_true(ok, string.format("strategies[%d].execute should not crash with nil context", i))
        end
    end)

    test("edge_rotation_crash: all match functions handle nil context", function()
        for i = 1, #strategies do
            local ok, result = pcall(strategies[i].matches, nil, {})
            assert_true(ok, string.format("strategies[%d].matches should not crash with nil context", i))
        end
    end)

    test("edge_rotation_crash: all match functions handle nil state", function()
        local ctx = make_context()
        for i = 1, #strategies do
            local ok, result = pcall(strategies[i].matches, ctx, nil)
            assert_true(ok, string.format("strategies[%d].matches should not crash with nil state", i))
        end
    end)
end
-- ============================================================================
-- Edge case: HowlOfTerror boundaries
-- ============================================================================
do
    -- HowlOfTerror: enemies >= 3 and hp <= 40 -> match
    local ctx = make_context({enemies_count = 3, hp = 40})
    local state = get_state(ctx)
    state.howl_of_terror_ready = true
    state.enemies = 3
    state.hp = 40
    assert_true(strategies[8].matches(ctx, state), "howl enemies=3 hp=40 -> match (>=3, <=40)")

    local ctx2 = make_context({enemies_count = 2, hp = 40})
    local state2 = get_state(ctx2)
    state2.howl_of_terror_ready = true
    state2.enemies = 2
    state2.hp = 40
    assert_false(strategies[8].matches(ctx2, state2), "howl enemies=2 -> no match (<3)")

    local ctx3 = make_context({enemies_count = 3, hp = 41})
    local state3 = get_state(ctx3)
    state3.howl_of_terror_ready = true
    state3.enemies = 3
    state3.hp = 41
    assert_false(strategies[8].matches(ctx3, state3), "howl hp=41 -> no match (>40)")
end

-- ============================================================================
-- Edge case: SiphonLife debuff refresh
-- ============================================================================
do
    local ctx = make_context({})
    local state = get_state(ctx)
    state.siphon_life_ready = true
    local saved = NS.debuff_remains
    NS.debuff_remains = function(target, ids) return 3 end
    assert_true(strategies[14].matches(ctx, state), "siphonlife remains=3 -> match (<=4)")
    NS.debuff_remains = saved

    local ctx2 = make_context({})
    local state2 = get_state(ctx2)
    state2.siphon_life_ready = true
    local saved2 = NS.debuff_remains
    NS.debuff_remains = function(target, ids) return 5 end
    assert_false(strategies[14].matches(ctx2, state2), "siphonlife remains=5 -> no match (>4)")
    NS.debuff_remains = saved2
end

-- ============================================================================
-- Edge case: DrainLife boundaries
-- ============================================================================
do
    -- DrainLife: hp <= drain_life_hp (60) -> match; > -> no match
    local ctx = make_context({hp = 60, is_moving = false})
    local state = get_state(ctx)
    state.drain_life_ready = true
    state.hp = 60
    state.drain_life_hp = 60
    state.mana_pct = 50
    state.drain_soul_execute = 25
    local saved = ctx.target.get_health_percentage
    ctx.target.get_health_percentage = function() return 50 end
    state = get_state(ctx)
    state.drain_life_ready = true
    state.hp = 60
    state.drain_life_hp = 60
    state.mana_pct = 50
    state.drain_soul_execute = 25
    assert_true(strategies[15].matches(ctx, state), "drainlife hp=60 -> match (<=60)")
    ctx.target.get_health_percentage = saved

    local ctx2 = make_context({hp = 61, is_moving = false})
    local state2 = get_state(ctx2)
    state2.drain_life_ready = true
    state2.hp = 61
    state2.drain_life_hp = 60
    state2.mana_pct = 50
    assert_false(strategies[15].matches(ctx2, state2), "drainlife hp=61 -> no match (>60)")

    -- DrainLife: target HP <= drain_soul_execute (25) -> no match (Drain Soul priority)
    local ctx3 = make_context({hp = 50, is_moving = false})
    local state3 = get_state(ctx3)
    state3.drain_life_ready = true
    state3.hp = 50
    state3.drain_life_hp = 60
    state3.mana_pct = 50
    state3.drain_soul_execute = 25
    local saved3 = ctx3.target.get_health_percentage
    ctx3.target.get_health_percentage = function() return 25 end
    state3 = get_state(ctx3)
    state3.drain_life_ready = true
    state3.hp = 50
    state3.drain_life_hp = 60
    state3.mana_pct = 50
    state3.drain_soul_execute = 25
    assert_false(strategies[15].matches(ctx3, state3), "drainlife target_hp=25 -> no match (DS executes)")
    ctx3.target.get_health_percentage = saved3

    -- DrainLife: mana < 10 -> no match
    local ctx4 = make_context({hp = 50, is_moving = false, mana_pct = 9})
    local state4 = get_state(ctx4)
    state4.drain_life_ready = true
    state4.hp = 50
    state4.drain_life_hp = 60
    state4.mana_pct = 9
    state4.drain_soul_execute = 25
    local saved4 = ctx4.target.get_health_percentage
    ctx4.target.get_health_percentage = function() return 50 end
    state4 = get_state(ctx4)
    state4.drain_life_ready = true
    state4.hp = 50
    state4.drain_life_hp = 60
    state4.mana_pct = 9
    state4.drain_soul_execute = 25
    assert_false(strategies[15].matches(ctx4, state4), "drainlife mana=9 -> no match (<10)")
    ctx4.target.get_health_percentage = saved4
end

-- ============================================================================
-- Edge case: SummonPet guards
-- ============================================================================
do
    -- SummonPet: pet exists -> no match
    local ctx = make_context({})
    ctx.pet = { is_valid = function() return true end, get_health_percentage = function() return 100 end }
    local state = get_state(ctx)
    state.summon_felguard_ready = true
    assert_false(strategies[6].matches(ctx, state), "summonpet pet exists -> no match")

    -- SummonPet: OOC -> no match
    local ctx2 = make_context({in_combat = false})
    ctx2.pet = nil
    local state2 = get_state(ctx2)
    state2.summon_felguard_ready = true
    assert_false(strategies[6].matches(ctx2, state2), "summonpet OOC -> no match")
end

-- ============================================================================
-- Edge case: Soulstone OOC guard
-- ============================================================================
do
    local ctx = make_context({in_combat = true})
    local state = get_state(ctx)
    state.soulstone_ready = true
    assert_false(strategies[3].matches(ctx, state), "soulstone in combat -> no match")

    local ctx2 = make_context({in_combat = false})
    local state2 = get_state(ctx2)
    state2.soulstone_ready = true
    assert_true(strategies[3].matches(ctx2, state2), "soulstone OOC ready -> match")
end

-- ============================================================================
-- Edge case: Settings toggle
-- ============================================================================
do
    local ctx = make_context({})
    ctx.settings.leveling_use_corruption = false
    local state = get_state(ctx)
    state.corruption_ready = true
    state.use_corruption = false
    state.siphon_life_ready = true
    assert_false(strategies[11].matches(ctx, state), "corruption setting disabled -> no match")

    local ctx2 = make_context({})
    ctx2.settings.leveling_use_immolate = false
    local state2 = get_state(ctx2)
    state2.immolate_ready = true
    state2.use_immolate = false
    assert_false(strategies[12].matches(ctx2, state2), "immolate setting disabled -> no match")

    local ctx3 = make_context({})
    ctx3.settings.leveling_use_curse_of_agony = false
    local state3 = get_state(ctx3)
    state3.curse_of_agony_ready = true
    state3.use_curse_of_agony = false
    assert_false(strategies[13].matches(ctx3, state3), "curseofagony setting disabled -> no match")
end

-- ============================================================================
-- Edge case: Movement guard (DrainLife)
-- ============================================================================
do
    local ctx = make_context({hp = 50, is_moving = true})
    local state = get_state(ctx)
    state.drain_life_ready = true
    state.hp = 50
    state.drain_life_hp = 60
    state.mana_pct = 50
    state.is_moving = true
    assert_false(strategies[15].matches(ctx, state), "drainlife moving -> no match")
end

-- ============================================================================
-- Edge case: OOC guards
-- ============================================================================
do
    -- Fear: OOC -> no match
    local ctx = make_context({in_combat = false, enemies_count = 3})
    local state = get_state(ctx)
    state.fear_ready = true
    state.enemies = 3
    assert_false(strategies[7].matches(ctx, state), "fear OOC -> no match")

    -- DeathCoil: OOC -> no match
    local ctx2 = make_context({in_combat = false, hp = 30})
    local state2 = get_state(ctx2)
    state2.death_coil_ready = true
    state2.hp = 30
    assert_false(strategies[9].matches(ctx2, state2), "deathcoil OOC -> no match")

    -- LifeTap: OOC -> no match
    local ctx3 = make_context({in_combat = false, mana_pct = 20, hp = 50})
    local state3 = get_state(ctx3)
    state3.life_tap_ready = true
    state3.mana_pct = 20
    state3.hp = 50
    assert_false(strategies[10].matches(ctx3, state3), "lifetap OOC -> no match")

    -- Corruption: OOC -> no match
    local ctx4 = make_context({in_combat = false})
    local state4 = get_state(ctx4)
    state4.corruption_ready = true
    state4.use_corruption = true
    assert_false(strategies[11].matches(ctx4, state4), "corruption OOC -> no match")

    -- Immolate: OOC -> no match
    local ctx5 = make_context({in_combat = false})
    local state5 = get_state(ctx5)
    state5.immolate_ready = true
    state5.use_immolate = true
    assert_false(strategies[12].matches(ctx5, state5), "immolate OOC -> no match")

    -- CurseOfAgony: OOC -> no match
    local ctx6 = make_context({in_combat = false})
    local state6 = get_state(ctx6)
    state6.curse_of_agony_ready = true
    state6.use_curse_of_agony = true
    assert_false(strategies[13].matches(ctx6, state6), "curseofagony OOC -> no match")

    -- SiphonLife: OOC -> no match
    local ctx7 = make_context({in_combat = false})
    local state7 = get_state(ctx7)
    state7.siphon_life_ready = true
    assert_false(strategies[14].matches(ctx7, state7), "siphonlife OOC -> no match")

    -- DrainSoul: OOC -> no match
    local ctx8 = make_context({in_combat = false})
    local state8 = get_state(ctx8)
    state8.drain_soul_ready = true
    state8.mana_pct = 20
    state8.drain_soul_execute = 25
    local saved8 = ctx8.target.get_health_percentage
    ctx8.target.get_health_percentage = function() return 20 end
    state8 = get_state(ctx8)
    state8.drain_soul_ready = true
    state8.mana_pct = 20
    state8.drain_soul_execute = 25
    assert_false(strategies[16].matches(ctx8, state8), "drainsoul OOC -> no match")
    ctx8.target.get_health_percentage = saved8

    -- ShadowBolt: OOC -> no match
    local ctx9 = make_context({in_combat = false, is_moving = false, mana_pct = 50})
    local state9 = get_state(ctx9)
    state9.shadow_bolt_ready = true
    state9.mana_pct = 50
    state9.is_moving = false
    assert_false(strategies[17].matches(ctx9, state9), "shadowbolt OOC -> no match")
end

-- ============================================================================
-- API crash: NS.try_cast throwing
-- ============================================================================
do
    local saved = NS.try_cast
    local ctx = make_context({})

    -- NS.try_cast throws -> execute should not crash
    NS.try_cast = function() error("simulated throw") end
    for i = 1, #strategies do
        local ok, result = pcall(strategies[i].execute, ctx)
        assert_true(ok, "try_cast=throw: strategy " .. i .. " execute did not crash")
    end

    NS.try_cast = saved
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

-- ============================================================================
-- Summary
-- ============================================================================

print(string.format("\n=== Warlock Leveling Unit Tests: %d passed, %d failed (%d assertions) ===\n", passed, failed, assertions))
if failed > 0 then
    error(string.format("Some tests FAILED (%d failures)", failed))
else
    print("All Warlock leveling unit tests passed!")
end
