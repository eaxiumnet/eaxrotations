-- test_arcane_wotlk_dsl_priority.lua — WotLK Arcane mage DSL priority order tests.
-- WHAT:  Validates that the 11 arcane_wotlk strategies are compiled correctly by the DSL
--        and that their match gates fire in the expected priority order.
-- WHEN:  run_wotlk_tests.lua and run_rotation_tests.lua.
-- WHY:   Regression guard for DSL-based strategy definitions.
-- SAFETY: Standalone; mocks all NS dependencies.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
local assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
local failures, total_tests, total_passed = {}, 0, 0

local function test(label, fn)
    total_tests = total_tests + 1
    local ok, err = pcall(fn)
    if ok then total_passed = total_passed + 1
    else failures[#failures + 1] = { label = label, error = err } end
end

local function make_action(ids, label)
    local id = type(ids) == "table" and ids[1] or ids
    return {
        id = id,
        name = label or tostring(id),
        cast_safe = function(self, target) return true end,
        cooldown_remaining = function(self) return 0 end,
        can_cast = function(self, target) return true end,
        is_learned = function(self) return true end,
    }
end

_G.EaxRotations = {
    MageSpells = {
        ArcaneBlast = make_action(42897, "ArcaneBlast"),
        ArcaneMissiles = make_action(42846, "ArcaneMissiles"),
        ArcaneBarrage = make_action(44425, "ArcaneBarrage"),
        Evocation = make_action(12051, "Evocation"),
        ArcanePower = make_action(12042, "ArcanePower"),
        IcyVeins = make_action(12472, "IcyVeins"),
        MirrorImage = make_action(55342, "MirrorImage"),
        PresenceOfMind = make_action(12043, "PresenceOfMind"),
        Counterspell = make_action(2139, "Counterspell"),
        ConjureManaEmerald = make_action(27101, "ConjureManaEmerald"),
        MageArmor = make_action(43024, "MageArmor"),
    },
    GetPlayer = function() return {
        get_health_percentage = function() return 80 end,
        get_mana_percentage = function() return 80 end,
    } end,
    me = {
        get_health_percentage = function() return 80 end,
        get_mana_percentage = function() return 80 end,
    },
    spell_action = make_action,
    spell_ready = function() return true end,
    spell_exists = function() return true end,
    try_cast = function() return true end,
    buff_up = function(unit, ids) return false end,
    buff_stacks = function(unit, ids) return 0 end,
    buff_remains = function() return 0 end,
    debuff_up = function(unit, ids) return false end,
    debuff_remains = function(unit, ids) return 0 end,
    get_debuff_stacks = function() return 0 end,
    cooldown_remains = function() return 0 end,
    is_item_ready = function() return false end,
    use_item_by_id = function() return true end,
    broken_api_throttled = function() return false end,
    time_now = function() return 0 end,
    log = function() end,
    log_warning = function() end,
    is_wotlk = function() return true end,
    should_use_long_cd = function(ctx, cd) return true end,
    rotation_registry = {
        register = function(self, name, strategies, options)
            _G.EaxRotations._registered_arcane = { strategies = strategies, options = options }
        end,
    },
}

package.loaded["shared/potion_helper_sylvanas"] =
    { try_use_potion = function() return false end, HEALTH_POTION_IDS = {}, DAMAGE_POTION_IDS = {} }
package.loaded["shared/strategy_dsl_sylvanas"] = package.loaded["shared/strategy_dsl_sylvanas"]
    or require("shared/strategy_dsl_sylvanas")

print("=== test_arcane_wotlk_dsl_priority ===")

local arcane = dofile("EaxRotations/classes/mage/arcane_wotlk.lua")
assert_true(type(arcane) == "table", "arcane_wotlk should return a table")
assert_true(type(arcane.strategies) == "table", "arcane_wotlk should expose strategies")
assert_true(#arcane.strategies == 11, "arcane_wotlk should have 11 strategies")

local registered = _G.EaxRotations._registered_arcane
assert_true(registered ~= nil, "arcane_wotlk should register under 'arcane'")

-- ============================================================================
-- Priority order test
-- ============================================================================
local expected_order = {
    "Counterspell",
    "MageArmor",
    "Evocation",
    "ManaGem",
    "ArcanePower",
    "IcyVeins",
    "MirrorImage",
    "PresenceOfMind",
    "ArcaneMissiles",
    "ArcaneBarrage",
    "ArcaneBlast",
}

test("priority order: 11 strategies match expected order", function()
    for i = 1, #expected_order do
        assert_true(arcane.strategies[i].name == expected_order[i],
            string.format("Strategy %d should be %s, got %s", i, expected_order[i], arcane.strategies[i].name))
    end
end)

-- ============================================================================
-- Match gate tests
-- ============================================================================

local ctx = { in_combat = true, target = {}, settings = {} }

-- Counterspell: matches when in_combat AND target_is_casting
test("Counterspell: matches when target is casting", function()
    local state = arcane.build_state(ctx)
    state.in_combat = true
    state.target_is_casting = true
    assert_true(arcane.strategies[1].matches(ctx, state), "Counterspell should match when target is casting")
end)

test("Counterspell: does not match when out of combat", function()
    local state = arcane.build_state(ctx)
    state.in_combat = false
    state.target_is_casting = true
    assert_false(arcane.strategies[1].matches(ctx, state), "Counterspell should not match when out of combat")
end)

test("Counterspell: does not match when target not casting", function()
    local state = arcane.build_state(ctx)
    state.in_combat = true
    state.target_is_casting = false
    assert_false(arcane.strategies[1].matches(ctx, state), "Counterspell should not match when target not casting")
end)

-- MageArmor: matches when not up
test("MageArmor: matches when armor not up", function()
    local orig_buff = _G.EaxRotations.buff_up
    _G.EaxRotations.buff_up = function(unit, ids) return false end  -- armor not up
    local state = arcane.build_state(ctx)
    local ok = arcane.strategies[2].matches(ctx, state)
    _G.EaxRotations.buff_up = orig_buff
    assert_true(ok, "MageArmor should match when not up")
end)

test("MageArmor: does not match when already up", function()
    local orig_buff = _G.EaxRotations.buff_up
    _G.EaxRotations.buff_up = function(unit, ids) return true end  -- armor up
    local state = arcane.build_state(ctx)
    local ok = arcane.strategies[2].matches(ctx, state)
    _G.EaxRotations.buff_up = orig_buff
    assert_false(ok, "MageArmor should not match when already up")
end)

-- Evocation: matches when mana < 20
test("Evocation: matches when mana < 20", function()
    local orig_mana = _G.EaxRotations.me.get_mana_percentage
    _G.EaxRotations.me.get_mana_percentage = function() return 15 end
    local state = arcane.build_state(ctx)
    local ok = arcane.strategies[3].matches(ctx, state)
    _G.EaxRotations.me.get_mana_percentage = orig_mana
    assert_true(ok, "Evocation should match when mana < 20")
end)

test("Evocation: does not match when mana >= 20", function()
    local state = arcane.build_state(ctx)  -- default mana 80
    assert_false(arcane.strategies[3].matches(ctx, state), "Evocation should not match when mana >= 20")
end)

-- ManaGem: matches when 20 <= mana < 40
test("ManaGem: matches when 20 <= mana < 40", function()
    local orig_mana = _G.EaxRotations.me.get_mana_percentage
    _G.EaxRotations.me.get_mana_percentage = function() return 30 end
    local state = arcane.build_state(ctx)
    local ok = arcane.strategies[4].matches(ctx, state)
    _G.EaxRotations.me.get_mana_percentage = orig_mana
    assert_true(ok, "ManaGem should match when mana between 20 and 40")
end)

test("ManaGem: does not match when mana < 20", function()
    local orig_mana = _G.EaxRotations.me.get_mana_percentage
    _G.EaxRotations.me.get_mana_percentage = function() return 10 end
    local state = arcane.build_state(ctx)
    local ok = arcane.strategies[4].matches(ctx, state)
    _G.EaxRotations.me.get_mana_percentage = orig_mana
    assert_false(ok, "ManaGem should not match when mana < 20")
end)

test("ManaGem: does not match when mana >= 40", function()
    local state = arcane.build_state(ctx)  -- default mana 80
    assert_false(arcane.strategies[4].matches(ctx, state), "ManaGem should not match when mana >= 40")
end)

-- ArcanePower: matches when in_combat, not already up, long_cd allowed
test("ArcanePower: matches when all conditions met", function()
    local orig_long_cd = _G.EaxRotations.should_use_long_cd
    _G.EaxRotations.should_use_long_cd = function(ctx, cd) return true end
    local state = arcane.build_state(ctx)
    state.in_combat = true
    state.arcane_power_up = false
    local ok = arcane.strategies[5].matches(ctx, state)
    _G.EaxRotations.should_use_long_cd = orig_long_cd
    assert_true(ok, "ArcanePower should match when all conditions met")
end)

test("ArcanePower: does not match when out of combat", function()
    local state = arcane.build_state(ctx)
    state.in_combat = false
    state.arcane_power_up = false
    assert_false(arcane.strategies[5].matches(ctx, state), "ArcanePower should not match when out of combat")
end)

test("ArcanePower: does not match when already active", function()
    local orig_buff = _G.EaxRotations.buff_up
    _G.EaxRotations.buff_up = function(unit, ids) return true end  -- AP buff up
    local state = arcane.build_state(ctx)
    state.in_combat = true
    local ok = arcane.strategies[5].matches(ctx, state)
    _G.EaxRotations.buff_up = orig_buff
    assert_false(ok, "ArcanePower should not match when already active")
end)

-- IcyVeins: matches when in_combat, not already up, long_cd allowed
test("IcyVeins: matches when all conditions met", function()
    local orig_long_cd = _G.EaxRotations.should_use_long_cd
    _G.EaxRotations.should_use_long_cd = function(ctx, cd) return true end
    local state = arcane.build_state(ctx)
    state.in_combat = true
    state.icy_veins_up = false
    local ok = arcane.strategies[6].matches(ctx, state)
    _G.EaxRotations.should_use_long_cd = orig_long_cd
    assert_true(ok, "IcyVeins should match when all conditions met")
end)

test("IcyVeins: does not match when out of combat", function()
    local state = arcane.build_state(ctx)
    state.in_combat = false
    assert_false(arcane.strategies[6].matches(ctx, state), "IcyVeins should not match when out of combat")
end)

test("IcyVeins: does not match when already active", function()
    local orig_buff = _G.EaxRotations.buff_up
    _G.EaxRotations.buff_up = function(unit, ids) return true end  -- IV buff up
    local state = arcane.build_state(ctx)
    state.in_combat = true
    local ok = arcane.strategies[6].matches(ctx, state)
    _G.EaxRotations.buff_up = orig_buff
    assert_false(ok, "IcyVeins should not match when already active")
end)

-- MirrorImage: matches when in_combat
test("MirrorImage: matches when in combat", function()
    local state = arcane.build_state(ctx)
    state.in_combat = true
    assert_true(arcane.strategies[7].matches(ctx, state), "MirrorImage should match when in combat")
end)

test("MirrorImage: does not match when out of combat", function()
    local state = arcane.build_state(ctx)
    state.in_combat = false
    assert_false(arcane.strategies[7].matches(ctx, state), "MirrorImage should not match when out of combat")
end)

-- PresenceOfMind: matches when in_combat, ready, long_cd allowed
test("PresenceOfMind: matches when all conditions met", function()
    local orig_long_cd = _G.EaxRotations.should_use_long_cd
    _G.EaxRotations.should_use_long_cd = function(ctx, cd) return true end
    local state = arcane.build_state(ctx)
    state.in_combat = true
    state.pom_ready = true
    local ok = arcane.strategies[8].matches(ctx, state)
    _G.EaxRotations.should_use_long_cd = orig_long_cd
    assert_true(ok, "PresenceOfMind should match when all conditions met")
end)

test("PresenceOfMind: does not match when not ready", function()
    local state = arcane.build_state(ctx)
    state.in_combat = true
    state.pom_ready = false
    assert_false(arcane.strategies[8].matches(ctx, state), "PresenceOfMind should not match when not ready")
end)

-- ArcaneMissiles: matches when missile_barrage_proc OR stacks >= 3
test("ArcaneMissiles: matches when missile barrage procs", function()
    local orig_buff = _G.EaxRotations.buff_up
    _G.EaxRotations.buff_up = function(unit, ids) return true end  -- proc up
    local state = arcane.build_state(ctx)
    local ok = arcane.strategies[9].matches(ctx, state)
    _G.EaxRotations.buff_up = orig_buff
    assert_true(ok, "ArcaneMissiles should match when missile barrage procs")
end)

test("ArcaneMissiles: matches when 3 AB stacks", function()
    local state = arcane.build_state(ctx)
    state.arcane_blast_stacks = 3
    assert_true(arcane.strategies[9].matches(ctx, state), "ArcaneMissiles should match at 3 stacks")
end)

test("ArcaneMissiles: does not match without proc and stacks < 3", function()
    local state = arcane.build_state(ctx)
    state.arcane_blast_stacks = 1
    assert_false(arcane.strategies[9].matches(ctx, state), "ArcaneMissiles should not match without proc and < 3 stacks")
end)

-- ArcaneBarrage: matches when missile_barrage_proc OR stacks >= 3
test("ArcaneBarrage: matches when missile barrage procs", function()
    local orig_buff = _G.EaxRotations.buff_up
    _G.EaxRotations.buff_up = function(unit, ids) return true end  -- proc up
    local state = arcane.build_state(ctx)
    local ok = arcane.strategies[10].matches(ctx, state)
    _G.EaxRotations.buff_up = orig_buff
    assert_true(ok, "ArcaneBarrage should match when missile barrage procs")
end)

test("ArcaneBarrage: matches when 3 AB stacks", function()
    local state = arcane.build_state(ctx)
    state.arcane_blast_stacks = 3
    assert_true(arcane.strategies[10].matches(ctx, state), "ArcaneBarrage should match at 3 stacks")
end)

test("ArcaneBarrage: does not match without proc and stacks < 3", function()
    local state = arcane.build_state(ctx)
    state.arcane_blast_stacks = 1
    assert_false(arcane.strategies[10].matches(ctx, state), "ArcaneBarrage should not match without proc and < 3 stacks")
end)

-- ArcaneBlast: matches when mana >= 20 and stacks < 3
test("ArcaneBlast: matches when mana >= 20 and stacks < 3", function()
    local state = arcane.build_state(ctx)  -- default mana 80, stacks 0
    assert_true(arcane.strategies[11].matches(ctx, state), "ArcaneBlast should match when mana >= 20 and stacks < 3")
end)

test("ArcaneBlast: does not match when mana < 20", function()
    local orig_mana = _G.EaxRotations.me.get_mana_percentage
    _G.EaxRotations.me.get_mana_percentage = function() return 10 end
    local state = arcane.build_state(ctx)
    local ok = arcane.strategies[11].matches(ctx, state)
    _G.EaxRotations.me.get_mana_percentage = orig_mana
    assert_false(ok, "ArcaneBlast should not match when mana < 20")
end)

test("ArcaneBlast: does not match at 3 stacks", function()
    local state = arcane.build_state(ctx)
    state.arcane_blast_stacks = 3
    assert_false(arcane.strategies[11].matches(ctx, state), "ArcaneBlast should not match at 3 stacks")
end)

print(string.format("Tests: %d/%d passed", total_passed, total_tests))
if #failures > 0 then
    print("FAILURES:")
    for _, f in ipairs(failures) do
        print("  " .. f.label .. ": " .. tostring(f.error))
    end
    os.exit(1)
end
