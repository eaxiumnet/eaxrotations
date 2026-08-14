-- test_protection_wotlk_dsl_priority.lua — WotLK Protection warrior DSL priority order tests.
-- WHAT:  Validates that the 9 protection_wotlk strategies are compiled correctly by the DSL
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
    WarriorSpells = {
        ShieldSlam = make_action(30356, "ShieldSlam"),
        Revenge = make_action(30357, "Revenge"),
        Devastate = make_action(30022, "Devastate"),
        HeroicStrike = make_action(47497, "HeroicStrike"),
        ThunderClap = make_action(47502, "ThunderClap"),
        ShieldBlock = make_action(2565, "ShieldBlock"),
        Pummel = make_action(6554, "Pummel"),
    },
    WarriorConstants = {
        STANCE = { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 },
    },
    PLAYER_UNIT = {},
    GetPlayer = function() return {
        get_class = function() return 1 end,
        get_power = function(self, p) return 50 end, -- W3.4: real member (me:get_rage is mock-only)
        get_health_percentage = function() return 80 end,
        get_stance = function() return 2 end,
    } end,
    me = {
        get_power = function(self, p) return 50 end, -- W3.4: real member (me:get_rage is mock-only)
        get_health_percentage = function() return 80 end,
        get_stance = function() return 2 end,
    },
    spell_action = make_action,
    spell_ready = function() return true end,
    spell_exists = function() return true end,
    try_cast = function() return true end,
    buff_up = function() return false end,
    buff_remains = function() return 0 end,
    debuff_up = function() return false end,
    debuff_remains = function(unit, ids)
        -- By default, ThunderClap debuff is not present (remains = 0)
        return 0
    end,
    debuff_stacks = function() return 0 end,
    get_debuff_stacks = function() return 0 end,
    cooldown_remains = function() return 0 end,
    is_interruptible = function() return true end,
    swing_time_until = function() return 0.5 end,
    is_item_ready = function() return false end,
    use_item_by_id = function() return true end,
    broken_api_throttled = function() return false end,
    time_now = function() return 0 end,
    log = function() end,
    log_warning = function() end,
    should_use_long_cd = function(ctx, cd) return true end,
    rotation_registry = {
        register = function(self, name, strategies, options)
            _G.EaxRotations._registered_protection = { strategies = strategies, options = options }
        end,
    },
}

package.loaded["shared/potion_helper_sylvanas"] =
    { try_use_potion = function() return false end, HEALTH_POTION_IDS = {}, DAMAGE_POTION_IDS = {} }

print("=== test_protection_wotlk_dsl_priority ===")

local prot = dofile("EaxRotations/classes/warrior/protection_wotlk.lua")
assert_true(type(prot) == "table", "protection_wotlk should return a table")
assert_true(type(prot.strategies) == "table", "protection_wotlk should expose strategies")
assert_true(#prot.strategies == 9, "protection_wotlk should have 9 strategies")

local registered = _G.EaxRotations._registered_protection
assert_true(registered ~= nil, "protection_wotlk should register under 'protection'")

-- ============================================================================
-- Priority order test
-- ============================================================================
-- W3.3 warrior sweep (2026-08-13): LastStand added first (the APL's #1
-- priority), BerserkerStance dance added for the Berserker-only Pummel, and
-- HeroicStrike moved up to queued rage >= 30 semantics per the fixture (HS is
-- NOT in the resolved APL pin set {ShieldSlam < ThunderClap < Devastate}).
local expected_order = {
    "LastStand",
    "BerserkerStance",
    "Pummel",
    "HeroicStrike",
    "ShieldBlock",
    "ShieldSlam",
    "Revenge",
    "ThunderClap",
    "Devastate",
}

test("priority order: 7 strategies match expected order", function()
    for i = 1, #expected_order do
        assert_true(prot.strategies[i].name == expected_order[i],
            string.format("Strategy %d should be %s, got %s", i, expected_order[i], prot.strategies[i].name))
    end
end)

-- ============================================================================
-- Match gate tests
-- ============================================================================

local ctx = { in_combat = true, target = {}, settings = {} }
local cast_ctx = { in_combat = true, target = { is_casting = function() return true end }, settings = {} }
local multi_ctx = { in_combat = true, target = {}, settings = {}, enemy_count = 3, enemies_count = 3 }

-- LastStand (1): emergency CD — hp < 30 in combat, ready
test("LastStand: matches when hp < 30 in combat", function()
    local orig_hp = _G.EaxRotations.me.get_health_percentage
    _G.EaxRotations.me.get_health_percentage = function() return 20 end
    local state = prot.build_state(ctx)
    local ok = prot.strategies[1].matches(ctx, state)
    _G.EaxRotations.me.get_health_percentage = orig_hp
    assert_true(ok, "LastStand should match when hp < 30")
end)

test("LastStand: does not match at healthy hp", function()
    local state = prot.build_state(ctx)
    assert_false(prot.strategies[1].matches(ctx, state), "LastStand should not match at hp >= 30")
end)

-- BerserkerStance (2): dance for the Berserker-only Pummel
test("BerserkerStance: matches when target is casting from Defensive stance", function()
    local state = prot.build_state(cast_ctx)
    assert_true(prot.strategies[2].matches(cast_ctx, state), "BerserkerStance should match when interrupt needed from Defensive")
end)

test("BerserkerStance: does not match when already Berserker", function()
    local orig_stance = _G.EaxRotations.me.get_stance
    _G.EaxRotations.me.get_stance = function() return 3 end
    local state = prot.build_state(cast_ctx)
    local ok = prot.strategies[2].matches(cast_ctx, state)
    _G.EaxRotations.me.get_stance = orig_stance
    assert_false(ok, "BerserkerStance should not match when already Berserker")
end)

-- Pummel (3): Berserker-stance-gated interrupt (WotLK Pummel is Berserker-only)
test("Pummel: matches in Berserker stance when target is casting", function()
    local orig_stance = _G.EaxRotations.me.get_stance
    _G.EaxRotations.me.get_stance = function() return 3 end
    local state = prot.build_state(cast_ctx)
    local ok = prot.strategies[3].matches(cast_ctx, state)
    _G.EaxRotations.me.get_stance = orig_stance
    assert_true(ok, "Pummel should match in Berserker stance when target is casting")
end)

-- Pummel: should NOT match in Defensive stance (the tank's home stance)
test("Pummel: does not match in Defensive stance", function()
    local state = prot.build_state(cast_ctx)
    assert_false(prot.strategies[3].matches(cast_ctx, state), "Pummel must not fire outside Berserker stance")
end)

-- Pummel: should NOT match when target is not casting
test("Pummel: does not match when target is not casting", function()
    local orig_stance = _G.EaxRotations.me.get_stance
    _G.EaxRotations.me.get_stance = function() return 3 end
    local state = prot.build_state(ctx)
    local ok = prot.strategies[3].matches(ctx, state)
    _G.EaxRotations.me.get_stance = orig_stance
    assert_false(ok, "Pummel should not match when target is not casting")
end)

-- Pummel: should NOT match out of combat
test("Pummel: does not match when out of combat", function()
    local orig_stance = _G.EaxRotations.me.get_stance
    _G.EaxRotations.me.get_stance = function() return 3 end
    local state = prot.build_state({ in_combat = false, target = { is_casting = function() return true end }, settings = {} })
    local ok = prot.strategies[3].matches({ in_combat = false, target = { is_casting = function() return true end }, settings = {} }, state)
    _G.EaxRotations.me.get_stance = orig_stance
    assert_false(ok, "Pummel should not match when out of combat")
end)

-- HeroicStrike (4): queued next-swing dump — rage >= 30 AND swing imminent
test("HeroicStrike: matches when rage >= 30 with an imminent swing", function()
    local orig_rage = _G.EaxRotations.me.get_power
    _G.EaxRotations.me.get_power = function() return 65 end
    local state = prot.build_state(ctx)
    local ok = prot.strategies[4].matches(ctx, state)
    _G.EaxRotations.me.get_power = orig_rage
    assert_true(ok, "HeroicStrike should match when rage >= 30 and swing imminent")
end)

-- HeroicStrike: should NOT match when rage < 30
test("HeroicStrike: does not match when rage < 30", function()
    local orig_rage = _G.EaxRotations.me.get_power
    _G.EaxRotations.me.get_power = function() return 20 end
    local state = prot.build_state(ctx)
    local ok = prot.strategies[4].matches(ctx, state)
    _G.EaxRotations.me.get_power = orig_rage
    assert_false(ok, "HeroicStrike should not match when rage < 30")
end)

-- HeroicStrike: should NOT match when the swing is not imminent (queued only)
test("HeroicStrike: does not match when the swing is far away", function()
    local orig_swing = _G.EaxRotations.swing_time_until
    _G.EaxRotations.swing_time_until = function() return 3.0 end
    local state = prot.build_state(ctx)
    local ok = prot.strategies[4].matches(ctx, state)
    _G.EaxRotations.swing_time_until = orig_swing
    assert_false(ok, "HeroicStrike must only queue on an imminent swing")
end)

-- ShieldBlock (5): rage >= 60 + need (multi-target or low hp)
test("ShieldBlock: matches when rage >= 60 and multi-target", function()
    local orig_rage = _G.EaxRotations.me.get_power
    _G.EaxRotations.me.get_power = function() return 80 end
    local state = prot.build_state(multi_ctx)
    local ok = prot.strategies[5].matches(multi_ctx, state)
    _G.EaxRotations.me.get_power = orig_rage
    assert_true(ok, "ShieldBlock should match at 60+ rage with 3 enemies")
end)

-- ShieldBlock: should NOT match when rage < 60 (would starve Shield Slam/Devastate)
test("ShieldBlock: does not match when rage < 60", function()
    local state = prot.build_state(multi_ctx)
    assert_false(prot.strategies[5].matches(multi_ctx, state), "ShieldBlock should not match below 60 rage")
end)

-- ShieldBlock: should NOT match single-target at full hp without a need
test("ShieldBlock: does not match single-target at full hp", function()
    local orig_rage = _G.EaxRotations.me.get_power
    _G.EaxRotations.me.get_power = function() return 80 end
    local state = prot.build_state(ctx)
    local ok = prot.strategies[5].matches(ctx, state)
    _G.EaxRotations.me.get_power = orig_rage
    assert_false(ok, "ShieldBlock needs a reason (multi-target or low hp)")
end)

-- ShieldBlock: should NOT match when not in combat
test("ShieldBlock: does not match when out of combat", function()
    local orig_rage = _G.EaxRotations.me.get_power
    _G.EaxRotations.me.get_power = function() return 80 end
    local state = prot.build_state({ in_combat = false, target = {}, settings = {} })
    local ok = prot.strategies[5].matches({ in_combat = false, target = {}, settings = {} }, state)
    _G.EaxRotations.me.get_power = orig_rage
    assert_false(ok, "ShieldBlock should not match when out of combat")
end)

-- ShieldSlam (6): should match when rage >= 20
test("ShieldSlam: matches when rage >= 20", function()
    local state = prot.build_state(ctx)
    assert_true(prot.strategies[6].matches(ctx, state), "ShieldSlam should match when rage >= 20")
end)

-- ShieldSlam: should NOT match when rage < 20
test("ShieldSlam: does not match when rage < 20", function()
    local orig_rage = _G.EaxRotations.me.get_power
    _G.EaxRotations.me.get_power = function() return 15 end
    local state = prot.build_state(ctx)
    local ok = prot.strategies[6].matches(ctx, state)
    _G.EaxRotations.me.get_power = orig_rage
    assert_false(ok, "ShieldSlam should not match when rage < 20")
end)

-- Revenge (7): should match when rage >= 5
test("Revenge: matches when rage >= 5", function()
    local state = prot.build_state(ctx)
    assert_true(prot.strategies[7].matches(ctx, state), "Revenge should match when rage >= 5")
end)

-- Revenge: should NOT match when rage < 5
test("Revenge: does not match when rage < 5", function()
    local orig_rage = _G.EaxRotations.me.get_power
    _G.EaxRotations.me.get_power = function() return 3 end
    local state = prot.build_state(ctx)
    local ok = prot.strategies[7].matches(ctx, state)
    _G.EaxRotations.me.get_power = orig_rage
    assert_false(ok, "Revenge should not match when rage < 5")
end)

-- ThunderClap (8): should match when debuff remains < 3 and rage >= 20
test("ThunderClap: matches when debuff remains < 3 and rage >= 20", function()
    local state = prot.build_state({
        in_combat = true,
        target = { get_health_percentage = function() return 100 end },
        settings = {},
        enemy_count = 2,
    })
    -- tclap_remains defaults to 0 (since debuff_remains returns 0)
    assert_true(prot.strategies[8].matches({ in_combat = true, target = {}, settings = {} }, state),
        "ThunderClap should match when debuff remains 0 and rage >= 20")
end)

-- ThunderClap: should NOT match when debuff remains >= 3
test("ThunderClap: does not match when debuff remains >= 3", function()
    local orig_debuff = _G.EaxRotations.debuff_remains
    _G.EaxRotations.debuff_remains = function(unit, ids) return 5 end
    local state = prot.build_state({ in_combat = true, target = {}, settings = {} })
    local ok = prot.strategies[8].matches({ in_combat = true, target = {}, settings = {} }, state)
    _G.EaxRotations.debuff_remains = orig_debuff
    assert_false(ok, "ThunderClap should not match when debuff remains >= 3")
end)

-- Devastate (9): should match when rage >= 15
test("Devastate: matches when rage >= 15", function()
    local state = prot.build_state(ctx)
    assert_true(prot.strategies[9].matches(ctx, state), "Devastate should match when rage >= 15")
end)

-- Devastate: should NOT match when rage < 15
test("Devastate: does not match when rage < 15", function()
    local orig_rage = _G.EaxRotations.me.get_power
    _G.EaxRotations.me.get_power = function() return 10 end
    local state = prot.build_state(ctx)
    local ok = prot.strategies[9].matches(ctx, state)
    _G.EaxRotations.me.get_power = orig_rage
    assert_false(ok, "Devastate should not match when rage < 15")
end)

print(string.format("Tests: %d/%d passed", total_passed, total_tests))
if #failures > 0 then
    print("FAILURES:")
    for _, f in ipairs(failures) do
        print("  " .. f.label .. ": " .. tostring(f.error))
    end
    os.exit(1)
end
