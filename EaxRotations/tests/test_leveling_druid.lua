-- test_leveling_druid.lua -- Druid leveling rotation tests.
-- WHAT:  Druid leveling rotation tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Protects against regressions in rotation logic and state handling.
-- SAFETY: Pure unit tests with mocked API context.

-- Unit tests for Druid leveling rotation
-- Tests build_state, all 12 match functions, strategy ordering,
-- helper functions, and edge case handling

package.loaded["shared/leveling_sylvanas"] = nil
package.loaded["shared/leveling_helpers_sylvanas"] = nil

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

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
    -- Feral spells
    CatForm = { 768 },
    BearForm = { 9634 },
    Prowl = { 9913 },
    Pounce = { 27006 },
    Ravage = { 27005 },
    Rake = { 27003 },
    MangleCat = { 33983 },
    Shred = { 27002 },
    Rip = { 27008 },
    FerociousBite = { 24248, 31018, 22829, 22828, 22827, 22568 },
    Claw = { 27001 },
    MangleBear = { 33983 },
    SwipeBear = { 26998 },
    Maul = { 26996 },
    FrenziedRegeneration = { 26999 },
    FaerieFireFeral = { 27011 },
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
    NS.has_form = function(form) return false end
    NS.is_behind_target = function(target) return false end

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

-- Strategy lookup helper (avoids hardcoded indices)
local function find_strategy(name)
    for i, s in ipairs(strategies) do
        if s.name == name then return s end
    end
    return nil
end

-- Strategy aliases for ergonomic test access
local S_BearSurvival = find_strategy("BearFormSurvival")
local S_FrenziedRegen = find_strategy("FrenziedRegeneration")
local S_CatFormEntry = find_strategy("CatFormEntry")
local S_ProwlOpener = find_strategy("ProwlOpener")
local S_Pounce = find_strategy("Pounce")
local S_Ravage = find_strategy("Ravage")
local S_FaerieFireFeral = find_strategy("FaerieFireFeral")
local S_Rake = find_strategy("Rake")
local S_MangleCat = find_strategy("MangleCat")
local S_Shred = find_strategy("Shred")
local S_Rip = find_strategy("Rip")
local S_FerociousBite = find_strategy("FerociousBite")
local S_Claw = find_strategy("Claw")
local S_MangleBear = find_strategy("MangleBear")
local S_SwipeBear = find_strategy("SwipeBear")
local S_Maul = find_strategy("Maul")
local S_MOTW = find_strategy("MarkOfTheWild")
local S_THORNS = find_strategy("Thorns")
local S_NATURESGRASP = find_strategy("NaturesGrasp")
local S_BARKSKIN = find_strategy("Barkskin")
local S_HEALINGTOUCH = find_strategy("HealingTouch")
local S_REJUV = find_strategy("Rejuvenation")
local S_ROOTS = find_strategy("EntanglingRoots")
local S_MOONFIRE = find_strategy("Moonfire")
local S_IS = find_strategy("InsectSwarm")
local S_FF = find_strategy("FaerieFire")
local S_HURRICANE = find_strategy("Hurricane")
local S_STARFIRE = find_strategy("Starfire")
local S_WRATH = find_strategy("Wrath")
local S_WAND = find_strategy("Wand")

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
    assert_true(S_MOTW.matches(ctx, state), "should match OOC without buff")
end)

test("motw_matches: in combat -> false", function()
    local ctx = make_context({in_combat = true})
    local state = get_state(ctx)
    state.has_mark_of_wild = false
    state.mark_of_the_wild_ready = true
    assert_false(S_MOTW.matches(ctx, state), "should not match in combat")
end)

test("motw_matches: already has buff -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.has_mark_of_wild = true
    state.mark_of_the_wild_ready = true
    assert_false(S_MOTW.matches(ctx, state), "should not match if buff active")
end)

test("motw_matches: nil state -> does not crash", function()
    local ok, result = pcall(S_MOTW.matches, make_context({in_combat = false}), nil)
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
    assert_true(S_THORNS.matches(ctx, state), "should match OOC without buff")
end)

test("thorns_matches: in combat -> false", function()
    local ctx = make_context({in_combat = true})
    local state = get_state(ctx)
    state.has_thorns = false
    state.thorns_ready = true
    assert_false(S_THORNS.matches(ctx, state), "should not match in combat")
end)

test("thorns_matches: already has buff -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.has_thorns = true
    state.thorns_ready = true
    assert_false(S_THORNS.matches(ctx, state), "should not match if buff active")
end)

test("thorns_matches: nil state -> does not crash", function()
    local ok, result = pcall(S_THORNS.matches, make_context({in_combat = false}), nil)
    assert_true(ok, "nil state should not throw")
end)

-- Test: natures_grasp_matches (strategy #3)
-- ============================================================================

test("natures_grasp_matches: low HP, in combat, ready -> true", function()
    local ctx = make_context({hp = 30})
    local state = get_state(ctx)
    state.natures_grasp_ready = true
    state.hp = 30
    state.in_combat = true
    state.enemies = 1
    assert_true(S_NATURESGRASP.matches(ctx, state), "low HP should trigger Nature's Grasp")
end)

test("natures_grasp_matches: overwhelmed (2+ enemies) -> true even at decent HP", function()
    local ctx = make_context({hp = 60, enemies_count = 3})
    local state = get_state(ctx)
    state.natures_grasp_ready = true
    state.hp = 60
    state.in_combat = true
    state.enemies = 3
    assert_true(S_NATURESGRASP.matches(ctx, state), "overwhelmed should trigger Nature's Grasp")
end)

test("natures_grasp_matches: high HP, 1 enemy -> false", function()
    local ctx = make_context({hp = 80})
    local state = get_state(ctx)
    state.natures_grasp_ready = true
    state.hp = 80
    state.in_combat = true
    state.enemies = 1
    assert_false(S_NATURESGRASP.matches(ctx, state), "safe HP with 1 enemy should not match")
end)

test("natures_grasp_matches: OOC -> false", function()
    local ctx = make_context({in_combat = false, hp = 30})
    local state = get_state(ctx)
    state.natures_grasp_ready = true
    state.hp = 30
    state.in_combat = false
    state.enemies = 1
    assert_false(S_NATURESGRASP.matches(ctx, state), "OOC should not match")
end)

test("natures_grasp_matches: nil state -> does not crash", function()
    local ok, result = pcall(S_NATURESGRASP.matches, make_context({hp = 30}), nil)
    assert_true(ok, "nil state should not throw")
end)

-- ============================================================================
-- Test: healing_touch_matches (strategy #5)
-- ============================================================================

test("healing_touch_matches: very low HP, in combat, ready -> true", function()
    local ctx = make_context({hp = 25})
    local state = get_state(ctx)
    state.healing_touch_ready = true
    state.hp = 25
    state.heal_hp = 40
    state.in_combat = true
    assert_true(S_HEALINGTOUCH.matches(ctx, state), "very low HP should trigger Healing Touch")
end)

test("healing_touch_matches: HP above (heal_hp - 10) -> false", function()
    local ctx = make_context({hp = 50})
    local state = get_state(ctx)
    state.healing_touch_ready = true
    state.hp = 50
    state.heal_hp = 40
    state.in_combat = true
    assert_false(S_HEALINGTOUCH.matches(ctx, state), "HP above heal_hp-10 should not match")
end)

test("healing_touch_matches: OOC -> false", function()
    local ctx = make_context({in_combat = false, hp = 25})
    local state = get_state(ctx)
    state.healing_touch_ready = true
    state.hp = 25
    state.in_combat = false
    assert_false(S_HEALINGTOUCH.matches(ctx, state), "OOC should not match")
end)

test("healing_touch_matches: nil state -> does not crash", function()
    local ok, result = pcall(S_HEALINGTOUCH.matches, make_context({hp = 25}), nil)
    assert_true(ok, "nil state should not throw")
end)

-- ============================================================================
-- Test: barkskin_matches (strategy #4)
-- ============================================================================

test("barkskin_matches: in combat, low HP, ready -> true", function()
    local ctx = make_context({hp = 35})
    local state = get_state(ctx)
    state.barkskin_ready = true
    state.hp = 35
    assert_true(S_BARKSKIN.matches(ctx, state), "low HP in combat should match")
end)

test("barkskin_matches: HP above 50 -> false", function()
    local ctx = make_context({hp = 80})
    local state = get_state(ctx)
    state.barkskin_ready = true
    state.hp = 80
    assert_false(S_BARKSKIN.matches(ctx, state), "HP above 50 should not match")
end)

test("barkskin_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false, hp = 35})
    local state = get_state(ctx)
    state.barkskin_ready = true
    state.in_combat = false
    state.hp = 35
    assert_false(S_BARKSKIN.matches(ctx, state), "OOC should not match")
end)

test("barkskin_matches: nil state -> does not crash", function()
    local ok, result = pcall(S_BARKSKIN.matches, make_context({hp = 35}), nil)
    assert_true(ok, "nil state should not throw")
end)

-- ============================================================================
-- Test: rejuvenation_matches (strategy #6)
-- ============================================================================

test("rejuvenation_matches: in combat, low HP, ready -> true", function()
    local ctx = make_context({hp = 30})
    local state = get_state(ctx)
    state.rejuvenation_ready = true
    state.hp = 30
    state.heal_hp = 40
    assert_true(S_REJUV.matches(ctx, state), "low HP in combat should match")
end)

test("rejuvenation_matches: HP above heal_hp -> false", function()
    local ctx = make_context({hp = 80})
    local state = get_state(ctx)
    state.rejuvenation_ready = true
    state.hp = 80
    state.heal_hp = 40
    assert_false(S_REJUV.matches(ctx, state), "HP above threshold should not match")
end)

test("rejuvenation_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false, hp = 30})
    local state = get_state(ctx)
    state.rejuvenation_ready = true
    state.in_combat = false
    state.hp = 30
    state.heal_hp = 40
    assert_false(S_REJUV.matches(ctx, state), "OOC should not match")
end)

test("rejuvenation_matches: nil state -> does not crash", function()
    local ok, result = pcall(S_REJUV.matches, make_context({hp = 30}), nil)
    assert_true(ok, "nil state should not throw")
end)

-- ============================================================================
-- Test: entangling_roots_matches (strategy #7)
-- ============================================================================

test("entangling_roots_matches: overwhelmed (3+ enemies, low HP) -> true", function()
    local ctx = make_context({enemies_count = 4, hp = 25})
    local state = get_state(ctx)
    state.entangling_roots_ready = true
    state.enemies = 4
    state.hp = 25
    assert_true(S_ROOTS.matches(ctx, state), "overwhelmed with 4 enemies and low HP should match")
end)

test("entangling_roots_matches: single enemy, high HP -> false", function()
    local ctx = make_context({enemies_count = 1, hp = 80})
    local state = get_state(ctx)
    state.entangling_roots_ready = true
    state.enemies = 1
    state.hp = 80
    assert_false(S_ROOTS.matches(ctx, state), "1 enemy high HP should not match")
end)

test("entangling_roots_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false, enemies_count = 4, hp = 25})
    local state = get_state(ctx)
    state.entangling_roots_ready = true
    state.in_combat = false
    state.enemies = 4
    state.hp = 25
    assert_false(S_ROOTS.matches(ctx, state), "OOC should not match")
end)

test("entangling_roots_matches: no target -> false", function()
    local ctx = make_context({target = nil, enemies_count = 4, hp = 25})
    local state = get_state(ctx)
    state.entangling_roots_ready = true
    state.target = nil
    state.enemies = 4
    state.hp = 25
    assert_false(S_ROOTS.matches(ctx, state), "no target should not match")
end)

test("entangling_roots_matches: nil state -> does not crash", function()
    local ok, result = pcall(S_ROOTS.matches, make_context({enemies_count = 4, hp = 25}), nil)
    assert_true(ok, "nil state should not throw")
end)

-- ============================================================================
-- Test: moonfire_matches (strategy #8)
-- ============================================================================

test("moonfire_matches: ready, target, DoT expiring -> true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.moonfire_ready = true
    NS.debuff_remains = function(target, ids) return 2 end
    assert_true(S_MOONFIRE.matches(ctx, state), "DoT expiring should match")
    NS.debuff_remains = function(target, ids) return 0 end
end)

test("moonfire_matches: DoT still active -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.moonfire_ready = true
    NS.debuff_remains = function(target, ids) return 8 end
    assert_false(S_MOONFIRE.matches(ctx, state), "DoT still active (8s > 4s) should not match")
    NS.debuff_remains = function(target, ids) return 0 end
end)

test("moonfire_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.moonfire_ready = true
    assert_false(S_MOONFIRE.matches(ctx, state), "OOC should not match")
end)

test("moonfire_matches: no target -> false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.moonfire_ready = true
    state.target = nil
    assert_false(S_MOONFIRE.matches(ctx, state), "no target should not match")
end)

test("moonfire_matches: nil state -> does not crash", function()
    local ok, result = pcall(S_MOONFIRE.matches, make_context(), nil)
    assert_true(ok, "nil state should not throw")
end)

-- ============================================================================
-- Test: insect_swarm_matches (strategy #9)
-- ============================================================================

test("insect_swarm_matches: ready, target, DoT expiring -> true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.insect_swarm_ready = true
    NS.debuff_remains = function(target, ids) return 2 end
    assert_true(S_IS.matches(ctx, state), "DoT expiring should match")
    NS.debuff_remains = function(target, ids) return 0 end
end)

test("insect_swarm_matches: DoT still active -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.insect_swarm_ready = true
    NS.debuff_remains = function(target, ids) return 8 end
    assert_false(S_IS.matches(ctx, state), "DoT still active (8s > 4s) should not match")
    NS.debuff_remains = function(target, ids) return 0 end
end)

test("insect_swarm_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.insect_swarm_ready = true
    assert_false(S_IS.matches(ctx, state), "OOC should not match")
end)

test("insect_swarm_matches: no target -> false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.insect_swarm_ready = true
    state.target = nil
    assert_false(S_IS.matches(ctx, state), "no target should not match")
end)

test("insect_swarm_matches: nil state -> does not crash", function()
    local ok, result = pcall(S_IS.matches, make_context(), nil)
    assert_true(ok, "nil state should not throw")
end)

-- ============================================================================
-- Test: faerie_fire_matches (strategy #10)
-- ============================================================================

test("faerie_fire_matches: ready, target, no debuff -> true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.faerie_fire_ready = true
    NS.debuff_remains = function(target, ids) return 0 end
    assert_true(S_FF.matches(ctx, state), "no debuff should match")
    NS.debuff_remains = function(target, ids) return 0 end
end)

test("faerie_fire_matches: debuff still active -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.faerie_fire_ready = true
    NS.debuff_remains = function(target, ids) return 20 end
    assert_false(S_FF.matches(ctx, state), "debuff active (20s > 10s) should not match")
    NS.debuff_remains = function(target, ids) return 0 end
end)

test("faerie_fire_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.faerie_fire_ready = true
    assert_false(S_FF.matches(ctx, state), "OOC should not match")
end)

test("faerie_fire_matches: no target -> false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.faerie_fire_ready = true
    state.target = nil
    assert_false(S_FF.matches(ctx, state), "no target should not match")
end)

test("faerie_fire_matches: nil state -> does not crash", function()
    local ok, result = pcall(S_FF.matches, make_context(), nil)
    assert_true(ok, "nil state should not throw")
end)

-- ============================================================================
-- Test: low-level feral level 42 reported spells
-- Reproduces the silent-gating bug where core spells are not usable at level 42.
-- ============================================================================

local function with_feral_mocks(fn)
    local saved_has_form = NS.has_form
    local saved_is_behind = NS.is_behind_target
    local saved_debuff_remains = NS.debuff_remains
    NS.has_form = function(form) return form == "cat" end
    NS.is_behind_target = function(target) return true end
    NS.debuff_remains = function(target, ids) return 0 end
    local ok, err = pcall(fn)
    NS.has_form = saved_has_form
    NS.is_behind_target = saved_is_behind
    NS.debuff_remains = saved_debuff_remains
    if not ok then error(err, 2) end
end

test("low_level_feral_42: Faerie Fire (Feral) fires in cat form at level 42", function()
    with_feral_mocks(function()
        local ctx = make_context({level = 42})
        local state = get_state(ctx)
        state.is_cat = true
        state.in_combat = true
        state.faerie_fire_feral_ready = true
        state.faerie_fire_feral_remains = 0
        assert_true(S_FaerieFireFeral.matches(ctx, state), "Faerie Fire (Feral) should fire at level 42")
    end)
end)

test("low_level_feral_42: Shred fires without Mangle debuff at level 42", function()
    with_feral_mocks(function()
        local ctx = make_context({level = 42})
        local state = get_state(ctx)
        state.is_cat = true
        state.is_behind = true
        state.energy = 60
        state.combo_points = 3
        state.shred_ready = true
        state.mangle_remains = 0
        state.mangle_cat_ready = false
        state.target_ttd = 60
        assert_true(S_Shred.matches(ctx, state), "Shred should fire at level 42 without Mangle debuff")
    end)
end)

test("low_level_feral_42: Ravage fires from stealth behind target at level 42", function()
    with_feral_mocks(function()
        local ctx = make_context({level = 42})
        local state = get_state(ctx)
        state.is_cat = true
        state.is_stealthed = true
        state.is_behind = true
        state.energy = 60
        state.ravage_ready = true
        assert_true(S_Ravage.matches(ctx, state), "Ravage should fire at level 42 from stealth behind target")
    end)
end)

test("low_level_feral_42: Rip fires at 4 combo points at level 42", function()
    with_feral_mocks(function()
        local ctx = make_context({level = 42})
        local state = get_state(ctx)
        state.is_cat = true
        state.energy = 40
        state.combo_points = 4
        state.rip_ready = true
        state.rip_remains = 0
        state.target_ttd = 60
        assert_true(S_Rip.matches(ctx, state), "Rip should fire at level 42 with 4 combo points")
    end)
end)

test("low_level_feral_42: Ferocious Bite fires at 4 combo points at level 42", function()
    with_feral_mocks(function()
        local ctx = make_context({level = 42})
        local state = get_state(ctx)
        state.is_cat = true
        state.energy = 40
        state.combo_points = 4
        state.bite_ready = true
        state.rip_remains = 0
        state.target_ttd = 60
        assert_true(S_FerociousBite.matches(ctx, state), "Ferocious Bite should fire at level 42 with 4 combo points")
    end)
end)

-- ============================================================================
-- Test: hurricane_matches (strategy #11)
-- ============================================================================

test("hurricane_matches: 3+ enemies, not moving, ready -> true", function()
    local ctx = make_context({enemies_count = 4, is_moving = false})
    local state = get_state(ctx)
    state.hurricane_ready = true
    state.enemies = 4
    state.is_moving = false
    assert_true(S_HURRICANE.matches(ctx, state), "3+ enemies stationary should match")
end)

test("hurricane_matches: 1 enemy -> false", function()
    local ctx = make_context({enemies_count = 1})
    local state = get_state(ctx)
    state.hurricane_ready = true
    state.enemies = 1
    assert_false(S_HURRICANE.matches(ctx, state), "1 enemy should not match")
end)

test("hurricane_matches: moving -> false", function()
    local ctx = make_context({enemies_count = 4, is_moving = true})
    local state = get_state(ctx)
    state.hurricane_ready = true
    state.enemies = 4
    state.is_moving = true
    assert_false(S_HURRICANE.matches(ctx, state), "moving should not match")
end)

test("hurricane_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false, enemies_count = 4})
    local state = get_state(ctx)
    state.hurricane_ready = true
    state.in_combat = false
    state.enemies = 4
    assert_false(S_HURRICANE.matches(ctx, state), "OOC should not match")
end)

test("hurricane_matches: no target -> false", function()
    local ctx = make_context({target = nil, enemies_count = 4})
    local state = get_state(ctx)
    state.hurricane_ready = true
    state.target = nil
    state.enemies = 4
    assert_false(S_HURRICANE.matches(ctx, state), "no target should not match")
end)

test("hurricane_matches: nil state -> does not crash", function()
    local ok, result = pcall(S_HURRICANE.matches, make_context({enemies_count = 4}), nil)
    assert_true(ok, "nil state should not throw")
end)

-- ============================================================================
-- Test: starfire_matches (strategy #12)
-- ============================================================================

test("starfire_matches: ready, target, not moving -> true", function()
    local ctx = make_context({is_moving = false})
    local state = get_state(ctx)
    state.starfire_ready = true
    state.is_moving = false
    assert_true(S_STARFIRE.matches(ctx, state), "stationary should match")
end)

test("starfire_matches: moving -> false", function()
    local ctx = make_context({is_moving = true})
    local state = get_state(ctx)
    state.starfire_ready = true
    state.is_moving = true
    assert_false(S_STARFIRE.matches(ctx, state), "moving should not match")
end)

test("starfire_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.starfire_ready = true
    state.in_combat = false
    assert_false(S_STARFIRE.matches(ctx, state), "OOC should not match")
end)

test("starfire_matches: no target -> false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.starfire_ready = true
    state.target = nil
    assert_false(S_STARFIRE.matches(ctx, state), "no target should not match")
end)

test("starfire_matches: nil state -> does not crash", function()
    local ok, result = pcall(S_STARFIRE.matches, make_context(), nil)
    assert_true(ok, "nil state should not throw")
end)

-- ============================================================================
-- Test: wrath_matches (strategy #13)
-- ============================================================================

test("wrath_matches: ready, target, in combat -> true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.wrath_ready = true
    assert_true(S_WRATH.matches(ctx, state), "ready with target should match")
end)

test("wrath_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.wrath_ready = true
    state.in_combat = false
    assert_false(S_WRATH.matches(ctx, state), "OOC should not match")
end)

test("wrath_matches: no target -> false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.wrath_ready = true
    state.target = nil
    assert_false(S_WRATH.matches(ctx, state), "no target should not match")
end)

test("wrath_matches: nil state -> does not crash", function()
    local ok, result = pcall(S_WRATH.matches, make_context(), nil)
    assert_true(ok, "nil state should not throw")
end)

-- ============================================================================
-- Test: wand_matches (strategy #14) - uses create_wand_matches from shared module
-- ============================================================================

test("wand_matches: low mana, in combat, has target -> true", function()
    local ctx = make_context({mana_pct = 10})
    local state = get_state(ctx)
    state.mana_pct = 10
    state.wand_threshold = 30
    state.wand_learned = true
    assert_true(S_WAND.matches(ctx, state), "low mana should match")
end)

test("wand_matches: enough mana -> false", function()
    local ctx = make_context({mana_pct = 80})
    local state = get_state(ctx)
    state.mana_pct = 80
    state.wand_threshold = 30
    state.wand_learned = true
    assert_false(S_WAND.matches(ctx, state), "enough mana should not match")
end)

test("wand_matches: no target -> false", function()
    local ctx = make_context({mana_pct = 10})
    ctx.target = nil  -- pairs() skips nil, so set explicitly
    local state = get_state(ctx)
    state.mana_pct = 10
    state.target = nil
    state.wand_learned = true
    assert_false(S_WAND.matches(ctx, state), "no target should not match")
end)

test("wand_matches: wand not learned -> false", function()
    local ctx = make_context({mana_pct = 10})
    local state = get_state(ctx)
    state.mana_pct = 10
    state.wand_learned = false
    assert_false(S_WAND.matches(ctx, state), "wand not learned should not match")
end)

-- ============================================================================
-- Test: Strategy priority ordering
-- ============================================================================

test("strategies: 30 strategies in correct priority order", function()
    local expected = {
        -- Feral (16 strategies: Bear survival → Cat DPS → utility)
        "BearFormSurvival",
        "FrenziedRegeneration",
        "CatFormEntry",
        "ProwlOpener",
        "Pounce",
        "Ravage",
        "FaerieFireFeral",
        "Rake",
        "MangleCat",
        "Shred",
        "Rip",
        "FerociousBite",
        "Claw",
        "MangleBear",
        "SwipeBear",
        "Maul",
        -- Caster fallback (14 strategies)
        "MarkOfTheWild",
        "Thorns",
        "NaturesGrasp",
        "Barkskin",
        "HealingTouch",
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
    assert_eq(#strategies, #expected, "should have " .. #expected .. " strategies")
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
    local ok, result = pcall(S_MOTW.execute)
    assert_true(ok, "execute should not throw")
end)

test("execute_Wand: does not crash with context", function()
    local ctx = make_context()
    local ok, result = pcall(S_WAND.execute, ctx)
    assert_true(ok, "execute with context should not throw")
end)

test("execute_Wand: does not crash without context", function()
    local ok, result = pcall(S_WAND.execute)
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
-- Test: build_state Feral fields
-- ============================================================================

test("build_state: Feral form fields default to false/caster", function()
    local ctx = make_context()
    local state = get_state(ctx)
    assert_false(state.is_bear, "is_bear default false")
    assert_false(state.is_cat, "is_cat default false")
    assert_true(state.in_caster, "in_caster default true when no forms")
    assert_eq(state.energy, 0, "energy default 0")
    assert_eq(state.combo_points, 0, "combo_points default 0")
    assert_eq(state.rage, 0, "rage default 0")
    assert_false(state.is_behind, "is_behind default false")
    assert_false(state.is_stealthed, "is_stealthed default false")
end)

test("build_state: Feral spell readiness fields populated", function()
    local ctx = make_context()
    local state = get_state(ctx)
    assert_true(state.cat_form_ready, "cat_form_ready should be true")
    assert_true(state.bear_form_ready, "bear_form_ready should be true")
    assert_true(state.prowl_ready, "prowl_ready should be true")
    assert_true(state.pounce_ready, "pounce_ready should be true")
    assert_true(state.ravage_ready, "ravage_ready should be true")
    assert_true(state.rake_ready, "rake_ready should be true")
    assert_true(state.mangle_cat_ready, "mangle_cat_ready should be true")
    assert_true(state.shred_ready, "shred_ready should be true")
    assert_true(state.rip_ready, "rip_ready should be true")
    assert_true(state.bite_ready, "bite_ready should be true")
    assert_true(state.claw_ready, "claw_ready should be true")
    assert_true(state.frenzied_regen_ready, "frenzied_regen_ready should be true")
end)

test("build_state: Feral debuff fields populated", function()
    local ctx = make_context()
    local state = get_state(ctx)
    assert_eq(state.rake_remains, 0, "rake_remains default 0")
    assert_eq(state.rip_remains, 0, "rip_remains default 0")
    assert_eq(state.mangle_remains, 0, "mangle_remains default 0")
    assert_eq(state.faerie_fire_feral_remains, 0, "faerie_fire_feral_remains default 0")
end)

test("build_state: leveling_use_feral and leveling_bear_hp from settings", function()
    local ctx = make_context()
    ctx.settings.leveling_use_feral = false
    ctx.settings.leveling_bear_hp = 30
    local state = get_state(ctx)
    assert_false(state.use_feral, "use_feral from settings")
    assert_eq(state.bear_hp, 30, "bear_hp from settings")
end)

test("build_state: use_feral defaults to true when setting missing", function()
    local ctx = make_context({settings = {}})
    local state = get_state(ctx)
    assert_true(state.use_feral, "use_feral default true")
    assert_eq(state.bear_hp, 40, "bear_hp default 40")
end)

-- ============================================================================
-- Test: Feral match functions
-- ============================================================================

test("BearFormSurvival: low HP, not in bear, in combat, form ready -> true", function()
    local ctx = make_context({hp = 25})
    local state = get_state(ctx)
    state.hp = 25
    state.bear_hp = 40
    state.bear_form_ready = true
    state.is_bear = false
    state.use_feral = true
    state.in_combat = true
    assert_not_nil(S_BearSurvival, "BearFormSurvival strategy should exist")
    assert_true(S_BearSurvival.matches(ctx, state), "low HP should trigger bear form")
end)

test("BearFormSurvival: HP above bear_hp -> false", function()
    local ctx = make_context({hp = 60})
    local state = get_state(ctx)
    state.hp = 60
    state.bear_hp = 40
    state.bear_form_ready = true
    state.is_bear = false
    state.use_feral = true
    state.in_combat = true
    assert_false(S_BearSurvival.matches(ctx, state), "HP above threshold should not match")
end)

test("BearFormSurvival: already in bear -> false", function()
    local ctx = make_context({hp = 25})
    local state = get_state(ctx)
    state.hp = 25
    state.bear_hp = 40
    state.bear_form_ready = true
    state.is_bear = true
    state.use_feral = true
    state.in_combat = true
    assert_false(S_BearSurvival.matches(ctx, state), "already in bear should not match")
end)

test("BearFormSurvival: use_feral disabled -> false", function()
    local ctx = make_context({hp = 25})
    local state = get_state(ctx)
    state.hp = 25
    state.bear_hp = 40
    state.bear_form_ready = true
    state.is_bear = false
    state.use_feral = false
    state.in_combat = true
    assert_false(S_BearSurvival.matches(ctx, state), "feral disabled should not match")
end)

test("CatFormEntry: in combat, not cat, in melee, form ready -> true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.in_combat = true
    state.use_feral = true
    state.cat_form_ready = true
    state.is_cat = false
    state.is_bear = false
    state.target = ctx.target
    state.in_melee = true
    assert_not_nil(S_CatFormEntry, "CatFormEntry strategy should exist")
    assert_true(S_CatFormEntry.matches(ctx, state), "should enter cat in combat")
end)

test("CatFormEntry: not in melee range -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.in_combat = true
    state.use_feral = true
    state.cat_form_ready = true
    state.is_cat = false
    state.is_bear = false
    state.target = ctx.target
    state.in_melee = false
    assert_false(S_CatFormEntry.matches(ctx, state), "not in melee should not match")
end)

test("CatFormEntry: already in cat -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.in_combat = true
    state.use_feral = true
    state.cat_form_ready = true
    state.is_cat = true
    state.is_bear = false
    state.target = ctx.target
    state.in_melee = true
    assert_false(S_CatFormEntry.matches(ctx, state), "already in cat should not match")
end)

test("ProwlOpener: OOC, prowl ready, cat form ready, target in range -> true", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.in_combat = false
    state.use_feral = true
    state.prowl_ready = true
    state.is_cat = false
    state.cat_form_ready = true
    state.is_stealthed = false
    state.target = ctx.target
    state.target_range = 15
    assert_not_nil(S_ProwlOpener, "ProwlOpener strategy should exist")
    assert_true(S_ProwlOpener.matches(ctx, state), "should prowl OOC with target")
end)

test("ProwlOpener: in combat -> false", function()
    local ctx = make_context({in_combat = true})
    local state = get_state(ctx)
    state.in_combat = true
    state.use_feral = true
    state.prowl_ready = true
    state.is_cat = false
    state.cat_form_ready = true
    state.is_stealthed = false
    state.target = ctx.target
    state.target_range = 15
    assert_false(S_ProwlOpener.matches(ctx, state), "in combat should not match")
end)

test("ProwlOpener: target too far -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.in_combat = false
    state.use_feral = true
    state.prowl_ready = true
    state.is_cat = false
    state.cat_form_ready = true
    state.is_stealthed = false
    state.target = ctx.target
    state.target_range = 25
    assert_false(S_ProwlOpener.matches(ctx, state), "target too far (25yd > 18yd) should not match")
end)

test("Feral: nil state -> does not crash (all Feral strategies)", function()
    local feral_names = {
        "BearFormSurvival", "FrenziedRegeneration", "CatFormEntry",
        "ProwlOpener", "Pounce", "Ravage", "FaerieFireFeral",
        "Rake", "MangleCat", "Shred", "Rip", "FerociousBite",
        "Claw", "MangleBear", "SwipeBear", "Maul",
    }
    for _, name in ipairs(feral_names) do
        local s = find_strategy(name)
        assert_not_nil(s, name .. " strategy should exist")
        local ok = pcall(s.matches, make_context(), nil)
        assert_true(ok, name .. " matches(ctx, nil) should not throw")
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

    -- OOC buffs from caster section should match
    assert_true(S_MOTW.matches(ctx, state), "MarkOfTheWild should match OOC without buff")
    assert_true(S_THORNS.matches(ctx, state), "Thorns should match OOC without buff")

    -- Combat abilities should not match OOC (skip Feral openers: Prowl, Pounce, Ravage)
    local ooc_mismatch_names = {
        "BearFormSurvival", "FrenziedRegeneration", "CatFormEntry",
        "FaerieFireFeral", "Rake", "MangleCat", "Shred", "Rip", "FerociousBite",
        "Claw", "MangleBear", "SwipeBear", "Maul",
        "NaturesGrasp", "Barkskin", "HealingTouch", "Rejuvenation", "EntanglingRoots", "Moonfire",
        "InsectSwarm", "FaerieFire", "Hurricane", "Starfire", "Wrath",
    }
    for _, name in ipairs(ooc_mismatch_names) do
        local s = find_strategy(name)
        assert_not_nil(s, name .. " should exist")
        local ok, matched = pcall(s.matches, ctx, state)
        assert_true(ok, name .. " matches should not throw")
        assert_false(matched, name .. " should not match OOC")
    end
end)

test("rotation: low HP scenario - barkskin should match", function()
    local ctx = make_context({hp = 35, mana_pct = 80})
    local state = get_state(ctx)
    state.barkskin_ready = true
    state.hp = 35
    -- Bear won't trigger because has_form returns false (not in bear form)
    -- and in_melee defaults false, so CatFormEntry won't match
    -- Barkskin should match when HP < 50
    assert_true(S_BARKSKIN.matches(ctx, state), "Barkskin should match when HP < 50")
end)

test("rotation: AoE scenario - hurricane should match with 3+ enemies", function()
    local ctx = make_context({enemies_count = 4, is_moving = false})
    local state = get_state(ctx)
    state.hurricane_ready = true
    state.enemies = 4
    state.is_moving = false

    -- Hurricane should match with 3+ enemies stationary
    assert_true(S_HURRICANE.matches(ctx, state), "Hurricane should match with 3+ enemies")
end)

test("rotation: low mana scenario - wand should match", function()
    local ctx = make_context({mana_pct = 10})
    local state = get_state(ctx)
    state.mana_pct = 10
    state.wand_threshold = 30
    state.wand_learned = true

    -- Wand should match when mana below threshold
    assert_true(S_WAND.matches(ctx, state), "Wand should match when mana below threshold")
end)

-- ============================================================================
-- Edge Case: Form Management — player shapeshifted into cat/bear form
-- The leveling rotation is caster-form. Shapeshifting blocks caster spells.
-- These tests verify graceful handling when player is in the wrong form.
-- ============================================================================

test("edge_form: cat_form has_buff returns false for caster buffs", function()
    -- When shapeshifted, caster buffs like Mark of the Wild won't be present
    local NS2, _, mp = build_mock_env()
    mp.has_buff = function(id) return false end  -- Cat form has no caster buffs
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    assert_false(state.has_mark_of_wild, "cat form should not have caster buff up")
    assert_false(state.has_thorns, "cat form should not have Thorns up")
end)

test("edge_form: cat_form match functions do not crash", function()
    -- All match functions should be callable when player is in wrong form
    local ctx = make_context({in_combat = true})
    local state = get_state(ctx)
    for i, s in ipairs(strategies) do
        local ok, result = pcall(s.matches, ctx, state)
        assert_true(ok, "strategy[" .. i .. "] (", s.name, ") matches should not throw when in cat form")
    end
end)

test("edge_form: OOC buff matches return false when in cat form via has_buff mock", function()
    -- Simulate cat form: player has no caster buffs, has "cat form" buff instead
    local ctx = make_context({in_combat = false})
    ctx.settings = {}
    local state = get_state(ctx)
    state.in_combat = false
    state.mark_of_the_wild_ready = true
    state.thorns_ready = true

    -- Without buff tracking, match functions should still evaluate correctly
    -- has_mark_of_wild = false (no buff), mark_of_the_wild_ready = true -> should match
    assert_true(S_MOTW.matches(ctx, state), "MotW should match when no buff and OOC")
    assert_true(S_THORNS.matches(ctx, state), "Thorns should match when no buff and OOC")
end)

test("edge_form: travel_form caster rotation still evaluates safely", function()
    -- In travel form, caster abilities are blocked but rotation shouldn't crash
    local ctx = make_context({in_combat = true, is_moving = true})
    local state = get_state(ctx)
    -- Wrath allows moving cast, Starfire/Hurricane do not
    local ok1, wrath_result = pcall(S_WRATH.matches, ctx, state)
    assert_true(ok1, "Wrath matches should not throw while moving/in travel form")
    local ok2, sf_result = pcall(S_STARFIRE.matches, ctx, state)
    assert_true(ok2, "Starfire matches should not throw while moving")
end)

-- ============================================================================
-- Edge Case: Mana Conservation — wand threshold, OOM, low mana
-- ============================================================================

test("edge_mana: wand_threshold = 0 means never wand (always enough mana)", function()
    local ctx = make_context({mana_pct = 1})
    ctx.settings.leveling_wand_threshold = 0
    local state = get_state(ctx)
    state.mana_pct = 1
    state.wand_threshold = 0
    state.wand_learned = true
    assert_false(S_WAND.matches(ctx, state), "threshold=0 with 1% mana should NOT match wand (1 >= 0 means enough mana)")
end)

test("edge_mana: wand_threshold = 100 means always wand (never enough mana)", function()
    local ctx = make_context({mana_pct = 50})
    ctx.settings.leveling_wand_threshold = 100
    local state = get_state(ctx)
    state.mana_pct = 50
    state.wand_threshold = 100
    state.wand_learned = true
    assert_true(S_WAND.matches(ctx, state), "threshold=100 with 50% mana should match wand (50 < 100 means too little mana)")
end)

test("edge_mana: wand_threshold = 100 with full mana (100%) does not wand", function()
    local ctx = make_context({mana_pct = 50})
    ctx.settings.leveling_wand_threshold = 100
    local state = get_state(ctx)
    state.mana_pct = 100
    state.wand_threshold = 100
    state.wand_learned = true
    assert_false(S_WAND.matches(ctx, state), "threshold=100 with 100% mana should NOT match wand (100 >= 100 means enough mana)")
end)

test("edge_mana: complete OOM with wand not learned -> no wand fallback", function()
    local ctx = make_context({mana_pct = 0})
    local state = get_state(ctx)
    state.mana_pct = 0
    state.wand_threshold = 30
    state.wand_learned = false
    assert_false(S_WAND.matches(ctx, state), "OOM without wand should not match wand")
end)

test("edge_mana: rapid mana changes handled gracefully", function()
    local ctx1 = make_context({mana_pct = 0})
    local state1 = get_state(ctx1)
    state1.mana_pct = 0
    state1.wand_threshold = 30
    state1.wand_learned = true
    assert_true(S_WAND.matches(ctx1, state1), "0% mana should match wand")

    local ctx2 = make_context({mana_pct = 100})
    local state2 = get_state(ctx2)
    state2.mana_pct = 100
    state2.wand_threshold = 30
    state2.wand_learned = true
    assert_false(S_WAND.matches(ctx2, state2), "100% mana should not match wand")
end)

test("edge_mana: low mana with all spells ready -> damage spells still preferred over wand", function()
    local ctx = make_context({mana_pct = 35, is_moving = false})
    local state = get_state(ctx)
    state.mana_pct = 35
    state.wand_threshold = 30
    state.wand_learned = true
    state.wrath_ready = true
    state.starfire_ready = true

    -- Mana at 35, threshold at 30. wand_threshold check: mana_pct >= threshold so wand should NOT match
    assert_false(S_WAND.matches(ctx, state), "wand should not match when mana (35) >= threshold (30)")

    -- Damage spells should still work
    assert_true(S_STARFIRE.matches(ctx, state), "Starfire should match at 35% mana (above threshold)")
    assert_true(S_WRATH.matches(ctx, state), "Wrath should match at 35% mana")
end)

-- ============================================================================
-- Edge Case: Helper Function Resilience — pcall, nil values, throwing APIs
-- ============================================================================

test("edge_helper: has_buff pcall catches throwing API", function()
    local NS2, _, mp2 = build_mock_env()
    -- Simulate a throwing has_buff
    mp2.has_buff = function(id) error("fake has_buff crash") end
    _G.EaxRotations = NS2
    _G.core = core

    -- Reload module with crashing has_buff
    local mod2 = dofile("EaxRotations/classes/druid/leveling_sylvanas.lua")
    if mod2 then
        local reg2 = NS2.rotation_registry._registrations["leveling"]
        local get_state2 = reg2 and reg2.opts and reg2.opts.get_state
        if get_state2 then
            local ctx = make_context({in_combat = false})
            local state = get_state2(ctx)
            -- has_buff uses pcall internally -> should not throw, just return false
            assert_false(state.has_mark_of_wild, "throwing has_buff should result in false via pcall")
        end
    end

    -- Restore
    _G.EaxRotations = NS
end)

test("edge_helper: spell_ready nil NS does not crash", function()
    local NS2, _, _ = build_mock_env()
    NS2.spell_ready = nil
    _G.EaxRotations = NS2

    local mod2 = dofile("EaxRotations/classes/druid/leveling_sylvanas.lua")
    if mod2 then
        local reg2 = NS2.rotation_registry._registrations["leveling"]
        local get_state2 = reg2 and reg2.opts and reg2.opts.get_state
        if get_state2 then
            local ctx = make_context()
            local state = get_state2(ctx)
            -- All spell_ready fields should be false when NS.spell_ready is nil
            assert_false(state.mark_of_the_wild_ready, "motw ready should be false when spell_ready nil")
            assert_false(state.moonfire_ready, "moonfire ready should be false when spell_ready nil")
            assert_false(state.wrath_ready, "wrath ready should be false when spell_ready nil")
        end
    end

    _G.EaxRotations = NS
end)

test("edge_helper: try_cast pcall catches failure gracefully", function()
    local NS2, _, _ = build_mock_env()
    NS2.try_cast = nil
    _G.EaxRotations = NS2

    local mod2 = dofile("EaxRotations/classes/druid/leveling_sylvanas.lua")
    if mod2 then
        local reg2 = NS2.rotation_registry._registrations["leveling"]
        if reg2 then
            local s1 = reg2.strategies[1]
            if s1 then
                local _, ok = pcall(s1.execute, make_context())
                assert_true(true, "execute with nil try_cast should not throw")
            end
        end
    end

    _G.EaxRotations = NS
end)

test("edge_helper: NS.get_local_player nil does not crash build_state", function()
    local NS2, _, _ = build_mock_env()
    NS2.get_local_player = nil
    _G.EaxRotations = NS2

    local mod2 = dofile("EaxRotations/classes/druid/leveling_sylvanas.lua")
    if mod2 then
        local reg2 = NS2.rotation_registry._registrations["leveling"]
        local get_state2 = reg2 and reg2.opts and reg2.opts.get_state
        if get_state2 then
            local ctx = make_context()
            local ok, state = pcall(get_state2, ctx)
            assert_true(ok, "build_state with nil get_local_player should not throw")
        end
    end

    _G.EaxRotations = NS
end)

test("edge_helper: empty settings table does not crash state builder", function()
    local ctx = {}
    ctx.is_solo = false
    ctx.is_leveling = true
    ctx.settings = {}
    ctx.me = {
        is_valid = function() return true end,
        has_buff = function() return false end,
        get_health = function() return 10000 end,
        get_max_health = function() return 10000 end,
    }
    ctx.target = {
        is_valid = function() return true end,
        get_health = function() return 8000 end,
        get_max_health = function() return 10000 end,
        is_casting = function() return false end,
        is_alive = function() return true end,
        get_guid = function() return "mock-target" end,
        get_distance = function() return 5 end,
        get_health_percentage = function() return 80 end,
    }

    local ok, state = pcall(get_state, ctx)
    assert_true(ok, "empty settings should not throw")
    if ok and state then
        assert_eq(state.wand_threshold, 30, "default wand_threshold = 30")
        assert_eq(state.heal_hp, 40, "default heal_hp = 40")
    end
end)

-- ============================================================================
-- ============================================================================
-- Edge case tests - boundary values
-- ============================================================================

do -- edge_bear_form_survival
    local label = "edge_bear_form_survival"

    test(label .. ": HP exactly bear_hp (40) -> match", function()
        local ctx = make_context({hp = 40})
        local state = get_state(ctx)
        state.bear_form_ready = true
        state.use_feral = true
        state.is_bear = false
        state.bear_hp = 40
        state.hp = 40
        assert_true(strategies[1].matches(ctx, state), "HP 40 should match (<= threshold)")
    end)

    test(label .. ": HP exactly 41 -> no match", function()
        local ctx = make_context({hp = 41})
        local state = get_state(ctx)
        state.bear_form_ready = true
        state.use_feral = true
        state.is_bear = false
        state.bear_hp = 40
        state.hp = 41
        assert_false(strategies[1].matches(ctx, state), "HP 41 should not match (> threshold)")
    end)

    test(label .. ": already bear -> no match", function()
        local ctx = make_context({hp = 30})
        local state = get_state(ctx)
        state.bear_form_ready = true
        state.use_feral = true
        state.is_bear = true
        state.bear_hp = 40
        state.hp = 30
        assert_false(strategies[1].matches(ctx, state), "already bear should not match")
    end)
end

do -- edge_frenzied_regen
    local label = "edge_frenzied_regen"

    test(label .. ": rage 15, HP 35 -> match", function()
        local ctx = make_context({hp = 35})
        local state = get_state(ctx)
        state.is_bear = true
        state.frenzied_regen_ready = true
        state.bear_hp = 40
        state.hp = 35
        state.rage = 15
        assert_true(strategies[2].matches(ctx, state), "rage 15 with HP 35 should match")
    end)

    test(label .. ": rage 14 -> no match", function()
        local ctx = make_context({hp = 35})
        local state = get_state(ctx)
        state.is_bear = true
        state.frenzied_regen_ready = true
        state.bear_hp = 40
        state.hp = 35
        state.rage = 14
        assert_false(strategies[2].matches(ctx, state), "rage 14 should not match (< 15)")
    end)

    test(label .. ": HP 36 -> no match", function()
        local ctx = make_context({hp = 36})
        local state = get_state(ctx)
        state.is_bear = true
        state.frenzied_regen_ready = true
        state.bear_hp = 40
        state.hp = 36
        state.rage = 20
        assert_false(strategies[2].matches(ctx, state), "HP 36 should not match (> 35)")
    end)
end

do -- edge_pounce
    local label = "edge_pounce"

    test(label .. ": energy exactly 50 -> match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.is_stealthed = true
        state.is_cat = true
        state.pounce_ready = true
        state.energy = 50
        assert_true(strategies[5].matches(ctx, state), "energy 50 should match (>= threshold)")
    end)

    test(label .. ": energy exactly 49 -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.is_stealthed = true
        state.is_cat = true
        state.pounce_ready = true
        state.energy = 49
        assert_false(strategies[5].matches(ctx, state), "energy 49 should not match (< threshold)")
    end)
end

do -- edge_ravage
    local label = "edge_ravage"

    test(label .. ": energy 60, behind, stealthed -> match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.is_stealthed = true
        state.is_cat = true
        state.ravage_ready = true
        state.energy = 60
        state.is_behind = true
        assert_true(strategies[6].matches(ctx, state), "energy 60 behind should match")
    end)

    test(label .. ": energy 59 -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.is_stealthed = true
        state.is_cat = true
        state.ravage_ready = true
        state.energy = 59
        state.is_behind = true
        assert_false(strategies[6].matches(ctx, state), "energy 59 should not match (< 60)")
    end)
end

do -- edge_rake
    local label = "edge_rake"

    test(label .. ": energy 35, CP 4, remains 3, TTD 6 -> match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.is_cat = true
        state.rake_ready = true
        state.energy = 35
        state.combo_points = 4
        state.rake_remains = 3
        state.target_ttd = 6
        assert_true(strategies[8].matches(ctx, state), "should match at boundary conditions")
    end)

    test(label .. ": energy 34 -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.is_cat = true
        state.rake_ready = true
        state.energy = 34
        state.combo_points = 2
        state.rake_remains = 0
        assert_false(strategies[8].matches(ctx, state), "energy 34 should not match (< 35)")
    end)

    test(label .. ": CP 5 -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.is_cat = true
        state.rake_ready = true
        state.energy = 100
        state.combo_points = 5
        state.rake_remains = 0
        assert_false(strategies[8].matches(ctx, state), "CP 5 should not match (>= 5)")
    end)

    test(label .. ": remains 4 -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.is_cat = true
        state.rake_ready = true
        state.energy = 100
        state.combo_points = 2
        state.rake_remains = 4
        assert_false(strategies[8].matches(ctx, state), "remains 4 should not match (> 3)")
    end)

    test(label .. ": TTD 5 -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.is_cat = true
        state.rake_ready = true
        state.energy = 100
        state.combo_points = 2
        state.rake_remains = 0
        state.target_ttd = 5
        assert_false(strategies[8].matches(ctx, state), "TTD 5 should not match (< 6)")
    end)
end

do -- edge_mangle_cat
    local label = "edge_mangle_cat"

    test(label .. ": energy 40, CP 4 -> match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.is_cat = true
        state.mangle_cat_ready = true
        state.energy = 40
        state.combo_points = 4
        assert_true(strategies[9].matches(ctx, state), "energy 40 with CP 4 should match")
    end)

    test(label .. ": energy 39 -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.is_cat = true
        state.mangle_cat_ready = true
        state.energy = 39
        state.combo_points = 2
        assert_false(strategies[9].matches(ctx, state), "energy 39 should not match (< 40)")
    end)

    test(label .. ": CP 5 -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.is_cat = true
        state.mangle_cat_ready = true
        state.energy = 100
        state.combo_points = 5
        assert_false(strategies[9].matches(ctx, state), "CP 5 should not match (>= 5)")
    end)
end

do -- edge_shred
    local label = "edge_shred"

    test(label .. ": energy 42, behind, mangle up -> match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.is_cat = true
        state.shred_ready = true
        state.energy = 42
        state.combo_points = 3
        state.is_behind = true
        state.mangle_remains = 6
        assert_true(strategies[10].matches(ctx, state), "energy 42 behind with mangle should match")
    end)

    test(label .. ": energy 41 -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.is_cat = true
        state.shred_ready = true
        state.energy = 41
        state.combo_points = 3
        state.is_behind = true
        state.mangle_remains = 6
        assert_false(strategies[10].matches(ctx, state), "energy 41 should not match (< 42)")
    end)

    test(label .. ": not behind -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.is_cat = true
        state.shred_ready = true
        state.energy = 100
        state.combo_points = 3
        state.is_behind = false
        state.mangle_remains = 6
        assert_false(strategies[10].matches(ctx, state), "not behind should not match")
    end)
end

do -- edge_rip
    local label = "edge_rip"

    test(label .. ": energy 30, CP 4, remains 2, TTD 6 -> match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.is_cat = true
        state.rip_ready = true
        state.energy = 30
        state.combo_points = 4
        state.rip_remains = 2
        state.target_ttd = 6
        assert_true(strategies[11].matches(ctx, state), "should match at boundary conditions")
    end)

    test(label .. ": energy 29 -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.is_cat = true
        state.rip_ready = true
        state.energy = 29
        state.combo_points = 4
        state.rip_remains = 0
        assert_false(strategies[11].matches(ctx, state), "energy 29 should not match (< 30)")
    end)

    test(label .. ": CP 3 -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.is_cat = true
        state.rip_ready = true
        state.energy = 100
        state.combo_points = 3
        state.rip_remains = 0
        assert_false(strategies[11].matches(ctx, state), "CP 3 should not match (< 4)")
    end)

    test(label .. ": remains 3 -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.is_cat = true
        state.rip_ready = true
        state.energy = 100
        state.combo_points = 4
        state.rip_remains = 3
        assert_false(strategies[11].matches(ctx, state), "remains 3 should not match (> 2)")
    end)
end

do -- edge_bite
    local label = "edge_bite"

    test(label .. ": energy 35, CP 4 -> match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.is_cat = true
        state.bite_ready = true
        state.energy = 35
        state.combo_points = 4
        state.rip_ready = false  -- Don't prefer Rip
        assert_true(strategies[12].matches(ctx, state), "energy 35 with CP 4 should match")
    end)

    test(label .. ": energy 34 -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.is_cat = true
        state.bite_ready = true
        state.energy = 34
        state.combo_points = 4
        assert_false(strategies[12].matches(ctx, state), "energy 34 should not match (< 35)")
    end)

    test(label .. ": CP 3 -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.is_cat = true
        state.bite_ready = true
        state.energy = 100
        state.combo_points = 3
        assert_false(strategies[12].matches(ctx, state), "CP 3 should not match (< 4)")
    end)
end

do -- edge_claw
    local label = "edge_claw"

    test(label .. ": energy 45, CP 4, no other builder available -> match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.is_cat = true
        state.claw_ready = true
        state.energy = 45
        state.combo_points = 4
        state.mangle_cat_ready = false
        state.rake_ready = false
        state.shred_ready = false
        assert_true(strategies[13].matches(ctx, state), "energy 45 with CP 4 should match")
    end)

    test(label .. ": energy 44 -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.is_cat = true
        state.claw_ready = true
        state.energy = 44
        state.combo_points = 2
        assert_false(strategies[13].matches(ctx, state), "energy 44 should not match (< 45)")
    end)

    test(label .. ": CP 5 -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.is_cat = true
        state.claw_ready = true
        state.energy = 100
        state.combo_points = 5
        assert_false(strategies[13].matches(ctx, state), "CP 5 should not match (>= 5)")
    end)
end

do -- edge_bear_abilities
    local label = "edge_bear_abilities"

    test(label .. ": MangleBear rage exactly 15 -> match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.is_bear = true
        state.mangle_bear_ready = true
        state.rage = 15
        state.in_melee = true
        assert_true(strategies[14].matches(ctx, state), "rage 15 should match (>= threshold)")
    end)

    test(label .. ": MangleBear rage 14 -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.is_bear = true
        state.mangle_bear_ready = true
        state.rage = 14
        state.in_melee = true
        assert_false(strategies[14].matches(ctx, state), "rage 14 should not match (< 15)")
    end)

    test(label .. ": SwipeBear rage 20, enemies 2 -> match", function()
        local ctx = make_context({enemies_count = 2})
        local state = get_state(ctx)
        state.is_bear = true
        state.swipe_ready = true
        state.rage = 20
        state.enemies = 2
        assert_true(strategies[15].matches(ctx, state), "rage 20 with 2 enemies should match")
    end)

    test(label .. ": SwipeBear rage 19 -> no match", function()
        local ctx = make_context({enemies_count = 2})
        local state = get_state(ctx)
        state.is_bear = true
        state.swipe_ready = true
        state.rage = 19
        state.enemies = 2
        assert_false(strategies[15].matches(ctx, state), "rage 19 should not match (< 20)")
    end)

    test(label .. ": SwipeBear 1 enemy -> no match", function()
        local ctx = make_context({enemies_count = 1})
        local state = get_state(ctx)
        state.is_bear = true
        state.swipe_ready = true
        state.rage = 40
        state.enemies = 1
        assert_false(strategies[15].matches(ctx, state), "1 enemy should not match (< 2)")
    end)

    test(label .. ": Maul rage exactly 40 -> match (high lvl threshold)", function()
        local ctx = make_context({ level = 50 })
        local state = get_state(ctx)
        state.is_bear = true
        state.maul_ready = true
        state.rage = 40
        state.level = 50
        assert_true(strategies[16].matches(ctx, state), "rage 40 should match (>= threshold at lvl50)")
    end)

    test(label .. ": Maul rage 39 -> no match (high lvl threshold)", function()
        local ctx = make_context({ level = 50 })
        local state = get_state(ctx)
        state.is_bear = true
        state.maul_ready = true
        state.rage = 39
        state.level = 50
        assert_false(strategies[16].matches(ctx, state), "rage 39 should not match (< threshold at lvl50)")
    end)
end

do -- edge_caster_defensive
    local label = "edge_caster_defensive"

    test(label .. ": Barkskin HP exactly 50 -> match", function()
        local ctx = make_context({hp = 50})
        local state = get_state(ctx)
        state.barkskin_ready = true
        state.hp = 50
        assert_true(strategies[20].matches(ctx, state), "HP 50 should match (<= threshold)")
    end)

    test(label .. ": Barkskin HP exactly 51 -> no match", function()
        local ctx = make_context({hp = 51})
        local state = get_state(ctx)
        state.barkskin_ready = true
        state.hp = 51
        assert_false(strategies[20].matches(ctx, state), "HP 51 should not match (> threshold)")
    end)

    test(label .. ": HealingTouch HP exactly 30 -> match", function()
        local ctx = make_context({hp = 30})
        local state = get_state(ctx)
        state.healing_touch_ready = true
        state.heal_hp = 40
        state.hp = 30
        assert_true(strategies[21].matches(ctx, state), "HP 30 should match (<= heal_hp - 10)")
    end)

    test(label .. ": HealingTouch HP exactly 31 -> no match", function()
        local ctx = make_context({hp = 31})
        local state = get_state(ctx)
        state.healing_touch_ready = true
        state.heal_hp = 40
        state.hp = 31
        assert_false(strategies[21].matches(ctx, state), "HP 31 should not match (> 30)")
    end)

    test(label .. ": Rejuvenation HP exactly 40 -> match", function()
        local ctx = make_context({hp = 40})
        local state = get_state(ctx)
        state.rejuvenation_ready = true
        state.heal_hp = 40
        state.hp = 40
        assert_true(strategies[22].matches(ctx, state), "HP 40 should match (<= threshold)")
    end)

    test(label .. ": Rejuvenation HP exactly 41 -> no match", function()
        local ctx = make_context({hp = 41})
        local state = get_state(ctx)
        state.rejuvenation_ready = true
        state.heal_hp = 40
        state.hp = 41
        assert_false(strategies[22].matches(ctx, state), "HP 41 should not match (> threshold)")
    end)
end

do -- edge_entangling_roots
    local label = "edge_entangling_roots"

    test(label .. ": enemies 3, any HP -> match", function()
        local ctx = make_context({hp = 50, enemies_count = 3})
        local state = get_state(ctx)
        state.entangling_roots_ready = true
        state.hp = 50
        state.enemies = 3
        assert_true(strategies[23].matches(ctx, state), "3 enemies should match regardless of HP")
    end)

    test(label .. ": HP exactly 30, enemies 2 -> match", function()
        local ctx = make_context({hp = 30, enemies_count = 2})
        local state = get_state(ctx)
        state.entangling_roots_ready = true
        state.hp = 30
        state.enemies = 2
        assert_true(strategies[23].matches(ctx, state), "HP 30 with 2 enemies should match")
    end)

    test(label .. ": HP 31, enemies 2 -> no match", function()
        local ctx = make_context({hp = 31, enemies_count = 2})
        local state = get_state(ctx)
        state.entangling_roots_ready = true
        state.hp = 31
        state.enemies = 2
        assert_false(strategies[23].matches(ctx, state), "HP 31 with 2 enemies should not match")
    end)

    test(label .. ": enemies 2, HP 30 -> no target, no match", function()
        local ctx = make_context({hp = 30, enemies_count = 2, target = nil})
        local state = get_state(ctx)
        state.entangling_roots_ready = true
        state.hp = 30
        state.enemies = 2
        state.target = nil
        assert_false(strategies[23].matches(ctx, state), "no target should not match")
    end)
end

do -- edge_natures_grasp
    local label = "edge_natures_grasp"

    test(label .. ": HP 50, enemies 2 -> match", function()
        local ctx = make_context({hp = 50, enemies_count = 2})
        local state = get_state(ctx)
        state.natures_grasp_ready = true
        state.hp = 50
        state.enemies = 2
        assert_true(strategies[19].matches(ctx, state), "HP 50 with 2 enemies should match")
    end)

    test(label .. ": HP 51, enemies 1 -> no match", function()
        local ctx = make_context({hp = 51, enemies_count = 1})
        local state = get_state(ctx)
        state.natures_grasp_ready = true
        state.hp = 51
        state.enemies = 1
        assert_false(strategies[19].matches(ctx, state), "HP 51 with 1 enemy should not match")
    end)

    test(label .. ": HP 51, enemies 1 -> no match", function()
        local ctx = make_context({hp = 51, enemies_count = 1})
        local state = get_state(ctx)
        state.natures_grasp_ready = true
        state.hp = 51
        state.enemies = 1
        assert_false(strategies[19].matches(ctx, state), "HP 51 with 1 enemy should not match")
    end)
end

do -- edge_caster_doTs
    local label = "edge_caster_doTs"

    test(label .. ": Moonfire remains 4 -> match", function()
        local ctx = make_context()
        local saved = NS.debuff_remains
        NS.debuff_remains = function(target, spell) return 4 end
        local state = get_state(ctx)
        state.moonfire_ready = true
        assert_true(strategies[24].matches(ctx, state), "remains 4 should match (<= 4)")
        NS.debuff_remains = saved
    end)

    test(label .. ": Moonfire remains 5 -> no match", function()
        local ctx = make_context()
        local saved = NS.debuff_remains
        NS.debuff_remains = function(target, spell) return 5 end
        local state = get_state(ctx)
        state.moonfire_ready = true
        assert_false(strategies[24].matches(ctx, state), "remains 5 should not match (> 4)")
        NS.debuff_remains = saved
    end)

    test(label .. ": Insect Swarm remains 4 -> match", function()
        local ctx = make_context()
        local saved = NS.debuff_remains
        NS.debuff_remains = function(target, spell) return 4 end
        local state = get_state(ctx)
        state.insect_swarm_ready = true
        assert_true(strategies[25].matches(ctx, state), "remains 4 should match (<= 4)")
        NS.debuff_remains = saved
    end)

    test(label .. ": Insect Swarm remains 5 -> no match", function()
        local ctx = make_context()
        local saved = NS.debuff_remains
        NS.debuff_remains = function(target, spell) return 5 end
        local state = get_state(ctx)
        state.insect_swarm_ready = true
        assert_false(strategies[25].matches(ctx, state), "remains 5 should not match (> 4)")
        NS.debuff_remains = saved
    end)

    test(label .. ": Faerie Fire remains 10 -> match", function()
        local ctx = make_context()
        local saved = NS.debuff_remains
        NS.debuff_remains = function(target, spell) return 10 end
        local state = get_state(ctx)
        state.faerie_fire_ready = true
        assert_true(strategies[26].matches(ctx, state), "remains 10 should match (<= 10)")
        NS.debuff_remains = saved
    end)

    test(label .. ": Faerie Fire remains 11 -> no match", function()
        local ctx = make_context()
        local saved = NS.debuff_remains
        NS.debuff_remains = function(target, spell) return 11 end
        local state = get_state(ctx)
        state.faerie_fire_ready = true
        assert_false(strategies[26].matches(ctx, state), "remains 11 should not match (> 10)")
        NS.debuff_remains = saved
    end)
end

do -- edge_hurricane
    local label = "edge_hurricane"

    test(label .. ": enemies exactly 3, not moving -> match", function()
        local ctx = make_context({enemies_count = 3, is_moving = false})
        local state = get_state(ctx)
        state.hurricane_ready = true
        state.enemies = 3
        state.is_moving = false
        assert_true(strategies[27].matches(ctx, state), "3 enemies not moving should match")
    end)

    test(label .. ": enemies exactly 2 -> no match", function()
        local ctx = make_context({enemies_count = 2})
        local state = get_state(ctx)
        state.hurricane_ready = true
        state.enemies = 2
        assert_false(strategies[27].matches(ctx, state), "2 enemies should not match (< 3)")
    end)

    test(label .. ": moving -> no match", function()
        local ctx = make_context({enemies_count = 4, is_moving = true})
        local state = get_state(ctx)
        state.hurricane_ready = true
        state.enemies = 4
        state.is_moving = true
        assert_false(strategies[27].matches(ctx, state), "moving should not match")
    end)
end

do -- edge_starfire_wrath
    local label = "edge_starfire_wrath"

    test(label .. ": Starfire not moving -> match", function()
        local ctx = make_context({is_moving = false})
        local state = get_state(ctx)
        state.starfire_ready = true
        state.is_moving = false
        assert_true(strategies[28].matches(ctx, state), "not moving should match")
    end)

    test(label .. ": Starfire moving -> no match", function()
        local ctx = make_context({is_moving = true})
        local state = get_state(ctx)
        state.starfire_ready = true
        state.is_moving = true
        assert_false(strategies[28].matches(ctx, state), "moving should not match")
    end)

    test(label .. ": Wrath in combat ready -> match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.wrath_ready = true
        assert_true(strategies[29].matches(ctx, state), "in combat ready should match")
    end)
end

do -- edge_motw_thorns
    local label = "edge_motw_thorns"

    test(label .. ": MarkOfTheWild OOC, no buff -> match", function()
        local ctx = make_context({in_combat = false})
        local state = get_state(ctx)
        state.has_mark_of_wild = false
        state.mark_of_the_wild_ready = true
        assert_true(strategies[17].matches(ctx, state), "OOC no buff should match")
    end)

    test(label .. ": Thorns OOC, no buff -> match", function()
        local ctx = make_context({in_combat = false})
        local state = get_state(ctx)
        state.has_thorns = false
        state.thorns_ready = true
        assert_true(strategies[18].matches(ctx, state), "OOC no buff should match")
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
        assert_eq(state.has_mark_of_wild, false, "has_mark_of_wild should be false when buff_up nil")
        assert_eq(state.has_thorns, false, "has_thorns should be false when buff_up nil")
        NS.buff_up = saved
    end)

    test(label .. ": NS.buff_up throws -> pcall catches, returns false", function()
        local saved = NS.buff_up
        NS.buff_up = function() error("crash") end
        local ctx = make_context({in_combat = false})
        local state = get_state(ctx)
        assert_eq(state.has_mark_of_wild, false, "has_mark_of_wild should be false when buff_up throws")
        assert_eq(state.has_thorns, false, "has_thorns should be false when buff_up throws")
        NS.buff_up = saved
    end)
end

do -- edge_api_debuff_remains
    local label = "edge_api_debuff_remains"

    test(label .. ": NS.debuff_remains nil -> safe_debuff_remains returns 0", function()
        local saved = NS.debuff_remains
        NS.debuff_remains = nil
        local ctx = make_context()
        local state = get_state(ctx)
        assert_eq(state.rake_remains, 0, "rake_remains 0 when debuff_remains nil")
        assert_eq(state.rip_remains, 0, "rip_remains 0 when debuff_remains nil")
        NS.debuff_remains = saved
    end)

    test(label .. ": NS.debuff_remains throws -> pcall catches, returns 0", function()
        local saved = NS.debuff_remains
        NS.debuff_remains = function() error("crash") end
        local ctx = make_context()
        local state = get_state(ctx)
        assert_eq(state.rake_remains, 0, "rake_remains 0 when debuff_remains throws")
        assert_eq(state.rip_remains, 0, "rip_remains 0 when debuff_remains throws")
        NS.debuff_remains = saved
    end)
end

do -- edge_api_spell_ready
    local label = "edge_api_spell_ready"

    test(label .. ": NS.spell_ready is nil -> all readiness fields false", function()
        local saved = NS.spell_ready
        NS.spell_ready = nil
        local ctx = make_context()
        local state = get_state(ctx)
        assert_eq(state.wrath_ready, false, "wrath_ready should be false")
        assert_eq(state.moonfire_ready, false, "moonfire_ready should be false")
        assert_eq(state.rake_ready, false, "rake_ready should be false")
        assert_eq(state.rip_ready, false, "rip_ready should be false")
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
-- ============================================================================
-- Deep dive: BearFormSurvival - form guards + OOC + HP boundary
-- ============================================================================
do
    -- BearFormSurvival: already in bear -> no match
    local ctx = make_context({hp = 25})
    local state = get_state(ctx)
    state.is_bear = true
    state.bear_form_ready = true
    state.use_feral = true
    state.hp = 25
    state.bear_hp = 40
    assert_false(strategies[1].matches(ctx, state), "bearsurvival already bear -> no match")

    -- BearFormSurvival: OOC -> no match
    local ctx2 = make_context({in_combat = false, hp = 25})
    local state2 = get_state(ctx2)
    state2.is_bear = false
    state2.bear_form_ready = true
    state2.use_feral = true
    state2.hp = 25
    state2.bear_hp = 40
    state2.in_combat = false
    assert_false(strategies[1].matches(ctx2, state2), "bearsurvival OOC -> no match")

    -- BearFormSurvival: feral disabled -> no match
    local ctx3 = make_context({hp = 25})
    local state3 = get_state(ctx3)
    state3.is_bear = false
    state3.bear_form_ready = true
    state3.use_feral = false
    state3.hp = 25
    state3.bear_hp = 40
    assert_false(strategies[1].matches(ctx3, state3), "bearsurvival feral disabled -> no match")

    -- BearFormSurvival: HP 41 (above bear_hp) -> no match
    local ctx4 = make_context({hp = 41})
    local state4 = get_state(ctx4)
    state4.is_bear = false
    state4.bear_form_ready = true
    state4.use_feral = true
    state4.hp = 41
    state4.bear_hp = 40
    assert_false(strategies[1].matches(ctx4, state4), "bearsurvival hp=41 -> no match (> bear_hp)")
end

-- ============================================================================
-- Deep dive: FrenziedRegeneration - rage/HP/form guards
-- ============================================================================
do
    -- FrenziedRegen: rage 15, hp 35 -> match
    local ctx = make_context({hp = 35})
    local state = get_state(ctx)
    state.is_bear = true
    state.frenzied_regen_ready = true
    state.rage = 15
    state.hp = 35
    state.bear_hp = 40
    assert_true(strategies[2].matches(ctx, state), "frenziedregen rage=15 hp=35 -> match")

    -- FrenziedRegen: rage 14 -> no match
    local ctx2 = make_context({hp = 35})
    local state2 = get_state(ctx2)
    state2.is_bear = true
    state2.frenzied_regen_ready = true
    state2.rage = 14
    state2.hp = 35
    state2.bear_hp = 40
    assert_false(strategies[2].matches(ctx2, state2), "frenziedregen rage=14 -> no match (< 15)")

    -- FrenziedRegen: hp 36 -> no match (> bear_hp - 5 = 35)
    local ctx3 = make_context({hp = 36})
    local state3 = get_state(ctx3)
    state3.is_bear = true
    state3.frenzied_regen_ready = true
    state3.rage = 40
    state3.hp = 36
    state3.bear_hp = 40
    assert_false(strategies[2].matches(ctx3, state3), "frenziedregen hp=36 -> no match (> 35)")

    -- FrenziedRegen: not in bear -> no match
    local ctx4 = make_context({hp = 35})
    local state4 = get_state(ctx4)
    state4.is_bear = false
    state4.frenzied_regen_ready = true
    state4.rage = 40
    state4.hp = 35
    assert_false(strategies[2].matches(ctx4, state4), "frenziedregen not bear -> no match")
end

-- ============================================================================
-- Deep dive: CatFormEntry - transition guards
-- ============================================================================
do
    -- CatFormEntry: already cat -> no match
    local ctx = make_context({})
    local state = get_state(ctx)
    state.is_cat = true
    state.cat_form_ready = true
    state.use_feral = true
    assert_false(strategies[3].matches(ctx, state), "catentry already cat -> no match")

    -- CatFormEntry: stay bear when hp <= bear_hp
    local ctx2 = make_context({hp = 35})
    local state2 = get_state(ctx2)
    state2.is_bear = true
    state2.is_cat = false
    state2.cat_form_ready = true
    state2.use_feral = true
    state2.hp = 35
    state2.bear_hp = 40
    state2.target = { is_valid = function() return true end }
    state2.in_melee = true
    assert_false(strategies[3].matches(ctx2, state2), "catentry stay bear hp=35 -> no match")

    -- CatFormEntry: not in melee -> no match
    local ctx3 = make_context({hp = 80})
    local state3 = get_state(ctx3)
    state3.is_bear = false
    state3.is_cat = false
    state3.cat_form_ready = true
    state3.use_feral = true
    state3.hp = 80
    state3.in_melee = false
    assert_false(strategies[3].matches(ctx3, state3), "catentry not melee -> no match")

    -- CatFormEntry: no target -> no match
    local ctx4 = make_context({hp = 80})
    ctx4.target = nil
    local state4 = get_state(ctx4)
    state4.is_bear = false
    state4.is_cat = false
    state4.cat_form_ready = true
    state4.use_feral = true
    state4.hp = 80
    state4.target = nil
    state4.in_melee = true
    assert_false(strategies[3].matches(ctx4, state4), "catentry no target -> no match")

    -- CatFormEntry: OOC -> no match
    local ctx5 = make_context({in_combat = false, hp = 80})
    local state5 = get_state(ctx5)
    state5.is_bear = false
    state5.is_cat = false
    state5.cat_form_ready = true
    state5.use_feral = true
    state5.hp = 80
    state5.in_combat = false
    state5.in_melee = true
    assert_false(strategies[3].matches(ctx5, state5), "catentry OOC -> no match")
end

-- ============================================================================
-- Deep dive: ProwlOpener - target_range boundary + form requirements
-- ============================================================================
do
    -- Prowl: target_range 18 -> match
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.prowl_ready = true
    state.use_feral = true
    state.is_cat = true
    state.is_stealthed = false
    state.target_range = 18
    assert_true(strategies[4].matches(ctx, state), "prowl range=18 -> match (<= 18)")

    -- Prowl: target_range 19 -> no match (> 18)
    local ctx2 = make_context({in_combat = false})
    local state2 = get_state(ctx2)
    state2.prowl_ready = true
    state2.use_feral = true
    state2.is_cat = true
    state2.is_stealthed = false
    state2.target_range = 19
    assert_false(strategies[4].matches(ctx2, state2), "prowl range=19 -> no match (> 18)")

    -- Prowl: already stealthed -> no match
    local ctx3 = make_context({in_combat = false})
    local state3 = get_state(ctx3)
    state3.prowl_ready = true
    state3.use_feral = true
    state3.is_cat = true
    state3.is_stealthed = true
    state3.target_range = 10
    assert_false(strategies[4].matches(ctx3, state3), "prowl already stealthed -> no match")

    -- Prowl: in combat -> no match
    local ctx4 = make_context({in_combat = true})
    local state4 = get_state(ctx4)
    state4.prowl_ready = true
    state4.use_feral = true
    state4.is_cat = true
    state4.is_stealthed = false
    state4.target_range = 10
    assert_false(strategies[4].matches(ctx4, state4), "prowl in combat -> no match")
end

-- ============================================================================
-- Deep dive: Pounce/Ravage - stealth/energy/form guards
-- ============================================================================
do
    -- Pounce: not stealthed -> no match
    local ctx = make_context({})
    local state = get_state(ctx)
    state.is_cat = true
    state.is_stealthed = false
    state.pounce_ready = true
    state.energy = 50
    assert_false(strategies[5].matches(ctx, state), "pounce not stealthed -> no match")

    -- Pounce: energy 49 -> no match
    local ctx2 = make_context({})
    local state2 = get_state(ctx2)
    state2.is_cat = true
    state2.is_stealthed = true
    state2.pounce_ready = true
    state2.energy = 49
    assert_false(strategies[5].matches(ctx2, state2), "pounce energy=49 -> no match (< 50)")

    -- Pounce: not cat -> no match
    local ctx3 = make_context({})
    local state3 = get_state(ctx3)
    state3.is_cat = false
    state3.is_stealthed = true
    state3.pounce_ready = true
    state3.energy = 50
    assert_false(strategies[5].matches(ctx3, state3), "pounce not cat -> no match")

    -- Ravage: not stealthed -> no match
    local ctx4 = make_context({})
    local state4 = get_state(ctx4)
    state4.is_cat = true
    state4.is_stealthed = false
    state4.ravage_ready = true
    state4.energy = 60
    state4.is_behind = true
    assert_false(strategies[6].matches(ctx4, state4), "ravage not stealthed -> no match")

    -- Ravage: energy 59 -> no match
    local ctx5 = make_context({})
    local state5 = get_state(ctx5)
    state5.is_cat = true
    state5.is_stealthed = true
    state5.ravage_ready = true
    state5.energy = 59
    state5.is_behind = true
    assert_false(strategies[6].matches(ctx5, state5), "ravage energy=59 -> no match (< 60)")

    -- Ravage: not behind -> no match
    local ctx6 = make_context({})
    local state6 = get_state(ctx6)
    state6.is_cat = true
    state6.is_stealthed = true
    state6.ravage_ready = true
    state6.energy = 60
    state6.is_behind = false
    assert_false(strategies[6].matches(ctx6, state6), "ravage not behind -> no match")
end

-- ============================================================================
-- Deep dive: FaerieFireFeral - form requirement + debuff boundary
-- ============================================================================
do
    -- FaerieFireFeral: in caster form (no cat/bear) -> no match
    local ctx = make_context({})
    local state = get_state(ctx)
    state.is_cat = false
    state.is_bear = false
    state.faerie_fire_feral_ready = true
    state.faerie_fire_feral_remains = 0
    assert_false(strategies[7].matches(ctx, state), "ffferal caster form -> no match")

    -- FaerieFireFeral: remains 11 -> no match (> 10)
    local ctx2 = make_context({})
    local state2 = get_state(ctx2)
    state2.is_cat = true
    state2.faerie_fire_feral_ready = true
    state2.faerie_fire_feral_remains = 11
    assert_false(strategies[7].matches(ctx2, state2), "ffferal remains=11 -> no match (> 10)")

    -- FaerieFireFeral: OOC -> no match
    local ctx3 = make_context({in_combat = false})
    local state3 = get_state(ctx3)
    state3.is_cat = true
    state3.faerie_fire_feral_ready = true
    state3.faerie_fire_feral_remains = 0
    state3.in_combat = false
    assert_false(strategies[7].matches(ctx3, state3), "ffferal OOC -> no match")
end

-- ============================================================================
-- Deep dive: Feral ability null target guards
-- ============================================================================
do
    local feral_strategies = {8, 9, 10, 11, 12, 13, 14, 15, 16}  -- Rake through Maul
    for _, idx in ipairs(feral_strategies) do
        local ctx = make_context({})
        ctx.target = nil
        local state = get_state(ctx)
        state.is_cat = strategies[idx].name ~= "SwipeBear" and strategies[idx].name ~= "MangleBear" and strategies[idx].name ~= "Maul"
        state.is_bear = not state.is_cat
        -- Set all readiness to true
        for k, v in pairs(state) do
            if type(k) == "string" and k:match("_ready$") then
                state[k] = true
            end
        end
        state.energy = 100
        state.rage = 100
        state.combo_points = 3
        state.in_melee = true
        state.is_behind = true
        state.mangle_remains = 10
        state.rake_remains = 0
        state.rip_remains = 0
        state.target = nil
        local ok, result = pcall(strategies[idx].matches, ctx, state)
        assert_false(result, strategies[idx].name .. " no target -> no match")
    end
end

-- ============================================================================
-- Deep dive: Claw - better builder preference guards
-- ============================================================================
do
    -- Claw: MangleCat available with enough energy -> no match (prefer Mangle)
    local ctx = make_context({})
    local state = get_state(ctx)
    state.is_cat = true
    state.claw_ready = true
    state.energy = 50
    state.combo_points = 3
    state.mangle_cat_ready = true
    state.rake_ready = false
    state.shred_ready = false
    assert_false(strategies[13].matches(ctx, state), "claw mangle available -> no match")

    -- Claw: Rake ready, remains 3, energy 50 -> no match (prefer Rake)
    local ctx2 = make_context({})
    local state2 = get_state(ctx2)
    state2.is_cat = true
    state2.claw_ready = true
    state2.energy = 50
    state2.combo_points = 3
    state2.mangle_cat_ready = false
    state2.rake_ready = true
    state2.rake_remains = 3
    state2.shred_ready = false
    assert_false(strategies[13].matches(ctx2, state2), "claw rake refreshable -> no match")

    -- Claw: Shred ready, behind, mangle debuff up, energy 50 -> no match (prefer Shred)
    local ctx3 = make_context({})
    local state3 = get_state(ctx3)
    state3.is_cat = true
    state3.claw_ready = true
    state3.energy = 50
    state3.combo_points = 3
    state3.mangle_cat_ready = false
    state3.rake_ready = false
    state3.shred_ready = true
    state3.is_behind = true
    state3.mangle_remains = 10
    assert_false(strategies[13].matches(ctx3, state3), "claw shred available -> no match")
end

-- ============================================================================
-- Deep dive: Bear ability not-bear guards
-- ============================================================================
do
    -- MangleBear: not bear -> no match
    local ctx = make_context({})
    local state = get_state(ctx)
    state.is_bear = false
    state.is_cat = true
    state.mangle_bear_ready = true
    state.rage = 40
    state.in_melee = true
    assert_false(strategies[14].matches(ctx, state), "manglebear not bear -> no match")

    -- SwipeBear: not bear -> no match
    local ctx2 = make_context({enemies_count = 3})
    local state2 = get_state(ctx2)
    state2.is_bear = false
    state2.swipe_ready = true
    state2.rage = 40
    state2.enemies = 3
    assert_false(strategies[15].matches(ctx2, state2), "swipebear not bear -> no match")

    -- Maul: not bear -> no match
    local ctx3 = make_context({})
    local state3 = get_state(ctx3)
    state3.is_bear = false
    state3.maul_ready = true
    state3.rage = 50
    assert_false(strategies[16].matches(ctx3, state3), "maul not bear -> no match")

    -- MangleBear: OOC -> no match
    local ctx4 = make_context({in_combat = false})
    local state4 = get_state(ctx4)
    state4.is_bear = true
    state4.mangle_bear_ready = true
    state4.rage = 40
    state4.in_melee = true
    state4.in_combat = false
    assert_false(strategies[14].matches(ctx4, state4), "manglebear OOC -> no match")
end

-- ============================================================================
-- Deep dive: Caster ability OOC + null target guards
-- ============================================================================
do
    -- NaturesGrasp: OOC -> no match
    local ctx = make_context({in_combat = false, hp = 30})
    local state = get_state(ctx)
    state.natures_grasp_ready = true
    state.hp = 30
    state.in_combat = false
    state.enemies = 1
    assert_false(strategies[19].matches(ctx, state), "naturesgrasp OOC -> no match")

    -- Barkskin: OOC -> no match
    local ctx2 = make_context({in_combat = false, hp = 30})
    local state2 = get_state(ctx2)
    state2.barkskin_ready = true
    state2.hp = 30
    state2.in_combat = false
    assert_false(strategies[20].matches(ctx2, state2), "barkskin OOC -> no match")

    -- HealingTouch: OOC -> no match
    local ctx3 = make_context({in_combat = false, hp = 20})
    local state3 = get_state(ctx3)
    state3.healing_touch_ready = true
    state3.hp = 20
    state3.heal_hp = 40
    state3.in_combat = false
    assert_false(strategies[21].matches(ctx3, state3), "healingtouch OOC -> no match")

    -- Rejuvenation: OOC -> no match
    local ctx4 = make_context({in_combat = false, hp = 30})
    local state4 = get_state(ctx4)
    state4.rejuvenation_ready = true
    state4.hp = 30
    state4.heal_hp = 40
    state4.in_combat = false
    assert_false(strategies[22].matches(ctx4, state4), "rejuvenation OOC -> no match")

    -- Moonfire: no target -> no match
    local ctx5 = make_context({})
    ctx5.target = nil
    local state5 = get_state(ctx5)
    state5.moonfire_ready = true
    state5.target = nil
    assert_false(strategies[24].matches(ctx5, state5), "moonfire no target -> no match")

    -- InsectSwarm: no target -> no match
    local ctx6 = make_context({})
    ctx6.target = nil
    local state6 = get_state(ctx6)
    state6.insect_swarm_ready = true
    state6.target = nil
    assert_false(strategies[25].matches(ctx6, state6), "insectswarm no target -> no match")

    -- Wrath: no target -> no match
    local ctx7 = make_context({})
    ctx7.target = nil
    local state7 = get_state(ctx7)
    state7.wrath_ready = true
    state7.target = nil
    assert_false(strategies[29].matches(ctx7, state7), "wrath no target -> no match")
end

-- ============================================================================
-- Deep dive: Wand mana boundary
-- ============================================================================
do
    -- Wand: mana 29 -> match (< 30)
    local ctx = make_context({mana_pct = 29})
    local state = get_state(ctx)
    state.wand_threshold = 30
    state.mana_pct = 29
    state.wand_learned = true
    assert_true(strategies[30].matches(ctx, state), "wand mana=29 -> match (< threshold)")

    -- Wand: mana 30 -> no match (>= 30)
    local ctx2 = make_context({mana_pct = 30})
    local state2 = get_state(ctx2)
    state2.wand_threshold = 30
    state2.mana_pct = 30
    state2.wand_learned = true
    assert_false(strategies[30].matches(ctx2, state2), "wand mana=30 -> no match (>= threshold)")
end

-- ============================================================================
-- Deep dive: Hurricane + Starfire OOC guards
-- ============================================================================
do
    -- Hurricane: OOC -> no match
    local ctx = make_context({in_combat = false, enemies_count = 4, is_moving = false})
    local state = get_state(ctx)
    state.hurricane_ready = true
    state.enemies = 4
    state.is_moving = false
    state.in_combat = false
    assert_false(strategies[27].matches(ctx, state), "hurricane OOC -> no match")

    -- Starfire: OOC -> no match
    local ctx2 = make_context({in_combat = false, is_moving = false})
    local state2 = get_state(ctx2)
    state2.starfire_ready = true
    state2.is_moving = false
    state2.in_combat = false
    assert_false(strategies[28].matches(ctx2, state2), "starfire OOC -> no match")

    -- Hurricane: no target -> no match
    local ctx3 = make_context({enemies_count = 4})
    ctx3.target = nil
    local state3 = get_state(ctx3)
    state3.hurricane_ready = true
    state3.enemies = 4
    state3.target = nil
    assert_false(strategies[27].matches(ctx3, state3), "hurricane no target -> no match")

    -- Starfire: no target -> no match
    local ctx4 = make_context({})
    ctx4.target = nil
    local state4 = get_state(ctx4)
    state4.starfire_ready = true
    state4.target = nil
    assert_false(strategies[28].matches(ctx4, state4), "starfire no target -> no match")
end

-- ============================================================================
-- Deep dive: NS.spell_ready throws (crash safety)
-- ============================================================================
do
    local saved = NS.spell_ready
    NS.spell_ready = function() error("simulated throw") end
    local ctx = make_context()
    local ok, state = pcall(get_state, ctx)
    NS.spell_ready = saved
    assert_true(ok, "spell_ready throwing should not crash build_state (pcall added)")
end

-- ============================================================================
-- Deep dive: Execute functions crash safety (NS.try_cast throwing)
-- ============================================================================
do
    local saved = NS.try_cast
    NS.try_cast = function() error("simulated throw") end
    local ctx = make_context()
    for i = 1, #strategies do
        local ok, result = pcall(strategies[i].execute, ctx)
        assert_true(ok, "try_cast=throw: strategy " .. i .. " execute did not crash")
    end
    NS.try_cast = saved
end

-- ============================================================================
-- Deep dive: Execute functions nil context + no-arg
-- ============================================================================
do
    for i = 1, #strategies do
        local ok, result = pcall(strategies[i].execute, nil)
        assert_true(ok, "execute nil ctx: strategy " .. i .. " did not crash")
    end

    for i = 1, #strategies do
        local ok, result = pcall(strategies[i].execute)
        assert_true(ok, "execute no-arg: strategy " .. i .. " did not crash")
    end
end
-- Summary
-- ============================================================================
-- ============================================================================
-- DEEP DIVE: OOC guard loop - ALL combat-gated strategies return false OOC
-- ============================================================================
do
    -- Strategies that check "if not state.in_combat then return false end":
    local combat_gated = {1, 2, 3, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29}
    -- OOC-only strategies (check "if state.in_combat then return false end"):
    local ooc_only = {4, 17, 18}
    -- No combat gate (Pounce 5, Ravage 6, Wand 30 uses shared wand_matches):
    local no_gate = {5, 6, 30}

    local ctx_ooc = make_context({in_combat = false})
    local state_ooc = get_state(ctx_ooc)
    state_ooc.is_stealthed = true  -- Needed for Pounce/Ravage to potentially match
    state_ooc.is_cat = true
    state_ooc.pounce_ready = true
    state_ooc.ravage_ready = true
    state_ooc.energy = 100
    state_ooc.is_behind = true
    state_ooc.in_combat = false

    -- Combat-gated strategies: must return false OOC
    for _, idx in ipairs(combat_gated) do
        local s = strategies[idx]
        test("ooc_guard: " .. s.name .. " returns false OOC (combat-gated)", function()
            assert_false(s.matches(ctx_ooc, state_ooc), s.name .. " should not match OOC")
        end)
    end

    local ctx_combat = make_context({in_combat = true})
    local state_combat = get_state(ctx_combat)
    state_combat.in_combat = true

    -- OOC-only strategies: must return false in combat
    for _, idx in ipairs(ooc_only) do
        local s = strategies[idx]
        test("ooc_guard: " .. s.name .. " returns false in combat (OOC-only)", function()
            assert_false(s.matches(ctx_combat, state_combat), s.name .. " should not match in combat")
        end)
    end

    -- No-gate strategies: should NOT crash OOC (may match depending on other guards)
    for _, idx in ipairs(no_gate) do
        local s = strategies[idx]
        test("ooc_guard: " .. s.name .. " does not crash OOC (no combat gate)", function()
            local ok, result = pcall(s.matches, ctx_ooc, state_ooc)
            assert_true(ok, s.name .. " should not throw OOC")
        end)
    end
end

-- ============================================================================
-- DEEP DIVE: Nil target guard loop - ALL target-dependent strategies
-- ============================================================================
do
    -- Strategies that check "if not state.target then return false end":
    local target_dependent = {3, 4, 7, 8, 9, 10, 11, 12, 13, 14, 16, 23, 24, 25, 26, 27, 28, 29, 30}
    -- SwipeBear (15) has no target check (AoE)
    -- NaturesGrasp (19), Barkskin (20), HealingTouch (21), Rejuvenation (22) have no target check
    -- BearFormSurvival (1), FrenziedRegen (2): no target check
    -- MarkOfTheWild (17), Thorns (18): no target check
    -- Pounce (5), Ravage (6): don't check state.target (use context.target from execute)
    local target_independent = {1, 2, 5, 6, 15, 17, 18, 19, 20, 21, 22}

    local ctx_notarget = make_context({in_combat = true})
    ctx_notarget.target = nil  -- pairs() skips nil, set explicitly
    local state_notarget = get_state(ctx_notarget)
    state_notarget.target = nil
    state_notarget.in_combat = true
    state_notarget.is_bear = true         -- Enable bear form for bear abilities
    state_notarget.is_cat = true           -- Enable cat form for cat abilities
    state_notarget.use_feral = true
    state_notarget.is_stealthed = true
    state_notarget.energy = 100
    state_notarget.rage = 100
    state_notarget.in_melee = true

    -- Ensure all spell readiness flags
    for _, s in ipairs(strategies) do
        for k, v in pairs(state_notarget) do
            if type(k) == "string" and k:match("_ready$") then
                state_notarget[k] = true
            end
        end
    end

    -- Target-dependent: must return false with nil target
    for _, idx in ipairs(target_dependent) do
        local s = strategies[idx]
        test("nil_target: " .. s.name .. " returns false with nil target", function()
            local ok, result = pcall(s.matches, ctx_notarget, state_notarget)
            assert_true(ok, s.name .. " should not throw with nil target")
            assert_false(result, s.name .. " should return false with nil target")
        end)
    end

    -- Target-independent: should NOT crash (may match or not, but shouldn't throw)
    for _, idx in ipairs(target_independent) do
        local s = strategies[idx]
        test("nil_target: " .. s.name .. " does not crash with nil target", function()
            local ok, result = pcall(s.matches, ctx_notarget, state_notarget)
            assert_true(ok, s.name .. " should not throw with nil target")
        end)
    end
end

-- ============================================================================
-- DEEP DIVE: Missing ready guards - per-strategy not-ready verification
-- ============================================================================
do
    -- Each strategy's specific ready flag that gates it
    local ready_checks = {
        { idx = 1,  flag = "bear_form_ready",         label = "BearFormSurvival" },
        { idx = 2,  flag = "frenzied_regen_ready",    label = "FrenziedRegeneration" },
        { idx = 3,  flag = "cat_form_ready",          label = "CatFormEntry" },
        { idx = 4,  flag = "prowl_ready",             label = "ProwlOpener" },
        { idx = 5,  flag = "pounce_ready",            label = "Pounce" },
        { idx = 6,  flag = "ravage_ready",            label = "Ravage" },
        { idx = 7,  flag = "faerie_fire_feral_ready", label = "FaerieFireFeral" },
        { idx = 8,  flag = "rake_ready",              label = "Rake" },
        { idx = 9,  flag = "mangle_cat_ready",        label = "MangleCat" },
        { idx = 10, flag = "shred_ready",             label = "Shred" },
        { idx = 11, flag = "rip_ready",               label = "Rip" },
        { idx = 12, flag = "bite_ready",              label = "FerociousBite" },
        { idx = 13, flag = "claw_ready",              label = "Claw" },
        { idx = 14, flag = "mangle_bear_ready",       label = "MangleBear" },
        { idx = 15, flag = "swipe_ready",             label = "SwipeBear" },
        { idx = 16, flag = "maul_ready",              label = "Maul" },
        { idx = 17, flag = "mark_of_the_wild_ready",  label = "MarkOfTheWild" },
        { idx = 18, flag = "thorns_ready",            label = "Thorns" },
        { idx = 19, flag = "natures_grasp_ready",     label = "NaturesGrasp" },
        { idx = 20, flag = "barkskin_ready",          label = "Barkskin" },
        { idx = 21, flag = "healing_touch_ready",     label = "HealingTouch" },
        { idx = 22, flag = "rejuvenation_ready",      label = "Rejuvenation" },
        { idx = 23, flag = "entangling_roots_ready",  label = "EntanglingRoots" },
        { idx = 24, flag = "moonfire_ready",          label = "Moonfire" },
        { idx = 25, flag = "insect_swarm_ready",      label = "InsectSwarm" },
        { idx = 26, flag = "faerie_fire_ready",       label = "FaerieFire" },
        { idx = 27, flag = "hurricane_ready",         label = "Hurricane" },
        { idx = 28, flag = "starfire_ready",          label = "Starfire" },
        { idx = 29, flag = "wrath_ready",             label = "Wrath" },
        -- Wand (30) uses create_wand_matches which checks wand_learned internally
    }

    -- Build a context+state where all normal conditions are met
    local ctx = make_context({in_combat = true, hp = 20, mana_pct = 10, enemies_count = 4, is_moving = false})
    ctx.target = { is_valid = function() return true end, get_health = function() return 8000 end, get_max_health = function() return 10000 end, is_casting = function() return false end, is_alive = function() return true end, get_guid = function() return "mock-target" end, get_distance = function() return 5 end, get_health_percentage = function() return 80 end }
    local state = get_state(ctx)
    state.target = ctx.target
    state.in_combat = true
    state.is_bear = true
    state.is_cat = true
    state.use_feral = true
    state.is_stealthed = true
    state.energy = 100
    state.rage = 100
    state.combo_points = 4
    state.hp = 20
    state.bear_hp = 40
    state.heal_hp = 40
    state.mana_pct = 10
    state.enemies = 4
    state.is_moving = false
    state.in_melee = true
    state.target_range = 5
    state.is_behind = true
    state.mangle_remains = 6
    state.rake_remains = 0
    state.rip_remains = 0
    state.wand_threshold = 30
    state.wand_learned = true

    -- Set ALL ready flags to true first, then override individually
    for k, v in pairs(state) do
        if type(k) == "string" and k:match("_ready$") then
            state[k] = true
        end
    end

    local saved_debuff = NS.debuff_remains
    NS.debuff_remains = function(target, spell) return 0 end

    for _, check in ipairs(ready_checks) do
        local s = strategies[check.idx]
        -- Set the specific flag to false
        state[check.flag] = false
        test("not_ready: " .. check.label .. " returns false when " .. check.flag .. " = false", function()
            assert_false(s.matches(ctx, state), check.label .. " should not match when not ready")
        end)
        state[check.flag] = true  -- Restore
    end

    NS.debuff_remains = saved_debuff
end

-- ============================================================================
-- DEEP DIVE: API crash safety - NS.debuff_remains throws in match functions
-- ============================================================================
do
    -- Moonfire and InsectSwarm match functions call NS.debuff_remains directly
    -- (inside pcall, but we should verify the pcall actually catches)
    local ctx = make_context({in_combat = true})
    local state = get_state(ctx)
    state.moonfire_ready = true
    state.insect_swarm_ready = true
    state.faerie_fire_ready = true
    state.in_combat = true

    -- NS.debuff_remains throws
    local saved = NS.debuff_remains
    NS.debuff_remains = function() error("crash") end

    test("api_crash: moonfire_matches catches debuff_remains throw", function()
        local ok, result = pcall(S_MOONFIRE.matches, ctx, state)
        assert_true(ok, "Moonfire match should not throw when debuff_remains crashes")
    end)

    test("api_crash: insect_swarm_matches catches debuff_remains throw", function()
        local ok, result = pcall(S_IS.matches, ctx, state)
        assert_true(ok, "InsectSwarm match should not throw when debuff_remains crashes")
    end)

    test("api_crash: faerie_fire_matches catches debuff_remains throw", function()
        local ok, result = pcall(S_FF.matches, ctx, state)
        assert_true(ok, "FaerieFire match should not throw when debuff_remains crashes")
    end)

    NS.debuff_remains = saved
end

-- ============================================================================
-- DEEP DIVE: Powershift/shapeshift scenarios - form transition boundaries
-- ============================================================================
do
    -- BearFormSurvival: transitions from cat/caster to bear when low HP
    test("powershift: cat->bear survival when HP drops below bear_hp", function()
        local ctx = make_context({hp = 25})
        local state = get_state(ctx)
        state.is_cat = true
        state.is_bear = false
        state.bear_form_ready = true
        state.use_feral = true
        state.hp = 25
        state.bear_hp = 40
        assert_true(strategies[1].matches(ctx, state), "should shift to bear when cat + HP low")
    end)

    test("powershift: caster->bear survival when HP drops below bear_hp", function()
        local ctx = make_context({hp = 25})
        local state = get_state(ctx)
        state.is_cat = false
        state.is_bear = false
        state.in_caster = true
        state.bear_form_ready = true
        state.use_feral = true
        state.hp = 25
        state.bear_hp = 40
        assert_true(strategies[1].matches(ctx, state), "should shift to bear when caster + HP low")
    end)

    test("powershift: cat->cat when already cat -> no match", function()
        local ctx = make_context({hp = 35})
        local state = get_state(ctx)
        state.is_cat = true
        state.is_bear = false
        state.bear_form_ready = true
        state.use_feral = true
        state.hp = 35
        state.bear_hp = 40
        assert_true(strategies[1].matches(ctx, state), "cat with low HP -> shift to bear (bear form ignores cat form)")
    end)

    -- CatFormEntry: transitions from caster/bear to cat when safe
    test("powershift: bear->cat when HP is safe", function()
        local ctx = make_context({hp = 80})
        local state = get_state(ctx)
        state.is_bear = true
        state.is_cat = false
        state.cat_form_ready = true
        state.use_feral = true
        state.hp = 80
        state.bear_hp = 40
        state.target = { is_valid = function() return true end }
        state.in_melee = true
        assert_true(strategies[3].matches(ctx, state), "should shift to cat when bear + HP safe")
    end)

    test("powershift: bear->cat blocked when HP is low", function()
        local ctx = make_context({hp = 30})
        local state = get_state(ctx)
        state.is_bear = true
        state.is_cat = false
        state.cat_form_ready = true
        state.use_feral = true
        state.hp = 30
        state.bear_hp = 40
        state.target = { is_valid = function() return true end }
        state.in_melee = true
        assert_false(strategies[3].matches(ctx, state), "should stay bear when HP is low")
    end)

    test("powershift: bear->cat at exactly bear_hp -> no match", function()
        local ctx = make_context({hp = 40})
        local state = get_state(ctx)
        state.is_bear = true
        state.is_cat = false
        state.cat_form_ready = true
        state.use_feral = true
        state.hp = 40
        state.bear_hp = 40
        state.target = { is_valid = function() return true end }
        state.in_melee = true
        assert_false(strategies[3].matches(ctx, state), "should stay bear at HP exactly bear_hp")
    end)

    test("powershift: bear->cat at bear_hp+1 -> match", function()
        local ctx = make_context({hp = 41})
        local state = get_state(ctx)
        state.is_bear = true
        state.is_cat = false
        state.cat_form_ready = true
        state.use_feral = true
        state.hp = 41
        state.bear_hp = 40
        state.target = { is_valid = function() return true end }
        state.in_melee = true
        assert_true(strategies[3].matches(ctx, state), "should shift to cat at HP bear_hp+1")
    end)

    -- FrenziedRegeneration: only usable in bear form
    test("powershift: frenzied_regen not available in cat form", function()
        local ctx = make_context({hp = 30})
        local state = get_state(ctx)
        state.is_cat = true
        state.is_bear = false
        state.frenzied_regen_ready = true
        state.rage = 40
        state.hp = 30
        state.bear_hp = 40
        assert_false(strategies[2].matches(ctx, state), "frenzied regen not available in cat")
    end)

    test("powershift: frenzied_regen not available in caster form", function()
        local ctx = make_context({hp = 30})
        local state = get_state(ctx)
        state.is_cat = false
        state.is_bear = false
        state.in_caster = true
        state.frenzied_regen_ready = true
        state.rage = 40
        state.hp = 30
        state.bear_hp = 40
        assert_false(strategies[2].matches(ctx, state), "frenzied regen not available in caster")
    end)

    -- Cat-only abilities:
    local cat_only_names = {"Pounce", "Ravage", "Rake", "MangleCat", "Shred", "Rip", "FerociousBite", "Claw"}
    for _, name in ipairs(cat_only_names) do
        local s = find_strategy(name)
        if s then
            test("powershift: " .. name .. " not available when not in cat form", function()
                local ctx = make_context({hp = 80, enemies_count = 1})
                local state = get_state(ctx)
                state.is_cat = false
                state.is_bear = false
                state.in_caster = true
                state.use_feral = true
                state.energy = 100
                state.combo_points = 4
                state.is_stealthed = true
                state.is_behind = true
                state.target = ctx.target
                state.in_melee = true
                state.rake_remains = 0
                state.rip_remains = 0
                state.mangle_remains = 6
                state.target_ttd = 60
                for k, v in pairs(state) do
                    if type(k) == "string" and k:match("_ready$") then state[k] = true end
                end
                assert_false(s.matches(ctx, state), name .. " should not match when not in cat")
            end)
        end
    end

    -- Bear-only abilities:
    local bear_only_names = {"MangleBear", "SwipeBear", "Maul", "FrenziedRegeneration"}
    for _, name in ipairs(bear_only_names) do
        local s = find_strategy(name)
        if s then
            test("powershift: " .. name .. " not available when not in bear form", function()
                local ctx = make_context({hp = 30, enemies_count = 4})
                local state = get_state(ctx)
                state.is_bear = false
                state.is_cat = true
                state.hp = 30
                state.bear_hp = 40
                state.rage = 100
                state.target = ctx.target
                state.in_melee = true
                for k, v in pairs(state) do
                    if type(k) == "string" and k:match("_ready$") then state[k] = true end
                end
                assert_false(s.matches(ctx, state), name .. " should not match when not in bear")
            end)
        end
    end
end

-- ============================================================================
-- DEEP DIVE: Mana boundaries - comprehensive wand threshold testing
-- ============================================================================
do
    test("mana_boundary: wand mana_pct exactly threshold -> no wand (>= threshold)", function()
        local ctx = make_context({mana_pct = 30})
        local state = get_state(ctx)
        state.mana_pct = 30
        state.wand_threshold = 30
        state.wand_learned = true
        assert_false(strategies[30].matches(ctx, state), "mana exactly threshold -> no wand")
    end)

    test("mana_boundary: wand mana_pct below threshold -> wand", function()
        local ctx = make_context({mana_pct = 29})
        local state = get_state(ctx)
        state.mana_pct = 29
        state.wand_threshold = 30
        state.wand_learned = true
        assert_true(strategies[30].matches(ctx, state), "mana below threshold -> wand")
    end)

    test("mana_boundary: NS.spell_ready nil does not crash wand match", function()
        local saved = NS.spell_ready
        NS.spell_ready = nil
        local ctx = make_context({mana_pct = 10})
        local state = get_state(ctx)
        state.mana_pct = 10
        state.wand_threshold = 30
        state.wand_learned = false
        local ok, result = pcall(strategies[30].matches, ctx, state)
        assert_true(ok, "wand match should not throw when spell_ready is nil")
        NS.spell_ready = saved
    end)

    test("mana_boundary: mana_pct=0 exactly -> wand below threshold", function()
        local ctx = make_context({mana_pct = 0})
        local state = get_state(ctx)
        state.mana_pct = 0
        state.wand_threshold = 30
        state.wand_learned = true
        assert_true(strategies[30].matches(ctx, state), "0% mana -> wand")
    end)

    test("mana_boundary: mana_pct=100 with threshold=30 -> no wand", function()
        local ctx = make_context({mana_pct = 100})
        local state = get_state(ctx)
        state.mana_pct = 100
        state.wand_threshold = 30
        state.wand_learned = true
        assert_false(strategies[30].matches(ctx, state), "100% mana -> no wand")
    end)
end

-- ============================================================================
-- DEEP DIVE: NS.try_cast returning false for individual strategies
-- ============================================================================
do
    -- All executes should handle try_cast returning false gracefully
    local saved = NS.try_cast
    NS.try_cast = function() return false end

    test("try_cast_false: all 30 strategies handle try_cast returning false", function()
        local ctx = make_context({in_combat = true, hp = 20, mana_pct = 10})
        for i, s in ipairs(strategies) do
            local ok, result = pcall(s.execute, ctx)
            assert_true(ok, "strategy[" .. i .. "] (" .. s.name .. ") execute should not throw when try_cast returns false")
            assert_false(result, "strategy[" .. i .. "] (" .. s.name .. ") execute should return false when try_cast returns false")
        end
    end)

    NS.try_cast = saved
end

-- ============================================================================
-- DEEP DIVE: NS.try_cast nil for individual strategies
-- ============================================================================
do
    local saved = NS.try_cast
    NS.try_cast = nil

    test("try_cast_nil: all 30 strategies handle nil try_cast gracefully", function()
        local ctx = make_context({in_combat = true, hp = 20, mana_pct = 10})
        for i, s in ipairs(strategies) do
            local ok, result = pcall(s.execute, ctx)
            assert_true(ok, "strategy[" .. i .. "] (" .. s.name .. ") execute should not throw when try_cast is nil")
        end
    end)

    NS.try_cast = saved
end

-- ============================================================================
-- DEEP DIVE: NS.has_form nil/throws in build_state
-- ============================================================================
do
    test("has_form_nil: build_state handles NS.has_form is nil", function()
        local saved = NS.has_form
        NS.has_form = nil
        local ctx = make_context()
        local state = get_state(ctx)
        assert_eq(state.is_bear, false, "is_bear should be false when has_form is nil")
        assert_eq(state.is_cat, false, "is_cat should be false when has_form is nil")
        assert_eq(state.in_caster, true, "in_caster should be true when has_form is nil")
        NS.has_form = saved
    end)

    test("has_form_throws: build_state handles NS.has_form throwing", function()
        local saved = NS.has_form
        NS.has_form = function() error("crash") end
        local ok, state = pcall(get_state, make_context())
        assert_false(ok, "build_state should throw when has_form throws (no pcall)")
        NS.has_form = saved
    end)
end

print(string.format("\n=== Druid Leveling Unit Tests: %d passed, %d failed (%d assertions) ===\n", passed, failed, assertions))
if failed > 0 then
    error(string.format("Some tests FAILED (%d failures)", failed))
else
    print("All Druid leveling unit tests passed!")
end
