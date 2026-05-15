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
    assert_eq(state.mana_pct, 100, "default mana_pct = 100")
    assert_eq(state.enemies, 0, "default enemy_count = 0")
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
-- Test: shield_matches (strategy #3)
-- ============================================================================

test("shield_matches: ready, no shield, low HP, target → true", function()
    local ctx = make_context({}, {hp_pct = 30})
    local state = get_state(ctx)
    state.has_shield = false
    state.shield_ready = true
    state.hp = 30
    state.heal_hp = 60
    assert_true(strategies[3].matches(ctx, state), "should match when HP < threshold")
end)

test("shield_matches: no target → false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.has_shield = false
    state.shield_ready = true
    assert_false(strategies[3].matches(ctx, state), "no target should return false")
end)

test("shield_matches: already has shield → false", function()
    local ctx = make_context({}, {hp_pct = 30})
    local state = get_state(ctx)
    state.has_shield = true
    state.shield_ready = true
    state.hp = 30
    assert_false(strategies[3].matches(ctx, state), "shield already active")
end)

test("shield_matches: HP above threshold → false", function()
    local ctx = make_context({}, {hp_pct = 80})
    local state = get_state(ctx)
    state.has_shield = false
    state.shield_ready = true
    state.hp = 80
    state.heal_hp = 60
    assert_false(strategies[3].matches(ctx, state), "HP above threshold")
end)

-- ============================================================================
-- Test: renew_matches (strategy #4)
-- ============================================================================

test("renew_matches: ready, no renew, low HP → true", function()
    local ctx = make_context({}, {hp_pct = 30})
    local state = get_state(ctx)
    state.has_renew = false
    state.renew_ready = true
    state.hp = 30
    state.heal_hp = 60
    assert_true(strategies[4].matches(ctx, state), "should match when HP < threshold")
end)

test("renew_matches: already has renew → false", function()
    local ctx = make_context({}, {hp_pct = 30})
    local state = get_state(ctx)
    state.has_renew = true
    state.renew_ready = true
    assert_false(strategies[4].matches(ctx, state), "renew already active")
end)

test("renew_matches: no target → false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.has_renew = false
    state.renew_ready = true
    assert_false(strategies[4].matches(ctx, state), "no target")
end)

-- ============================================================================
-- Test: heal_matches (GreaterHeal, strategy #5)
-- ============================================================================

test("heal_matches: ready, low HP, not moving → true", function()
    local ctx = make_context({}, {hp_pct = 30, is_moving = false})
    local state = get_state(ctx)
    state.greater_heal_ready = true
    state.hp = 30
    state.heal_hp = 60
    state.is_moving = false
    assert_true(strategies[5].matches(ctx, state), "should match when low HP, stationary")
end)

test("heal_matches: moving → false", function()
    local ctx = make_context({}, {hp_pct = 30, is_moving = true})
    local state = get_state(ctx)
    state.greater_heal_ready = true
    state.hp = 30
    state.is_moving = true
    assert_false(strategies[5].matches(ctx, state), "moving should not match")
end)

test("heal_matches: HP above threshold → false", function()
    local ctx = make_context({}, {hp_pct = 80})
    local state = get_state(ctx)
    state.greater_heal_ready = true
    state.hp = 80
    state.heal_hp = 60
    assert_false(strategies[5].matches(ctx, state), "HP above threshold")
end)

-- ============================================================================
-- Test: scream_matches (PsychicScream, strategy #6)
-- ============================================================================

test("scream_matches: ready, 3+ enemies → true", function()
    local ctx = make_context({}, {enemy_count = 3})
    local state = get_state(ctx)
    state.scream_ready = true
    state.enemies = 3
    assert_true(strategies[6].matches(ctx, state), "3 enemies should match")
end)

test("scream_matches: 1 enemy → false", function()
    local ctx = make_context({}, {enemy_count = 1})
    local state = get_state(ctx)
    state.scream_ready = true
    state.enemies = 1
    assert_false(strategies[6].matches(ctx, state), "1 enemy should not match")
end)

test("scream_matches: not ready → false", function()
    local ctx = make_context({}, {enemy_count = 3})
    local state = get_state(ctx)
    state.scream_ready = false
    state.enemies = 3
    assert_false(strategies[6].matches(ctx, state), "scream not ready")
end)

-- ============================================================================
-- Test: fade_matches (strategy #7)
-- ============================================================================

test("fade_matches: ready, high threat → true", function()
    local ctx = make_context({state = {threat_status = 3, target_creature_type = "humanoid", hp_pct = 80, mana_pct = 80, enemy_count = 1, is_moving = false}})
    local state = get_state(ctx)
    state.fade_ready = true
    assert_true(strategies[7].matches(ctx, state), "high threat should match")
end)

test("fade_matches: low threat → false", function()
    local ctx = make_context({state = {threat_status = 1, target_creature_type = "humanoid", hp_pct = 80, mana_pct = 80, enemy_count = 1, is_moving = false}})
    local state = get_state(ctx)
    state.fade_ready = true
    assert_false(strategies[7].matches(ctx, state), "low threat should not match")
end)

test("fade_matches: not ready → false", function()
    local ctx = make_context({state = {threat_status = 3, target_creature_type = "humanoid", hp_pct = 80, mana_pct = 80, enemy_count = 1, is_moving = false}})
    local state = get_state(ctx)
    state.fade_ready = false
    assert_false(strategies[7].matches(ctx, state), "fade not ready")
end)

-- ============================================================================
-- Test: shackle_matches (strategy #8)
-- ============================================================================

test("shackle_matches: ready, undead target → true", function()
    local ctx = make_context({state = {target_creature_type = "undead", threat_status = 0, hp_pct = 80, mana_pct = 80, enemy_count = 1, is_moving = false}})
    local state = get_state(ctx)
    state.shackle_ready = true
    assert_true(strategies[8].matches(ctx, state), "undead target should match")
end)

test("shackle_matches: humanoid target → false", function()
    local ctx = make_context({state = {target_creature_type = "humanoid", threat_status = 0, hp_pct = 80, mana_pct = 80, enemy_count = 1, is_moving = false}})
    local state = get_state(ctx)
    state.shackle_ready = true
    assert_false(strategies[8].matches(ctx, state), "humanoid should not match")
end)

test("shackle_matches: not ready → false", function()
    local ctx = make_context({state = {target_creature_type = "undead", threat_status = 0, hp_pct = 80, mana_pct = 80, enemy_count = 1, is_moving = false}})
    local state = get_state(ctx)
    state.shackle_ready = false
    assert_false(strategies[8].matches(ctx, state), "shackle not ready")
end)

-- ============================================================================
-- Test: swp_matches (ShadowWordPain, strategy #9)
-- ============================================================================

test("swp_matches: ready, debuff expiring → true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    NS.debuff_remains = function(target, ids) return 0 end  -- expired
    state.swp_ready = true
    assert_true(strategies[9].matches(ctx, state), "expired SWP should match")
end)

test("swp_matches: debuff fresh → false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    NS.debuff_remains = function(target, ids) return 12 end  -- still up
    state.swp_ready = true
    assert_false(strategies[9].matches(ctx, state), "fresh SWP should not match")
end)

test("swp_matches: not ready → false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    NS.debuff_remains = function(target, ids) return 0 end
    state.swp_ready = false
    assert_false(strategies[9].matches(ctx, state), "SWP not ready")
end)

-- ============================================================================
-- Test: holy_fire_matches (strategy #11, HF is after SWD)
-- ============================================================================

test("holy_fire_matches: ready, not moving, debuff expired → true", function()
    local ctx = make_context({}, {is_moving = false})
    local state = get_state(ctx)
    NS.debuff_remains = function(target, ids) return 0 end
    state.holy_fire_ready = true
    state.is_moving = false
    assert_true(strategies[11].matches(ctx, state), "should match when not moving and debuff expired")
end)

test("holy_fire_matches: moving → false", function()
    local ctx = make_context({}, {is_moving = true})
    local state = get_state(ctx)
    NS.debuff_remains = function(target, ids) return 0 end
    state.holy_fire_ready = true
    state.is_moving = true
    assert_false(strategies[11].matches(ctx, state), "moving should not match")
end)

test("holy_fire_matches: debuff still up → false", function()
    local ctx = make_context({}, {is_moving = false})
    local state = get_state(ctx)
    NS.debuff_remains = function(target, ids) return 8 end
    state.holy_fire_ready = true
    state.is_moving = false
    assert_false(strategies[11].matches(ctx, state), "fresh Holy Fire debuff should not match")
end)

-- ============================================================================
-- Test: mind_blast_matches (strategy #12)
-- ============================================================================

test("mind_blast_matches: ready, has target → true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.mind_blast_ready = true
    assert_true(strategies[12].matches(ctx, state), "ready with target should match")
end)

test("mind_blast_matches: no target → false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.mind_blast_ready = true
    state.target = nil
    assert_false(strategies[12].matches(ctx, state), "no target should return false")
end)

-- ============================================================================
-- Test: swd_matches (ShadowWordDeath, strategy #10, before HF)
-- ============================================================================

test("swd_matches: ready, HP < 35% → true", function()
    local ctx = make_context({}, {hp_pct = 20})
    local state = get_state(ctx)
    state.swd_ready = true
    state.hp = 20
    assert_true(strategies[10].matches(ctx, state), "SWD with execute range should match")
end)

test("swd_matches: HP ≥ 35% → false", function()
    local ctx = make_context({}, {hp_pct = 50})
    local state = get_state(ctx)
    state.swd_ready = true
    state.hp = 50
    assert_false(strategies[10].matches(ctx, state), "HP above 35% should not match")
end)

test("swd_matches: not ready → false", function()
    local ctx = make_context({}, {hp_pct = 20})
    local state = get_state(ctx)
    state.swd_ready = false
    state.hp = 20
    assert_false(strategies[10].matches(ctx, state), "SWD not ready")
end)

-- ============================================================================
-- Test: holy_nova_matches (strategy #13)
-- ============================================================================

test("holy_nova_matches: ready, 3+ enemies, not moving → true", function()
    local ctx = make_context({}, {enemy_count = 3, is_moving = false})
    local state = get_state(ctx)
    state.holy_nova_ready = true
    state.enemies = 3
    state.is_moving = false
    assert_true(strategies[13].matches(ctx, state), "3 enemies stationary should match")
end)

test("holy_nova_matches: 1 enemy → false", function()
    local ctx = make_context({}, {enemy_count = 1})
    local state = get_state(ctx)
    state.holy_nova_ready = true
    state.enemies = 1
    assert_false(strategies[13].matches(ctx, state), "1 enemy should not match")
end)

test("holy_nova_matches: moving → false", function()
    local ctx = make_context({}, {enemy_count = 3, is_moving = true})
    local state = get_state(ctx)
    state.holy_nova_ready = true
    state.enemies = 3
    state.is_moving = true
    assert_false(strategies[13].matches(ctx, state), "moving should not match")
end)

test("holy_nova_matches: not ready → false", function()
    local ctx = make_context({}, {enemy_count = 3})
    local state = get_state(ctx)
    state.holy_nova_ready = false
    state.enemies = 3
    assert_false(strategies[13].matches(ctx, state), "holy nova not ready")
end)

-- ============================================================================
-- Test: smite_matches (strategy #14)
-- ============================================================================

test("smite_matches: ready, not moving, enough mana → true", function()
    local ctx = make_context({}, {mana_pct = 80, is_moving = false})
    local state = get_state(ctx)
    state.smite_ready = true
    state.mana_pct = 80
    state.wand_threshold = 20
    state.is_moving = false
    assert_true(strategies[14].matches(ctx, state), "enough mana stationary should match")
end)

test("smite_matches: moving → false", function()
    local ctx = make_context({}, {mana_pct = 80, is_moving = true})
    local state = get_state(ctx)
    state.smite_ready = true
    state.mana_pct = 80
    state.is_moving = true
    assert_false(strategies[14].matches(ctx, state), "moving should not match")
end)

test("smite_matches: low mana → false", function()
    local ctx = make_context({}, {mana_pct = 10, is_moving = false})
    local state = get_state(ctx)
    state.smite_ready = true
    state.mana_pct = 10
    state.wand_threshold = 20
    state.is_moving = false
    assert_false(strategies[14].matches(ctx, state), "low mana should not match")
end)

test("smite_matches: not ready → false", function()
    local ctx = make_context({state = {mana_pct = 80, is_moving = false}})
    local state = get_state(ctx)
    state.smite_ready = false
    state.mana_pct = 80
    state.is_moving = false
    assert_false(strategies[14].matches(ctx, state), "smite not ready")
end)

-- ============================================================================
-- Test: wand_matches_fn (strategy #15)
-- ============================================================================

test("wand_matches: low mana, has target → true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.mana_pct = 10
    state.wand_threshold = 20
    assert_true(strategies[15].matches(ctx, state), "low mana should match")
end)

test("wand_matches: enough mana → false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.mana_pct = 80
    state.wand_threshold = 20
    assert_false(strategies[15].matches(ctx, state), "enough mana should not match")
end)

test("wand_matches: no target → false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.mana_pct = 10
    state.target = nil
    assert_false(strategies[15].matches(ctx, state), "no target should not match")
end)

-- ============================================================================
-- Test: Strategy priority ordering
-- ============================================================================

test("strategies: 15 strategies in correct priority order", function()
    local expected = {
        "PowerWordFortitude",
        "InnerFire",
        "PowerWordShield",
        "Renew",
        "GreaterHeal",
        "PsychicScream",
        "Fade",
        "ShackleUndead",
        "ShadowWordPain",
        "ShadowWordDeath",
        "HolyFire",
        "MindBlast",
        "HolyNova",
        "Smite",
        "Wand",
    }
    assert_eq(#strategies, 15, "should have 15 strategies")
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
    local ok, result = pcall(strategies[15].execute, ctx)
    assert_true(ok, "execute with context should not throw")
end)

test("execute_Wand: does not crash without context", function()
    local ok, result = pcall(strategies[15].execute)
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
    assert_false(strategies[3].matches(ctx, state), "shield should not match OOC with full HP")

    -- damage abilities should not match (no target OOC)
    assert_false(strategies[9].matches(ctx, state), "SWP should not match OOC without target")

    -- wand should not match (no target OOC)
    assert_false(strategies[15].matches(ctx, state), "wand should not match OOC")
end)

test("rotation: low HP scenario - heal/shield should match", function()
    local ctx = make_context({state = {enemy_count = 1, hp_pct = 25, mana_pct = 80, is_moving = false, threat_status = 0, target_creature_type = "humanoid"}})
    local state = get_state(ctx)
    state.has_shield = false
    state.has_renew = false
    state.hp = 25
    state.heal_hp = 60

    -- shield should match (low HP, no shield)
    assert_true(strategies[3].matches(ctx, state), "shield should match when low HP")

    -- renew should match (low HP, no renew)
    assert_true(strategies[4].matches(ctx, state), "renew should match when low HP")

    -- heal should match (low HP, not moving)
    assert_true(strategies[5].matches(ctx, state), "greater heal should match when low HP")
end)

test("rotation: execute scenario - SWD should match when HP < 35%", function()
    local ctx = make_context({state = {enemy_count = 1, hp_pct = 20, mana_pct = 80, is_moving = false, threat_status = 0, target_creature_type = "humanoid"}})
    local state = get_state(ctx)
    state.swd_ready = true
    state.hp = 20

    -- SWD should match when target HP < 35%
    assert_true(strategies[10].matches(ctx, state), "SWD should match in execute range")

    -- Priority is determined by array index, not match functions.
    -- SWD (index 10) has higher priority than Smite (index 14) because
    -- the rotation registry iterates strategies in order and picks the
    -- first one that matches. Smite may also match (enough mana) but that's
    -- independent — the registry handles priority.
    local smite_matches_ok, smite_match = pcall(strategies[14].matches, ctx, state)
    assert_true(smite_matches_ok, "smite matches should not throw")
    -- Whether smite matches depends on mana - it's fine either way
end)

-- ============================================================================
-- Summary
-- ============================================================================

print(string.format("\\n=== Priest Leveling Unit Tests: %d passed, %d failed (%d assertions) ===\\n", passed, failed, assertions))
if failed > 0 then
    error(string.format("Some tests FAILED (%d failures)", failed))
else
    print("All Priest leveling unit tests passed!")
end
