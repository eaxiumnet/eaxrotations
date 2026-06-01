-- Unit tests for Rogue leveling rotation
-- Tests build_state, all 13 match functions, strategy ordering,
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
        get_class = function() return 4 end,
        is_in_combat = function() return false end,
        get_target = function() return mock_target end,
        get_position = function() return { x = 0, y = 0, z = 0 } end,
        get_power = function() return 100 end,
    }

    NS.log = function() end
    NS.log_warning = function() end
    NS.spell_ready = function(spell_action)
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
    NS.get_distance = function(target)
        if not target then return nil end
        return 10
    end
    NS.debuff_remains = function(target, spell)
        if not target or not spell then return 0 end
        return 0
    end
    NS.debuff_stacks = function(target, spell)
        if not target or not spell then return 0 end
        return 0
    end
    NS.buff_remains = function(unit, buff_ids) return 0 end
    NS.buff_up = function(unit, buff_ids) return false end
    NS.combo_points = 0
    NS.energy = 100

    -- rotation_registry mock that captures registrations
    NS.rotation_registry = {
        _registrations = {},
        register = function(self, key, strategies, opts)
            self._registrations[key] = { strategies = strategies, opts = opts }
        end,
        set_class_config = function(self, config) end,
    }

    NS.RogueSpells = {}
    for k, v in pairs(MOCK_ROGUE_SPELLS) do
        NS.RogueSpells[k] = v
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
            get_power = function() return 100 end,
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
            use_cooldowns = true,
            leveling_use_blade_flurry = true,
            leveling_blade_flurry_enemies = 3,
            leveling_vanish_hp = 15,
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
-- Load the Rogue leveling module
-- ============================================================================

local NS, core, mock_player, mock_target, mock_state = build_mock_env()
local ok, module = pcall(dofile, "EaxRotations/classes/rogue/leveling_sylvanas.lua")
if not ok then
    error("Failed to load Rogue leveling module: " .. tostring(module))
end
if not module or type(module) ~= "table" then
    error("Rogue leveling module should return a table of strategies")
end

-- Get the registration info
local reg = NS.rotation_registry._registrations["leveling"]
if not reg then
    error("Rogue leveling module should register as 'leveling' in rotation_registry")
end
local strategies = reg.strategies
local get_state = reg.opts.get_state

print("=== Rogue Leveling Unit Tests ===\n")
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
        me = { is_valid = function() return true end, has_buff = function() return false end, get_health = function() return 10000 end, get_max_health = function() return 10000 end, get_power = function() return 100 end },
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
    assert_true(state.sinister_strike_ready, "sinister_strike_ready")
    assert_true(state.eviscerate_ready, "eviscerate_ready")
    assert_true(state.slice_and_dice_ready, "slice_and_dice_ready")
    assert_true(state.rupture_ready, "rupture_ready")
    assert_true(state.garrote_ready, "garrote_ready")
    assert_true(state.kick_ready, "kick_ready")
    assert_true(state.gouge_ready, "gouge_ready")
    assert_true(state.evasion_ready, "evasion_ready")
    assert_true(state.sprint_ready, "sprint_ready")
    assert_true(state.blade_flurry_ready, "blade_flurry_ready")
    assert_true(state.adrenaline_rush_ready, "adrenaline_rush_ready")
    assert_true(state.cold_blood_ready, "cold_blood_ready")
    assert_true(state.vanish_ready, "vanish_ready")
    assert_true(state.stealth_ready, "stealth_ready")
    assert_true(state.sap_ready, "sap_ready")
    assert_true(state.blind_ready, "blind_ready")
    assert_true(state.expose_armor_ready, "expose_armor_ready")
end)

test("build_state: combo points and energy from NS", function()
    NS.combo_points = 3
    NS.energy = 60
    local ctx = make_context()
    local state = get_state(ctx)
    assert_eq(state.combo_points, 3, "combo_points from NS")
    assert_eq(state.energy, 60, "energy from NS")
    assert_eq(state.max_combo_points, 5, "max_combo_points")
end)

test("build_state: custom settings from context", function()
    local ctx = make_context()
    ctx.settings.use_cooldowns = false
    ctx.settings.leveling_use_blade_flurry = false
    ctx.settings.leveling_blade_flurry_enemies = 2
    ctx.settings.leveling_vanish_hp = 30
    local state = get_state(ctx)
    assert_false(state.use_cooldowns, "use_cooldowns from settings")
    assert_false(state.use_blade_flurry, "use_blade_flurry from settings")
    assert_eq(state.blade_flurry_min_enemies, 2, "blade_flurry_min_enemies from settings")
    assert_eq(state.vanish_hp, 30, "vanish_hp from settings")
end)

test("build_state: missing settings uses defaults", function()
    local ctx = make_context({settings = {}})
    local state = get_state(ctx)
    assert_true(state.use_cooldowns, "default use_cooldowns = true")
    assert_true(state.use_blade_flurry, "default use_blade_flurry = true")
    assert_eq(state.blade_flurry_min_enemies, 3, "default blade_flurry_min_enemies = 3")
    assert_eq(state.vanish_hp, 15, "default vanish_hp = 15")
end)

-- ============================================================================
-- Test: stealth_matches (strategy #1)
-- ============================================================================

test("stealth_matches: OOC, not stealthed, ready, target nearby -> true", function()
    local ctx = make_context({in_combat = false})
    NS.get_distance = function() return 10 end
    local state = get_state(ctx)
    state.stealthed = false
    state.stealth_ready = true
    assert_true(strategies[1].matches(ctx, state), "should match when OOC with target nearby")
end)

test("stealth_matches: in combat -> false", function()
    local ctx = make_context({in_combat = true})
    local state = get_state(ctx)
    state.stealthed = false
    state.stealth_ready = true
    assert_false(strategies[1].matches(ctx, state), "should not match in combat")
end)

test("stealth_matches: already stealthed -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.stealthed = true
    state.stealth_ready = true
    assert_false(strategies[1].matches(ctx, state), "should not match if already stealthed")
end)

test("stealth_matches: target too far -> false", function()
    local ctx = make_context({in_combat = false})
    NS.get_distance = function() return 40 end
    local state = get_state(ctx)
    state.stealthed = false
    state.stealth_ready = true
    assert_false(strategies[1].matches(ctx, state), "should not match if target far away")
end)

test("stealth_matches: nil state -> does not crash", function()
    local ctx = make_context({in_combat = false})
    local ok, result = pcall(strategies[1].matches, ctx, nil)
    assert_true(ok, "nil state should not throw")
end)

-- ============================================================================
-- Test: kick_matches (strategy #4)
-- ============================================================================

test("kick_matches: ready, target casting, interrupt enabled -> true", function()
    local ctx = make_context()
    ctx.target.is_casting = function() return true end
    local state = get_state(ctx)
    state.kick_ready = true
    assert_true(strategies[4].matches(ctx, state), "target casting should match")
end)

test("kick_matches: target not casting -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.kick_ready = true
    assert_false(strategies[4].matches(ctx, state), "target not casting should not match")
end)

test("kick_matches: no target -> false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.kick_ready = true
    state.target = nil
    assert_false(strategies[4].matches(ctx, state), "no target should return false")
end)

test("kick_matches: interrupt disabled -> false", function()
    local ctx = make_context()
    ctx.settings.use_interrupt = false
    local state = get_state(ctx)
    state.kick_ready = true
    state.use_interrupt = false
    assert_false(strategies[4].matches(ctx, state), "interrupt disabled should not match")
end)

-- ============================================================================
-- Test: vanish_matches (strategy #7)
-- ============================================================================

test("vanish_matches: ready, very low HP -> true", function()
    local ctx = make_context({hp = 10})
    local state = get_state(ctx)
    state.vanish_ready = true
    state.hp = 10
    state.vanish_hp = 15
    assert_true(strategies[7].matches(ctx, state), "HP below threshold should match")
end)

test("vanish_matches: HP above threshold -> false", function()
    local ctx = make_context({hp = 50})
    local state = get_state(ctx)
    state.vanish_ready = true
    state.hp = 50
    state.vanish_hp = 15
    assert_false(strategies[7].matches(ctx, state), "HP above threshold should not match")
end)

test("vanish_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false, hp = 10})
    local state = get_state(ctx)
    state.vanish_ready = true
    state.in_combat = false
    state.hp = 10
    assert_false(strategies[7].matches(ctx, state), "OOC should not match")
end)

-- ============================================================================
-- Test: evasion_matches (strategy #8)
-- ============================================================================

test("evasion_matches: ready, low HP, multiple enemies -> true", function()
    local ctx = make_context({hp = 40, enemies_count = 3})
    local state = get_state(ctx)
    state.evasion_ready = true
    state.hp = 40
    state.enemies = 3
    assert_true(strategies[8].matches(ctx, state), "should match when overwhelmed")
end)

test("evasion_matches: HP above 50 -> false", function()
    local ctx = make_context({hp = 80, enemies_count = 3})
    local state = get_state(ctx)
    state.evasion_ready = true
    state.hp = 80
    state.enemies = 3
    assert_false(strategies[8].matches(ctx, state), "HP above 50 should not match")
end)

test("evasion_matches: single enemy -> false", function()
    local ctx = make_context({hp = 40, enemies_count = 1})
    local state = get_state(ctx)
    state.evasion_ready = true
    state.hp = 40
    state.enemies = 1
    assert_false(strategies[8].matches(ctx, state), "single enemy should not match")
end)

test("evasion_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false, hp = 40})
    local state = get_state(ctx)
    state.evasion_ready = true
    state.in_combat = false
    state.hp = 40
    assert_false(strategies[8].matches(ctx, state), "OOC should not match")
end)

-- ============================================================================
-- Test: sprint_escape_matches (strategy #9)
-- ============================================================================

test("sprint_matches: ready, very low HP -> true", function()
    local ctx = make_context({hp = 20})
    local state = get_state(ctx)
    state.sprint_ready = true
    state.hp = 20
    assert_true(strategies[10].matches(ctx, state), "HP below 30 should match")
end)

test("sprint_matches: HP above 30 -> false", function()
    local ctx = make_context({hp = 50})
    local state = get_state(ctx)
    state.sprint_ready = true
    state.hp = 50
    assert_false(strategies[10].matches(ctx, state), "HP above 30 should not match")
end)

test("sprint_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false, hp = 20})
    local state = get_state(ctx)
    state.sprint_ready = true
    state.in_combat = false
    state.hp = 20
    assert_false(strategies[10].matches(ctx, state), "OOC should not match")
end)

-- ============================================================================
-- Test: cold_blood_matches (strategy #11)
-- ============================================================================

test("cold_blood_matches: ready, 5 CP, cooldowns enabled -> true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.cold_blood_ready = true
    state.use_cooldowns = true
    state.combo_points = 5
    assert_true(strategies[11].matches(ctx, state), "5 CP with cooldowns should match")
end)

test("cold_blood_matches: below 5 CP -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.cold_blood_ready = true
    state.use_cooldowns = true
    state.combo_points = 3
    assert_false(strategies[11].matches(ctx, state), "3 CP should not match")
end)

test("cold_blood_matches: cooldowns disabled -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.cold_blood_ready = true
    state.use_cooldowns = false
    state.combo_points = 5
    assert_false(strategies[11].matches(ctx, state), "cooldowns disabled should not match")
end)

test("cold_blood_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.cold_blood_ready = true
    state.use_cooldowns = true
    state.combo_points = 5
    state.in_combat = false
    assert_false(strategies[11].matches(ctx, state), "OOC should not match")
end)

-- ============================================================================
-- Test: adrenaline_rush_matches (strategy #12)
-- ============================================================================

test("adrenaline_rush_matches: ready, low energy, cooldowns enabled -> true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.adrenaline_rush_ready = true
    state.use_cooldowns = true
    state.energy = 40
    assert_true(strategies[12].matches(ctx, state), "low energy with cooldowns should match")
end)

test("adrenaline_rush_matches: energy above 60 -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.adrenaline_rush_ready = true
    state.use_cooldowns = true
    state.energy = 70
    assert_false(strategies[12].matches(ctx, state), "energy above 60 should not match")
end)

test("adrenaline_rush_matches: cooldowns disabled -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.adrenaline_rush_ready = true
    state.use_cooldowns = false
    state.energy = 40
    assert_false(strategies[12].matches(ctx, state), "cooldowns disabled should not match")
end)

-- ============================================================================
-- Test: blade_flurry_matches (strategy #13)
-- ============================================================================

test("blade_flurry_matches: ready, 3+ enemies, enabled -> true", function()
    local ctx = make_context({enemies_count = 4})
    local state = get_state(ctx)
    state.blade_flurry_ready = true
    state.use_blade_flurry = true
    state.enemies = 4
    state.blade_flurry_min_enemies = 3
    assert_true(strategies[14].matches(ctx, state), "3+ enemies should match")
end)

test("blade_flurry_matches: not enough enemies -> false", function()
    local ctx = make_context({enemies_count = 1})
    local state = get_state(ctx)
    state.blade_flurry_ready = true
    state.use_blade_flurry = true
    state.enemies = 1
    state.blade_flurry_min_enemies = 3
    assert_false(strategies[14].matches(ctx, state), "1 enemy should not match")
end)

test("blade_flurry_matches: disabled -> false", function()
    local ctx = make_context({enemies_count = 4})
    local state = get_state(ctx)
    state.blade_flurry_ready = true
    state.use_blade_flurry = false
    state.enemies = 4
    assert_false(strategies[14].matches(ctx, state), "disabled should not match")
end)

-- ============================================================================
-- Test: slice_and_dice_matches (strategy #14)
-- ============================================================================

test("slice_and_dice_matches: ready, no buff, enough CP -> true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.slice_and_dice_ready = true
    state.has_slice_and_dice = false
    state.combo_points = 2
    assert_true(strategies[15].matches(ctx, state), "should match when ready")
end)

test("slice_and_dice_matches: already has buff -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.slice_and_dice_ready = true
    state.has_slice_and_dice = true
    state.combo_points = 2
    assert_false(strategies[15].matches(ctx, state), "buff active should not match")
end)

test("slice_and_dice_matches: 0 combo points -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.slice_and_dice_ready = true
    state.has_slice_and_dice = false
    state.combo_points = 0
    assert_false(strategies[15].matches(ctx, state), "0 CP should not match")
end)

test("slice_and_dice_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.slice_and_dice_ready = true
    state.has_slice_and_dice = false
    state.combo_points = 2
    state.in_combat = false
    assert_false(strategies[15].matches(ctx, state), "OOC should not match")
end)

-- ============================================================================
-- Test: rupture_matches (strategy #15)
-- ============================================================================

test("rupture_matches: ready, 3-4 CP, debuff expired -> true", function()
    local ctx = make_context()
    NS.debuff_remains = function(target, spell) return 0 end
    local state = get_state(ctx)
    state.rupture_ready = true
    state.combo_points = 3
    assert_true(strategies[16].matches(ctx, state), "should match when ready")
end)

test("rupture_matches: debuff still active -> false", function()
    local ctx = make_context()
    NS.debuff_remains = function(target, spell) return 10 end
    local state = get_state(ctx)
    state.rupture_ready = true
    state.combo_points = 3
    assert_false(strategies[16].matches(ctx, state), "active debuff should not match")
    NS.debuff_remains = function(target, spell) return 0 end
end)

test("rupture_matches: 5 CP (prefer eviscerate) -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.rupture_ready = true
    state.combo_points = 5
    assert_false(strategies[16].matches(ctx, state), "5 CP should prefer eviscerate")
end)

test("rupture_matches: 1 CP -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.rupture_ready = true
    state.combo_points = 1
    assert_false(strategies[16].matches(ctx, state), "1 CP should not match")
end)

-- ============================================================================
-- Test: expose_armor_matches (strategy #16)
-- ============================================================================

test("expose_armor_matches: ready, 3-4 CP, no stacks -> true", function()
    local ctx = make_context()
    NS.debuff_stacks = function(target, spell) return 0 end
    local state = get_state(ctx)
    state.expose_armor_ready = true
    state.use_expose_armor = true
    state.target_ttd = 30
    state.combo_points = 3
    assert_true(strategies[17].matches(ctx, state), "should match when ready")
end)

test("expose_armor_matches: already has stacks -> false", function()
    local ctx = make_context()
    NS.debuff_stacks = function(target, spell) return 3 end
    local state = get_state(ctx)
    state.expose_armor_ready = true
    state.use_expose_armor = true
    state.target_ttd = 30
    state.combo_points = 3
    assert_false(strategies[17].matches(ctx, state), "stacks active should not match")
    NS.debuff_stacks = function(target, spell) return 0 end
end)

test("expose_armor_matches: 5 CP (prefer eviscerate) -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.expose_armor_ready = true
    state.use_expose_armor = true
    state.target_ttd = 30
    state.combo_points = 5
    assert_false(strategies[17].matches(ctx, state), "5 CP should prefer eviscerate")
end)

test("expose_armor_matches: 1 CP -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.expose_armor_ready = true
    state.use_expose_armor = true
    state.target_ttd = 30
    state.combo_points = 1
    assert_false(strategies[17].matches(ctx, state), "1 CP should not match")
end)

-- ============================================================================
-- Test: eviscerate_matches (strategy #18)
-- ============================================================================

test("eviscerate_matches: ready, 5 CP -> true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.eviscerate_ready = true
    state.combo_points = 5
    assert_true(strategies[19].matches(ctx, state), "5 CP should match")
end)

test("eviscerate_matches: 3 CP -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.eviscerate_ready = true
    state.combo_points = 3
    assert_false(strategies[19].matches(ctx, state), "3 CP should not match")
end)

test("eviscerate_matches: no target -> false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.eviscerate_ready = true
    state.target = nil
    state.combo_points = 5
    assert_false(strategies[19].matches(ctx, state), "no target should not match")
end)

-- ============================================================================
-- Test: sinister_strike_matches (strategy #19)
-- ============================================================================

test("sinister_strike_matches: ready, below 5 CP -> true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.sinister_strike_ready = true
    state.combo_points = 3
    assert_true(strategies[20].matches(ctx, state), "should match when below max CP")
end)

test("sinister_strike_matches: at 5 CP -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.sinister_strike_ready = true
    state.combo_points = 5
    assert_false(strategies[20].matches(ctx, state), "5 CP should not match")
end)

test("sinister_strike_matches: no target -> false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.sinister_strike_ready = true
    state.target = nil
    state.combo_points = 3
    assert_false(strategies[20].matches(ctx, state), "no target should not match")
end)

test("sinister_strike_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.sinister_strike_ready = true
    state.combo_points = 3
    state.in_combat = false
    assert_false(strategies[20].matches(ctx, state), "OOC should not match")
end)

-- ============================================================================
-- Test: Strategy priority ordering
-- ============================================================================

test("strategies: 20 strategies in correct priority order", function()
    local expected = {
        "Stealth",
        "Ambush",
        "Garrote",
        "Kick",
        "Gouge",
        "ShivPurge",
        "Vanish",
        "Evasion",
        "HealthPotion",
        "Sprint",
        "Blind",
        "ColdBlood",
        "AdrenalineRush",
        "BladeFlurry",
        "SliceAndDice",
        "Rupture",
        "ExposeArmor",
        "KidneyShot",
        "Eviscerate",
        "SinisterStrike",
    }
    assert_eq(#strategies, 20, "should have 20 strategies")
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

test("execute_Stealth: does not crash", function()
    local ok, result = pcall(strategies[1].execute)
    assert_true(ok, "execute should not throw")
end)

test("execute_SinisterStrike: does not crash with context", function()
    local ctx = make_context()
    local ok, result = pcall(strategies[20].execute, ctx)
    assert_true(ok, "execute with context should not throw")
end)

-- ============================================================================
-- Test: Nil guard - module returns nil when NS is nil
-- ============================================================================

test("module: returns nil when EaxRotations is nil", function()
    local _, c = build_mock_env()
    _G.EaxRotations = nil
    local nil_mod = dofile("EaxRotations/classes/rogue/leveling_sylvanas.lua")
    assert_nil(nil_mod, "should return nil when NS is nil")
    _G.EaxRotations = NS
end)

-- ============================================================================
-- Test: All match functions handle nil gracefully
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
    local ctx = make_context({in_combat = true, hp = 100, enemies_count = 1})
    local state = get_state(ctx)
    assert_not_nil(state, "state should be built")
    for i, s in ipairs(strategies) do
        local ok_match, matched = pcall(s.matches, ctx, state)
        assert_true(ok_match, "strategy[" .. i .. "] matches should not throw")
        local ok_exec, executed = pcall(s.execute, ctx)
        assert_true(ok_exec, "strategy[" .. i .. "] execute should not throw")
    end
end)

test("rotation: OOC scenario - Stealth should match, combat abilities should not", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.stealthed = false
    state.stealth_ready = true
    -- Reset distance to safe value (previous test may have changed it)
    NS.get_distance = function() return 10 end

    -- Stealth should match OOC with target nearby
    assert_true(strategies[1].matches(ctx, state), "Stealth should match OOC")

    -- Combat abilities should not match OOC (strategies 2-13)
    -- Kick(2) checks state.target:is_casting and state.in_combat
    -- Vanish(3) checks state.in_combat
    -- Evasion(4) checks state.in_combat
    -- ... all combat abilities require in_combat
    for i = 3, 13 do
        local ok, matched = pcall(strategies[i].matches, ctx, state)
        assert_true(ok, "strategy[" .. i .. "] matches should not throw")
        assert_false(matched, "strategy[" .. i .. "] should not match OOC")
    end
end)

test("rotation: low HP scenario - various escape/defense abilities", function()
    local ctx = make_context({hp = 20, enemies_count = 3})
    local state = get_state(ctx)
    state.vanish_ready = true
    state.evasion_ready = true
    state.sprint_ready = true
    state.hp = 20
    state.enemies = 3
    state.vanish_hp = 15

    -- Vanish: HP(20) > vanish_hp(15), should NOT match
    assert_false(strategies[7].matches(ctx, state), "Vanish should not match when HP above threshold")

    -- Set HP low enough for Vanish
    state.hp = 10
    assert_true(strategies[7].matches(ctx, state), "Vanish should match when HP below threshold")

    -- Sprint: HP(10) < 30, should match
    -- Sprint also checks sprint_ready which is true
    assert_true(strategies[10].matches(ctx, state), "Sprint should match when HP below 30")

    -- Evasion: HP(10) < 50, enemies(3) >= 2, should match
    assert_true(state.enemies >= 2, "there are 3 enemies")
    assert_true(strategies[8].matches(ctx, state), "Evasion should match when low HP with multiple enemies")
end)

test("rotation: max combo points finisher priority", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.eviscerate_ready = true
    state.sinister_strike_ready = true
    state.combo_points = 5

    -- Eviscerate should match at 5 CP
    assert_true(strategies[19].matches(ctx, state), "Eviscerate should match at 5 CP")
    -- Sinister Strike should not match at 5 CP
    assert_false(strategies[20].matches(ctx, state), "Sinister Strike should not match at 5 CP")
end)

-- ============================================================================
-- Summary
-- ============================================================================

print(string.format("\n=== Rogue Leveling Unit Tests: %d passed, %d failed (%d assertions) ===\n", passed, failed, assertions))
if failed > 0 then
    error(string.format("Some tests FAILED (%d failures)", failed))
else
    print("All Rogue leveling unit tests passed!")
end
