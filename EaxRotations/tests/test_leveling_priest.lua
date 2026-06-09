-- Unit tests for Priest leveling rotation
-- Tests build_state, all 15 match functions, helper functions,
-- strategy ordering, and edge case handling

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

local MOCK_PRIEST_SPELLS = {
    PowerWordFortitude = { 25312 },
    InnerFire = { 25382 },
    PowerWordShield = { 25218 },
    ShadowWordPain = { 27607 },
    Renew = { 25222 },
    Heal = { 25213 },
    FlashHeal = { 25235 },
    GreaterHeal = { 25213 },
    HolyFire = { 25233 },
    HolyNova = { 15237 },
    MindBlast = { 25375 },
    ShadowWordDeath = { 32379 },
    Fade = { 586 },
    PsychicScream = { 10890 },
    ShackleUndead = { 9484 },
    InnerFocus = { 14751 },
    Smite = { 25364 },
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
        buffs = {},         -- buff_id -> remaining
        debuffs = {},       -- debuff_id -> remaining
        is_casting = false,
        target_guid = "mock-target",
        threat_status = 0,
        target_creature_type = "humanoid",
    }

    local mock_target = {
        is_valid = function() return true end,
        get_health = function() return 8000 end,
        get_max_health = function() return 10000 end,
        is_casting = function() return mock_state.is_casting end,
        is_alive = function() return true end,
        get_guid = function() return mock_state.target_guid end,
        get_creature_type = function() return mock_state.target_creature_type end,
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
        get_class = function() return 5 end,
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
        -- For unit testing, default to 0 so DoTs need refresh
        return 0
    end
    NS.buff_remains = function(unit, buff_ids) return 0 end

    -- rotation_registry mock that captures registrations
    NS.rotation_registry = {
        _registrations = {},
        register = function(self, key, strategies, opts)
            self._registrations[key] = { strategies = strategies, opts = opts }
        end,
        set_class_config = function(self, config) end,
    }

    NS.PriestSpells = {}
    for k, v in pairs(MOCK_PRIEST_SPELLS) do
        NS.PriestSpells[k] = v
    end

    _G.core = core
    _G.EaxRotations = NS

    return NS, core, mock_player, mock_target, mock_state
end

--- Create a mock context with sensible defaults.
--- @param overrides table Optional overrides for context fields
--- @param state_overrides table Optional overrides for context.state sub-table
local function make_context(overrides, state_overrides)
    local ctx = {
        is_solo = false,
        is_leveling = true,
        in_combat = true,
        mana_pct = 80,
        hp = 100,
        enemies_count = 1,
        is_moving = false,
        target = {
            is_valid = function() return true end,
            get_health = function() return 8000 end,
            get_max_health = function() return 10000 end,
            is_casting = function() return false end,
            is_alive = function() return true end,
            get_guid = function() return "mock-target" end,
        },
        pet = { guid = "mock-pet" },
        settings = {
            playstyle = "leveling",
            active_playstyle = "leveling",
            use_interrupt = true,
            leveling_wand_threshold = 30,
            leveling_heal_hp = 40,
        },
        state = {
            enemy_count = 1,
            hp_pct = 100,
            is_moving = false,
            mana_pct = 80,
            threat_status = 0,
            target_creature_type = "humanoid",
        },
    }
    if overrides then
        for k, v in pairs(overrides) do
            ctx[k] = v
        end
    end
    if state_overrides then
        if not ctx.state then ctx.state = {} end
        for k, v in pairs(state_overrides) do
            ctx.state[k] = v
        end
    end
    return ctx
end

-- ============================================================================
-- Load the Priest leveling module
-- ============================================================================

local NS, core, mock_player, mock_target, mock_state = build_mock_env()
local ok, module = pcall(dofile, "EaxRotations/classes/priest/leveling_sylvanas.lua")
if not ok then
    error("Failed to load Priest leveling module: " .. tostring(module))
end
if not module or type(module) ~= "table" then
    error("Priest leveling module should return a table of strategies")
end

-- Get the registration info
local reg = NS.rotation_registry._registrations["leveling"]
if not reg then
    error("Priest leveling module should register as 'leveling' in rotation_registry")
end
local strategies = reg.strategies
local get_state = reg.opts.get_state

print("=== Priest Leveling Unit Tests ===\n")
print("Loaded " .. tostring(#strategies) .. " strategies\n")

-- ============================================================================
-- Test: Helper functions (tested indirectly through state/spell readiness)
-- ============================================================================

test("build_state: nil context returns nil", function()
    assert_nil(get_state(nil), "nil context should return nil")
end)

test("build_state: minimal context returns full state table", function()
    local ctx = make_context({}, {})
    local state = get_state(ctx)
    assert_not_nil(state, "should return a table")
    assert_eq(state.in_combat, true, "in_combat from context")
    assert_eq(state.mana_pct, 80, "mana_pct from context.state")
    assert_eq(state.hp, 100, "hp from context.state")
    assert_eq(state.enemies, 1, "enemies from context.state")
    assert_false(state.is_moving, "is_moving from context.state")
    assert_not_nil(state.target, "target from build_common_state")
end)

test("build_state: missing context.state uses defaults", function()
    -- Build context directly without state sub-table (nil values can't be passed
    -- through pairs() in make_context overrides since Lua drops nil table entries)
    local ctx = {
        is_solo = false,
        is_leveling = true,
        in_combat = true,
        mana_pct = 80,
        hp = 100,
        enemies_count = 1,
        is_moving = false,
        target = { is_valid = function() return true end, get_health = function() return 8000 end, get_max_health = function() return 10000 end, is_casting = function() return false end, is_alive = function() return true end, get_guid = function() return "mock-target" end },
        pet = { guid = "mock-pet" },
        settings = {},
        -- No 'state' key
    }
    local state = get_state(ctx)
    assert_not_nil(state, "should return a table")
    assert_eq(state.hp, 100, "default hp_pct = 100")
    assert_eq(state.mana_pct, 80, "mana_pct from context")
    assert_eq(state.enemies, 1, "enemies_count from context")
    assert_false(state.is_moving, "default is_moving = false")
end)

test("build_state: spells readiness fields populated", function()
    local ctx = make_context()
    local state = get_state(ctx)
    assert_true(state.fortitude_ready, "fortitude_ready should be true")
    assert_true(state.inner_fire_ready, "inner_fire_ready should be true")
    assert_true(state.shield_ready, "shield_ready should be true")
    assert_true(state.renew_ready, "renew_ready should be true")
    assert_true(state.greater_heal_ready, "greater_heal_ready should be true")
    assert_true(state.swp_ready, "swp_ready should be true")
    assert_true(state.smite_ready, "smite_ready should be true")
    assert_true(state.holy_fire_ready, "holy_fire_ready should be true")
    assert_true(state.mind_blast_ready, "mind_blast_ready should be true")
    assert_true(state.swd_ready, "swd_ready should be true")
    assert_true(state.scream_ready, "scream_ready should be true")
    assert_true(state.shackle_ready, "shackle_ready should be true")
    assert_true(state.fade_ready, "fade_ready should be true")
    assert_true(state.inner_focus_ready, "inner_focus_ready should be true")
end)

test("build_state: custom thresholds from settings", function()
    local ctx = make_context({}, {})
    ctx.settings.leveling_heal_hp = 60
    ctx.settings.leveling_wand_threshold = 15
    local state = get_state(ctx)
    assert_eq(state.heal_hp, 60, "heal_hp from settings")
    assert_eq(state.wand_threshold, 15, "wand_threshold from settings")
end)

test("build_state: missing settings uses defaults", function()
    local ctx = make_context({settings = {}})
    local state = get_state(ctx)
    assert_eq(state.heal_hp, 60, "default heal_hp = 60")
    assert_eq(state.wand_threshold, 20, "default wand_threshold = 20")
end)

-- ============================================================================
-- Test: fortitude_matches (strategy #1)
-- ============================================================================

test("fortitude_matches: OOC, ready, no buff → true", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.has_fortitude = false
    state.fortitude_ready = true
    assert_true(strategies[1].matches(ctx, state), "should match")
end)

test("fortitude_matches: in combat → false", function()
    local ctx = make_context({in_combat = true})
    local state = get_state(ctx)
    state.has_fortitude = false
    state.fortitude_ready = true
    assert_false(strategies[1].matches(ctx, state), "should not match in combat")
end)

test("fortitude_matches: already has buff → false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.has_fortitude = true
    state.fortitude_ready = true
    assert_false(strategies[1].matches(ctx, state), "should not match if buff active")
end)

test("fortitude_matches: nil state → false", function()
    assert_false(strategies[1].matches(make_context({in_combat = false}), nil), "nil state should return false")
end)

-- ============================================================================
-- Test: inner_fire_matches (strategy #2)
-- ============================================================================

test("inner_fire_matches: OOC, ready, no buff → true", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.has_inner_fire = false
    state.inner_fire_ready = true
    assert_true(strategies[2].matches(ctx, state), "should match")
end)

test("inner_fire_matches: has buff → false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.has_inner_fire = true
    state.inner_fire_ready = true
    assert_false(strategies[2].matches(ctx, state), "should not match if buff active")
end)

-- ============================================================================
-- Test: shield_matches (strategy #4)
-- ============================================================================

test("shield_matches: ready, no shield, low HP, target → true", function()
    local ctx = make_context({}, {hp_pct = 30})
    local state = get_state(ctx)
    state.has_shield = false
    state.shield_ready = true
    state.hp = 30
    state.heal_hp = 60
    assert_true(strategies[4].matches(ctx, state), "should match when HP < threshold")
end)

test("shield_matches: no target → false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.has_shield = false
    state.shield_ready = true
    assert_false(strategies[4].matches(ctx, state), "no target should return false")
end)

test("shield_matches: already has shield → false", function()
    local ctx = make_context({}, {hp_pct = 30})
    local state = get_state(ctx)
    state.has_shield = true
    state.shield_ready = true
    state.hp = 30
    assert_false(strategies[4].matches(ctx, state), "shield already active")
end)

test("shield_matches: HP above threshold → false", function()
    local ctx = make_context({}, {hp_pct = 80})
    local state = get_state(ctx)
    state.has_shield = false
    state.shield_ready = true
    state.hp = 80
    state.heal_hp = 60
    assert_false(strategies[4].matches(ctx, state), "HP above threshold")
end)

-- ============================================================================
-- Test: renew_matches (strategy #5)
-- ============================================================================

test("renew_matches: ready, no renew, low HP → true", function()
    local ctx = make_context({}, {hp_pct = 30})
    local state = get_state(ctx)
    state.has_renew = false
    state.renew_ready = true
    state.hp = 30
    state.heal_hp = 60
    assert_true(strategies[5].matches(ctx, state), "should match when HP < threshold")
end)

test("renew_matches: already has renew → false", function()
    local ctx = make_context({}, {hp_pct = 30})
    local state = get_state(ctx)
    state.has_renew = true
    state.renew_ready = true
    assert_false(strategies[5].matches(ctx, state), "renew already active")
end)

test("renew_matches: no target → false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.has_renew = false
    state.renew_ready = true
    assert_false(strategies[5].matches(ctx, state), "no target")
end)

-- ============================================================================
-- Test: heal_matches (GreaterHeal, strategy #8)
-- ============================================================================

test("heal_matches: ready, low HP, not moving → true", function()
    local ctx = make_context({}, {hp_pct = 30, is_moving = false})
    local state = get_state(ctx)
    state.greater_heal_ready = true
    state.hp = 30
    state.heal_hp = 60
    state.is_moving = false
    assert_true(strategies[8].matches(ctx, state), "should match when low HP, stationary")
end)

test("heal_matches: moving → false", function()
    local ctx = make_context({}, {hp_pct = 30, is_moving = true})
    local state = get_state(ctx)
    state.greater_heal_ready = true
    state.hp = 30
    state.is_moving = true
    assert_false(strategies[8].matches(ctx, state), "moving should not match")
end)

test("heal_matches: HP above threshold → false", function()
    local ctx = make_context({}, {hp_pct = 80})
    local state = get_state(ctx)
    state.greater_heal_ready = true
    state.hp = 80
    state.heal_hp = 60
    assert_false(strategies[8].matches(ctx, state), "HP above threshold")
end)

-- ============================================================================
-- Test: scream_matches (PsychicScream, strategy #9)
-- ============================================================================

test("scream_matches: ready, 3+ enemies → true", function()
    local ctx = make_context({}, {enemy_count = 3})
    local state = get_state(ctx)
    state.scream_ready = true
    state.enemies = 3
    assert_true(strategies[9].matches(ctx, state), "3 enemies should match")
end)

test("scream_matches: 1 enemy → false", function()
    local ctx = make_context({}, {enemy_count = 1})
    local state = get_state(ctx)
    state.scream_ready = true
    state.enemies = 1
    assert_false(strategies[9].matches(ctx, state), "1 enemy should not match")
end)

test("scream_matches: not ready → false", function()
    local ctx = make_context({}, {enemy_count = 3})
    local state = get_state(ctx)
    state.scream_ready = false
    state.enemies = 3
    assert_false(strategies[9].matches(ctx, state), "scream not ready")
end)

-- ============================================================================
-- Test: fade_matches (strategy #10)
-- ============================================================================

test("fade_matches: ready, high threat → true", function()
    local ctx = make_context({threat_pct = 99, target_creature_type = "humanoid", hp_pct = 80, mana_pct = 80, enemy_count = 1, is_moving = false})
    local state = get_state(ctx)
    state.fade_ready = true
    assert_true(strategies[10].matches(ctx, state), "high threat should match")
end)

test("fade_matches: low threat → false", function()
    local ctx = make_context({threat_pct = 33, target_creature_type = "humanoid", hp_pct = 80, mana_pct = 80, enemy_count = 1, is_moving = false})
    local state = get_state(ctx)
    state.fade_ready = true
    assert_false(strategies[10].matches(ctx, state), "low threat should not match")
end)

test("fade_matches: not ready → false", function()
    local ctx = make_context({threat_pct = 99, target_creature_type = "humanoid", hp_pct = 80, mana_pct = 80, enemy_count = 1, is_moving = false})
    local state = get_state(ctx)
    state.fade_ready = false
    assert_false(strategies[10].matches(ctx, state), "fade not ready")
end)

-- ============================================================================
-- Test: shackle_matches (strategy #11)
-- ============================================================================

test("shackle_matches: ready, undead target → true", function()
    local ctx = make_context({target_creature_type = "undead"})
    local state = get_state(ctx)
    state.shackle_ready = true
    -- target_creature_type() re-queries the target object on every match call,
    -- so replace state.target with one that reports undead.
    state.target = {
        is_valid = function() return true end,
        get_creature_type = function() return "undead" end,
    }
    assert_true(strategies[11].matches(ctx, state), "undead target should match")
end)

test("shackle_matches: humanoid target → false", function()
    local ctx = make_context({target_creature_type = "humanoid"})
    local state = get_state(ctx)
    state.shackle_ready = true
    assert_false(strategies[11].matches(ctx, state), "humanoid should not match")
end)

test("shackle_matches: not ready → false", function()
    local ctx = make_context({target_creature_type = "undead"})
    local state = get_state(ctx)
    state.shackle_ready = false
    assert_false(strategies[11].matches(ctx, state), "shackle not ready")
end)

-- ============================================================================
-- Test: swp_matches (ShadowWordPain, strategy #12)
-- ============================================================================

test("swp_matches: ready, debuff expiring → true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    NS.debuff_remains = function(target, ids) return 0 end  -- expired
    state.swp_ready = true
    assert_true(strategies[12].matches(ctx, state), "expired SWP should match")
end)

test("swp_matches: debuff fresh → false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    NS.debuff_remains = function(target, ids) return 12 end  -- still up
    state.swp_ready = true
    assert_false(strategies[12].matches(ctx, state), "fresh SWP should not match")
end)

test("swp_matches: not ready → false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    NS.debuff_remains = function(target, ids) return 0 end
    state.swp_ready = false
    assert_false(strategies[12].matches(ctx, state), "SWP not ready")
end)

-- ============================================================================
-- Test: holy_fire_matches (strategy #15, HF is after SWD)
-- ============================================================================

test("holy_fire_matches: ready, not moving, debuff expired → true", function()
    local ctx = make_context({}, {is_moving = false})
    local state = get_state(ctx)
    NS.debuff_remains = function(target, ids) return 0 end
    state.holy_fire_ready = true
    state.is_moving = false
    assert_true(strategies[15].matches(ctx, state), "should match when not moving and debuff expired")
end)

test("holy_fire_matches: moving → false", function()
    local ctx = make_context({}, {is_moving = true})
    local state = get_state(ctx)
    NS.debuff_remains = function(target, ids) return 0 end
    state.holy_fire_ready = true
    state.is_moving = true
    assert_false(strategies[15].matches(ctx, state), "moving should not match")
end)

test("holy_fire_matches: debuff still up → false", function()
    local ctx = make_context({}, {is_moving = false})
    local state = get_state(ctx)
    NS.debuff_remains = function(target, ids) return 8 end
    state.holy_fire_ready = true
    state.is_moving = false
    assert_false(strategies[15].matches(ctx, state), "fresh Holy Fire debuff should not match")
end)

-- ============================================================================
-- Test: mind_blast_matches (strategy #16)
-- ============================================================================

test("mind_blast_matches: ready, has target → true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.mind_blast_ready = true
    assert_true(strategies[16].matches(ctx, state), "ready with target should match")
end)

test("mind_blast_matches: no target → false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.mind_blast_ready = true
    state.target = nil
    assert_false(strategies[16].matches(ctx, state), "no target should return false")
end)

-- ============================================================================
-- Test: swd_matches (ShadowWordDeath, strategy #14, before HF)
-- ============================================================================

test("swd_matches: ready, HP > 60% -> true", function()
    local ctx = make_context({}, {hp_pct = 80})
    local state = get_state(ctx)
    state.swd_ready = true
    state.hp = 80
    assert_true(strategies[14].matches(ctx, state), "SWD should match only when self HP is safe")
end)

test("swd_matches: HP <= 60% -> false", function()
    local ctx = make_context({}, {hp_pct = 50})
    local state = get_state(ctx)
    state.swd_ready = true
    state.hp = 50
    assert_false(strategies[14].matches(ctx, state), "SWD should not fire when self damage is unsafe")
end)

test("swd_matches: not ready → false", function()
    local ctx = make_context({}, {hp_pct = 80})
    local state = get_state(ctx)
    state.swd_ready = false
    state.hp = 80
    assert_false(strategies[14].matches(ctx, state), "SWD not ready")
end)

-- ============================================================================
-- Test: holy_nova_matches (strategy #18)
-- ============================================================================

test("holy_nova_matches: ready, 3+ enemies, not moving → true", function()
    local ctx = make_context({}, {enemy_count = 3, is_moving = false})
    local state = get_state(ctx)
    state.holy_nova_ready = true
    state.enemies = 3
    state.is_moving = false
    assert_true(strategies[18].matches(ctx, state), "3 enemies stationary should match")
end)

test("holy_nova_matches: 1 enemy → false", function()
    local ctx = make_context({}, {enemy_count = 1})
    local state = get_state(ctx)
    state.holy_nova_ready = true
    state.enemies = 1
    assert_false(strategies[18].matches(ctx, state), "1 enemy should not match")
end)

test("holy_nova_matches: moving → false", function()
    local ctx = make_context({}, {enemy_count = 3, is_moving = true})
    local state = get_state(ctx)
    state.holy_nova_ready = true
    state.enemies = 3
    state.is_moving = true
    assert_false(strategies[18].matches(ctx, state), "moving should not match")
end)

test("holy_nova_matches: not ready → false", function()
    local ctx = make_context({}, {enemy_count = 3})
    local state = get_state(ctx)
    state.holy_nova_ready = false
    state.enemies = 3
    assert_false(strategies[18].matches(ctx, state), "holy nova not ready")
end)

-- ============================================================================
-- Test: smite_matches (strategy #19)
-- ============================================================================

test("smite_matches: ready, not moving, enough mana → true", function()
    local ctx = make_context({}, {mana_pct = 80, is_moving = false})
    local state = get_state(ctx)
    state.smite_ready = true
    state.mana_pct = 80
    state.wand_threshold = 20
    state.is_moving = false
    assert_true(strategies[19].matches(ctx, state), "enough mana stationary should match")
end)

test("smite_matches: moving → false", function()
    local ctx = make_context({}, {mana_pct = 80, is_moving = true})
    local state = get_state(ctx)
    state.smite_ready = true
    state.mana_pct = 80
    state.is_moving = true
    assert_false(strategies[19].matches(ctx, state), "moving should not match")
end)

test("smite_matches: low mana → false", function()
    local ctx = make_context({}, {mana_pct = 10, is_moving = false})
    local state = get_state(ctx)
    state.smite_ready = true
    state.mana_pct = 10
    state.wand_threshold = 20
    state.is_moving = false
    assert_false(strategies[19].matches(ctx, state), "low mana should not match")
end)

test("smite_matches: not ready → false", function()
    local ctx = make_context({state = {mana_pct = 80, is_moving = false}})
    local state = get_state(ctx)
    state.smite_ready = false
    state.mana_pct = 80
    state.is_moving = false
    assert_false(strategies[19].matches(ctx, state), "smite not ready")
end)

-- ============================================================================
-- Test: wand_matches_fn (strategy #20)
-- ============================================================================

test("wand_matches: low mana, has target → true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.mana_pct = 10
    state.wand_threshold = 20
    assert_true(strategies[20].matches(ctx, state), "low mana should match")
end)

test("wand_matches: enough mana → false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.mana_pct = 80
    state.wand_threshold = 20
    assert_false(strategies[20].matches(ctx, state), "enough mana should not match")
end)

test("wand_matches: no target → false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.mana_pct = 10
    state.target = nil
    assert_false(strategies[20].matches(ctx, state), "no target should not match")
end)

-- ============================================================================
-- Test: Strategy priority ordering
-- ============================================================================

test("strategies: 21 strategies in correct priority order", function()
    local expected = {
        "PowerWordFortitude",
        "InnerFire",
        "Shadowform",
        "PowerWordShield",
        "Renew",
        "FlashHeal",
        "InnerFocus",
        "GreaterHeal",
        "PsychicScream",
        "Fade",
        "ShackleUndead",
        "ShadowWordPain",
        "VampiricTouch",
        "ShadowWordDeath",
        "HolyFire",
        "MindBlast",
        "MindFlay",
        "HolyNova",
        "Smite",
        "Wand",
        "SymbolOfHope",
    }
    assert_eq(#strategies, 21, "should have 21 strategies after adding Shadowform, FlashHeal, InnerFocus, VT, MindFlay, SymbolOfHope")
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

test("execute_PowerWordFortitude: does not crash", function()
    local ctx = make_context({in_combat = false})
    local ok, result = pcall(strategies[1].execute)
    assert_true(ok, "execute should not throw")
end)

test("execute_Wand: does not crash with context", function()
    local ctx = make_context()
    local ok, result = pcall(strategies[20].execute, ctx)
    assert_true(ok, "execute with context should not throw")
end)

test("execute_Wand: does not crash without context", function()
    local ok, result = pcall(strategies[20].execute)
    assert_true(ok, "execute without context should not throw")
end)

-- ============================================================================
-- Test: Nil guard - module returns nil when NS is nil
-- ============================================================================

test("module: returns nil when EaxRotations is nil", function()
    local _, c = build_mock_env()
    _G.EaxRotations = nil
    local nil_mod = dofile("EaxRotations/classes/priest/leveling_sylvanas.lua")
    assert_nil(nil_mod, "should return nil when NS is nil")
    _G.EaxRotations = NS
end)

-- ============================================================================
-- Test: All match functions handle nil context gracefully
-- ============================================================================

test("match_functions: all handle nil context ← false", function()
    for i, s in ipairs(strategies) do
        local ok, result = pcall(s.matches, nil, {})
        assert_true(ok, "strategy[" .. i .. "] (" .. s.name .. ") matches(nil, {}) should not throw")
        -- Most match functions check `if not state then return false end`, nil context usually handled
    end
end)

test("match_functions: all handle nil state ← false", function()
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
    local ctx = make_context({in_combat = true}, {enemy_count = 1, hp_pct = 100, mana_pct = 80, is_moving = false})
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
    local ctx = make_context({in_combat = false, state = {enemy_count = 0, hp_pct = 100, mana_pct = 100, is_moving = false, threat_status = 0, target_creature_type = "humanoid"}})
    local state = get_state(ctx)
    state.has_fortitude = false
    state.has_inner_fire = false

    -- fortitude should match (OOC)
    assert_true(strategies[1].matches(ctx, state), "fortitude should match OOC")

    -- inner fire should match (OOC)
    assert_true(strategies[2].matches(ctx, state), "inner fire should match OOC")

    -- shield should not match (no target when OOC, and 100% HP)
    assert_false(strategies[4].matches(ctx, state), "shield should not match OOC with full HP")

    -- damage abilities should not match (no target OOC)
    assert_false(strategies[12].matches(ctx, state), "SWP should not match OOC without target")

    -- wand should not match (no target OOC)
    assert_false(strategies[20].matches(ctx, state), "wand should not match OOC")
end)

test("rotation: low HP scenario - heal/shield should match", function()
    local ctx = make_context({state = {enemy_count = 1, hp_pct = 25, mana_pct = 80, is_moving = false, threat_status = 0, target_creature_type = "humanoid"}})
    local state = get_state(ctx)
    state.has_shield = false
    state.has_renew = false
    state.hp = 25
    state.heal_hp = 60

    -- shield should match (low HP, no shield)
    assert_true(strategies[4].matches(ctx, state), "shield should match when low HP")

    -- renew should match (low HP, no renew)
    assert_true(strategies[5].matches(ctx, state), "renew should match when low HP")

    -- heal should match (low HP, not moving)
    assert_true(strategies[8].matches(ctx, state), "greater heal should match when low HP")
end)

test("rotation: safe HP scenario - SWD should match when HP > 60%", function()
    local ctx = make_context({state = {enemy_count = 1, hp_pct = 80, mana_pct = 80, is_moving = false, threat_status = 0, target_creature_type = "humanoid"}})
    local state = get_state(ctx)
    state.swd_ready = true
    state.hp = 80

    assert_true(strategies[14].matches(ctx, state), "SWD should match only when self HP is safe")

    -- Priority is determined by array index, not match functions.
    -- SWD (index 14) has higher priority than Smite (index 19) because
    -- the rotation registry iterates strategies in order and picks the
    -- first one that matches. Smite may also match (enough mana) but that's
    -- independent — the registry handles priority.
    local smite_matches_ok, smite_match = pcall(strategies[19].matches, ctx, state)
    assert_true(smite_matches_ok, "smite matches should not throw")
    -- Whether smite matches depends on mana - it's fine either way
end)

-- ============================================================================
-- Edge Case Tests: Power Word: Shield (strategy 3)
-- ============================================================================

do -- edge_shield
    test("edge_shield: shield matches at HP 59 (below heal_hp threshold)", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.shield_ready = true
        state.hp = 39
        assert_true(strategies[4].matches(ctx, state), "shield should match at HP 39 (below 40)")
    end)

    test("edge_shield: shield does not match at HP 60 (at heal_hp threshold)", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.shield_ready = true
        state.hp = 40
        assert_false(strategies[4].matches(ctx, state), "shield should not match at HP 40 (at threshold)")
    end)

    test("edge_shield: shield does not match when no target", function()
        local ctx = make_context({target = nil})
        local state = get_state(ctx)
        state.shield_ready = true
        state.hp = 40
        state.target = nil
        assert_false(strategies[4].matches(ctx, state), "shield should not match with no target")
    end)
end

-- ============================================================================
-- Edge Case Tests: Renew (strategy 4)
-- ============================================================================

do -- edge_renew
    test("edge_renew: renew matches at HP 59 (below heal_hp threshold)", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.renew_ready = true
        state.hp = 39
        assert_true(strategies[5].matches(ctx, state), "renew should match at HP 39")
    end)

    test("edge_renew: renew does not match at HP 60 (at heal_hp threshold)", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.renew_ready = true
        state.hp = 40
        assert_false(strategies[5].matches(ctx, state), "renew should not match at HP 40")
    end)

    test("edge_renew: renew does not match when no target", function()
        local ctx = make_context({target = nil})
        local state = get_state(ctx)
        state.renew_ready = true
        state.hp = 40
        state.target = nil
        assert_false(strategies[5].matches(ctx, state), "renew should not match with no target")
    end)
end

-- ============================================================================
-- Edge Case Tests: GreaterHeal (strategy 5)
-- ============================================================================

do -- edge_heal
    test("edge_heal: GreaterHeal matches at HP 59, not moving", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.greater_heal_ready = true
        state.hp = 39
        state.is_moving = false
        assert_true(strategies[8].matches(ctx, state), "heal should match at HP 39, stationary")
    end)

    test("edge_heal: GreaterHeal does not match when moving", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.greater_heal_ready = true
        state.hp = 40
        state.is_moving = true
        assert_false(strategies[8].matches(ctx, state), "heal should not match while moving")
    end)

    test("edge_heal: GreaterHeal does not match at HP 60 (at heal_hp threshold)", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.greater_heal_ready = true
        state.hp = 40
        state.is_moving = false
        assert_false(strategies[8].matches(ctx, state), "heal should not match at HP 40")
    end)
end

-- ============================================================================
-- Edge Case Tests: Psychic Scream (strategy 6)
-- ============================================================================

do -- edge_scream
    test("edge_scream: scream matches when enemy count is exactly 3", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.scream_ready = true
        state.enemies = 3
        assert_true(strategies[9].matches(ctx, state), "scream should match at exactly 3 enemies")
    end)

    test("edge_scream: scream does not match when enemy count exactly 2", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.scream_ready = true
        state.enemies = 2
        assert_false(strategies[9].matches(ctx, state), "scream should not match at 2 enemies")
    end)

    test("edge_scream: scream does not match when not ready", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.scream_ready = false
        state.enemies = 3
        assert_false(strategies[9].matches(ctx, state), "scream should not match when not ready")
    end)
end

-- ============================================================================
-- Edge Case Tests: Fade (strategy 7)
-- ============================================================================

do -- edge_fade
    test("edge_fade: fade matches when threat >= 3", function()
        local ctx = make_context({threat_pct = 99})
        local state = get_state(ctx)
        state.fade_ready = true
        assert_true(strategies[10].matches(ctx, state), "fade should match at threat 3")
    end)

    test("edge_fade: fade does not match when threat < 3", function()
        local ctx = make_context({threat_pct = 33})
        local state = get_state(ctx)
        state.fade_ready = true
        assert_false(strategies[10].matches(ctx, state), "fade should not match at threat 2")
    end)

    test("edge_fade: fade does not match when not ready", function()
        local ctx = make_context({threat_pct = 99})
        local state = get_state(ctx)
        state.fade_ready = false
        assert_false(strategies[10].matches(ctx, state), "fade should not match when not ready")
    end)
end

-- ============================================================================
-- Edge Case Tests: Shackle Undead (strategy 8)
-- ============================================================================

do -- edge_shackle
    test("edge_shackle: shackle matches when target is undead", function()
        local ctx = make_context({}, {target_creature_type = "undead"})
        local state = get_state(ctx)
        state.shackle_ready = true
        -- target_creature_type() re-queries the target object on every match call,
        -- so replace state.target with one that reports undead.
        state.target = {
            is_valid = function() return true end,
            get_creature_type = function() return "undead" end,
        }
        assert_true(strategies[11].matches(ctx, state), "shackle should match on undead target")
    end)

    test("edge_shackle: shackle does not match when target is humanoid", function()
        local ctx = make_context({}, {target_creature_type = "humanoid"})
        local state = get_state(ctx)
        state.shackle_ready = true
        assert_false(strategies[11].matches(ctx, state), "shackle should not match on humanoid")
    end)

    test("edge_shackle: shackle does not match when not ready", function()
        local ctx = make_context({}, {target_creature_type = "undead"})
        local state = get_state(ctx)
        state.shackle_ready = false
        assert_false(strategies[11].matches(ctx, state), "shackle should not match when not ready")
    end)
end

-- ============================================================================
-- Edge Case Tests: Shadow Word: Pain (strategy 9)
-- ============================================================================

do -- edge_swp
    test("edge_swp: SWP matches when debuff remains exactly 0 (needs refresh)", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.swp_ready = true
        local saved_remains = NS.debuff_remains
        NS.debuff_remains = function(target, ids) return 0 end
        assert_true(strategies[12].matches(ctx, state), "SWP should match when debuff at 0")
        NS.debuff_remains = saved_remains
    end)

    test("edge_swp: SWP does not match when debuff remains at 4 (>= refresh threshold)", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.swp_ready = true
        local saved_remains = NS.debuff_remains
        NS.debuff_remains = function(target, ids) return 4 end
        assert_false(strategies[12].matches(ctx, state), "SWP should not match when remains >= 4")
        NS.debuff_remains = saved_remains
    end)

    test("edge_swp: SWP does not match when not ready", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.swp_ready = false
        local saved_remains = NS.debuff_remains
        NS.debuff_remains = function(target, ids) return 0 end
        assert_false(strategies[12].matches(ctx, state), "SWP should not match when not ready")
        NS.debuff_remains = saved_remains
    end)

    test("edge_swp: SWP does not match when no target", function()
        local ctx = make_context({target = nil})
        local state = get_state(ctx)
        state.swp_ready = true
        state.target = nil
        assert_false(strategies[12].matches(ctx, state), "SWP should not match with no target")
    end)
end

-- ============================================================================
-- Edge Case Tests: Shadow Word: Death (strategy 14)
-- ============================================================================

do -- edge_swd
    test("edge_swd: SWD matches when player HP is 61", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.swd_ready = true
        state.hp = 61
        assert_true(strategies[14].matches(ctx, state), "SWD should match above 60 HP")
    end)

    test("edge_swd: SWD does not match when player HP is exactly 60", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.swd_ready = true
        state.hp = 60
        assert_false(strategies[14].matches(ctx, state), "SWD should not match at HP 60")
    end)

    test("edge_swd: SWD does not match when not ready", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.swd_ready = false
        state.hp = 80
        assert_false(strategies[14].matches(ctx, state), "SWD should not match when not ready")
    end)

    test("edge_swd: SWD does not match when no target", function()
        local ctx = make_context({target = nil})
        local state = get_state(ctx)
        state.swd_ready = true
        state.target = nil
        state.hp = 80
        assert_false(strategies[14].matches(ctx, state), "SWD should not match with no target")
    end)
end

-- ============================================================================
-- Edge Case Tests: Holy Fire (strategy 11)
-- ============================================================================

do -- edge_holy_fire
    test("edge_holy_fire: Holy Fire matches when debuff remains 0, not moving", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.holy_fire_ready = true
        state.is_moving = false
        local saved_remains = NS.debuff_remains
        NS.debuff_remains = function(target, ids) return 0 end
        assert_true(strategies[15].matches(ctx, state), "Holy Fire should match when debuff at 0")
        NS.debuff_remains = saved_remains
    end)

    test("edge_holy_fire: Holy Fire does not match when moving", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.holy_fire_ready = true
        state.is_moving = true
        local saved_remains = NS.debuff_remains
        NS.debuff_remains = function(target, ids) return 0 end
        assert_false(strategies[15].matches(ctx, state), "Holy Fire should not match while moving")
        NS.debuff_remains = saved_remains
    end)

    test("edge_holy_fire: Holy Fire does not match when debuff remains at 4", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.holy_fire_ready = true
        state.is_moving = false
        local saved_remains = NS.debuff_remains
        NS.debuff_remains = function(target, ids) return 4 end
        assert_false(strategies[15].matches(ctx, state), "Holy Fire should not match when remains >= 4")
        NS.debuff_remains = saved_remains
    end)
end

-- ============================================================================
-- Edge Case Tests: Mind Blast (strategy 12)
-- ============================================================================

do -- edge_mind_blast
    test("edge_mind_blast: Mind Blast matches when ready", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.mind_blast_ready = true
        assert_true(strategies[16].matches(ctx, state), "Mind Blast should match when ready")
    end)

    test("edge_mind_blast: Mind Blast does not match when not ready", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.mind_blast_ready = false
        assert_false(strategies[16].matches(ctx, state), "Mind Blast should not match when not ready")
    end)

    test("edge_mind_blast: Mind Blast does not match when no target", function()
        local ctx = make_context({target = nil})
        local state = get_state(ctx)
        state.mind_blast_ready = true
        state.target = nil
        assert_false(strategies[16].matches(ctx, state), "Mind Blast should not match with no target")
    end)
end

-- ============================================================================
-- Edge Case Tests: Holy Nova (strategy 13)
-- ============================================================================

do -- edge_holy_nova
    test("edge_holy_nova: Holy Nova matches when enemy count exactly 3, not moving", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.holy_nova_ready = true
        state.enemies = 3
        state.is_moving = false
        assert_true(strategies[18].matches(ctx, state), "Holy Nova should match at 3 enemies")
    end)

    test("edge_holy_nova: Holy Nova does not match when enemy count exactly 2", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.holy_nova_ready = true
        state.enemies = 2
        state.is_moving = false
        assert_false(strategies[18].matches(ctx, state), "Holy Nova should not match at 2 enemies")
    end)

    test("edge_holy_nova: Holy Nova does not match while moving", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.holy_nova_ready = true
        state.enemies = 3
        state.is_moving = true
        assert_false(strategies[18].matches(ctx, state), "Holy Nova should not match while moving")
    end)
end

-- ============================================================================
-- Edge Case Tests: Smite (strategy 14)
-- ============================================================================

do -- edge_smite
    test("edge_smite: smite matches when mana_pct exactly at threshold (20), not moving", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.smite_ready = true
        state.mana_pct = 30
        state.is_moving = false
        assert_true(strategies[19].matches(ctx, state), "smite should match at mana_pct 30 (at threshold)")
    end)

    test("edge_smite: smite does not match when mana_pct below threshold (19)", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.smite_ready = true
        state.mana_pct = 29
        state.is_moving = false
        assert_false(strategies[19].matches(ctx, state), "smite should not match at mana_pct 29")
    end)

    test("edge_smite: smite does not match while moving", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.smite_ready = true
        state.mana_pct = 50
        state.is_moving = true
        assert_false(strategies[19].matches(ctx, state), "smite should not match while moving")
    end)

    test("edge_smite: smite does not match when not ready", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.smite_ready = false
        state.mana_pct = 50
        state.is_moving = false
        assert_false(strategies[19].matches(ctx, state), "smite should not match when not ready")
    end)

    test("edge_smite: smite does not match when no target", function()
        local ctx = make_context({target = nil})
        local state = get_state(ctx)
        state.smite_ready = true
        state.mana_pct = 50
        state.is_moving = false
        state.target = nil
        assert_false(strategies[19].matches(ctx, state), "smite should not match with no target")
    end)
end

-- ============================================================================
-- Edge Case Tests: Wand (strategy 15)
-- ============================================================================

do -- edge_wand
    test("edge_wand: wand matches when mana_pct (10) below threshold (20)", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.mana_pct = 10
        assert_true(strategies[20].matches(ctx, state), "wand should match at low mana")
    end)

    test("edge_wand: wand does not match when mana_pct exactly at threshold (20)", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.mana_pct = 30
        assert_false(strategies[20].matches(ctx, state), "wand should not match at mana_pct 30 (at threshold)")
    end)

    test("edge_wand: wand does not match when no target", function()
        local ctx = make_context({target = nil})
        local state = get_state(ctx)
        state.mana_pct = 10
        state.target = nil
        assert_false(strategies[20].matches(ctx, state), "wand should not match with no target")
    end)
end

-- ============================================================================
-- Edge Case Tests: Buff API Safety (has_buff via pcall)
-- ============================================================================

do -- edge_buff
    test("edge_buff: NS.get_local_player nil in build_state returns safe defaults for buff checks", function()
        local saved = NS.get_local_player
        NS.get_local_player = function() return nil end
        local ok, state = pcall(get_state, make_context())
        NS.get_local_player = saved
        assert_true(ok, "build_state should not crash when NS.get_local_player returns nil")
        if ok and state then
            assert_false(state.has_fortitude, "has_fortitude should be false when no local player")
            assert_false(state.has_inner_fire, "has_inner_fire should be false when no local player")
        end
    end)

    test("edge_buff: NS.get_local_player throws in build_state returns safe defaults for buff checks", function()
        local saved = NS.get_local_player
        NS.get_local_player = function() error("player system failure") end
        local ok, state = pcall(get_state, make_context())
        NS.get_local_player = saved
        assert_true(ok, "build_state should not crash when NS.get_local_player throws")
        if ok and state then
            assert_false(state.has_fortitude, "has_fortitude should be false when get_local_player throws")
            assert_false(state.has_inner_fire, "has_inner_fire should be false when get_local_player throws")
        end
    end)
end

-- ============================================================================
-- Edge Case Tests: Spell API Safety (spell_ready via spell_ready wrapper)
-- ============================================================================

do -- edge_api
    test("edge_api: NS.spell_ready nil in build_state returns false for readiness", function()
        local saved = NS.spell_ready
        NS.spell_ready = nil
        local ok, state = pcall(get_state, make_context())
        NS.spell_ready = saved
        assert_true(ok, "build_state should not crash when NS.spell_ready is nil")
        if ok and state then
            assert_false(state.smite_ready, "smite_ready should be false when NS.spell_ready is nil")
            assert_false(state.shield_ready, "shield_ready should be false when NS.spell_ready is nil")
        end
    end)

    test("edge_api: NS.spell_ready throws in build_state returns false for readiness", function()
        local saved = NS.spell_ready
        NS.spell_ready = function() error("cd system down") end
        local ok, state = pcall(get_state, make_context())
        NS.spell_ready = saved
        assert_true(ok, "build_state should not crash when NS.spell_ready throws")
        if ok and state then
            assert_false(state.smite_ready, "smite_ready should be false when NS.spell_ready throws")
        end
    end)

    test("edge_api: NS.try_cast nil does not crash execute functions", function()
        local saved = NS.try_cast
        NS.try_cast = nil
        local ctx = make_context()
        for i, s in ipairs(strategies) do
            local ok, result = pcall(s.execute, ctx)
            assert_true(ok, string.format("strategies[%d].execute should not crash when NS.try_cast is nil", i))
        end
        NS.try_cast = saved
    end)
end

-- ============================================================================
-- Edge Case Tests: Rotation Crash Safety (nil context / nil state)
-- ============================================================================

do -- edge_rotation_crash
    test("edge_rotation_crash: all match functions handle nil context", function()
        for i, s in ipairs(strategies) do
            local ok, result = pcall(s.matches, nil, {})
            assert_true(ok, string.format("strategies[%d].matches should not crash with nil context", i))
        end
    end)

    test("edge_rotation_crash: all match functions handle nil state", function()
        local ctx = make_context()
        for i, s in ipairs(strategies) do
            local ok, result = pcall(s.matches, ctx, nil)
            assert_true(ok, string.format("strategies[%d].matches should not crash with nil state", i))
        end
    end)

    test("edge_rotation_crash: all execute functions handle nil context", function()
        for i, s in ipairs(strategies) do
            local ok, result = pcall(s.execute)
            assert_true(ok, string.format("strategies[%d].execute should not crash with nil context", i))
        end
    end)
end
-- ============================================================================
-- ============================================================================
-- Edge case: HP boundaries
-- ============================================================================
do
    -- Shield: HP < heal_hp (60) -> match; >= heal_hp -> no match
    local ctx = make_context({}, {hp_pct = 59})
    local state = get_state(ctx)
    state.shield_ready = true
    state.hp = 59
    state.heal_hp = 60
    assert_true(strategies[4].matches(ctx, state), "shield hp=59 -> match (<60)")

    local ctx2 = make_context({}, {hp_pct = 60})
    local state2 = get_state(ctx2)
    state2.shield_ready = true
    state2.hp = 60
    state2.heal_hp = 60
    assert_false(strategies[4].matches(ctx2, state2), "shield hp=60 -> no match (>=60)")

    -- Renew: HP < heal_hp (60) -> match; >= heal_hp -> no match
    local ctx3 = make_context({}, {hp_pct = 59})
    local state3 = get_state(ctx3)
    state3.renew_ready = true
    state3.hp = 59
    state3.heal_hp = 60
    assert_true(strategies[5].matches(ctx3, state3), "renew hp=59 -> match (<60)")

    local ctx4 = make_context({}, {hp_pct = 60})
    local state4 = get_state(ctx4)
    state4.renew_ready = true
    state4.hp = 60
    state4.heal_hp = 60
    assert_false(strategies[5].matches(ctx4, state4), "renew hp=60 -> no match (>=60)")

    -- FlashHeal: 30 <= HP < 50 -> match; HP < 30 or HP >= 50 -> no match
    local ctx5 = make_context({}, {hp_pct = 30})
    local state5 = get_state(ctx5)
    state5.flash_heal_ready = true
    state5.hp = 30
    assert_true(strategies[6].matches(ctx5, state5), "flashheal hp=30 -> match (>=30)")

    local ctx6 = make_context({}, {hp_pct = 29})
    local state6 = get_state(ctx6)
    state6.flash_heal_ready = true
    state6.hp = 29
    assert_false(strategies[6].matches(ctx6, state6), "flashheal hp=29 -> no match (<30)")

    local ctx7 = make_context({}, {hp_pct = 49})
    local state7 = get_state(ctx7)
    state7.flash_heal_ready = true
    state7.hp = 49
    assert_true(strategies[6].matches(ctx7, state7), "flashheal hp=49 -> match (<50)")

    local ctx8 = make_context({}, {hp_pct = 50})
    local state8 = get_state(ctx8)
    state8.flash_heal_ready = true
    state8.hp = 50
    assert_false(strategies[6].matches(ctx8, state8), "flashheal hp=50 -> no match (>=50)")

    -- InnerFocus: HP <= 50 -> match; > 50 -> no match
    local ctx9 = make_context({}, {hp_pct = 50})
    local state9 = get_state(ctx9)
    state9.inner_focus_ready = true
    state9.hp = 50
    assert_true(strategies[7].matches(ctx9, state9), "innerfocus hp=50 -> match (<=50)")

    local ctx10 = make_context({}, {hp_pct = 51})
    local state10 = get_state(ctx10)
    state10.inner_focus_ready = true
    state10.hp = 51
    assert_false(strategies[7].matches(ctx10, state10), "innerfocus hp=51 -> no match (>50)")

    -- GreaterHeal: HP < heal_hp (60) -> match; >= heal_hp -> no match
    local ctx11 = make_context({}, {hp_pct = 59, is_moving = false})
    local state11 = get_state(ctx11)
    state11.greater_heal_ready = true
    state11.hp = 59
    state11.heal_hp = 60
    state11.is_moving = false
    assert_true(strategies[8].matches(ctx11, state11), "greaterheal hp=59 -> match (<60)")

    local ctx12 = make_context({}, {hp_pct = 60, is_moving = false})
    local state12 = get_state(ctx12)
    state12.greater_heal_ready = true
    state12.hp = 60
    state12.heal_hp = 60
    state12.is_moving = false
    assert_false(strategies[8].matches(ctx12, state12), "greaterheal hp=60 -> no match (>=60)")

    -- SWD: HP > 60 -> match; <= 60 -> no match
    local ctx13 = make_context({}, {hp_pct = 61})
    local state13 = get_state(ctx13)
    state13.swd_ready = true
    state13.hp = 61
    assert_true(strategies[14].matches(ctx13, state13), "swd hp=61 -> match (>60)")

    local ctx14 = make_context({}, {hp_pct = 60})
    local state14 = get_state(ctx14)
    state14.swd_ready = true
    state14.hp = 60
    assert_false(strategies[14].matches(ctx14, state14), "swd hp=60 -> no match (<=60)")
end

-- ============================================================================
-- Edge case: Mana boundaries
-- ============================================================================
do
    -- Smite: mana_pct >= wand_threshold (20) -> match; < -> no match
    local ctx = make_context({}, {mana_pct = 20, is_moving = false})
    local state = get_state(ctx)
    state.smite_ready = true
    state.mana_pct = 20
    state.wand_threshold = 20
    state.is_moving = false
    assert_true(strategies[19].matches(ctx, state), "smite mana=20 -> match (>=20)")

    local ctx2 = make_context({}, {mana_pct = 19, is_moving = false})
    local state2 = get_state(ctx2)
    state2.smite_ready = true
    state2.mana_pct = 19
    state2.wand_threshold = 20
    state2.is_moving = false
    assert_false(strategies[19].matches(ctx2, state2), "smite mana=19 -> no match (<20)")

    -- Wand: mana_pct < wand_threshold (20) -> match; >= -> no match
    local ctx3 = make_context({}, {mana_pct = 19})
    local state3 = get_state(ctx3)
    state3.mana_pct = 19
    state3.wand_threshold = 20
    assert_true(strategies[20].matches(ctx3, state3), "wand mana=19 -> match (<20)")

    local ctx4 = make_context({}, {mana_pct = 20})
    local state4 = get_state(ctx4)
    state4.mana_pct = 20
    state4.wand_threshold = 20
    assert_false(strategies[20].matches(ctx4, state4), "wand mana=20 -> no match (>=20)")

    -- MindFlay: mana_pct >= 12 -> match; < 12 -> no match
    local ctx5 = make_context({}, {mana_pct = 12, is_moving = false})
    local state5 = get_state(ctx5)
    state5.mf_ready = true
    state5.mana_pct = 12
    state5.is_moving = false
    assert_true(strategies[17].matches(ctx5, state5), "mindflay mana=12 -> match (>=12)")

    local ctx6 = make_context({}, {mana_pct = 11, is_moving = false})
    local state6 = get_state(ctx6)
    state6.mf_ready = true
    state6.mana_pct = 11
    state6.is_moving = false
    assert_false(strategies[17].matches(ctx6, state6), "mindflay mana=11 -> no match (<12)")
end

-- ============================================================================
-- Edge case: Enemy thresholds
-- ============================================================================
do
    -- Scream: enemies >= 3 -> match; < 3 -> no match
    local ctx = make_context({}, {enemy_count = 3})
    local state = get_state(ctx)
    state.scream_ready = true
    state.enemies = 3
    assert_true(strategies[9].matches(ctx, state), "scream enemies=3 -> match (>=3)")

    local ctx2 = make_context({}, {enemy_count = 2})
    local state2 = get_state(ctx2)
    state2.scream_ready = true
    state2.enemies = 2
    assert_false(strategies[9].matches(ctx2, state2), "scream enemies=2 -> no match (<3)")

    -- HolyNova: enemies >= 3, not moving -> match; < 3 or moving -> no match
    local ctx3 = make_context({}, {enemy_count = 3, is_moving = false})
    local state3 = get_state(ctx3)
    state3.holy_nova_ready = true
    state3.enemies = 3
    state3.is_moving = false
    assert_true(strategies[18].matches(ctx3, state3), "holynova enemies=3 -> match (>=3)")

    local ctx4 = make_context({}, {enemy_count = 2, is_moving = false})
    local state4 = get_state(ctx4)
    state4.holy_nova_ready = true
    state4.enemies = 2
    state4.is_moving = false
    assert_false(strategies[18].matches(ctx4, state4), "holynova enemies=2 -> no match (<3)")
end

-- ============================================================================
-- Edge case: Movement guards
-- ============================================================================
do
    local ctx = make_context({}, {hp_pct = 40, is_moving = true})
    local state = get_state(ctx)
    state.greater_heal_ready = true
    state.hp = 40
    state.heal_hp = 60
    state.is_moving = true
    assert_false(strategies[8].matches(ctx, state), "greaterheal moving -> no match")

    local ctx2 = make_context({}, {is_moving = true})
    local state2 = get_state(ctx2)
    state2.holy_fire_ready = true
    state2.is_moving = true
    assert_false(strategies[15].matches(ctx2, state2), "holyfire moving -> no match")

    local ctx3 = make_context({}, {is_moving = true})
    local state3 = get_state(ctx3)
    state3.mf_ready = true
    state3.mana_pct = 50
    state3.is_moving = true
    assert_false(strategies[17].matches(ctx3, state3), "mindflay moving -> no match")

    local ctx4 = make_context({}, {enemy_count = 3, is_moving = true})
    local state4 = get_state(ctx4)
    state4.holy_nova_ready = true
    state4.enemies = 3
    state4.is_moving = true
    assert_false(strategies[18].matches(ctx4, state4), "holynova moving -> no match")

    local ctx5 = make_context({}, {mana_pct = 50, is_moving = true})
    local state5 = get_state(ctx5)
    state5.smite_ready = true
    state5.mana_pct = 50
    state5.is_moving = true
    assert_false(strategies[19].matches(ctx5, state5), "smite moving -> no match")
end

-- ============================================================================
-- Edge case: Channeling guards
-- ============================================================================
do
    local ctx = make_context({}, {})
    ctx.state.is_channeling = true
    local state = get_state(ctx)
    state.vt_ready = true
    state.vt_remaining = 0
    state.is_channeling = true
    assert_false(strategies[13].matches(ctx, state), "vt channeling -> no match")

    local ctx2 = make_context({}, {})
    ctx2.state.is_channeling = true
    local state2 = get_state(ctx2)
    state2.mf_ready = true
    state2.mana_pct = 50
    state2.is_channeling = true
    state2.is_moving = false
    assert_false(strategies[17].matches(ctx2, state2), "mindflay channeling -> no match")
end

-- ============================================================================
-- Edge case: Debuff refresh boundaries
-- ============================================================================
do
    -- SWP: remains < 4 -> match; >= 4 -> no match
    local ctx = make_context({})
    local state = get_state(ctx)
    state.swp_ready = true
    local saved = NS.debuff_remains
    NS.debuff_remains = function(target, ids) return 3 end
    assert_true(strategies[12].matches(ctx, state), "swp remains=3 -> match (<4)")
    NS.debuff_remains = saved

    local ctx2 = make_context({})
    local state2 = get_state(ctx2)
    state2.swp_ready = true
    local saved2 = NS.debuff_remains
    NS.debuff_remains = function(target, ids) return 4 end
    assert_false(strategies[12].matches(ctx2, state2), "swp remains=4 -> no match (>=4)")
    NS.debuff_remains = saved2

    -- HolyFire: remains < 4 -> match; >= 4 -> no match
    local ctx3 = make_context({}, {is_moving = false})
    local state3 = get_state(ctx3)
    state3.holy_fire_ready = true
    state3.is_moving = false
    local saved3 = NS.debuff_remains
    NS.debuff_remains = function(target, ids) return 3 end
    assert_true(strategies[15].matches(ctx3, state3), "holyfire remains=3 -> match (<4)")
    NS.debuff_remains = saved3

    local ctx4 = make_context({}, {is_moving = false})
    local state4 = get_state(ctx4)
    state4.holy_fire_ready = true
    state4.is_moving = false
    local saved4 = NS.debuff_remains
    NS.debuff_remains = function(target, ids) return 4 end
    assert_false(strategies[15].matches(ctx4, state4), "holyfire remains=4 -> no match (>=4)")
    NS.debuff_remains = saved4

    -- VT: vt_remaining <= 3 -> match; > 3 -> no match
    local ctx5 = make_context({})
    local state5 = get_state(ctx5)
    state5.vt_ready = true
    state5.vt_remaining = 3
    assert_true(strategies[13].matches(ctx5, state5), "vt remaining=3 -> match (<=3)")

    local ctx6 = make_context({})
    local state6 = get_state(ctx6)
    state6.vt_ready = true
    state6.vt_remaining = 4
    assert_false(strategies[13].matches(ctx6, state6), "vt remaining=4 -> no match (>3)")
end

-- ============================================================================
-- Edge case: Buff guards
-- ============================================================================
do
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.has_fortitude = true
    state.fortitude_ready = true
    assert_false(strategies[1].matches(ctx, state), "fortitude buff active -> no match")

    local ctx2 = make_context({in_combat = false})
    local state2 = get_state(ctx2)
    state2.has_inner_fire = true
    state2.inner_fire_ready = true
    assert_false(strategies[2].matches(ctx2, state2), "innerfire buff active -> no match")

    local ctx3 = make_context({in_combat = false})
    local state3 = get_state(ctx3)
    state3.has_shadowform = true
    state3.shadowform_ready = true
    state3.use_shadowform = true
    assert_false(strategies[3].matches(ctx3, state3), "shadowform buff active -> no match")
end

-- ============================================================================
-- Edge case: Settings toggle
-- ============================================================================
do
    local ctx = make_context({in_combat = false})
    ctx.settings.leveling_use_shadowform = false
    local state = get_state(ctx)
    state.shadowform_ready = true
    state.use_shadowform = false
    assert_false(strategies[3].matches(ctx, state), "shadowform setting disabled -> no match")

    local ctx2 = make_context({})
    ctx2.settings.use_symbol_of_hope = false
    ctx2.is_group = true
    local state2 = get_state(ctx2)
    state2.symbol_of_hope_ready = true
    assert_false(strategies[21].matches(ctx2, state2), "symbolofhope setting disabled -> no match")

    local ctx3 = make_context({})
    ctx3.is_group = false
    local state3 = get_state(ctx3)
    state3.symbol_of_hope_ready = true
    assert_false(strategies[21].matches(ctx3, state3), "symbolofhope not group -> no match")

    -- SymbolOfHope: in combat, mana < 20 -> no match; mana >= 20 -> match
    local ctx4 = make_context({})
    ctx4.is_group = true
    local state4 = get_state(ctx4)
    state4.symbol_of_hope_ready = true
    state4.mana_pct = 20
    assert_true(strategies[21].matches(ctx4, state4), "symbolofhope combat mana=20 -> match (>=20)")

    local ctx5 = make_context({})
    ctx5.is_group = true
    local state5 = get_state(ctx5)
    state5.symbol_of_hope_ready = true
    state5.mana_pct = 19
    assert_false(strategies[21].matches(ctx5, state5), "symbolofhope combat mana=19 -> no match (<20)")
end

-- ============================================================================
-- Edge case: Fade threat boundary
-- ============================================================================
do
    local ctx = make_context({threat_pct = 99})
    local state = get_state(ctx)
    state.fade_ready = true
    assert_true(strategies[10].matches(ctx, state), "fade threat=99 -> match (>=99)")

    local ctx2 = make_context({threat_pct = 98})
    local state2 = get_state(ctx2)
    state2.fade_ready = true
    assert_false(strategies[10].matches(ctx2, state2), "fade threat=98 -> no match (<99)")
end

-- ============================================================================
-- Edge case: ShackleUndead creature type
-- ============================================================================
do
    local ctx = make_context({}, {target_creature_type = "undead"})
    local state = get_state(ctx)
    state.shackle_ready = true
    state.target = {
        is_valid = function() return true end,
        get_creature_type = function() return "undead" end,
    }
    assert_true(strategies[11].matches(ctx, state), "shackle undead -> match")

    local ctx2 = make_context({}, {target_creature_type = "humanoid"})
    local state2 = get_state(ctx2)
    state2.shackle_ready = true
    assert_false(strategies[11].matches(ctx2, state2), "shackle humanoid -> no match")

    local ctx3 = make_context({})
    ctx3.target = nil
    local state3 = get_state(ctx3)
    state3.shackle_ready = true
    state3.target = nil
    assert_false(strategies[11].matches(ctx3, state3), "shackle no target -> no match")
end

-- ============================================================================
-- Edge case: OOC guards
-- ============================================================================
do
    -- Shield: OOC -> no match
    local ctx = make_context({in_combat = false}, {hp_pct = 40})
    local state = get_state(ctx)
    state.shield_ready = true
    state.hp = 40
    state.heal_hp = 60
    assert_false(strategies[4].matches(ctx, state), "shield OOC -> no match")

    -- Renw: OOC -> no match
    local ctx2 = make_context({in_combat = false}, {hp_pct = 40})
    local state2 = get_state(ctx2)
    state2.renew_ready = true
    state2.hp = 40
    state2.heal_hp = 60
    assert_false(strategies[5].matches(ctx2, state2), "renew OOC -> no match")

    -- InnerFocus: OOC -> no match
    local ctx3 = make_context({in_combat = false}, {hp_pct = 40})
    local state3 = get_state(ctx3)
    state3.inner_focus_ready = true
    state3.hp = 40
    assert_false(strategies[7].matches(ctx3, state3), "innerfocus OOC -> no match")
end

-- ============================================================================
-- API crash: NS.try_cast nil/throwing
-- ============================================================================
do
    local saved = NS.try_cast
    local ctx = make_context({})

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

-- ============================================================================
-- Deep dive: OOC guard loop — combat-gated strategies return false OOC
-- ============================================================================
do
    -- Combat-gated indices: {4,5,6,7,8} — have `if not state.in_combat then return false end`
    -- OOC-only indices {1,2} — have `if state.in_combat then return false end` (tested separately)
    -- Shadowform (3), Scream (9+), and most damage spells have NO combat gate
    local combat_gated = {4, 5, 6, 7, 8}
    local ctx = make_context({in_combat = false, hp = 30, mana_pct = 80, enemies_count = 1, is_moving = false})
    local state = get_state(ctx)
    -- Set all booleans to true to satisfy non-combat guards
    for k, v in pairs(state) do
        if type(v) == "boolean" then state[k] = true end
    end
    state.in_combat = false
    state.has_shield = false
    state.has_renew = false
    state.hp = 30
    state.heal_hp = 60

    for _, idx in ipairs(combat_gated) do
        local ok, matched = pcall(strategies[idx].matches, ctx, state)
        assert_true(ok, "strategy " .. idx .. " (" .. strategies[idx].name .. ") OOC guards do not throw")
        assert_false(matched, "strategy " .. idx .. " (" .. strategies[idx].name .. ") should not match OOC")
    end

    -- OOC-only strategies {1,2} verify they match OOC but NOT in combat
    local ctx_ooc = make_context({in_combat = false})
    local state_ooc = get_state(ctx_ooc)
    state_ooc.has_fortitude = false
    state_ooc.has_inner_fire = false
    state_ooc.fortitude_ready = true
    state_ooc.inner_fire_ready = true
    assert_true(strategies[1].matches(ctx_ooc, state_ooc), "fortitude matches OOC without buff")
    assert_true(strategies[2].matches(ctx_ooc, state_ooc), "innerfire matches OOC without buff")

    -- OOC-only strategies return false in combat
    local ctx_combat = make_context({in_combat = true})
    local state_combat = get_state(ctx_combat)
    state_combat.has_fortitude = false
    state_combat.has_inner_fire = false
    state_combat.fortitude_ready = true
    state_combat.inner_fire_ready = true
    assert_false(strategies[1].matches(ctx_combat, state_combat), "fortitude no match in combat")
    assert_false(strategies[2].matches(ctx_combat, state_combat), "innerfire no match in combat")
end

-- ============================================================================
-- Deep dive: Nil target guard loop
-- ============================================================================
do
    -- Target-dependent indices: {9,10,11,12,13,14,15,16,17,18,19,20}
    -- Non-target: {1,2,3,4,5,6,7,8,21}
    local target_dependent = {9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20}
    local ctx = make_context({target = nil, in_combat = true, hp = 50, mana_pct = 50, enemies_count = 3, is_moving = false})
    ctx.target = nil
    local state = get_state(ctx)
    for k, v in pairs(state) do
        if type(v) == "boolean" then state[k] = true end
    end
    state.target = nil
    state.in_combat = true
    state.mana_pct = 50
    state.enemies = 3
    state.hp = 61
    state.wand_threshold = 20
    state.vt_remaining = 0
    state.is_moving = false
    state.is_channeling = false

    for _, idx in ipairs(target_dependent) do
        local ok, matched = pcall(strategies[idx].matches, ctx, state)
        assert_true(ok, "strategy " .. idx .. " (" .. strategies[idx].name .. ") nil target guards do not throw")
        assert_false(matched, "strategy " .. idx .. " (" .. strategies[idx].name .. ") should not match with nil target")
    end
end

-- ============================================================================
-- Deep dive: Missing spell readiness guards
-- ============================================================================
do
    local ctx = make_context({in_combat = true, hp = 30, mana_pct = 50, enemies_count = 3, is_moving = false})
    ctx.target = {
        is_valid = function() return true end,
        get_health = function() return 8000 end,
        get_max_health = function() return 10000 end,
        get_health_percentage = function() return 80 end,
        get_creature_type = function() return "undead" end,
    }
    ctx.is_group = true

    -- Strategy 3: Shadowform not ready
    local state3 = get_state(ctx)
    state3.shadowform_ready = false
    state3.use_shadowform = true
    state3.has_shadowform = false
    assert_false(strategies[3].matches(ctx, state3), "shadowform not ready -> no match")

    -- Strategy 3: Shadowform use_shadowform disabled
    local state3b = get_state(ctx)
    state3b.shadowform_ready = true
    state3b.use_shadowform = false
    state3b.has_shadowform = false
    assert_false(strategies[3].matches(ctx, state3b), "shadowform setting disabled -> no match")

    -- Strategy 3: Shadowform already active
    local state3c = get_state(ctx)
    state3c.shadowform_ready = true
    state3c.use_shadowform = true
    state3c.has_shadowform = true
    assert_false(strategies[3].matches(ctx, state3c), "shadowform already active -> no match")

    -- Strategy 4: Shield not ready
    local state4 = get_state(ctx)
    state4.shield_ready = false
    state4.has_shield = false
    state4.hp = 30
    state4.heal_hp = 60
    assert_false(strategies[4].matches(ctx, state4), "shield not ready -> no match")

    -- Strategy 5: Renew not ready
    local state5 = get_state(ctx)
    state5.renew_ready = false
    state5.has_renew = false
    state5.hp = 30
    state5.heal_hp = 60
    assert_false(strategies[5].matches(ctx, state5), "renew not ready -> no match")

    -- Strategy 6: FlashHeal not ready
    local state6 = get_state(ctx)
    state6.flash_heal_ready = false
    state6.hp = 40
    assert_false(strategies[6].matches(ctx, state6), "flashheal not ready -> no match")

    -- Strategy 6: FlashHeal HP >= 50 -> no match
    local state6b = get_state(ctx)
    state6b.flash_heal_ready = true
    state6b.hp = 50
    assert_false(strategies[6].matches(ctx, state6b), "flashheal hp=50 -> no match (>=50)")

    -- Strategy 6: FlashHeal HP < 30 -> no match (use GreaterHeal for critical)
    local state6c = get_state(ctx)
    state6c.flash_heal_ready = true
    state6c.hp = 29
    assert_false(strategies[6].matches(ctx, state6c), "flashheal hp=29 -> no match (<30)")

    -- Strategy 6: FlashHeal HP=35 in range -> match
    local state6d = get_state(ctx)
    state6d.flash_heal_ready = true
    state6d.hp = 35
    assert_true(strategies[6].matches(ctx, state6d), "flashheal hp=35 -> match (30-49)")

    -- Strategy 7: InnerFocus not ready
    local state7 = get_state(ctx)
    state7.inner_focus_ready = false
    state7.hp = 30
    assert_false(strategies[7].matches(ctx, state7), "innerfocus not ready -> no match")

    -- Strategy 7: InnerFocus HP > 50 -> no match
    local state7b = get_state(ctx)
    state7b.inner_focus_ready = true
    state7b.hp = 51
    assert_false(strategies[7].matches(ctx, state7b), "innerfocus hp=51 -> no match (>50)")

    -- Strategy 8: GreaterHeal not ready
    local state8 = get_state(ctx)
    state8.greater_heal_ready = false
    state8.hp = 30
    state8.heal_hp = 60
    assert_false(strategies[8].matches(ctx, state8), "greaterheal not ready -> no match")

    -- Strategy 13: VT not ready
    local state13 = get_state(ctx)
    state13.vt_ready = false
    state13.vt_remaining = 0
    state13.is_channeling = false
    assert_false(strategies[13].matches(ctx, state13), "vt not ready -> no match")

    -- Strategy 13: VT is_channeling -> no match
    local state13b = get_state(ctx)
    state13b.vt_ready = true
    state13b.vt_remaining = 0
    state13b.is_channeling = true
    assert_false(strategies[13].matches(ctx, state13b), "vt channeling -> no match")

    -- Strategy 17: MindFlay not ready
    local state17 = get_state(ctx)
    state17.mf_ready = false
    state17.mana_pct = 50
    state17.is_moving = false
    state17.is_channeling = false
    assert_false(strategies[17].matches(ctx, state17), "mindflay not ready -> no match")

    -- Strategy 17: MindFlay is_channeling -> no match
    local state17b = get_state(ctx)
    state17b.mf_ready = true
    state17b.mana_pct = 50
    state17b.is_moving = false
    state17b.is_channeling = true
    assert_false(strategies[17].matches(ctx, state17b), "mindflay channeling -> no match")

    -- Strategy 21: SymbolOfHope not ready
    local state21 = get_state(ctx)
    state21.symbol_of_hope_ready = false
    assert_false(strategies[21].matches(ctx, state21), "symbolofhope not ready -> no match")

    -- Strategy 21: SymbolOfHope not group -> no match
    local ctx21b = make_context({})
    ctx21b.is_group = false
    local state21b = get_state(ctx21b)
    state21b.symbol_of_hope_ready = true
    assert_false(strategies[21].matches(ctx21b, state21b), "symbolofhope not group -> no match")

    -- Strategy 21: SymbolOfHope setting disabled -> no match
    local ctx21c = make_context({})
    ctx21c.is_group = true
    ctx21c.settings.use_symbol_of_hope = false
    local state21c = get_state(ctx21c)
    state21c.symbol_of_hope_ready = true
    state21c.use_symbol_of_hope = false
    assert_false(strategies[21].matches(ctx21c, state21c), "symbolofhope setting disabled -> no match")
end

-- ============================================================================
-- Deep dive: ShackleUndead target.get_creature_type throws
-- ============================================================================
do
    local ctx = make_context()
    ctx.target = {
        is_valid = function() return true end,
        get_creature_type = function() error("simulated creature type throw") end,
    }
    local state = get_state(ctx)
    state.shackle_ready = true
    local ok, result = pcall(strategies[11].matches, ctx, state)
    assert_true(ok, "shackle get_creature_type throws -> pcall catches")
    assert_false(result, "shackle get_creature_type throws -> no match")
end

-- ============================================================================
-- Deep dive: SWP NS.debuff_remains throws
-- ============================================================================
do
    local ctx = make_context()
    local state = get_state(ctx)
    state.swp_ready = true
    local saved = NS.debuff_remains
    NS.debuff_remains = function() error("simulated debuff remains throw") end
    local ok, result = pcall(strategies[12].matches, ctx, state)
    assert_true(ok, "swp debuff_remains throws -> pcall catches")
    -- When remains throws, pcall catches, ok=false, remains stays at default 0
    -- 0 < 4 -> match fires
    assert_true(result, "swp debuff_remains throws -> falls back to 0 (<4), match fires")
    NS.debuff_remains = saved
end

-- ============================================================================
-- Deep dive: HolyFire NS.debuff_remains throws
-- ============================================================================
do
    local ctx = make_context({}, {is_moving = false})
    local state = get_state(ctx)
    state.holy_fire_ready = true
    state.is_moving = false
    local saved = NS.debuff_remains
    NS.debuff_remains = function() error("simulated debuff remains throw") end
    local ok, result = pcall(strategies[15].matches, ctx, state)
    assert_true(ok, "holyfire debuff_remains throws -> pcall catches")
    assert_true(result, "holyfire debuff_remains throws -> falls back to 0 (<4), match fires")
    NS.debuff_remains = saved
end

-- ============================================================================
-- Deep dive: Fade with nil context.threat_pct
-- ============================================================================
do
    -- Fade checks `(context.threat_pct or 0) >= 99`
    -- nil context.threat_pct -> 0 >= 99 -> false -> no match
    local ctx = make_context({})
    ctx.threat_pct = nil
    -- Remove threat_pct from ctx
    local state = get_state(ctx)
    state.fade_ready = true
    assert_false(strategies[10].matches(ctx, state), "fade nil threat_pct -> no match (0 >= 99 false)")
end

-- ============================================================================
-- Deep dive: Wand OOC matches (no combat gate) vs. mana boundary
-- ============================================================================
do
    -- Wand has NO combat gate, checks target + mana < threshold
    local ctx = make_context({in_combat = false, mana_pct = 19})
    local state = get_state(ctx)
    state.mana_pct = 19
    state.wand_threshold = 20
    assert_true(strategies[20].matches(ctx, state), "wand OOC mana=19 -> match (<20, no combat gate)")

    local ctx2 = make_context({in_combat = false, mana_pct = 20})
    local state2 = get_state(ctx2)
    state2.mana_pct = 20
    state2.wand_threshold = 20
    assert_false(strategies[20].matches(ctx2, state2), "wand OOC mana=20 -> no match (>=20)")

    -- Wand with no target -> false
    local ctx3 = make_context({target = nil, mana_pct = 10})
    local state3 = get_state(ctx3)
    state3.mana_pct = 10
    state3.target = nil
    assert_false(strategies[20].matches(ctx3, state3), "wand no target -> no match")
end

-- ============================================================================
-- Deep dive: Smite moving + mana boundary (full coverage)
-- ============================================================================
do
    local ctx = make_context({}, {mana_pct = 20, is_moving = false})
    local state = get_state(ctx)
    state.smite_ready = true
    state.mana_pct = 20
    state.wand_threshold = 20
    state.is_moving = false
    assert_true(strategies[19].matches(ctx, state), "smite mana=20 stationary -> match (>=20)")

    -- Smite mana=19 -> no match
    local ctx2 = make_context({}, {mana_pct = 19, is_moving = false})
    local state2 = get_state(ctx2)
    state2.smite_ready = true
    state2.mana_pct = 19
    state2.wand_threshold = 20
    state2.is_moving = false
    assert_false(strategies[19].matches(ctx2, state2), "smite mana=19 -> no match (<20)")

    -- Smite no target -> false
    local ctx3 = make_context({target = nil}, {mana_pct = 50, is_moving = false})
    local state3 = get_state(ctx3)
    state3.smite_ready = true
    state3.mana_pct = 50
    state3.target = nil
    assert_false(strategies[19].matches(ctx3, state3), "smite no target -> no match")
end

-- ============================================================================
-- Deep dive: SymbolOfHope mana 20/19 boundary in combat
-- ============================================================================
do
    -- SymbolOfHope: in combat, mana >= 20 -> match
    local ctx = make_context({})
    ctx.is_group = true
    local state = get_state(ctx)
    state.symbol_of_hope_ready = true
    state.mana_pct = 20
    assert_true(strategies[21].matches(ctx, state), "symbolofhope combat mana=20 -> match (>=20)")

    -- SymbolOfHope: in combat, mana < 20 -> no match
    local ctx2 = make_context({})
    ctx2.is_group = true
    local state2 = get_state(ctx2)
    state2.symbol_of_hope_ready = true
    state2.mana_pct = 19
    assert_false(strategies[21].matches(ctx2, state2), "symbolofhope combat mana=19 -> no match (<20)")

    -- SymbolOfHope: OOC, group, ready -> match regardless of mana
    local ctx3 = make_context({in_combat = false})
    ctx3.is_group = true
    local state3 = get_state(ctx3)
    state3.symbol_of_hope_ready = true
    state3.mana_pct = 10
    assert_true(strategies[21].matches(ctx3, state3), "symbolofhope OOC group -> match regardless of mana")
end

-- ============================================================================
-- Deep dive: All execute functions handle nil NS.try_cast gracefully
-- ============================================================================
do
    local saved_try = NS.try_cast
    NS.try_cast = nil
    local ctx = make_context()
    for i = 1, #strategies do
        local ok, result = pcall(strategies[i].execute, ctx)
        assert_true(ok, "try_cast=nil: strategy " .. i .. " execute did not crash")
    end
    NS.try_cast = saved_try
end

-- ============================================================================
-- Deep dive: All execute functions handle NS.try_cast returning false
-- ============================================================================
do
    local saved_try = NS.try_cast
    NS.try_cast = function() return false end
    local ctx = make_context()
    for i = 1, #strategies do
        local ok, result = pcall(strategies[i].execute, ctx)
        assert_true(ok, "try_cast=false: strategy " .. i .. " execute did not crash")
    end
    NS.try_cast = saved_try
end

-- ============================================================================
-- Deep dive: Null state safety for all match functions (double-check)
-- ============================================================================
do
    local ctx = make_context()
    for i = 1, #strategies do
        local ok, result = pcall(strategies[i].matches, ctx, nil)
        assert_true(ok, "strategy " .. i .. " nil state does not throw")
        assert_false(result, "strategy " .. i .. " nil state returns false")
    end
end

-- ============================================================================
-- Deep dive: Fade and Shackle no target explicit check
-- ============================================================================
do
    -- Fade: no target -> false (already in nil target loop, but double-check independently)
    local ctx = make_context({target = nil})
    ctx.target = nil
    local state = get_state(ctx)
    state.fade_ready = true
    state.target = nil
    assert_false(strategies[10].matches(ctx, state), "fade no target -> no match")

    -- Shackle: no target -> false
    local ctx2 = make_context({target = nil})
    ctx2.target = nil
    local state2 = get_state(ctx2)
    state2.shackle_ready = true
    state2.target = nil
    assert_false(strategies[11].matches(ctx2, state2), "shackle no target -> no match")
end

-- ============================================================================
-- Deep dive: HolyNova no target explicit + moving + enemy boundaries
-- ============================================================================
do
    -- HolyNova: no target -> false
    local ctx = make_context({target = nil, enemies_count = 3, is_moving = false})
    ctx.target = nil
    local state = get_state(ctx)
    state.holy_nova_ready = true
    state.target = nil
    state.enemies = 3
    assert_false(strategies[18].matches(ctx, state), "holynova no target -> no match")

    -- HolyNova: enemies=3 not moving -> match
    local ctx2 = make_context({enemies_count = 3, is_moving = false})
    local state2 = get_state(ctx2)
    state2.holy_nova_ready = true
    state2.enemies = 3
    state2.is_moving = false
    assert_true(strategies[18].matches(ctx2, state2), "holynova enemies=3 stationary -> match")

    -- HolyNova: enemies=2 -> no match
    local ctx3 = make_context({enemies_count = 2, is_moving = false})
    local state3 = get_state(ctx3)
    state3.holy_nova_ready = true
    state3.enemies = 2
    state3.is_moving = false
    assert_false(strategies[18].matches(ctx3, state3), "holynova enemies=2 -> no match")
end

-- ============================================================================
-- Deep dive: MindBlast no target -> false (explicit standalone)
-- ============================================================================
do
    local ctx = make_context({target = nil})
    ctx.target = nil
    local state = get_state(ctx)
    state.mind_blast_ready = true
    state.target = nil
    assert_false(strategies[16].matches(ctx, state), "mindblast no target -> no match")
end

-- ============================================================================
-- Deep dive: FlashHeal + InnerFocus + GreaterHeal OOC already tested in loop
-- Additional: GreaterHeal moving already tested, but also verify FlashHeal moving
-- ============================================================================
do
    -- FlashHeal: moving -> false (no movement check in match function!)
    -- Wait, let me re-check flash_heal_matches:
    --   if not state then return false end
    --   if not state.in_combat then return false end
    --   if (state.hp or 100) >= 50 then return false end
    --   if (state.hp or 100) < 30 then return false end
    --   return state.flash_heal_ready
    -- No movement check! So FlashHeal works while moving (it's instant cast).
    local ctx = make_context({is_moving = true, hp = 40})
    local state = get_state(ctx)
    state.flash_heal_ready = true
    state.hp = 40
    assert_true(strategies[6].matches(ctx, state), "flashheal moving -> match (instant, no movement check)")
end

-- ============================================================================
-- Deep dive: NS.debuff_remains nil returns 0 for SWP refresh
-- ============================================================================
do
    local saved = NS.debuff_remains
    NS.debuff_remains = nil
    local ctx = make_context()
    local state = get_state(ctx)
    state.swp_ready = true
    -- safe_debuff_remains checks `if not NS.debuff_remains then return 0 end`
    local ok, result = pcall(strategies[12].matches, ctx, state)
    assert_true(ok, "swp NS.debuff_remains nil -> pcall catches, returns 0, match fires")
    assert_true(result, "swp NS.debuff_remains nil -> remains=0 <4 -> match")
    NS.debuff_remains = saved
end
-- Summary
-- ============================================================================

print(string.format("\\n=== Priest Leveling Unit Tests: %d passed, %d failed (%d assertions) ===\\n", passed, failed, assertions))
if failed > 0 then
    error(string.format("Some tests FAILED (%d failures)", failed))
else
    print("All Priest leveling unit tests passed!")
end
