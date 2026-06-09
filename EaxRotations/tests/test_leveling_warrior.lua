-- Unit tests for Warrior leveling rotation
-- Tests build_state, all 16 match functions, strategy ordering,
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

local MOCK_WARRIOR_SPELLS = {
    Charge = { 100 },
    Rend = { 772 },
    HeroicStrike = { 78 },
    Overpower = { 7384 },
    ThunderClap = { 6343 },
    DemoralizingShout = { 1160 },
    Execute = { 5308 },
    VictoryRush = { 34428 },
    Pummel = { 6552 },
    BattleShout = { 6673 },
    Bloodrage = { 2687 },
    BerserkerRage = { 18499 },
    Cleave = { 845 },
    Whirlwind = { 1680 },
    SweepingStrikes = { 12328 },
    MortalStrike = { 12294 },
    Bloodthirst = { 23881 },
    SunderArmor = { 7386 },
    Hamstring = { 1715 },
    Slam = { 1464 },
    Rampage = { 29801 },
    Disarm = { 676 },
    DefensiveStance = { 71 },
    ShieldBash = { 72 },
    ShieldSlam = { 23922 },
    ShieldWall = { 871 },
    IntimidatingShout = { 5246 },
}

--- Create a fresh mock environment.
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
        get_class = function() return 1 end,
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
    NS.debuff_stacks = function(target, spell) return 0 end
    NS.buff_remains = function(unit, buff_ids) return 0 end
    NS.buff_up = function(unit, buff_ids) return false end

    -- rotation_registry mock
    NS.rotation_registry = {
        _registrations = {},
        register = function(self, key, strategies, opts)
            self._registrations[key] = { strategies = strategies, opts = opts }
        end,
        set_class_config = function(self, config) end,
    }

    NS.WarriorSpells = {}
    for k, v in pairs(MOCK_WARRIOR_SPELLS) do
        NS.WarriorSpells[k] = v
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
            leveling_use_execute = true,
            leveling_use_rend = true,
            leveling_use_thunder_clap = true,
            leveling_exec_hp = 20,
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
-- Load the Warrior leveling module
-- ============================================================================

local NS, core, mock_player, mock_target, mock_state = build_mock_env()
local ok, module = pcall(dofile, "EaxRotations/classes/warrior/leveling_sylvanas.lua")
if not ok then
    error("Failed to load Warrior leveling module: " .. tostring(module))
end
if not module or type(module) ~= "table" then
    error("Warrior leveling module should return a table of strategies")
end

local reg = NS.rotation_registry._registrations["leveling"]
if not reg then
    error("Warrior leveling module should register as 'leveling' in rotation_registry")
end
local strategies = reg.strategies
local get_state = reg.opts.get_state

local function find_strategy(name)
    for i, s in ipairs(strategies) do
        if s.name == name then return s end
    end
    error("strategy not found: " .. tostring(name), 2)
end

print("=== Warrior Leveling Unit Tests ===\n")
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
    assert_eq(state.in_combat, true, "in_combat from context")
end)

test("build_state: missing context fields use defaults", function()
    local ctx = {
        is_solo = false,
        is_leveling = true,
        me = { is_valid = function() return true end, has_buff = function(id) return false end, get_health = function() return 10000 end, get_max_health = function() return 10000 end, get_power = function() return 100 end },
        target = { is_valid = function() return true end, get_health = function() return 8000 end, get_max_health = function() return 10000 end, is_casting = function() return false end, is_alive = function() return true end, get_guid = function() return "mock-target" end, get_distance = function() return 5 end, get_health_percentage = function() return 80 end },
        settings = {},
    }
    local state = get_state(ctx)
    assert_not_nil(state, "should return a table")
    assert_eq(state.hp, 100, "default hp = 100")
    assert_eq(state.mana_pct, 100, "default mana_pct = 100")
    assert_eq(state.enemies, 0, "default enemies = 0")
    assert_false(state.in_combat, "default in_combat = false")
end)

test("build_state: spell readiness fields populated", function()
    local ctx = make_context()
    local state = get_state(ctx)
    assert_true(state.charge_ready, "charge_ready")
    assert_true(state.rend_ready, "rend_ready")
    assert_true(state.heroic_strike_ready, "heroic_strike_ready")
    assert_true(state.overpower_ready, "overpower_ready")
    assert_true(state.thunder_clap_ready, "thunder_clap_ready")
    assert_true(state.demoralizing_shout_ready, "demoralizing_shout_ready")
    assert_true(state.execute_ready, "execute_ready")
    assert_true(state.victory_rush_ready, "victory_rush_ready")
    assert_true(state.pummel_ready, "pummel_ready")
    assert_true(state.battle_shout_ready, "battle_shout_ready")
    assert_true(state.bloodrage_ready, "bloodrage_ready")
    assert_true(state.berserker_rage_ready, "berserker_rage_ready")
    assert_true(state.cleave_ready, "cleave_ready")
    assert_true(state.whirlwind_ready, "whirlwind_ready")
    assert_true(state.sweeping_strikes_ready, "sweeping_strikes_ready")
    assert_true(state.mortal_strike_ready, "mortal_strike_ready")
    assert_true(state.bloodthirst_ready, "bloodthirst_ready")
    assert_true(state.sunder_armor_ready, "sunder_armor_ready")
    assert_true(state.hamstring_ready, "hamstring_ready")
    assert_true(state.slam_ready, "slam_ready")
    assert_true(state.disarm_ready, "disarm_ready")
    assert_true(state.shield_bash_ready, "shield_bash_ready")
end)

test("build_state: custom settings from context", function()
    local ctx = make_context()
    ctx.settings.leveling_use_execute = false
    ctx.settings.leveling_use_rend = false
    ctx.settings.leveling_use_thunder_clap = false
    ctx.settings.leveling_exec_hp = 35
    local state = get_state(ctx)
    assert_false(state.use_execute, "use_execute from settings")
    assert_false(state.use_rend, "use_rend from settings")
    assert_false(state.use_thunder_clap, "use_thunder_clap from settings")
    assert_eq(state.exec_hp, 35, "exec_hp from settings")
end)

test("build_state: missing settings uses defaults", function()
    local ctx = make_context({settings = {}})
    local state = get_state(ctx)
    assert_true(state.use_execute, "default use_execute = true")
    assert_true(state.use_rend, "default use_rend = true")
    assert_true(state.use_thunder_clap, "default use_thunder_clap = true")
    assert_eq(state.exec_hp, 20, "default exec_hp = 20")
end)

-- ============================================================================
-- Test: battle_shout_matches (strategy #1)
-- ============================================================================

test("battle_shout_matches: OOC, ready, no buff -> true", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.has_battle_shout = false
    state.battle_shout_ready = true
    assert_true(strategies[1].matches(ctx, state), "OOC without buff should match")
end)

test("battle_shout_matches: in combat -> false", function()
    local ctx = make_context({in_combat = true})
    local state = get_state(ctx)
    state.has_battle_shout = false
    state.battle_shout_ready = true
    assert_false(strategies[1].matches(ctx, state), "in combat should not match")
end)

test("battle_shout_matches: already has buff -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.has_battle_shout = true
    state.battle_shout_ready = true
    assert_false(strategies[1].matches(ctx, state), "already buffed should not match")
end)

-- ============================================================================
-- Test: pummel_matches (strategy #2)
-- ============================================================================

test("pummel_matches: ready, target casting, interrupt enabled -> true", function()
    local ctx = make_context()
    ctx.target.is_casting = function() return true end
    local state = get_state(ctx)
    state.pummel_ready = true
    assert_true(strategies[2].matches(ctx, state), "target casting should match")
end)

test("pummel_matches: target not casting -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.pummel_ready = true
    assert_false(strategies[2].matches(ctx, state), "target not casting should not match")
end)

test("pummel_matches: interrupt disabled -> false", function()
    local ctx = make_context()
    ctx.settings.use_interrupt = false
    local state = get_state(ctx)
    state.pummel_ready = true
    state.use_interrupt = false
    assert_false(strategies[2].matches(ctx, state), "interrupt disabled should not match")
end)

-- ============================================================================
-- Test: charge_matches (strategy #3)
-- ============================================================================

test("charge_matches: ready, target at correct distance -> true", function()
    local ctx = make_context({in_combat = false})
    NS.get_distance = function(target) return 15 end
    local state = get_state(ctx)
    state.charge_ready = true
    assert_true(strategies[5].matches(ctx, state), "target at mid range should match")
end)

test("charge_matches: target too close -> false", function()
    local ctx = make_context({in_combat = false})
    NS.get_distance = function(target) return 5 end
    local state = get_state(ctx)
    state.charge_ready = true
    assert_false(strategies[5].matches(ctx, state), "target too close should not match")
end)

test("charge_matches: target too far -> false", function()
    local ctx = make_context({in_combat = false})
    NS.get_distance = function(target) return 30 end
    local state = get_state(ctx)
    state.charge_ready = true
    assert_false(strategies[5].matches(ctx, state), "target too far should not match")
end)

-- ============================================================================
-- Test: bloodrage_matches (strategy #4)
-- ============================================================================

test("bloodrage_matches: ready, low rage -> true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.bloodrage_ready = true
    mock_player.get_power = function() return 10 end
    assert_true(strategies[6].matches(ctx, state), "low rage should match")
    mock_player.get_power = function() return 100 end
end)

test("bloodrage_matches: enough rage -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.bloodrage_ready = true
    mock_player.get_power = function() return 50 end
    assert_false(strategies[6].matches(ctx, state), "rage above 20 should not match")
    mock_player.get_power = function() return 100 end
end)

test("bloodrage_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.bloodrage_ready = true
    state.in_combat = false
    assert_false(strategies[6].matches(ctx, state), "OOC should not match")
end)

-- ============================================================================
-- Test: victory_rush_matches (strategy #5)
-- ============================================================================

test("victory_rush_matches: ready, in combat, has target -> true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.victory_rush_ready = true
    assert_true(strategies[8].matches(ctx, state), "should match when ready")
end)

test("victory_rush_matches: no target -> false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.victory_rush_ready = true
    state.target = nil
    assert_false(strategies[8].matches(ctx, state), "no target should not match")
end)

test("victory_rush_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.victory_rush_ready = true
    state.in_combat = false
    assert_false(strategies[8].matches(ctx, state), "OOC should not match")
end)

-- ============================================================================
-- Test: execute_matches (strategy #6)
-- ============================================================================

test("execute_matches: ready, target HP low -> true", function()
    local ctx = make_context()
    ctx.target.get_health_percentage = function() return 15 end
    local state = get_state(ctx)
    state.execute_ready = true
    state.use_execute = true
    state.exec_hp = 20
    assert_true(strategies[11].matches(ctx, state), "target HP below 20 should match")
end)

test("execute_matches: target HP above threshold -> false", function()
    local ctx = make_context()
    ctx.target.get_health_percentage = function() return 50 end
    local state = get_state(ctx)
    state.execute_ready = true
    state.use_execute = true
    state.exec_hp = 20
    assert_false(strategies[11].matches(ctx, state), "target HP above 20 should not match")
end)

test("execute_matches: disabled -> false", function()
    local ctx = make_context()
    ctx.target.get_health_percentage = function() return 15 end
    local state = get_state(ctx)
    state.execute_ready = true
    state.use_execute = false
    state.exec_hp = 20
    assert_false(strategies[11].matches(ctx, state), "disabled should not match")
end)

-- ============================================================================
-- Test: sweeping_strikes_matches (strategy #7)
-- ============================================================================

test("sweeping_strikes_matches: ready, 2+ enemies -> true", function()
    local ctx = make_context({enemies_count = 3})
    local state = get_state(ctx)
    state.sweeping_strikes_ready = true
    state.enemies = 3
    assert_true(find_strategy("SweepingStrikes").matches(ctx, state), "3 enemies should match")
end)

test("sweeping_strikes_matches: single enemy -> false", function()
    local ctx = make_context({enemies_count = 1})
    local state = get_state(ctx)
    state.sweeping_strikes_ready = true
    state.enemies = 1
    assert_false(find_strategy("SweepingStrikes").matches(ctx, state), "1 enemy should not match")
end)

test("sweeping_strikes_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false, enemies_count = 3})
    local state = get_state(ctx)
    state.sweeping_strikes_ready = true
    state.in_combat = false
    state.enemies = 3
    assert_false(find_strategy("SweepingStrikes").matches(ctx, state), "OOC should not match")
end)

-- ============================================================================
-- Test: whirlwind_matches (strategy #8)
-- ============================================================================

test("whirlwind_matches: ready, 3+ enemies -> true", function()
    local ctx = make_context({enemies_count = 4})
    local state = get_state(ctx)
    state.whirlwind_ready = true
    state.enemies = 4
    assert_true(find_strategy("Whirlwind").matches(ctx, state), "4 enemies should match")
end)

test("whirlwind_matches: 1 enemy -> false", function()
    local ctx = make_context({enemies_count = 1})
    local state = get_state(ctx)
    state.whirlwind_ready = true
    state.enemies = 1
    assert_false(find_strategy("Whirlwind").matches(ctx, state), "1 enemy should not match")
end)

-- ============================================================================
-- Test: thunder_clap_matches (strategy #9)
-- ============================================================================

test("thunder_clap_matches: ready, 2+ enemies -> true", function()
    local ctx = make_context({enemies_count = 3})
    local state = get_state(ctx)
    state.thunder_clap_ready = true
    state.use_thunder_clap = true
    state.enemies = 3
    assert_true(find_strategy("ThunderClap").matches(ctx, state), "3 enemies should match")
end)

test("thunder_clap_matches: 1 enemy -> false", function()
    local ctx = make_context({enemies_count = 1})
    local state = get_state(ctx)
    state.thunder_clap_ready = true
    state.use_thunder_clap = true
    state.enemies = 1
    assert_false(find_strategy("ThunderClap").matches(ctx, state), "1 enemy should not match")
end)

-- ============================================================================
-- Test: rend_matches (strategy #10)
-- ============================================================================

test("rend_matches: ready, DoT expired -> true", function()
    local ctx = make_context()
    NS.debuff_remains = function(target, spell) return 0 end
    local state = get_state(ctx)
    state.rend_ready = true
    state.use_rend = true
    assert_true(find_strategy("Rend").matches(ctx, state), "DoT expired should match")
end)

test("rend_matches: DoT still active -> false", function()
    local ctx = make_context()
    NS.debuff_remains = function(target, spell) return 10 end
    local state = get_state(ctx)
    state.rend_ready = true
    state.use_rend = true
    assert_false(find_strategy("Rend").matches(ctx, state), "active DoT should not match")
    NS.debuff_remains = function(target, spell) return 0 end
end)

test("rend_matches: disabled -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.rend_ready = true
    state.use_rend = false
    assert_false(find_strategy("Rend").matches(ctx, state), "disabled should not match")
end)

-- ============================================================================
-- Test: spec_filler_matches (strategy #11)
-- ============================================================================

test("spec_filler_matches: Mortal Strike ready -> true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.mortal_strike_ready = true
    state.bloodthirst_ready = false
    assert_true(find_strategy("SpecFiller").matches(ctx, state), "MS ready should match")
end)

test("spec_filler_matches: Bloodthirst ready -> true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.mortal_strike_ready = false
    state.bloodthirst_ready = true
    assert_true(find_strategy("SpecFiller").matches(ctx, state), "Bloodthirst ready should match")
end)

test("spec_filler_matches: neither ready -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.mortal_strike_ready = false
    state.bloodthirst_ready = false
    assert_false(find_strategy("SpecFiller").matches(ctx, state), "neither ready should not match")
end)

test("spec_filler_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.mortal_strike_ready = true
    state.in_combat = false
    assert_false(find_strategy("SpecFiller").matches(ctx, state), "OOC should not match")
end)

-- ============================================================================
-- Test: overpower_matches (strategy #12)
-- ============================================================================

test("overpower_matches: ready, has target -> true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.overpower_ready = true
    assert_true(find_strategy("Overpower").matches(ctx, state), "should match when ready")
end)

test("overpower_matches: no target -> false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.overpower_ready = true
    state.target = nil
    assert_false(find_strategy("Overpower").matches(ctx, state), "no target should not match")
end)

test("overpower_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.overpower_ready = true
    state.in_combat = false
    assert_false(find_strategy("Overpower").matches(ctx, state), "OOC should not match")
end)

-- ============================================================================
-- Test: heroic_strike_matches (strategy #13)
-- ============================================================================

test("heroic_strike_matches: ready, enough rage, has target -> true", function()
    local ctx = make_context()
    mock_player.get_power = function() return 80 end
    local state = get_state(ctx)
    state.heroic_strike_ready = true
    assert_true(find_strategy("HeroicStrike").matches(ctx, state), "enough rage should match")
    mock_player.get_power = function() return 100 end
end)

test("heroic_strike_matches: not enough rage -> false", function()
    local ctx = make_context()
    mock_player.get_power = function() return 20 end
    local state = get_state(ctx)
    state.heroic_strike_ready = true
    assert_false(find_strategy("HeroicStrike").matches(ctx, state), "low rage should not match")
    mock_player.get_power = function() return 100 end
end)

test("heroic_strike_matches: no target -> false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.heroic_strike_ready = true
    state.target = nil
    assert_false(find_strategy("HeroicStrike").matches(ctx, state), "no target should not match")
end)

-- ============================================================================
-- Test: Strategy priority ordering
-- ============================================================================

test("strategies: 25 strategies in correct priority order", function()
    local expected = {
        "BattleShout",
        "Pummel",
        "ShieldSlamPurge",
        "Disarm",
        "Charge",
        "Bloodrage",
        "BerserkerRage",
        "VictoryRush",
        "ShieldWall",
        "HealthPotion",
        "Execute",
        "PvPCCGate",
        "IntimidatingShout",
        "Rend",
        "SweepingStrikes",
        "Cleave",
        "Whirlwind",
        "ThunderClap",
        "DemoralizingShout",
        "Rampage",
        "Hamstring",
        "SpecFiller",
        "Overpower",
        "SunderArmor",
        "HeroicStrike",
    }
    assert_eq(#strategies, 25, "should have 25 strategies")
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

test("execute_BattleShout: does not crash", function()
    local ok, result = pcall(strategies[1].execute)
    assert_true(ok, "execute should not throw")
end)

test("execute_HeroicStrike: does not crash with context", function()
    local ctx = make_context()
    local ok, result = pcall(find_strategy("HeroicStrike").execute, ctx)
    assert_true(ok, "execute with context should not throw")
end)

-- ============================================================================
-- Test: Nil guard
-- ============================================================================

test("module: returns nil when EaxRotations is nil", function()
    local _, c = build_mock_env()
    _G.EaxRotations = nil
    local nil_mod = dofile("EaxRotations/classes/warrior/leveling_sylvanas.lua")
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

test("rotation: OOC scenario - BattleShout should match, combat abilities should not", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.has_battle_shout = false
    state.battle_shout_ready = true

    -- BattleShout should match OOC
    assert_true(strategies[1].matches(ctx, state), "BattleShout should match OOC")

    -- Combat abilities need in_combat
    for i = 2, #strategies do
        local ok, matched = pcall(strategies[i].matches, ctx, state)
        assert_true(ok, "strategy[" .. i .. "] matches should not throw")
        if strategies[i].name ~= "PvPCCGate" and strategies[i].name ~= "Charge" then
            assert_false(matched, "strategy[" .. i .. "] (" .. strategies[i].name .. ") should not match OOC")
        end
    end
end)

test("rotation: execute scenario - should match when target HP low", function()
    local ctx = make_context()
    ctx.target.get_health_percentage = function() return 15 end
    local state = get_state(ctx)
    state.execute_ready = true
    state.use_execute = true
    state.exec_hp = 20

    -- Execute should match
    assert_true(strategies[11].matches(ctx, state), "Execute should match when target HP < 20")

    -- Rend should also match (DoT expired)
    state.rend_ready = true
    state.use_rend = true
    assert_true(find_strategy("Rend").matches(ctx, state), "Rend should match (DoT expired)")
end)

-- ============================================================================
-- ============================================================================
-- Edge case tests - boundary values
-- ============================================================================

do -- edge_bloodrage
    local label = "edge_bloodrage"

    test(label .. ": rage exactly 20 -> match", function()
        local saved = mock_player.get_power
        mock_player.get_power = function() return 20 end
        local ctx = make_context()
        local state = get_state(ctx)
        state.bloodrage_ready = true
        assert_true(strategies[6].matches(ctx, state), "rage 20 should match (<= threshold)")
        mock_player.get_power = saved
    end)

    test(label .. ": rage exactly 21 -> no match", function()
        local saved = mock_player.get_power
        mock_player.get_power = function() return 21 end
        local ctx = make_context()
        local state = get_state(ctx)
        state.bloodrage_ready = true
        assert_false(strategies[6].matches(ctx, state), "rage 21 should not match (> threshold)")
        mock_player.get_power = saved
    end)
end

do -- edge_execute
    local label = "edge_execute"

    test(label .. ": target HP exactly 20 -> match", function()
        local ctx = make_context()
        ctx.target.get_health_percentage = function() return 20 end
        local state = get_state(ctx)
        state.execute_ready = true
        state.use_execute = true
        state.exec_hp = 20
        assert_true(strategies[11].matches(ctx, state), "target HP 20 should match (<= threshold)")
    end)

    test(label .. ": target HP exactly 21 -> no match", function()
        local ctx = make_context()
        ctx.target.get_health_percentage = function() return 21 end
        local state = get_state(ctx)
        state.execute_ready = true
        state.use_execute = true
        state.exec_hp = 20
        assert_false(strategies[11].matches(ctx, state), "target HP 21 should not match (> threshold)")
    end)

    test(label .. ": execute disabled -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.execute_ready = true
        state.use_execute = false
        state.exec_hp = 20
        assert_false(strategies[11].matches(ctx, state), "disabled should not match")
    end)
end

do -- edge_sweeping_strikes
    local label = "edge_sweeping_strikes"

    test(label .. ": enemies exactly 2 -> match", function()
        local ctx = make_context({enemies_count = 2})
        local state = get_state(ctx)
        state.sweeping_strikes_ready = true
        state.enemies = 2
        assert_true(strategies[15].matches(ctx, state), "2 enemies should match (>= 2)")
    end)

    test(label .. ": exactly 1 enemy -> no match", function()
        local ctx = make_context({enemies_count = 1})
        local state = get_state(ctx)
        state.sweeping_strikes_ready = true
        state.enemies = 1
        assert_false(strategies[15].matches(ctx, state), "1 enemy should not match (< 2)")
    end)
end

do -- edge_cleave
    local label = "edge_cleave"

    test(label .. ": enemies exactly 2, rage 25 -> match", function()
        local saved = mock_player.get_power
        mock_player.get_power = function() return 25 end
        local ctx = make_context({enemies_count = 2})
        local state = get_state(ctx)
        state.cleave_ready = true
        state.enemies = 2
        assert_true(strategies[16].matches(ctx, state), "2 enemies with rage 25 should match")
        mock_player.get_power = saved
    end)

    test(label .. ": enemies exactly 2, rage 24 -> no match", function()
        local saved = mock_player.get_power
        mock_player.get_power = function() return 24 end
        local ctx = make_context({enemies_count = 2})
        local state = get_state(ctx)
        state.cleave_ready = true
        state.enemies = 2
        assert_false(strategies[16].matches(ctx, state), "2 enemies with rage 24 should not match")
        mock_player.get_power = saved
    end)

    test(label .. ": exactly 1 enemy -> no match", function()
        local ctx = make_context({enemies_count = 1})
        local state = get_state(ctx)
        state.cleave_ready = true
        state.enemies = 1
        assert_false(strategies[16].matches(ctx, state), "1 enemy should not match (< 2)")
    end)
end

do -- edge_whirlwind
    local label = "edge_whirlwind"

    test(label .. ": enemies exactly 3 -> match", function()
        local ctx = make_context({enemies_count = 3})
        local state = get_state(ctx)
        state.whirlwind_ready = true
        state.enemies = 3
        assert_true(strategies[17].matches(ctx, state), "3 enemies should match (>= 3)")
    end)

    test(label .. ": exactly 2 enemies -> no match", function()
        local ctx = make_context({enemies_count = 2})
        local state = get_state(ctx)
        state.whirlwind_ready = true
        state.enemies = 2
        assert_false(strategies[17].matches(ctx, state), "2 enemies should not match (< 3)")
    end)
end

do -- edge_thunder_clap
    local label = "edge_thunder_clap"

    test(label .. ": enemies exactly 2 -> match", function()
        local ctx = make_context({enemies_count = 2})
        local state = get_state(ctx)
        state.thunder_clap_ready = true
        state.use_thunder_clap = true
        state.enemies = 2
        assert_true(strategies[18].matches(ctx, state), "2 enemies should match (>= 2)")
    end)

    test(label .. ": exactly 1 enemy -> no match", function()
        local ctx = make_context({enemies_count = 1})
        local state = get_state(ctx)
        state.thunder_clap_ready = true
        state.use_thunder_clap = true
        state.enemies = 1
        assert_false(strategies[18].matches(ctx, state), "1 enemy should not match (< 2)")
    end)
end

do -- edge_rend
    local label = "edge_rend"

    test(label .. ": debuff remains exactly 4 -> match", function()
        local ctx = make_context()
        local saved = NS.debuff_remains
        NS.debuff_remains = function(target, spell) return 4 end
        local state = get_state(ctx)
        state.rend_ready = true
        state.use_rend = true
        assert_true(strategies[14].matches(ctx, state), "remains 4 should match (<= 4)")
        NS.debuff_remains = saved
    end)

    test(label .. ": debuff remains exactly 5 -> no match", function()
        local ctx = make_context()
        local saved = NS.debuff_remains
        NS.debuff_remains = function(target, spell) return 5 end
        local state = get_state(ctx)
        state.rend_ready = true
        state.use_rend = true
        assert_false(strategies[14].matches(ctx, state), "remains 5 should not match (> 4)")
        NS.debuff_remains = saved
    end)

    test(label .. ": rend disabled -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.rend_ready = true
        state.use_rend = false
        assert_false(strategies[14].matches(ctx, state), "disabled should not match")
    end)
end

do -- edge_rampage
    local label = "edge_rampage"

    test(label .. ": rage exactly 30, no buff -> match", function()
        local saved_power = mock_player.get_power
        local saved_buff = NS.buff_up
        mock_player.get_power = function() return 30 end
        NS.buff_up = function(unit, ids) return false end
        local ctx = make_context()
        local state = get_state(ctx)
        state.rampage_ready = true
        state.has_rampage = false
        state.rampage_remains = 0
        assert_true(strategies[20].matches(ctx, state), "rage 30 with no buff should match")
        mock_player.get_power = saved_power
        NS.buff_up = saved_buff
    end)

    test(label .. ": rage exactly 29 -> no match", function()
        local saved_power = mock_player.get_power
        mock_player.get_power = function() return 29 end
        local ctx = make_context()
        local state = get_state(ctx)
        state.rampage_ready = true
        state.has_rampage = false
        state.rampage_remains = 0
        assert_false(strategies[20].matches(ctx, state), "rage 29 should not match (< 30)")
        mock_player.get_power = saved_power
    end)

    test(label .. ": buff remains exactly 3 -> match (<= 3)", function()
        local saved_power = mock_player.get_power
        mock_player.get_power = function() return 100 end
        local saved_buff = NS.buff_up
        local saved_remains = NS.buff_remains
        NS.buff_up = function(unit, ids) return true end
        NS.buff_remains = function(unit, ids) return 3 end
        local ctx = make_context()
        local state = get_state(ctx)
        state.rampage_ready = true
        state.has_rampage = true
        state.rampage_remains = 3
        assert_true(strategies[20].matches(ctx, state), "remains 3 should match")
        mock_player.get_power = saved_power
        NS.buff_up = saved_buff
        NS.buff_remains = saved_remains
    end)

    test(label .. ": buff remains exactly 4 -> no match (> 3)", function()
        local saved_power = mock_player.get_power
        mock_player.get_power = function() return 100 end
        local saved_buff = NS.buff_up
        local saved_remains = NS.buff_remains
        NS.buff_up = function(unit, ids) return true end
        NS.buff_remains = function(unit, ids) return 4 end
        local ctx = make_context()
        local state = get_state(ctx)
        state.rampage_ready = true
        state.has_rampage = true
        state.rampage_remains = 4
        assert_false(strategies[20].matches(ctx, state), "remains 4 should not match (> 3)")
        mock_player.get_power = saved_power
        NS.buff_up = saved_buff
        NS.buff_remains = saved_remains
    end)
end

do -- edge_sunder_armor
    local label = "edge_sunder_armor"

    test(label .. ": 2 stacks, HP 40, rage 25, target has armor -> match", function()
        local saved_power = mock_player.get_power
        mock_player.get_power = function() return 25 end
        local saved_stacks = NS.debuff_stacks
        NS.debuff_stacks = function(target, spell) return 2 end
        local ctx = make_context()
        ctx.target_armor = 100
        ctx.target.get_health_percentage = function() return 40 end
        local state = get_state(ctx)
        state.sunder_armor_ready = true
        state.sunder_stacks = 2
        assert_true(strategies[24].matches(ctx, state), "2 stacks with HP 40 should match")
        mock_player.get_power = saved_power
        NS.debuff_stacks = saved_stacks
    end)

    test(label .. ": 3 stacks -> no match", function()
        local saved_power = mock_player.get_power
        mock_player.get_power = function() return 100 end
        local saved_stacks = NS.debuff_stacks
        NS.debuff_stacks = function(target, spell) return 3 end
        local ctx = make_context()
        ctx.target_armor = 100
        local state = get_state(ctx)
        state.sunder_armor_ready = true
        state.sunder_stacks = 3
        assert_false(strategies[24].matches(ctx, state), "3 stacks should not match (>= 3)")
        mock_player.get_power = saved_power
        NS.debuff_stacks = saved_stacks
    end)

    test(label .. ": target HP 39 -> no match", function()
        local saved_power = mock_player.get_power
        mock_player.get_power = function() return 100 end
        local saved_stacks = NS.debuff_stacks
        NS.debuff_stacks = function(target, spell) return 0 end
        local ctx = make_context()
        ctx.target_armor = 100
        ctx.target.get_health_percentage = function() return 39 end
        local state = get_state(ctx)
        state.sunder_armor_ready = true
        state.sunder_stacks = 0
        assert_false(strategies[24].matches(ctx, state), "HP 39 should not match (< 40)")
        mock_player.get_power = saved_power
        NS.debuff_stacks = saved_stacks
    end)

    test(label .. ": rage 24 -> no match", function()
        local saved_power = mock_player.get_power
        mock_player.get_power = function() return 24 end
        local saved_stacks = NS.debuff_stacks
        NS.debuff_stacks = function(target, spell) return 0 end
        local ctx = make_context()
        ctx.target_armor = 100
        ctx.target.get_health_percentage = function() return 60 end
        local state = get_state(ctx)
        state.sunder_armor_ready = true
        state.sunder_stacks = 0
        assert_false(strategies[24].matches(ctx, state), "rage 24 should not match (< 25)")
        mock_player.get_power = saved_power
        NS.debuff_stacks = saved_stacks
    end)
end

do -- edge_heroic_strike
    local label = "edge_heroic_strike"

    test(label .. ": rage exactly 50 -> match", function()
        local saved = mock_player.get_power
        mock_player.get_power = function() return 50 end
        local ctx = make_context()
        local state = get_state(ctx)
        state.heroic_strike_ready = true
        assert_true(strategies[25].matches(ctx, state), "rage 50 should match (>= 50)")
        mock_player.get_power = saved
    end)

    test(label .. ": rage exactly 49 -> no match", function()
        local saved = mock_player.get_power
        mock_player.get_power = function() return 49 end
        local ctx = make_context()
        local state = get_state(ctx)
        state.heroic_strike_ready = true
        assert_false(strategies[25].matches(ctx, state), "rage 49 should not match (< 50)")
        mock_player.get_power = saved
    end)
end

do -- edge_hamstring
    local label = "edge_hamstring"

    test(label .. ": target HP exactly 20 -> match", function()
        local ctx = make_context()
        ctx.target.get_health_percentage = function() return 20 end
        local state = get_state(ctx)
        state.hamstring_ready = true
        assert_true(strategies[21].matches(ctx, state), "target HP 20 should match (<= 20)")
    end)

    test(label .. ": target HP exactly 21 -> no match", function()
        local ctx = make_context()
        ctx.target.get_health_percentage = function() return 21 end
        local state = get_state(ctx)
        state.hamstring_ready = true
        assert_false(strategies[21].matches(ctx, state), "target HP 21 should not match (> 20)")
    end)
end

do -- edge_demo_shout
    local label = "edge_demo_shout"

    test(label .. ": enemies exactly 2 -> match", function()
        local ctx = make_context({enemies_count = 2})
        local state = get_state(ctx)
        state.demoralizing_shout_ready = true
        state.enemies = 2
        assert_true(strategies[19].matches(ctx, state), "2 enemies should match (>= 2)")
    end)

    test(label .. ": exactly 1 enemy -> no match", function()
        local ctx = make_context({enemies_count = 1})
        local state = get_state(ctx)
        state.demoralizing_shout_ready = true
        state.enemies = 1
        assert_false(strategies[19].matches(ctx, state), "1 enemy should not match (< 2)")
    end)
end

do -- edge_shield_wall
    local label = "edge_shield_wall"

    test(label .. ": HP exactly 20 -> match", function()
        local ctx = make_context({hp = 20})
        local state = get_state(ctx)
        state.shield_wall_ready = true
        state.hp = 20
        assert_true(strategies[9].matches(ctx, state), "HP 20 should match (<= 20)")
    end)

    test(label .. ": HP exactly 21 -> no match", function()
        local ctx = make_context({hp = 21})
        local state = get_state(ctx)
        state.shield_wall_ready = true
        state.hp = 21
        assert_false(strategies[9].matches(ctx, state), "HP 21 should not match (> 20)")
    end)
end

do -- edge_intimidating_shout
    local label = "edge_intimidating_shout"

    test(label .. ": enemies 3, HP 30 -> match", function()
        local ctx = make_context({hp = 30, enemies_count = 3})
        local state = get_state(ctx)
        state.intimidating_shout_ready = true
        state.hp = 30
        state.enemies = 3
        assert_true(strategies[13].matches(ctx, state), "3 enemies with HP 30 should match")
    end)

    test(label .. ": 2 enemies -> no match", function()
        local ctx = make_context({hp = 30, enemies_count = 2})
        local state = get_state(ctx)
        state.intimidating_shout_ready = true
        state.hp = 30
        state.enemies = 2
        assert_false(strategies[13].matches(ctx, state), "2 enemies should not match (< 3)")
    end)

    test(label .. ": HP 31 -> no match", function()
        local ctx = make_context({hp = 31, enemies_count = 3})
        local state = get_state(ctx)
        state.intimidating_shout_ready = true
        state.hp = 31
        state.enemies = 3
        assert_false(strategies[13].matches(ctx, state), "HP 31 should not match (> 30)")
    end)
end

do -- edge_berserker_rage
    local label = "edge_berserker_rage"

    test(label .. ": enemies exactly 2 -> match", function()
        local ctx = make_context({enemies_count = 2})
        local state = get_state(ctx)
        state.berserker_rage_ready = true
        state.enemies = 2
        assert_true(strategies[7].matches(ctx, state), "2 enemies should match (>= 2)")
    end)

    test(label .. ": exactly 1 enemy -> no match", function()
        local ctx = make_context({enemies_count = 1})
        local state = get_state(ctx)
        state.berserker_rage_ready = true
        state.enemies = 1
        assert_false(strategies[7].matches(ctx, state), "1 enemy should not match (< 2)")
    end)
end

do -- edge_charge
    local label = "edge_charge"

    test(label .. ": distance exactly 8 -> match", function()
        local ctx = make_context({in_combat = false})
        local saved = NS.get_distance
        NS.get_distance = function() return 8 end
        local state = get_state(ctx)
        state.charge_ready = true
        assert_true(strategies[5].matches(ctx, state), "distance 8 should match (>= 8)")
        NS.get_distance = saved
    end)

    test(label .. ": distance exactly 7 -> no match", function()
        local ctx = make_context({in_combat = false})
        local saved = NS.get_distance
        NS.get_distance = function() return 7 end
        local state = get_state(ctx)
        state.charge_ready = true
        assert_false(strategies[5].matches(ctx, state), "distance 7 should not match (< 8)")
        NS.get_distance = saved
    end)

    test(label .. ": distance exactly 25 -> match", function()
        local ctx = make_context({in_combat = false})
        local saved = NS.get_distance
        NS.get_distance = function() return 25 end
        local state = get_state(ctx)
        state.charge_ready = true
        assert_true(strategies[5].matches(ctx, state), "distance 25 should match (<= 25)")
        NS.get_distance = saved
    end)

    test(label .. ": distance exactly 26 -> no match", function()
        local ctx = make_context({in_combat = false})
        local saved = NS.get_distance
        NS.get_distance = function() return 26 end
        local state = get_state(ctx)
        state.charge_ready = true
        assert_false(strategies[5].matches(ctx, state), "distance 26 should not match (> 25)")
        NS.get_distance = saved
    end)

    test(label .. ": in combat -> no match", function()
        local ctx = make_context({in_combat = true})
        local state = get_state(ctx)
        state.charge_ready = true
        assert_false(strategies[5].matches(ctx, state), "in combat should not match")
    end)
end

do -- edge_battle_shout
    local label = "edge_battle_shout"

    test(label .. ": OOC, no buff, ready -> match", function()
        local ctx = make_context({in_combat = false})
        local state = get_state(ctx)
        state.battle_shout_ready = true
        state.has_battle_shout = false
        assert_true(strategies[1].matches(ctx, state), "OOC with no buff should match")
    end)

    test(label .. ": already has buff -> no match", function()
        local ctx = make_context({in_combat = false})
        local state = get_state(ctx)
        state.battle_shout_ready = true
        state.has_battle_shout = true
        assert_false(strategies[1].matches(ctx, state), "buff active should not match")
    end)

    test(label .. ": in combat -> no match", function()
        local ctx = make_context({in_combat = true})
        local state = get_state(ctx)
        state.battle_shout_ready = true
        state.has_battle_shout = false
        assert_false(strategies[1].matches(ctx, state), "in combat should not match")
    end)
end

do -- edge_pummel
    local label = "edge_pummel"

    test(label .. ": target casting, ready -> match", function()
        local ctx = make_context()
        ctx.target.is_casting = function() return true end
        local state = get_state(ctx)
        state.pummel_ready = true
        state.use_interrupt = true
        assert_true(strategies[2].matches(ctx, state), "target casting should match")
    end)

    test(label .. ": target not casting -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.pummel_ready = true
        state.use_interrupt = true
        assert_false(strategies[2].matches(ctx, state), "target not casting should not match")
    end)

    test(label .. ": interrupt disabled -> no match", function()
        local ctx = make_context()
        ctx.target.is_casting = function() return true end
        local state = get_state(ctx)
        state.pummel_ready = true
        state.use_interrupt = false
        assert_false(strategies[2].matches(ctx, state), "interrupt disabled should not match")
    end)
end

do -- edge_victory_rush
    local label = "edge_victory_rush"

    test(label .. ": ready, in combat -> match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.victory_rush_ready = true
        assert_true(strategies[8].matches(ctx, state), "ready in combat should match")
    end)

    test(label .. ": not ready -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.victory_rush_ready = false
        assert_false(strategies[8].matches(ctx, state), "not ready should not match")
    end)
end

do -- edge_overpower
    local label = "edge_overpower"

    test(label .. ": ready, in combat -> match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.overpower_ready = true
        assert_true(strategies[23].matches(ctx, state), "ready in combat should match")
    end)

    test(label .. ": not ready -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.overpower_ready = false
        assert_false(strategies[23].matches(ctx, state), "not ready should not match")
    end)
end

-- ============================================================================
-- Edge case tests - API crash safety
-- ============================================================================

do -- edge_api_buff
    local label = "edge_api_buff"

    test(label .. ": NS.buff_up is nil -> has_buff returns false", function()
        local saved = NS.buff_up
        NS.buff_up = nil
        local ctx = make_context({in_combat = false})
        local state = get_state(ctx)
        assert_eq(state.has_battle_shout, false, "has_battle_shout should be false when buff_up nil")
        assert_eq(state.has_rampage, false, "has_rampage should be false when buff_up nil")
        NS.buff_up = saved
    end)

    test(label .. ": NS.buff_up throws -> pcall catches, has_buff returns false", function()
        local saved = NS.buff_up
        NS.buff_up = function() error("crash") end
        local ctx = make_context({in_combat = false})
        local state = get_state(ctx)
        assert_eq(state.has_battle_shout, false, "has_battle_shout should be false when buff_up throws")
        assert_eq(state.has_rampage, false, "has_rampage should be false when buff_up throws")
        NS.buff_up = saved
    end)

    test(label .. ": NS.buff_remains is nil -> buff_remains returns 0", function()
        local saved = NS.buff_remains
        NS.buff_remains = nil
        local ctx = make_context()
        local state = get_state(ctx)
        assert_eq(state.rampage_remains, 0, "rampage_remains should be 0 when buff_remains nil")
        NS.buff_remains = saved
    end)

    test(label .. ": NS.buff_remains throws -> pcall catches, returns 0", function()
        local saved = NS.buff_remains
        NS.buff_remains = function() error("crash") end
        local ctx = make_context()
        local state = get_state(ctx)
        assert_eq(state.rampage_remains, 0, "rampage_remains should be 0 when buff_remains throws")
        NS.buff_remains = saved
    end)

    test(label .. ": NS.debuff_stacks nil -> debuff_stacks returns 0", function()
        local saved = NS.debuff_stacks
        NS.debuff_stacks = nil
        local ctx = make_context()
        local state = get_state(ctx)
        assert_eq(state.sunder_stacks, 0, "sunder_stacks should be 0 when debuff_stacks nil")
        NS.debuff_stacks = saved
    end)

    test(label .. ": NS.debuff_stacks throws -> pcall catches, returns 0", function()
        local saved = NS.debuff_stacks
        NS.debuff_stacks = function() error("crash") end
        local ctx = make_context()
        local state = get_state(ctx)
        assert_eq(state.sunder_stacks, 0, "sunder_stacks should be 0 when debuff_stacks throws")
        NS.debuff_stacks = saved
    end)
end

do -- edge_api_spell_ready
    local label = "edge_api_spell_ready"

    test(label .. ": NS.spell_ready is nil -> all readiness fields false", function()
        local saved = NS.spell_ready
        NS.spell_ready = nil
        local ctx = make_context()
        local state = get_state(ctx)
        assert_eq(state.charge_ready, false, "charge_ready should be false")
        assert_eq(state.execute_ready, false, "execute_ready should be false")
        assert_eq(state.heroic_strike_ready, false, "heroic_strike_ready should be false")
        assert_eq(state.pummel_ready, false, "pummel_ready should be false")
        assert_eq(state.overpower_ready, false, "overpower_ready should be false")
        NS.spell_ready = saved
    end)

    test(label .. ": NS.spell_ready returns nil -> readiness fields false", function()
        local saved = NS.spell_ready
        NS.spell_ready = function() return nil end
        local ctx = make_context()
        local state = get_state(ctx)
        assert_eq(state.charge_ready, false, "charge_ready should be false when spell_ready returns nil")
        NS.spell_ready = saved
    end)

    test(label .. ": match functions handle nil readiness -> no crash", function()
        local saved_spell = NS.spell_ready
        NS.spell_ready = nil
        local ctx = make_context()
        local state = get_state(ctx)
        for i = 1, #strategies do
            local ok, matched = pcall(strategies[i].matches, ctx, state)
            assert_true(ok, "strategy[" .. i .. "] matches should not throw when readiness is nil")
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

    test(label .. ": all execute functions handle no args", function()
        for i, s in ipairs(strategies) do
            local ok, result = pcall(s.execute)
            assert_true(ok, "strategy[" .. i .. "] execute() with no args should not throw")
        end
    end)
end
-- Summary
-- ============================================================================

print(string.format("\n=== Warrior Leveling Unit Tests: %d passed, %d failed (%d assertions) ===\n", passed, failed, assertions))
if failed > 0 then
    error(string.format("Some tests FAILED (%d failures)", failed))
else
    print("All Warrior leveling unit tests passed!")
end
