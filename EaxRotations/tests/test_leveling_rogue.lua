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
-- Test: sprint_escape_matches (strategy #10)
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
-- Test: cold_blood_matches (strategy #12)
-- ============================================================================

test("cold_blood_matches: ready, 5 CP, cooldowns enabled -> true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.cold_blood_ready = true
    state.use_cooldowns = true
    state.combo_points = 5
    assert_true(strategies[12].matches(ctx, state), "5 CP with cooldowns should match")
end)

test("cold_blood_matches: below 5 CP -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.cold_blood_ready = true
    state.use_cooldowns = true
    state.combo_points = 3
    assert_false(strategies[12].matches(ctx, state), "3 CP should not match")
end)

test("cold_blood_matches: cooldowns disabled -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.cold_blood_ready = true
    state.use_cooldowns = false
    state.combo_points = 5
    assert_false(strategies[12].matches(ctx, state), "cooldowns disabled should not match")
end)

test("cold_blood_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.cold_blood_ready = true
    state.use_cooldowns = true
    state.combo_points = 5
    state.in_combat = false
    assert_false(strategies[12].matches(ctx, state), "OOC should not match")
end)

-- ============================================================================
-- Test: adrenaline_rush_matches (strategy #13)
-- ============================================================================

test("adrenaline_rush_matches: ready, low energy, cooldowns enabled -> true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.adrenaline_rush_ready = true
    state.use_cooldowns = true
    state.energy = 40
    assert_true(strategies[13].matches(ctx, state), "low energy with cooldowns should match")
end)

test("adrenaline_rush_matches: energy above 60 -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.adrenaline_rush_ready = true
    state.use_cooldowns = true
    state.energy = 70
    assert_false(strategies[13].matches(ctx, state), "energy above 60 should not match")
end)

test("adrenaline_rush_matches: cooldowns disabled -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.adrenaline_rush_ready = true
    state.use_cooldowns = false
    state.energy = 40
    assert_false(strategies[13].matches(ctx, state), "cooldowns disabled should not match")
end)

-- ============================================================================
-- Test: blade_flurry_matches (strategy #14)
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
-- Test: slice_and_dice_matches (strategy #15)
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
-- Test: rupture_matches (strategy #16)
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
-- Test: expose_armor_matches (strategy #17)
-- ============================================================================

test("expose_armor_matches: ready, 3-4 CP, no stacks -> true", function()
    local ctx = make_context()
    ctx.target_armor = 100  -- gate added in feat(rogue): gate Expose Armor on target_armor > 0
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
    ctx.target_armor = 100
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
    ctx.target_armor = 100
    local state = get_state(ctx)
    state.expose_armor_ready = true
    state.use_expose_armor = true
    state.target_ttd = 30
    state.combo_points = 5
    assert_false(strategies[17].matches(ctx, state), "5 CP should prefer eviscerate")
end)

test("expose_armor_matches: 1 CP -> false", function()
    local ctx = make_context()
    ctx.target_armor = 100
    local state = get_state(ctx)
    state.expose_armor_ready = true
    state.use_expose_armor = true
    state.target_ttd = 30
    state.combo_points = 1
    assert_false(strategies[17].matches(ctx, state), "1 CP should not match")
end)

-- ============================================================================
-- Test: eviscerate_matches (strategy #19)
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
-- Test: sinister_strike_matches (strategy #20)
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
-- ============================================================================
-- Edge case tests - boundary values
-- ============================================================================

do -- edge_gouge
    local label = "edge_gouge"

    test(label .. ": HP exactly 40 -> match", function()
        local ctx = make_context({hp = 40})
        local state = get_state(ctx)
        state.gouge_ready = true
        state.hp = 40
        assert_true(strategies[5].matches(ctx, state), "HP 40 should match (<= threshold)")
    end)

    test(label .. ": HP exactly 41 -> no match", function()
        local ctx = make_context({hp = 41})
        local state = get_state(ctx)
        state.gouge_ready = true
        state.hp = 41
        assert_false(strategies[5].matches(ctx, state), "HP 41 should not match (> threshold)")
    end)
end

do -- edge_vanish
    local label = "edge_vanish"

    test(label .. ": HP exactly 15 (vanish_hp) -> match", function()
        local ctx = make_context({hp = 15})
        local state = get_state(ctx)
        state.vanish_ready = true
        state.hp = 15
        state.vanish_hp = 15
        assert_true(strategies[7].matches(ctx, state), "HP 15 should match (<= threshold)")
    end)

    test(label .. ": HP exactly 16 (above vanish_hp) -> no match", function()
        local ctx = make_context({hp = 16})
        local state = get_state(ctx)
        state.vanish_ready = true
        state.hp = 16
        state.vanish_hp = 15
        assert_false(strategies[7].matches(ctx, state), "HP 16 should not match (> threshold)")
    end)

    test(label .. ": vanish not ready -> no match", function()
        local ctx = make_context({hp = 10})
        local state = get_state(ctx)
        state.vanish_ready = false
        state.hp = 10
        state.vanish_hp = 15
        assert_false(strategies[7].matches(ctx, state), "not ready should not match")
    end)

    test(label .. ": OOC -> no match", function()
        local ctx = make_context({hp = 10, in_combat = false})
        local state = get_state(ctx)
        state.vanish_ready = true
        state.hp = 10
        state.vanish_hp = 15
        state.in_combat = false
        assert_false(strategies[7].matches(ctx, state), "OOC should not match")
    end)
end

do -- edge_evasion
    local label = "edge_evasion"

    test(label .. ": HP exactly 50, enemies exactly 2 -> match", function()
        local ctx = make_context({hp = 50, enemies_count = 2})
        local state = get_state(ctx)
        state.evasion_ready = true
        state.hp = 50
        state.enemies = 2
        assert_true(strategies[8].matches(ctx, state), "HP 50 with 2 enemies should match")
    end)

    test(label .. ": HP exactly 51, enemies 2 -> no match", function()
        local ctx = make_context({hp = 51, enemies_count = 2})
        local state = get_state(ctx)
        state.evasion_ready = true
        state.hp = 51
        state.enemies = 2
        assert_false(strategies[8].matches(ctx, state), "HP 51 should not match (> 50)")
    end)

    test(label .. ": HP 40, exactly 1 enemy -> no match", function()
        local ctx = make_context({hp = 40, enemies_count = 1})
        local state = get_state(ctx)
        state.evasion_ready = true
        state.hp = 40
        state.enemies = 1
        assert_false(strategies[8].matches(ctx, state), "1 enemy should not match (< 2)")
    end)

    test(label .. ": not ready -> no match", function()
        local ctx = make_context({hp = 40, enemies_count = 3})
        local state = get_state(ctx)
        state.evasion_ready = false
        state.hp = 40
        state.enemies = 3
        assert_false(strategies[8].matches(ctx, state), "not ready should not match")
    end)
end

do -- edge_sprint
    local label = "edge_sprint"

    test(label .. ": HP exactly 30 -> match", function()
        local ctx = make_context({hp = 30})
        local state = get_state(ctx)
        state.sprint_ready = true
        state.hp = 30
        assert_true(strategies[10].matches(ctx, state), "HP 30 should match (<= threshold)")
    end)

    test(label .. ": HP exactly 31 -> no match", function()
        local ctx = make_context({hp = 31})
        local state = get_state(ctx)
        state.sprint_ready = true
        state.hp = 31
        assert_false(strategies[10].matches(ctx, state), "HP 31 should not match (> threshold)")
    end)
end

do -- edge_blind
    local label = "edge_blind"

    test(label .. ": HP exactly 30 -> match", function()
        local ctx = make_context({hp = 30})
        local state = get_state(ctx)
        state.blind_ready = true
        state.hp = 30
        assert_true(strategies[11].matches(ctx, state), "HP 30 should match (<= threshold)")
    end)

    test(label .. ": HP exactly 31 -> no match", function()
        local ctx = make_context({hp = 31})
        local state = get_state(ctx)
        state.blind_ready = true
        state.hp = 31
        assert_false(strategies[11].matches(ctx, state), "HP 31 should not match (> threshold)")
    end)
end

do -- edge_cold_blood
    local label = "edge_cold_blood"

    test(label .. ": 5 CP, cooldowns enabled -> match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.cold_blood_ready = true
        state.use_cooldowns = true
        state.combo_points = 5
        assert_true(strategies[12].matches(ctx, state), "5 CP with cooldowns should match")
    end)

    test(label .. ": 4 CP -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.cold_blood_ready = true
        state.use_cooldowns = true
        state.combo_points = 4
        assert_false(strategies[12].matches(ctx, state), "4 CP should not match (< 5)")
    end)

    test(label .. ": cooldowns disabled -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.cold_blood_ready = true
        state.use_cooldowns = false
        state.combo_points = 5
        assert_false(strategies[12].matches(ctx, state), "cooldowns disabled should not match")
    end)
end

do -- edge_adrenaline_rush
    local label = "edge_adrenaline_rush"

    test(label .. ": energy exactly 60 -> match (<= 60)", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.adrenaline_rush_ready = true
        state.use_cooldowns = true
        state.energy = 60
        assert_true(strategies[13].matches(ctx, state), "energy 60 should match (<= 60)")
    end)

    test(label .. ": energy exactly 61 -> no match (> 60)", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.adrenaline_rush_ready = true
        state.use_cooldowns = true
        state.energy = 61
        assert_false(strategies[13].matches(ctx, state), "energy 61 should not match (> 60)")
    end)

    test(label .. ": cooldowns disabled -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.adrenaline_rush_ready = true
        state.use_cooldowns = false
        state.energy = 40
        assert_false(strategies[13].matches(ctx, state), "cooldowns disabled should not match")
    end)
end

do -- edge_blade_flurry
    local label = "edge_blade_flurry"

    test(label .. ": enemies exactly 3 (threshold) -> match", function()
        local ctx = make_context({enemies_count = 3})
        local state = get_state(ctx)
        state.blade_flurry_ready = true
        state.use_blade_flurry = true
        state.enemies = 3
        state.blade_flurry_min_enemies = 3
        assert_true(strategies[14].matches(ctx, state), "3 enemies should match (>= threshold)")
    end)

    test(label .. ": enemies exactly 2 -> no match", function()
        local ctx = make_context({enemies_count = 2})
        local state = get_state(ctx)
        state.blade_flurry_ready = true
        state.use_blade_flurry = true
        state.enemies = 2
        state.blade_flurry_min_enemies = 3
        assert_false(strategies[14].matches(ctx, state), "2 enemies should not match (< threshold)")
    end)

    test(label .. ": AoE disabled -> no match", function()
        local ctx = make_context({enemies_count = 4})
        local state = get_state(ctx)
        state.blade_flurry_ready = true
        state.use_blade_flurry = false
        state.enemies = 4
        assert_false(strategies[14].matches(ctx, state), "AoE disabled should not match")
    end)
end

do -- edge_slice_and_dice
    local label = "edge_slice_and_dice"

    test(label .. ": 1 CP, no buff -> match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.slice_and_dice_ready = true
        state.has_slice_and_dice = false
        state.combo_points = 1
        assert_true(strategies[15].matches(ctx, state), "1 CP should match (>= 1)")
    end)

    test(label .. ": 0 CP -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.slice_and_dice_ready = true
        state.has_slice_and_dice = false
        state.combo_points = 0
        assert_false(strategies[15].matches(ctx, state), "0 CP should not match (< 1)")
    end)

    test(label .. ": buff already active -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.slice_and_dice_ready = true
        state.has_slice_and_dice = true
        state.combo_points = 2
        assert_false(strategies[15].matches(ctx, state), "buff active should not match")
    end)
end

do -- edge_rupture
    local label = "edge_rupture"

    test(label .. ": 3 CP, debuff remains 0 -> match", function()
        local ctx = make_context()
        local saved = NS.debuff_remains
        NS.debuff_remains = function(target, spell) return 0 end
        local state = get_state(ctx)
        state.rupture_ready = true
        state.combo_points = 3
        assert_true(strategies[16].matches(ctx, state), "3 CP with expired debuff should match")
        NS.debuff_remains = saved
    end)

    test(label .. ": 2 CP -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.rupture_ready = true
        state.combo_points = 2
        assert_false(strategies[16].matches(ctx, state), "2 CP should not match (< 3)")
    end)

    test(label .. ": 5 CP (prefer eviscerate) -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.rupture_ready = true
        state.combo_points = 5
        assert_false(strategies[16].matches(ctx, state), "5 CP should not match (>= max)")
    end)

    test(label .. ": 4 CP -> match", function()
        local ctx = make_context()
        local saved = NS.debuff_remains
        NS.debuff_remains = function(target, spell) return 0 end
        local state = get_state(ctx)
        state.rupture_ready = true
        state.combo_points = 4
        assert_true(strategies[16].matches(ctx, state), "4 CP should match (< 5 and >= 3)")
        NS.debuff_remains = saved
    end)

    test(label .. ": debuff remains exactly 4 -> match (<= 4)", function()
        local ctx = make_context()
        local saved = NS.debuff_remains
        NS.debuff_remains = function(target, spell) return 4 end
        local state = get_state(ctx)
        state.rupture_ready = true
        state.combo_points = 3
        assert_true(strategies[16].matches(ctx, state), "remains 4 should match (<= 4)")
        NS.debuff_remains = saved
    end)

    test(label .. ": debuff remains exactly 5 -> no match (> 4)", function()
        local ctx = make_context()
        local saved = NS.debuff_remains
        NS.debuff_remains = function(target, spell) return 5 end
        local state = get_state(ctx)
        state.rupture_ready = true
        state.combo_points = 3
        assert_false(strategies[16].matches(ctx, state), "remains 5 should not match (> 4)")
        NS.debuff_remains = saved
    end)
end

do -- edge_expose_armor
    local label = "edge_expose_armor"

    test(label .. ": 3 CP, 0 stacks, target has armor -> match", function()
        local ctx = make_context()
        ctx.target_armor = 100
        local saved = NS.debuff_stacks
        NS.debuff_stacks = function(target, spell) return 0 end
        local state = get_state(ctx)
        state.expose_armor_ready = true
        state.use_expose_armor = true
        state.combo_points = 3
        state.target_ttd = 30
        assert_true(strategies[17].matches(ctx, state), "3 CP with 0 stacks should match")
        NS.debuff_stacks = saved
    end)

    test(label .. ": 2 CP -> no match", function()
        local ctx = make_context()
        ctx.target_armor = 100
        local state = get_state(ctx)
        state.expose_armor_ready = true
        state.use_expose_armor = true
        state.combo_points = 2
        state.target_ttd = 30
        assert_false(strategies[17].matches(ctx, state), "2 CP should not match")
    end)

    test(label .. ": 5 CP (prefer eviscerate) -> no match", function()
        local ctx = make_context()
        ctx.target_armor = 100
        local state = get_state(ctx)
        state.expose_armor_ready = true
        state.use_expose_armor = true
        state.combo_points = 5
        state.target_ttd = 30
        assert_false(strategies[17].matches(ctx, state), "5 CP should not match (>= max)")
    end)

    test(label .. ": 1 stack already -> no match", function()
        local ctx = make_context()
        ctx.target_armor = 100
        local saved = NS.debuff_stacks
        NS.debuff_stacks = function(target, spell) return 1 end
        local state = get_state(ctx)
        state.expose_armor_ready = true
        state.use_expose_armor = true
        state.combo_points = 3
        state.target_ttd = 30
        assert_false(strategies[17].matches(ctx, state), "1 stack should not match")
        NS.debuff_stacks = saved
    end)

    test(label .. ": no target armor -> no match", function()
        local ctx = make_context()
        ctx.target_armor = 0
        local state = get_state(ctx)
        state.expose_armor_ready = true
        state.use_expose_armor = true
        state.combo_points = 3
        assert_false(strategies[17].matches(ctx, state), "no armor should not match")
    end)
end

do -- edge_kidney_shot
    local label = "edge_kidney_shot"

    test(label .. ": 3 CP, HP 40 -> match", function()
        local ctx = make_context({hp = 40})
        local state = get_state(ctx)
        state.kidney_shot_ready = true
        state.combo_points = 3
        state.hp = 40
        assert_true(strategies[18].matches(ctx, state), "3 CP with HP 40 should match")
    end)

    test(label .. ": 2 CP -> no match", function()
        local ctx = make_context({hp = 40})
        local state = get_state(ctx)
        state.kidney_shot_ready = true
        state.combo_points = 2
        state.hp = 40
        assert_false(strategies[18].matches(ctx, state), "2 CP should not match")
    end)

    test(label .. ": HP 41 -> no match", function()
        local ctx = make_context({hp = 41})
        local state = get_state(ctx)
        state.kidney_shot_ready = true
        state.combo_points = 3
        state.hp = 41
        assert_false(strategies[18].matches(ctx, state), "HP 41 should not match (> 40)")
    end)

    test(label .. ": not ready -> no match", function()
        local ctx = make_context({hp = 40})
        local state = get_state(ctx)
        state.kidney_shot_ready = false
        state.combo_points = 3
        state.hp = 40
        assert_false(strategies[18].matches(ctx, state), "not ready should not match")
    end)
end

do -- edge_eviscerate
    local label = "edge_eviscerate"

    test(label .. ": 5 CP -> match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.eviscerate_ready = true
        state.combo_points = 5
        assert_true(strategies[19].matches(ctx, state), "5 CP should match")
    end)

    test(label .. ": 4 CP -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.eviscerate_ready = true
        state.combo_points = 4
        assert_false(strategies[19].matches(ctx, state), "4 CP should not match (< max)")
    end)

    test(label .. ": no target -> no match", function()
        local ctx = make_context({target = nil})
        local state = get_state(ctx)
        state.eviscerate_ready = true
        state.target = nil
        state.combo_points = 5
        assert_false(strategies[19].matches(ctx, state), "no target should not match")
    end)
end

do -- edge_sinister_strike
    local label = "edge_sinister_strike"

    test(label .. ": 4 CP -> match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.sinister_strike_ready = true
        state.combo_points = 4
        assert_true(strategies[20].matches(ctx, state), "4 CP should match (< max)")
    end)

    test(label .. ": 5 CP -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.sinister_strike_ready = true
        state.combo_points = 5
        assert_false(strategies[20].matches(ctx, state), "5 CP should not match (>= max)")
    end)

    test(label .. ": no target -> no match", function()
        local ctx = make_context({target = nil})
        local state = get_state(ctx)
        state.sinister_strike_ready = true
        state.target = nil
        state.combo_points = 3
        assert_false(strategies[20].matches(ctx, state), "no target should not match")
    end)

    test(label .. ": OOC -> no match", function()
        local ctx = make_context({in_combat = false})
        local state = get_state(ctx)
        state.sinister_strike_ready = true
        state.combo_points = 3
        state.in_combat = false
        assert_false(strategies[20].matches(ctx, state), "OOC should not match")
    end)
end

do -- edge_stealth
    local label = "edge_stealth"

    test(label .. ": distance exactly 30 -> match", function()
        local ctx = make_context({in_combat = false})
        local saved = NS.get_distance
        NS.get_distance = function() return 30 end
        local state = get_state(ctx)
        state.stealthed = false
        state.stealth_ready = true
        assert_true(strategies[1].matches(ctx, state), "distance 30 should match (<= 30)")
        NS.get_distance = saved
    end)

    test(label .. ": distance exactly 31 -> no match", function()
        local ctx = make_context({in_combat = false})
        local saved = NS.get_distance
        NS.get_distance = function() return 31 end
        local state = get_state(ctx)
        state.stealthed = false
        state.stealth_ready = true
        assert_false(strategies[1].matches(ctx, state), "distance 31 should not match (> 30)")
        NS.get_distance = saved
    end)

    test(label .. ": already stealthed -> no match", function()
        local ctx = make_context({in_combat = false})
        local state = get_state(ctx)
        state.stealthed = true
        state.stealth_ready = true
        assert_false(strategies[1].matches(ctx, state), "already stealthed should not match")
    end)

    test(label .. ": OOC -> match", function()
        local ctx = make_context({in_combat = false})
        local state = get_state(ctx)
        state.stealthed = false
        state.stealth_ready = true
        assert_true(strategies[1].matches(ctx, state), "OOC with target nearby should match")
    end)
end

do -- edge_ambush_garrote
    local label = "edge_ambush_garrote"

    test(label .. ": Ambush - stealthed OOC -> match", function()
        local ctx = make_context({in_combat = false})
        local state = get_state(ctx)
        state.stealthed = true
        state.ambush_ready = true
        assert_true(strategies[2].matches(ctx, state), "stealthed OOC should match")
    end)

    test(label .. ": Ambush - not stealthed -> no match", function()
        local ctx = make_context({in_combat = false})
        local state = get_state(ctx)
        state.stealthed = false
        state.ambush_ready = true
        assert_false(strategies[2].matches(ctx, state), "not stealthed should not match")
    end)

    test(label .. ": Garrote - stealthed OOC -> match", function()
        local ctx = make_context({in_combat = false})
        local state = get_state(ctx)
        state.stealthed = true
        state.garrote_ready = true
        assert_true(strategies[3].matches(ctx, state), "stealthed OOC should match")
    end)

    test(label .. ": Garrote - not stealthed -> no match", function()
        local ctx = make_context({in_combat = false})
        local state = get_state(ctx)
        state.stealthed = false
        state.garrote_ready = true
        assert_false(strategies[3].matches(ctx, state), "not stealthed should not match")
    end)
end

do -- edge_kick
    local label = "edge_kick"

    test(label .. ": target casting, ready -> match", function()
        local ctx = make_context()
        ctx.target.is_casting = function() return true end
        local state = get_state(ctx)
        state.kick_ready = true
        state.use_interrupt = true
        assert_true(strategies[4].matches(ctx, state), "target casting should match")
    end)

    test(label .. ": target not casting -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.kick_ready = true
        state.use_interrupt = true
        assert_false(strategies[4].matches(ctx, state), "target not casting should not match")
    end)

    test(label .. ": interrupt disabled -> no match", function()
        local ctx = make_context()
        ctx.target.is_casting = function() return true end
        local state = get_state(ctx)
        state.kick_ready = true
        state.use_interrupt = false
        assert_false(strategies[4].matches(ctx, state), "interrupt disabled should not match")
    end)
end

-- ============================================================================
-- Edge case tests - API crash safety
-- ============================================================================

do -- edge_api_buff_up
    local label = "edge_api_buff_up"

    test(label .. ": NS.buff_up is nil -> has_buff returns false", function()
        local saved = NS.buff_up
        NS.buff_up = nil
        local ctx = make_context()
        local state = get_state(ctx)
        -- has_buff used by has_slice_and_dice and stealthed; both should be false
        assert_eq(state.has_slice_and_dice, false, "has_slice_and_dice should be false when buff_up nil")
        assert_eq(state.stealthed, false, "stealthed should be false when buff_up nil")
        NS.buff_up = saved
    end)

    test(label .. ": NS.buff_up throws -> pcall catches, has_buff returns false", function()
        local saved = NS.buff_up
        NS.buff_up = function() error("crash") end
        local ctx = make_context()
        local state = get_state(ctx)
        assert_eq(state.has_slice_and_dice, false, "has_slice_and_dice should be false when buff_up throws")
        assert_eq(state.stealthed, false, "stealthed should be false when buff_up throws")
        NS.buff_up = saved
    end)
end

do -- edge_api_spell_ready
    local label = "edge_api_spell_ready"

    test(label .. ": NS.spell_ready is nil -> all readiness fields false", function()
        local saved = NS.spell_ready
        NS.spell_ready = nil
        local ctx = make_context()
        local state = get_state(ctx)
        -- All spell readiness should default to false
        assert_eq(state.sinister_strike_ready, false, "sinister_strike_ready should be false")
        assert_eq(state.eviscerate_ready, false, "eviscerate_ready should be false")
        assert_eq(state.kick_ready, false, "kick_ready should be false")
        assert_eq(state.vanish_ready, false, "vanish_ready should be false")
        assert_eq(state.stealth_ready, false, "stealth_ready should be false")
        NS.spell_ready = saved
    end)

    test(label .. ": NS.spell_ready returns nil -> readiness fields are nil/false", function()
        local saved = NS.spell_ready
        NS.spell_ready = function() return nil end
        local ctx = make_context()
        local state = get_state(ctx)
        -- NS.spell_ready and NS.spell_ready(...) or false -> nil and nil or false -> false
        assert_eq(state.sinister_strike_ready, false, "should be false when spell_ready returns nil")
        NS.spell_ready = saved
    end)

    test(label .. ": match functions handle nil readiness -> return false", function()
        local saved_spell = NS.spell_ready
        NS.spell_ready = nil
        local ctx = make_context({in_combat = false, hp = 10})
        local state = get_state(ctx)
        -- All readiness fields are false, so combat matches should return false gracefully
        for i = 4, 20 do
            local ok, matched = pcall(strategies[i].matches, ctx, state)
            assert_true(ok, "strategy[" .. i .. "] matches should not throw when readiness is nil")
            -- Most should return false since readiness fields are nil/false
        end
        NS.spell_ready = saved_spell
    end)
end

do -- edge_api_try_cast
    local label = "edge_api_try_cast"

    test(label .. ": NS.try_cast returns nil -> execute returns false, no crash", function()
        local saved = NS.try_cast
        NS.try_cast = function() return nil end
        local ctx = make_context()
        for i, s in ipairs(strategies) do
            local ok, result = pcall(s.execute, ctx)
            assert_true(ok, "strategy[" .. i .. "] execute should not throw when try_cast returns nil")
        end
        NS.try_cast = saved
    end)

    test(label .. ": NS.try_cast is nil -> execute returns false, no crash", function()
        local saved = NS.try_cast
        NS.try_cast = nil
        local ctx = make_context()
        for i, s in ipairs(strategies) do
            local ok, result = pcall(s.execute, ctx)
            assert_true(ok, "strategy[" .. i .. "] execute should not throw when try_cast is nil")
        end
        NS.try_cast = saved
    end)
end

-- ============================================================================
-- Edge case tests - rotation crash safety
-- ============================================================================

do -- edge_rotation_crash
    local label = "edge_rotation_crash"

    test(label .. ": all match functions handle nil context", function()
        for i, s in ipairs(strategies) do
            local ok, result = pcall(s.matches, nil, {})
            assert_true(ok, "strategy[" .. i .. "] matches(nil, {}) should not throw")
        end
    end)

    test(label .. ": all match functions handle nil state", function()
        local ctx = make_context()
        for i, s in ipairs(strategies) do
            local ok, result = pcall(s.matches, ctx, nil)
            assert_true(ok, "strategy[" .. i .. "] matches(ctx, nil) should not throw")
        end
    end)

    test(label .. ": all execute functions handle nil context", function()
        for i, s in ipairs(strategies) do
            local ok, result = pcall(s.execute, nil)
            assert_true(ok, "strategy[" .. i .. "] execute(nil) should not throw")
        end
    end)

    test(label .. ": all execute functions handle nil context with nil references", function()
        for i, s in ipairs(strategies) do
            local ok, result = pcall(s.execute)
            assert_true(ok, "strategy[" .. i .. "] execute() with no args should not throw")
        end
    end)
end
-- ============================================================================
-- Deep dive: Stealth - target distance + state guards
-- ============================================================================
do
    -- Stealth: OOC, not stealthed, ready, target close -> match
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.stealthed = false
    state.stealth_ready = true
    local saved = NS.get_distance
    NS.get_distance = function() return 25 end
    ctx.target = { is_valid = function() return true end }
    state.target = ctx.target
    assert_true(strategies[1].matches(ctx, state), "stealth dist=25 -> match (<= 30)")
    NS.get_distance = saved

    -- Stealth: target dist 31 -> no match (> 30)
    local ctx2 = make_context({in_combat = false})
    local state2 = get_state(ctx2)
    state2.stealthed = false
    state2.stealth_ready = true
    local saved2 = NS.get_distance
    NS.get_distance = function() return 31 end
    ctx2.target = { is_valid = function() return true end }
    state2.target = ctx2.target
    assert_false(strategies[1].matches(ctx2, state2), "stealth dist=31 -> no match (> 30)")
    NS.get_distance = saved2

    -- Stealth: already stealthed -> no match
    local ctx3 = make_context({in_combat = false})
    local state3 = get_state(ctx3)
    state3.stealthed = true
    state3.stealth_ready = true
    ctx3.target = { is_valid = function() return true end }
    state3.target = ctx3.target
    assert_false(strategies[1].matches(ctx3, state3), "stealth already stealthed -> no match")

    -- Stealth: in combat -> no match
    local ctx4 = make_context({in_combat = true})
    local state4 = get_state(ctx4)
    state4.stealthed = false
    state4.stealth_ready = true
    state4.in_combat = true
    assert_false(strategies[1].matches(ctx4, state4), "stealth in combat -> no match")

    -- Stealth: no target -> no match
    local ctx5 = make_context({in_combat = false})
    ctx5.target = nil
    local state5 = get_state(ctx5)
    state5.stealthed = false
    state5.stealth_ready = true
    state5.target = nil
    assert_false(strategies[1].matches(ctx5, state5), "stealth no target -> no match")
end

-- ============================================================================
-- Deep dive: Ambush/Garrote - stealth + OOC guards
-- ============================================================================
do
    -- Ambush: OOC, stealthed, ready -> match
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.stealthed = true
    state.ambush_ready = true
    ctx.target = { is_valid = function() return true end }
    state.target = ctx.target
    assert_true(strategies[2].matches(ctx, state), "ambush stealthed OOC -> match")

    -- Ambush: not stealthed -> no match
    local ctx2 = make_context({in_combat = false})
    local state2 = get_state(ctx2)
    state2.stealthed = false
    state2.ambush_ready = true
    assert_false(strategies[2].matches(ctx2, state2), "ambush not stealthed -> no match")

    -- Ambush: in combat -> no match
    local ctx3 = make_context({in_combat = true})
    local state3 = get_state(ctx3)
    state3.stealthed = true
    state3.ambush_ready = true
    state3.in_combat = true
    assert_false(strategies[3].matches(ctx3, state3), "ambush in combat -> no match")

    -- Ambush: no target -> no match
    local ctx4 = make_context({in_combat = false})
    ctx4.target = nil
    local state4 = get_state(ctx4)
    state4.stealthed = true
    state4.ambush_ready = true
    state4.target = nil
    assert_false(strategies[2].matches(ctx4, state4), "ambush no target -> no match")

    -- Garrote: stealthed OOC -> match
    local ctx5 = make_context({in_combat = false})
    local state5 = get_state(ctx5)
    state5.stealthed = true
    state5.garrote_ready = true
    assert_true(strategies[3].matches(ctx5, state5), "garrote stealthed OOC -> match")

    -- Garrote: not stealthed -> no match
    local ctx6 = make_context({in_combat = false})
    local state6 = get_state(ctx6)
    state6.stealthed = false
    state6.garrote_ready = true
    assert_false(strategies[3].matches(ctx6, state6), "garrote not stealthed -> no match")
end

-- ============================================================================
-- Deep dive: Kick interrupt - target casting
-- ============================================================================
do
    -- Kick: target casting -> match
    local ctx = make_context({})
    ctx.target.is_casting = function() return true end
    local state = get_state(ctx)
    state.kick_ready = true
    state.use_interrupt = true
    assert_true(strategies[4].matches(ctx, state), "kick target casting -> match")

    -- Kick: target not casting -> no match
    local ctx2 = make_context({})
    ctx2.target.is_casting = function() return false end
    local state2 = get_state(ctx2)
    state2.kick_ready = true
    state2.use_interrupt = true
    assert_false(strategies[4].matches(ctx2, state2), "kick target not casting -> no match")

    -- Kick: interrupt disabled -> no match
    local ctx3 = make_context({})
    ctx3.target.is_casting = function() return true end
    local state3 = get_state(ctx3)
    state3.kick_ready = true
    state3.use_interrupt = false
    assert_false(strategies[4].matches(ctx3, state3), "kick interrupt disabled -> no match")
end

-- ============================================================================
-- Deep dive: Gouge/Vanish/Evasion/Sprint/Blind HP boundaries
-- ============================================================================
do
    -- Gouge: HP 40 -> match (<= 40)
    local ctx = make_context({hp = 40})
    local state = get_state(ctx)
    state.gouge_ready = true
    state.hp = 40
    assert_true(strategies[5].matches(ctx, state), "gouge hp=40 -> match (<= 40)")

    -- Gouge: HP 41 -> no match (> 40)
    local ctx2 = make_context({hp = 41})
    local state2 = get_state(ctx2)
    state2.gouge_ready = true
    state2.hp = 41
    assert_false(strategies[5].matches(ctx2, state2), "gouge hp=41 -> no match")

    -- Vanish: HP 15 (vanish_hp default) -> match
    local ctx3 = make_context({hp = 15})
    local state3 = get_state(ctx3)
    state3.vanish_ready = true
    state3.vanish_hp = 15
    state3.hp = 15
    assert_true(strategies[7].matches(ctx3, state3), "vanish hp=15 -> match (<= 15)")

    -- Vanish: HP 16 -> no match
    local ctx4 = make_context({hp = 16})
    local state4 = get_state(ctx4)
    state4.vanish_ready = true
    state4.vanish_hp = 15
    state4.hp = 16
    assert_false(strategies[7].matches(ctx4, state4), "vanish hp=16 -> no match")

    -- Evasion: HP 50, enemies 2 -> match
    local ctx5 = make_context({hp = 50, enemies_count = 2})
    local state5 = get_state(ctx5)
    state5.evasion_ready = true
    state5.hp = 50
    state5.enemies = 2
    assert_true(strategies[8].matches(ctx5, state5), "evasion hp=50 enemies=2 -> match")

    -- Evasion: HP 51, enemies 2 -> no match (hp > 50)
    local ctx6 = make_context({hp = 51, enemies_count = 2})
    local state6 = get_state(ctx6)
    state6.evasion_ready = true
    state6.hp = 51
    state6.enemies = 2
    assert_false(strategies[8].matches(ctx6, state6), "evasion hp=51 -> no match")

    -- Evasion: HP 40, enemies 1 -> no match (enemies < 2)
    local ctx7 = make_context({hp = 40, enemies_count = 1})
    local state7 = get_state(ctx7)
    state7.evasion_ready = true
    state7.hp = 40
    state7.enemies = 1
    assert_false(strategies[8].matches(ctx7, state7), "evasion enemies=1 -> no match")

    -- Sprint: HP 30 -> match (<= 30)
    local ctx8 = make_context({hp = 30})
    local state8 = get_state(ctx8)
    state8.sprint_ready = true
    state8.hp = 30
    assert_true(strategies[10].matches(ctx8, state8), "sprint hp=30 -> match (<= 30)")

    -- Sprint: HP 31 -> no match
    local ctx9 = make_context({hp = 31})
    local state9 = get_state(ctx9)
    state9.sprint_ready = true
    state9.hp = 31
    assert_false(strategies[10].matches(ctx9, state9), "sprint hp=31 -> no match")

    -- Blind: HP 30 -> match (<= 30)
    local ctx10 = make_context({hp = 30})
    local state10 = get_state(ctx10)
    state10.blind_ready = true
    state10.hp = 30
    assert_true(strategies[11].matches(ctx10, state10), "blind hp=30 -> match (<= 30)")

    -- Blind: HP 31 -> no match
    local ctx11 = make_context({hp = 31})
    local state11 = get_state(ctx11)
    state11.blind_ready = true
    state11.hp = 31
    assert_false(strategies[11].matches(ctx11, state11), "blind hp=31 -> no match")
end

-- ============================================================================
-- Deep dive: CP boundaries (SliceAndDice, Rupture, Eviscerate, SinisterStrike, etc.)
-- ============================================================================
do
    -- SliceAndDice: CP 1 -> match (>= 1)
    local ctx = make_context({})
    local state = get_state(ctx)
    state.slice_and_dice_ready = true
    state.has_slice_and_dice = false
    state.combo_points = 1
    assert_true(strategies[15].matches(ctx, state), "snd cp=1 -> match (>= 1)")

    -- SliceAndDice: CP 0 -> no match
    local ctx2 = make_context({})
    local state2 = get_state(ctx2)
    state2.slice_and_dice_ready = true
    state2.has_slice_and_dice = false
    state2.combo_points = 0
    assert_false(strategies[15].matches(ctx2, state2), "snd cp=0 -> no match")

    -- SliceAndDice: already has buff -> no match
    local ctx3 = make_context({})
    local state3 = get_state(ctx3)
    state3.slice_and_dice_ready = true
    state3.has_slice_and_dice = true
    state3.combo_points = 3
    assert_false(strategies[15].matches(ctx3, state3), "snd buff active -> no match")

    -- Rupture: CP 3 -> match (>= 3, < 5)
    local ctx4 = make_context({})
    local state4 = get_state(ctx4)
    state4.rupture_ready = true
    state4.combo_points = 3
    local saved = NS.debuff_remains
    NS.debuff_remains = function() return 0 end
    assert_true(strategies[16].matches(ctx4, state4), "rupture cp=3 -> match")
    NS.debuff_remains = saved

    -- Rupture: CP 2 -> no match (< 3)
    local ctx5 = make_context({})
    local state5 = get_state(ctx5)
    state5.rupture_ready = true
    state5.combo_points = 2
    assert_false(strategies[16].matches(ctx5, state5), "rupture cp=2 -> no match")

    -- Rupture: CP 5 -> no match (prefer Eviscerate at 5)
    local ctx6 = make_context({})
    local state6 = get_state(ctx6)
    state6.rupture_ready = true
    state6.combo_points = 5
    state6.max_combo_points = 5
    assert_false(strategies[16].matches(ctx6, state6), "rupture cp=5 -> no match (prefer evisc)")

    -- Rupture: remains 4 -> match (<= 4)
    local ctx7 = make_context({})
    local state7 = get_state(ctx7)
    state7.rupture_ready = true
    state7.combo_points = 3
    local saved7 = NS.debuff_remains
    NS.debuff_remains = function() return 4 end
    assert_true(strategies[16].matches(ctx7, state7), "rupture remains=4 -> match")
    NS.debuff_remains = saved7

    -- Rupture: remains 5 -> no match (> 4)
    local ctx8 = make_context({})
    local state8 = get_state(ctx8)
    state8.rupture_ready = true
    state8.combo_points = 3
    local saved8 = NS.debuff_remains
    NS.debuff_remains = function() return 5 end
    assert_false(strategies[16].matches(ctx8, state8), "rupture remains=5 -> no match")
    NS.debuff_remains = saved8

    -- Eviscerate: CP 5 -> match (>= 5)
    local ctx9 = make_context({})
    local state9 = get_state(ctx9)
    state9.eviscerate_ready = true
    state9.combo_points = 5
    state9.max_combo_points = 5
    assert_true(strategies[19].matches(ctx9, state9), "eviscerate cp=5 -> match (>= 5)")

    -- Eviscerate: CP 4 -> no match (< 5)
    local ctx10 = make_context({})
    local state10 = get_state(ctx10)
    state10.eviscerate_ready = true
    state10.combo_points = 4
    state10.max_combo_points = 5
    assert_false(strategies[19].matches(ctx10, state10), "eviscerate cp=4 -> no match")

    -- SinisterStrike: CP 4 -> match (< 5)
    local ctx11 = make_context({})
    local state11 = get_state(ctx11)
    state11.sinister_strike_ready = true
    state11.combo_points = 4
    state11.max_combo_points = 5
    assert_true(strategies[20].matches(ctx11, state11), "ss cp=4 -> match (< 5)")

    -- SinisterStrike: CP 5 -> no match (>= 5)
    local ctx12 = make_context({})
    local state12 = get_state(ctx12)
    state12.sinister_strike_ready = true
    state12.combo_points = 5
    state12.max_combo_points = 5
    assert_false(strategies[20].matches(ctx12, state12), "ss cp=5 -> no match (>= 5)")
end

-- ============================================================================
-- Deep dive: ColdBlood + AdrenalineRush - cooldown/energy boundaries
-- ============================================================================
do
    -- ColdBlood: CP 5, cooldowns enabled -> match
    local ctx = make_context({})
    local state = get_state(ctx)
    state.cold_blood_ready = true
    state.combo_points = 5
    state.use_cooldowns = true
    assert_true(strategies[12].matches(ctx, state), "coldblood cp=5 enabled -> match")

    -- ColdBlood: CP 4 -> no match (< 5)
    local ctx2 = make_context({})
    local state2 = get_state(ctx2)
    state2.cold_blood_ready = true
    state2.combo_points = 4
    state2.use_cooldowns = true
    assert_false(strategies[12].matches(ctx2, state2), "coldblood cp=4 -> no match")

    -- ColdBlood: cooldowns disabled -> no match
    local ctx3 = make_context({})
    local state3 = get_state(ctx3)
    state3.cold_blood_ready = true
    state3.combo_points = 5
    state3.use_cooldowns = false
    assert_false(strategies[12].matches(ctx3, state3), "coldblood cds disabled -> no match")

    -- AdrenalineRush: energy 60 -> match (<= 60)
    local ctx4 = make_context({})
    local state4 = get_state(ctx4)
    state4.adrenaline_rush_ready = true
    state4.energy = 60
    state4.use_cooldowns = true
    assert_true(strategies[13].matches(ctx4, state4), "ar energy=60 -> match (<= 60)")

    -- AdrenalineRush: energy 61 -> no match (> 60)
    local ctx5 = make_context({})
    local state5 = get_state(ctx5)
    state5.adrenaline_rush_ready = true
    state5.energy = 61
    state5.use_cooldowns = true
    assert_false(strategies[13].matches(ctx5, state5), "ar energy=61 -> no match")

    -- AdrenalineRush: cooldowns disabled -> no match
    local ctx6 = make_context({})
    local state6 = get_state(ctx6)
    state6.adrenaline_rush_ready = true
    state6.energy = 40
    state6.use_cooldowns = false
    assert_false(strategies[13].matches(ctx6, state6), "ar cds disabled -> no match")
end

-- ============================================================================
-- Deep dive: BladeFlurry enemies threshold + setting
-- ============================================================================
do
    -- BladeFlurry: enemies 3 -> match (>= 3)
    local ctx = make_context({enemies_count = 3})
    local state = get_state(ctx)
    state.blade_flurry_ready = true
    state.use_blade_flurry = true
    state.blade_flurry_min_enemies = 3
    state.enemies = 3
    assert_true(strategies[14].matches(ctx, state), "bf enemies=3 -> match (>= 3)")

    -- BladeFlurry: enemies 2 -> no match (< 3)
    local ctx2 = make_context({enemies_count = 2})
    local state2 = get_state(ctx2)
    state2.blade_flurry_ready = true
    state2.use_blade_flurry = true
    state2.blade_flurry_min_enemies = 3
    state2.enemies = 2
    assert_false(strategies[14].matches(ctx2, state2), "bf enemies=2 -> no match")

    -- BladeFlurry: setting disabled -> no match
    local ctx3 = make_context({enemies_count = 4})
    local state3 = get_state(ctx3)
    state3.blade_flurry_ready = true
    state3.use_blade_flurry = false
    state3.blade_flurry_min_enemies = 3
    state3.enemies = 4
    assert_false(strategies[14].matches(ctx3, state3), "bf setting disabled -> no match")
end

-- ============================================================================
-- Deep dive: KidneyShot CP + HP boundaries
-- ============================================================================
do
    -- KidneyShot: CP 3, HP 40 -> match (>= 3, <= 40)
    local ctx = make_context({hp = 40})
    local state = get_state(ctx)
    state.kidney_shot_ready = true
    state.combo_points = 3
    state.hp = 40
    assert_true(strategies[18].matches(ctx, state), "ks cp=3 hp=40 -> match")

    -- KidneyShot: CP 2 -> no match (< 3)
    local ctx2 = make_context({hp = 30})
    local state2 = get_state(ctx2)
    state2.kidney_shot_ready = true
    state2.combo_points = 2
    state2.hp = 30
    assert_false(strategies[18].matches(ctx2, state2), "ks cp=2 -> no match")

    -- KidneyShot: HP 41 -> no match (> 40)
    local ctx3 = make_context({hp = 41})
    local state3 = get_state(ctx3)
    state3.kidney_shot_ready = true
    state3.combo_points = 4
    state3.hp = 41
    assert_false(strategies[18].matches(ctx3, state3), "ks hp=41 -> no match")
end

-- ============================================================================
-- Deep dive: Null target guards for all target-dependent strategies
-- ============================================================================
do
    local target_dependent = {2, 3, 4, 5, 11, 16, 17, 18, 19, 20}  -- Ambush through SinisterStrike
    for _, idx in ipairs(target_dependent) do
        local ctx = make_context({})
        ctx.target = nil
        local state = get_state(ctx)
        for k, v in pairs(state) do
            if type(k) == "string" and k:match("_ready$") then
                state[k] = true
            end
        end
        state.stealthed = false
        state.combo_points = 4
        state.max_combo_points = 5
        state.energy = 100
        state.hp = 30
        state.use_interrupt = true
        state.use_cooldowns = true
        state.target = nil
        local ok, result = pcall(strategies[idx].matches, ctx, state)
        assert_false(result, strategies[idx].name .. " no target -> no match")
    end
end

-- ============================================================================
-- Deep dive: ExposeArmor setting + armor gate
-- ============================================================================
do
    -- ExposeArmor: setting enabled, cp 3, armor > 0 -> match
    local ctx = make_context({})
    ctx.target_armor = 100
    local state = get_state(ctx)
    state.expose_armor_ready = true
    state.use_expose_armor = true
    state.combo_points = 3
    state.target_armor = 100
    state.max_combo_points = 5
    local saved = NS.debuff_stacks
    NS.debuff_stacks = function() return 0 end
    -- Check 1: ttd defaults to 999 which IS >= 20, so without elite/boss it still matches
    assert_true(strategies[17].matches(ctx, state), "exposearmor cp=3 ttd default -> match (ttd 999 >= 20)")
    NS.debuff_stacks = saved

    -- Check 2: ttd < 20 and no elite/boss -> no match
    local ctx1b = make_context({})
    ctx1b.target_armor = 100
    local state1b = get_state(ctx1b)
    state1b.expose_armor_ready = true
    state1b.use_expose_armor = true
    state1b.combo_points = 3
    state1b.max_combo_points = 5
    state1b.target_ttd = 5
    local saved1b = NS.debuff_stacks
    NS.debuff_stacks = function() return 0 end
    assert_false(strategies[17].matches(ctx1b, state1b), "exposearmor cp=3 ttd=5 no elite -> no match")
    NS.debuff_stacks = saved1b

    -- Check 3: target_is_elite -> match even with low ttd
    local state1c = get_state(ctx1b)
    state1c.expose_armor_ready = true
    state1c.use_expose_armor = true
    state1c.combo_points = 3
    state1c.max_combo_points = 5
    state1c.target_is_elite = true
    state1c.target_ttd = 5
    local saved1c = NS.debuff_stacks
    NS.debuff_stacks = function() return 0 end
    assert_true(strategies[17].matches(ctx1b, state1c), "exposearmor cp=3 target_is_elite -> match")
    NS.debuff_stacks = saved1c

    -- ExposeArmor: setting disabled -> no match
    local ctx2 = make_context({})
    ctx2.target_armor = 100
    local state2 = get_state(ctx2)
    state2.expose_armor_ready = true
    state2.use_expose_armor = false
    state2.combo_points = 3
    assert_false(strategies[17].matches(ctx2, state2), "exposearmor disabled -> no match")

    -- ExposeArmor: cp 2 -> no match
    local ctx3 = make_context({})
    ctx3.target_armor = 100
    local state3 = get_state(ctx3)
    state3.expose_armor_ready = true
    state3.use_expose_armor = true
    state3.combo_points = 2
    state3.target_armor = 100
    assert_false(strategies[17].matches(ctx3, state3), "exposearmor cp=2 -> no match")

    -- ExposeArmor: CP 5 -> no match (prefer Eviscerate at 5)
    local ctx4 = make_context({})
    ctx4.target_armor = 100
    local state4 = get_state(ctx4)
    state4.expose_armor_ready = true
    state4.use_expose_armor = true
    state4.combo_points = 5
    state4.max_combo_points = 5
    state4.target_armor = 100
    assert_false(strategies[17].matches(ctx4, state4), "exposearmor cp=5 -> no match (prefer evisc)")
end

-- ============================================================================
-- Deep dive: OOC guards for combat abilities
-- ============================================================================
do
    local combat_strategies = {4, 5, 6, 7, 8, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20}
    for _, idx in ipairs(combat_strategies) do
        local ctx = make_context({in_combat = false})
        local state = get_state(ctx)
        for k, v in pairs(state) do
            if type(k) == "string" and k:match("_ready$") then
                state[k] = true
            end
        end
        state.stealthed = false
        state.combo_points = 4
        state.max_combo_points = 5
        state.energy = 100
        state.hp = 20
        state.enemies = 4
        state.use_interrupt = true
        state.use_cooldowns = true
        state.has_slice_and_dice = false
        state.in_combat = false
        state.blade_flurry_min_enemies = 3
        state.vanish_hp = 15
        state.use_expose_armor = true
        -- ExposeArmor also needs target_armor > 0 and special conditions
        ctx.target_armor = 1000
        state.target_armor = 1000
        state.target_is_elite = true
        local saved = NS.debuff_stacks
        NS.debuff_stacks = function() return 0 end
        local ok, result = pcall(strategies[idx].matches, ctx, state)
        assert_false(result, strategies[idx].name .. " OOC -> no match")
        NS.debuff_stacks = saved
    end
end

-- ============================================================================
-- Deep dive: ShivPurge PvP gate + melee range
-- ============================================================================
do
    -- ShivPurge complex conditions - just test PvP gate
    local ctx = make_context({})
    ctx.is_pvp = true
    ctx.in_melee_range = true
    ctx.target.is_player = function() return true end
    local state = get_state(ctx)
    state.shiv_ready = true
    state.is_pvp = true
    state.in_melee_range = true
    state.target = ctx.target
    state.shiv_purge_name = nil  -- No dispel target found -> no match
    assert_false(strategies[6].matches(ctx, state), "shivpurge no dispel target -> no match")

    -- ShivPurge: not PvP -> no match
    local ctx2 = make_context({})
    ctx2.is_pvp = false
    local state2 = get_state(ctx2)
    state2.shiv_ready = true
    state2.is_pvp = false
    assert_false(strategies[6].matches(ctx2, state2), "shivpurge not pvp -> no match")
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
-- Deep dive: NS.spell_ready throws (crash safety for pcall fix)
-- ============================================================================
do
    local saved = NS.spell_ready
    NS.spell_ready = function() error('simulated throw') end
    local ctx = make_context()
    local ok, state = pcall(get_state, ctx)
    NS.spell_ready = saved
    assert_true(ok, 'spell_ready throwing should not crash build_state (pcall fix)')
end
-- Summary
-- ============================================================================
-- Deep dive: Stealth - target distance + state guards
-- ============================================================================
do
    -- Stealth: OOC, not stealthed, ready, target close -> match
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.stealthed = false
    state.stealth_ready = true
    local saved = NS.get_distance
    NS.get_distance = function() return 25 end
    ctx.target = { is_valid = function() return true end }
    state.target = ctx.target
    assert_true(strategies[1].matches(ctx, state), "stealth dist=25 -> match (<= 30)")
    NS.get_distance = saved

    -- Stealth: target dist 31 -> no match (> 30)
    local ctx2 = make_context({in_combat = false})
    local state2 = get_state(ctx2)
    state2.stealthed = false
    state2.stealth_ready = true
    local saved2 = NS.get_distance
    NS.get_distance = function() return 31 end
    ctx2.target = { is_valid = function() return true end }
    state2.target = ctx2.target
    assert_false(strategies[1].matches(ctx2, state2), "stealth dist=31 -> no match (> 30)")
    NS.get_distance = saved2

    -- Stealth: already stealthed -> no match
    local ctx3 = make_context({in_combat = false})
    local state3 = get_state(ctx3)
    state3.stealthed = true
    state3.stealth_ready = true
    ctx3.target = { is_valid = function() return true end }
    state3.target = ctx3.target
    assert_false(strategies[1].matches(ctx3, state3), "stealth already stealthed -> no match")

    -- Stealth: in combat -> no match
    local ctx4 = make_context({in_combat = true})
    local state4 = get_state(ctx4)
    state4.stealthed = false
    state4.stealth_ready = true
    state4.in_combat = true
    assert_false(strategies[1].matches(ctx4, state4), "stealth in combat -> no match")

    -- Stealth: no target -> no match
    local ctx5 = make_context({in_combat = false})
    ctx5.target = nil
    local state5 = get_state(ctx5)
    state5.stealthed = false
    state5.stealth_ready = true
    state5.target = nil
    assert_false(strategies[1].matches(ctx5, state5), "stealth no target -> no match")
end

-- ============================================================================
-- Deep dive: Ambush/Garrote - stealth + OOC guards
-- ============================================================================
do
    -- Ambush: OOC, stealthed, ready -> match
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.stealthed = true
    state.ambush_ready = true
    ctx.target = { is_valid = function() return true end }
    state.target = ctx.target
    assert_true(strategies[2].matches(ctx, state), "ambush stealthed OOC -> match")

    -- Ambush: not stealthed -> no match
    local ctx2 = make_context({in_combat = false})
    local state2 = get_state(ctx2)
    state2.stealthed = false
    state2.ambush_ready = true
    assert_false(strategies[2].matches(ctx2, state2), "ambush not stealthed -> no match")

    -- Ambush: in combat -> no match
    local ctx3 = make_context({in_combat = true})
    local state3 = get_state(ctx3)
    state3.stealthed = true
    state3.ambush_ready = true
    state3.in_combat = true
    assert_false(strategies[3].matches(ctx3, state3), "ambush in combat -> no match")

    -- Ambush: no target -> no match
    local ctx4 = make_context({in_combat = false})
    ctx4.target = nil
    local state4 = get_state(ctx4)
    state4.stealthed = true
    state4.ambush_ready = true
    state4.target = nil
    assert_false(strategies[2].matches(ctx4, state4), "ambush no target -> no match")

    -- Garrote: stealthed OOC -> match
    local ctx5 = make_context({in_combat = false})
    local state5 = get_state(ctx5)
    state5.stealthed = true
    state5.garrote_ready = true
    assert_true(strategies[3].matches(ctx5, state5), "garrote stealthed OOC -> match")

    -- Garrote: not stealthed -> no match
    local ctx6 = make_context({in_combat = false})
    local state6 = get_state(ctx6)
    state6.stealthed = false
    state6.garrote_ready = true
    assert_false(strategies[3].matches(ctx6, state6), "garrote not stealthed -> no match")
end

-- ============================================================================
-- Deep dive: Kick interrupt - target casting
-- ============================================================================
do
    -- Kick: target casting -> match
    local ctx = make_context({})
    ctx.target.is_casting = function() return true end
    local state = get_state(ctx)
    state.kick_ready = true
    state.use_interrupt = true
    assert_true(strategies[4].matches(ctx, state), "kick target casting -> match")

    -- Kick: target not casting -> no match
    local ctx2 = make_context({})
    ctx2.target.is_casting = function() return false end
    local state2 = get_state(ctx2)
    state2.kick_ready = true
    state2.use_interrupt = true
    assert_false(strategies[4].matches(ctx2, state2), "kick target not casting -> no match")

    -- Kick: interrupt disabled -> no match
    local ctx3 = make_context({})
    ctx3.target.is_casting = function() return true end
    local state3 = get_state(ctx3)
    state3.kick_ready = true
    state3.use_interrupt = false
    assert_false(strategies[4].matches(ctx3, state3), "kick interrupt disabled -> no match")
end

-- ============================================================================
-- Deep dive: Gouge/Vanish/Evasion/Sprint/Blind HP boundaries
-- ============================================================================
do
    -- Gouge: HP 40 -> match (<= 40)
    local ctx = make_context({hp = 40})
    local state = get_state(ctx)
    state.gouge_ready = true
    state.hp = 40
    assert_true(strategies[5].matches(ctx, state), "gouge hp=40 -> match (<= 40)")

    -- Gouge: HP 41 -> no match (> 40)
    local ctx2 = make_context({hp = 41})
    local state2 = get_state(ctx2)
    state2.gouge_ready = true
    state2.hp = 41
    assert_false(strategies[5].matches(ctx2, state2), "gouge hp=41 -> no match")

    -- Vanish: HP 15 (vanish_hp default) -> match
    local ctx3 = make_context({hp = 15})
    local state3 = get_state(ctx3)
    state3.vanish_ready = true
    state3.vanish_hp = 15
    state3.hp = 15
    assert_true(strategies[7].matches(ctx3, state3), "vanish hp=15 -> match (<= 15)")

    -- Vanish: HP 16 -> no match
    local ctx4 = make_context({hp = 16})
    local state4 = get_state(ctx4)
    state4.vanish_ready = true
    state4.vanish_hp = 15
    state4.hp = 16
    assert_false(strategies[7].matches(ctx4, state4), "vanish hp=16 -> no match")

    -- Evasion: HP 50, enemies 2 -> match
    local ctx5 = make_context({hp = 50, enemies_count = 2})
    local state5 = get_state(ctx5)
    state5.evasion_ready = true
    state5.hp = 50
    state5.enemies = 2
    assert_true(strategies[8].matches(ctx5, state5), "evasion hp=50 enemies=2 -> match")

    -- Evasion: HP 51, enemies 2 -> no match (hp > 50)
    local ctx6 = make_context({hp = 51, enemies_count = 2})
    local state6 = get_state(ctx6)
    state6.evasion_ready = true
    state6.hp = 51
    state6.enemies = 2
    assert_false(strategies[8].matches(ctx6, state6), "evasion hp=51 -> no match")

    -- Evasion: HP 40, enemies 1 -> no match (enemies < 2)
    local ctx7 = make_context({hp = 40, enemies_count = 1})
    local state7 = get_state(ctx7)
    state7.evasion_ready = true
    state7.hp = 40
    state7.enemies = 1
    assert_false(strategies[8].matches(ctx7, state7), "evasion enemies=1 -> no match")

    -- Sprint: HP 30 -> match (<= 30)
    local ctx8 = make_context({hp = 30})
    local state8 = get_state(ctx8)
    state8.sprint_ready = true
    state8.hp = 30
    assert_true(strategies[10].matches(ctx8, state8), "sprint hp=30 -> match (<= 30)")

    -- Sprint: HP 31 -> no match
    local ctx9 = make_context({hp = 31})
    local state9 = get_state(ctx9)
    state9.sprint_ready = true
    state9.hp = 31
    assert_false(strategies[10].matches(ctx9, state9), "sprint hp=31 -> no match")

    -- Blind: HP 30 -> match (<= 30)
    local ctx10 = make_context({hp = 30})
    local state10 = get_state(ctx10)
    state10.blind_ready = true
    state10.hp = 30
    assert_true(strategies[11].matches(ctx10, state10), "blind hp=30 -> match (<= 30)")

    -- Blind: HP 31 -> no match
    local ctx11 = make_context({hp = 31})
    local state11 = get_state(ctx11)
    state11.blind_ready = true
    state11.hp = 31
    assert_false(strategies[11].matches(ctx11, state11), "blind hp=31 -> no match")
end

-- ============================================================================
-- Deep dive: CP boundaries (SliceAndDice, Rupture, Eviscerate, SinisterStrike, etc.)
-- ============================================================================
do
    -- SliceAndDice: CP 1 -> match (>= 1)
    local ctx = make_context({})
    local state = get_state(ctx)
    state.slice_and_dice_ready = true
    state.has_slice_and_dice = false
    state.combo_points = 1
    assert_true(strategies[15].matches(ctx, state), "snd cp=1 -> match (>= 1)")

    -- SliceAndDice: CP 0 -> no match
    local ctx2 = make_context({})
    local state2 = get_state(ctx2)
    state2.slice_and_dice_ready = true
    state2.has_slice_and_dice = false
    state2.combo_points = 0
    assert_false(strategies[15].matches(ctx2, state2), "snd cp=0 -> no match")

    -- SliceAndDice: already has buff -> no match
    local ctx3 = make_context({})
    local state3 = get_state(ctx3)
    state3.slice_and_dice_ready = true
    state3.has_slice_and_dice = true
    state3.combo_points = 3
    assert_false(strategies[15].matches(ctx3, state3), "snd buff active -> no match")

    -- Rupture: CP 3 -> match (>= 3, < 5)
    local ctx4 = make_context({})
    local state4 = get_state(ctx4)
    state4.rupture_ready = true
    state4.combo_points = 3
    local saved = NS.debuff_remains
    NS.debuff_remains = function() return 0 end
    assert_true(strategies[16].matches(ctx4, state4), "rupture cp=3 -> match")
    NS.debuff_remains = saved

    -- Rupture: CP 2 -> no match (< 3)
    local ctx5 = make_context({})
    local state5 = get_state(ctx5)
    state5.rupture_ready = true
    state5.combo_points = 2
    assert_false(strategies[16].matches(ctx5, state5), "rupture cp=2 -> no match")

    -- Rupture: CP 5 -> no match (prefer Eviscerate at 5)
    local ctx6 = make_context({})
    local state6 = get_state(ctx6)
    state6.rupture_ready = true
    state6.combo_points = 5
    state6.max_combo_points = 5
    assert_false(strategies[16].matches(ctx6, state6), "rupture cp=5 -> no match (prefer evisc)")

    -- Rupture: remains 4 -> match (<= 4)
    local ctx7 = make_context({})
    local state7 = get_state(ctx7)
    state7.rupture_ready = true
    state7.combo_points = 3
    local saved7 = NS.debuff_remains
    NS.debuff_remains = function() return 4 end
    assert_true(strategies[16].matches(ctx7, state7), "rupture remains=4 -> match")
    NS.debuff_remains = saved7

    -- Rupture: remains 5 -> no match (> 4)
    local ctx8 = make_context({})
    local state8 = get_state(ctx8)
    state8.rupture_ready = true
    state8.combo_points = 3
    local saved8 = NS.debuff_remains
    NS.debuff_remains = function() return 5 end
    assert_false(strategies[16].matches(ctx8, state8), "rupture remains=5 -> no match")
    NS.debuff_remains = saved8

    -- Eviscerate: CP 5 -> match (>= 5)
    local ctx9 = make_context({})
    local state9 = get_state(ctx9)
    state9.eviscerate_ready = true
    state9.combo_points = 5
    state9.max_combo_points = 5
    assert_true(strategies[19].matches(ctx9, state9), "eviscerate cp=5 -> match (>= 5)")

    -- Eviscerate: CP 4 -> no match (< 5)
    local ctx10 = make_context({})
    local state10 = get_state(ctx10)
    state10.eviscerate_ready = true
    state10.combo_points = 4
    state10.max_combo_points = 5
    assert_false(strategies[19].matches(ctx10, state10), "eviscerate cp=4 -> no match")

    -- SinisterStrike: CP 4 -> match (< 5)
    local ctx11 = make_context({})
    local state11 = get_state(ctx11)
    state11.sinister_strike_ready = true
    state11.combo_points = 4
    state11.max_combo_points = 5
    assert_true(strategies[20].matches(ctx11, state11), "ss cp=4 -> match (< 5)")

    -- SinisterStrike: CP 5 -> no match (>= 5)
    local ctx12 = make_context({})
    local state12 = get_state(ctx12)
    state12.sinister_strike_ready = true
    state12.combo_points = 5
    state12.max_combo_points = 5
    assert_false(strategies[20].matches(ctx12, state12), "ss cp=5 -> no match (>= 5)")
end

-- ============================================================================
-- Deep dive: ColdBlood + AdrenalineRush - cooldown/energy boundaries
-- ============================================================================
do
    -- ColdBlood: CP 5, cooldowns enabled -> match
    local ctx = make_context({})
    local state = get_state(ctx)
    state.cold_blood_ready = true
    state.combo_points = 5
    state.use_cooldowns = true
    assert_true(strategies[12].matches(ctx, state), "coldblood cp=5 enabled -> match")

    -- ColdBlood: CP 4 -> no match (< 5)
    local ctx2 = make_context({})
    local state2 = get_state(ctx2)
    state2.cold_blood_ready = true
    state2.combo_points = 4
    state2.use_cooldowns = true
    assert_false(strategies[12].matches(ctx2, state2), "coldblood cp=4 -> no match")

    -- ColdBlood: cooldowns disabled -> no match
    local ctx3 = make_context({})
    local state3 = get_state(ctx3)
    state3.cold_blood_ready = true
    state3.combo_points = 5
    state3.use_cooldowns = false
    assert_false(strategies[12].matches(ctx3, state3), "coldblood cds disabled -> no match")

    -- AdrenalineRush: energy 60 -> match (<= 60)
    local ctx4 = make_context({})
    local state4 = get_state(ctx4)
    state4.adrenaline_rush_ready = true
    state4.energy = 60
    state4.use_cooldowns = true
    assert_true(strategies[13].matches(ctx4, state4), "ar energy=60 -> match (<= 60)")

    -- AdrenalineRush: energy 61 -> no match (> 60)
    local ctx5 = make_context({})
    local state5 = get_state(ctx5)
    state5.adrenaline_rush_ready = true
    state5.energy = 61
    state5.use_cooldowns = true
    assert_false(strategies[13].matches(ctx5, state5), "ar energy=61 -> no match")

    -- AdrenalineRush: cooldowns disabled -> no match
    local ctx6 = make_context({})
    local state6 = get_state(ctx6)
    state6.adrenaline_rush_ready = true
    state6.energy = 40
    state6.use_cooldowns = false
    assert_false(strategies[13].matches(ctx6, state6), "ar cds disabled -> no match")
end

-- ============================================================================
-- Deep dive: BladeFlurry enemies threshold + setting
-- ============================================================================
do
    -- BladeFlurry: enemies 3 -> match (>= 3)
    local ctx = make_context({enemies_count = 3})
    local state = get_state(ctx)
    state.blade_flurry_ready = true
    state.use_blade_flurry = true
    state.blade_flurry_min_enemies = 3
    state.enemies = 3
    assert_true(strategies[14].matches(ctx, state), "bf enemies=3 -> match (>= 3)")

    -- BladeFlurry: enemies 2 -> no match (< 3)
    local ctx2 = make_context({enemies_count = 2})
    local state2 = get_state(ctx2)
    state2.blade_flurry_ready = true
    state2.use_blade_flurry = true
    state2.blade_flurry_min_enemies = 3
    state2.enemies = 2
    assert_false(strategies[14].matches(ctx2, state2), "bf enemies=2 -> no match")

    -- BladeFlurry: setting disabled -> no match
    local ctx3 = make_context({enemies_count = 4})
    local state3 = get_state(ctx3)
    state3.blade_flurry_ready = true
    state3.use_blade_flurry = false
    state3.blade_flurry_min_enemies = 3
    state3.enemies = 4
    assert_false(strategies[14].matches(ctx3, state3), "bf setting disabled -> no match")
end

-- ============================================================================
-- Deep dive: KidneyShot CP + HP boundaries
-- ============================================================================
do
    -- KidneyShot: CP 3, HP 40 -> match (>= 3, <= 40)
    local ctx = make_context({hp = 40})
    local state = get_state(ctx)
    state.kidney_shot_ready = true
    state.combo_points = 3
    state.hp = 40
    assert_true(strategies[18].matches(ctx, state), "ks cp=3 hp=40 -> match")

    -- KidneyShot: CP 2 -> no match (< 3)
    local ctx2 = make_context({hp = 30})
    local state2 = get_state(ctx2)
    state2.kidney_shot_ready = true
    state2.combo_points = 2
    state2.hp = 30
    assert_false(strategies[18].matches(ctx2, state2), "ks cp=2 -> no match")

    -- KidneyShot: HP 41 -> no match (> 40)
    local ctx3 = make_context({hp = 41})
    local state3 = get_state(ctx3)
    state3.kidney_shot_ready = true
    state3.combo_points = 4
    state3.hp = 41
    assert_false(strategies[18].matches(ctx3, state3), "ks hp=41 -> no match")
end

-- ============================================================================
-- Deep dive: Null target guards for all target-dependent strategies
-- ============================================================================
do
    local target_dependent = {2, 3, 4, 5, 11, 16, 17, 18, 19, 20}  -- Ambush through SinisterStrike
    for _, idx in ipairs(target_dependent) do
        local ctx = make_context({})
        ctx.target = nil
        local state = get_state(ctx)
        for k, v in pairs(state) do
            if type(k) == "string" and k:match("_ready$") then
                state[k] = true
            end
        end
        state.stealthed = false
        state.combo_points = 4
        state.max_combo_points = 5
        state.energy = 100
        state.hp = 30
        state.use_interrupt = true
        state.use_cooldowns = true
        state.target = nil
        local ok, result = pcall(strategies[idx].matches, ctx, state)
        assert_false(result, strategies[idx].name .. " no target -> no match")
    end
end

-- ============================================================================
-- Deep dive: OOC guards for combat abilities
-- ============================================================================
do
    local combat_strategies = {4, 5, 6, 7, 8, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20}
    for _, idx in ipairs(combat_strategies) do
        local ctx = make_context({in_combat = false})
        local state = get_state(ctx)
        for k, v in pairs(state) do
            if type(k) == "string" and k:match("_ready$") then
                state[k] = true
            end
        end
        state.stealthed = false
        state.combo_points = 4
        state.max_combo_points = 5
        state.energy = 100
        state.hp = 20
        state.enemies = 4
        state.use_interrupt = true
        state.use_cooldowns = true
        state.has_slice_and_dice = false
        state.in_combat = false
        state.blade_flurry_min_enemies = 3
        state.vanish_hp = 15
        state.use_expose_armor = true
        -- ExposeArmor also needs target_armor > 0 and special conditions
        ctx.target_armor = 1000
        state.target_armor = 1000
        state.target_is_elite = true
        local saved = NS.debuff_stacks
        NS.debuff_stacks = function() return 0 end
        local ok, result = pcall(strategies[idx].matches, ctx, state)
        assert_false(result, strategies[idx].name .. " OOC -> no match")
        NS.debuff_stacks = saved
    end
end

-- ============================================================================
-- Deep dive: ShivPurge PvP gate + melee range
-- ============================================================================
do
    -- ShivPurge complex conditions - just test PvP gate
    local ctx = make_context({})
    ctx.is_pvp = true
    ctx.in_melee_range = true
    ctx.target.is_player = function() return true end
    local state = get_state(ctx)
    state.shiv_ready = true
    state.is_pvp = true
    state.in_melee_range = true
    state.target = ctx.target
    state.shiv_purge_name = nil  -- No dispel target found -> no match
    assert_false(strategies[6].matches(ctx, state), "shivpurge no dispel target -> no match")

    -- ShivPurge: not PvP -> no match
    local ctx2 = make_context({})
    ctx2.is_pvp = false
    local state2 = get_state(ctx2)
    state2.shiv_ready = true
    state2.is_pvp = false
    assert_false(strategies[6].matches(ctx2, state2), "shivpurge not pvp -> no match")
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
-- Deep dive: NS.spell_ready throws (crash safety for pcall fix)
-- ============================================================================
do
    local saved = NS.spell_ready
    NS.spell_ready = function() error('simulated throw') end
    local ctx = make_context()
    local ok, state = pcall(get_state, ctx)
    NS.spell_ready = saved
    assert_true(ok, 'spell_ready throwing should not crash build_state (pcall fix)')
end
-- ============================================================================

print(string.format("\n=== Rogue Leveling Unit Tests: %d passed, %d failed (%d assertions) ===\n", passed, failed, assertions))
if failed > 0 then
    error(string.format("Some tests FAILED (%d failures)", failed))
else
    print("All Rogue leveling unit tests passed!")
end
