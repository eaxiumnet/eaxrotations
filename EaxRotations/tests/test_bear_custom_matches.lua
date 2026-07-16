-- test_bear_custom_matches.lua -- Guardian Bear custom match validation tests.
-- WHAT:  Guardian Bear custom match validation tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Ensures spec-specific match functions behave correctly under mocked combat state.
-- SAFETY: Uses synthetic context; no live game data required.

-- unit tests for bear_sylvanas custom matches functions.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_eq, assert_false

local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_eq = function(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
end
setup_asserts()

-- Mock NS namespace
local action_calls = {}
local _time_counter = 0
_G.EaxRotations = {
    time_now = function() _time_counter = _time_counter + 1; return _time_counter end,
    DruidSpells = {},
    action_matches = function(ctx, act)
        action_calls[#action_calls + 1] = { fn = "action_matches", ctx = ctx, act = act }
        return true
    end,
    debuff_remains = function(target, debuff_list)
        return target and target._debuff_remains or 0
    end,
    get_debuff_stacks = function(target, debuff_list)
        return target and target._debuff_stacks or 0
    end,
    setting_number = function(settings, key, default)
        return type(settings) == "table" and type(settings[key]) == "number" and settings[key] or default
    end,
    setting_bool = function(settings, key, default)
        local value = settings and settings[key]
        if value == nil then return default end
        return value ~= false
    end,
    log = function() end,
    rotation_registry = {
        register = function() end,
    },
    same_unit = function(a, b)
        if a == nil or b == nil then return false end
        if a == b then return true end
        if a.get_guid and b.get_guid then
            local ok_a, guid_a = pcall(a.get_guid, a)
            local ok_b, guid_b = pcall(b.get_guid, b)
            if ok_a and ok_b and guid_a and guid_b then return guid_a == guid_b end
        end
        return false
    end,
}

local result = dofile("EaxRotations/classes/druid/bear_sylvanas.lua")
local strategies = result.strategies or result
assert_true(strategies, "strategies table should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then
            return strategies[i]
        end
    end
    error("strategy not found: " .. name)
end

-- ============================================================================
-- OOC buffs must NEVER cast in bear form (MotW/Thorns cancel form → shift loop)
-- ============================================================================

local mark = find_strategy("MarkOfTheWild")
local thorns = find_strategy("Thorns")
local _prev_has_form = _G.EaxRotations.has_form

-- In bear form: never rebuff (would cancel form and spam BearForm)
_G.EaxRotations.has_form = function(form) return form == "bear" end
assert_false(mark.matches({ in_combat = false }, {}), "MarkOfTheWild must not match in bear form")
assert_false(thorns.matches({ in_combat = false }, {}), "Thorns must not match in bear form")

-- Caster form OOC: buffs allowed
_G.EaxRotations.has_form = function(form) return false end
assert_true(mark.matches({ in_combat = false }, {}), "MarkOfTheWild should match OOC out of bear when buff missing")
assert_true(thorns.matches({ in_combat = false }, {}), "Thorns should match OOC out of bear when buff missing")
assert_false(mark.matches({ in_combat = true }, {}), "MarkOfTheWild must not match in combat")
_G.EaxRotations.has_form = _prev_has_form

-- ============================================================================
-- Faerie Fire Feral: only when debuff <= 4 sec
-- ============================================================================

local faerie_fire = find_strategy("FaerieFireFeral")

-- Debuff fresh -> should NOT match
action_calls = {}
assert_false(faerie_fire.matches({ target = { _debuff_remains = 10 }, target_armor = 5000, in_combat = true, in_melee_range = true, target_range = 5 }, {}), "FaerieFireFeral should not match when debuff > 4 sec")
assert_eq(#action_calls, 0, "action_matches should not be called when debuff fresh")

-- Debuff low -> should match
action_calls = {}
assert_true(faerie_fire.matches({ target = { _debuff_remains = 2 }, target_armor = 5000, in_combat = true, in_melee_range = true, target_range = 5 }, {}), "FaerieFireFeral should match when debuff <= 4 sec")

-- No target -> should return false
assert_false(faerie_fire.matches({ in_combat = true, in_melee_range = true, target_range = 5 }, {}), "FaerieFireFeral should not match without target")

-- ============================================================================
-- Lacerate: stack to 5 ASAP, then maintain
-- ============================================================================

local lacerate = find_strategy("Lacerate")

-- Stacks < 5 -> should match (regardless of remains)
action_calls = {}
assert_true(lacerate.matches({ target = { _debuff_stacks = 3, _debuff_remains = 10 } }), "Lacerate should match when stacks < 5")

-- Stacks at 5, remains > 3 -> should NOT match
action_calls = {}
assert_false(lacerate.matches({ target = { _debuff_stacks = 5, _debuff_remains = 8 } }), "Lacerate should not match when 5-stack maintained")
assert_eq(#action_calls, 0, "action_matches should not be called when 5-stack maintained")

-- Stacks at 5, remains <= 3 -> should match
action_calls = {}
assert_true(lacerate.matches({ target = { _debuff_stacks = 5, _debuff_remains = 2 } }), "Lacerate should match when 5-stack about to drop")

-- No target -> should return false
assert_false(lacerate.matches({}), "Lacerate should not match without target")

-- ============================================================================
-- Swipe AoE: only when 3+ enemies
-- ============================================================================

local swipe_aoe = find_strategy("SwipeAoE")

-- Too few enemies -> should NOT match
action_calls = {}
assert_false(swipe_aoe.matches({ enemy_count = 2 }), "SwipeAoE should not match with < 3 enemies")
assert_eq(#action_calls, 0, "action_matches should not be called with < 3 enemies")

-- 3+ enemies -> should match
action_calls = {}
assert_true(swipe_aoe.matches({ enemy_count = 4 }), "SwipeAoE should match with >= 3 enemies")

-- ============================================================================
-- Swipe: only when 2+ enemies
-- ============================================================================

local swipe = find_strategy("Swipe")

-- Too few enemies -> should NOT match
action_calls = {}
assert_false(swipe.matches({ enemy_count = 1 }), "Swipe should not match with < 2 enemies")
assert_eq(#action_calls, 0, "action_matches should not be called with < 2 enemies")

-- 2+ enemies -> should match
action_calls = {}
assert_true(swipe.matches({ enemy_count = 3 }), "Swipe should match with >= 2 enemies")

-- TBC Swipe must cast on the enemy target (not self). Self-cast is rejected by the
-- client and spam-loops via the spell queue (see live logs: Swipe | Target <player>).
local last_try_cast = nil
_G.EaxRotations.try_cast = function(spell, target, reason, opts)
    last_try_cast = { spell = spell, target = target, reason = reason, opts = opts }
    return true
end
local enemy = { name = "Axxarien Hellcaller" }
local me = { name = "Rarbarber" }
local swipe_ok = swipe.execute({ target = enemy, me = me, enemy_count = 3, in_combat = true })
assert_true(swipe_ok, "Swipe execute should succeed when try_cast returns true")
assert_true(last_try_cast ~= nil, "Swipe execute should call try_cast")
assert_eq(last_try_cast.target, enemy, "Swipe must cast on enemy target, not player self")
assert_true(last_try_cast.target ~= me, "Swipe must not cast on player self")
local swipe_aoe_ok = swipe_aoe.execute({ target = enemy, me = me, enemy_count = 4, in_combat = true })
assert_true(swipe_aoe_ok, "SwipeAoE execute should succeed when try_cast returns true")
assert_eq(last_try_cast.target, enemy, "SwipeAoE must cast on enemy target, not player self")
_G.EaxRotations.try_cast = nil

-- Pre-Lacerate: 2-target Swipe must work without Lacerate stacks (Lacerate is L66)
-- In test env define_action returns rank_ids[1] (Lacerate = 33745).
local LACERATE_R1 = 33745
local _prev_swipe_exists = _G.EaxRotations.spell_exists
_G.EaxRotations.spell_exists = function(spell)
    if spell == LACERATE_R1 then return false end
    return true
end
action_calls = {}
assert_true(swipe.matches({ enemy_count = 2, target = { _debuff_stacks = 0 }, target_ttd = 30 }),
    "Swipe cleave should match pre-Lacerate with 0 stacks and long TTD")
_G.EaxRotations.spell_exists = _prev_swipe_exists

-- With Lacerate learned: still require stacks or short TTD
_G.EaxRotations.spell_exists = function() return true end
action_calls = {}
assert_false(swipe.matches({ enemy_count = 2, target = { _debuff_stacks = 0 }, target_ttd = 30 }),
    "Swipe cleave should NOT match with Lacerate learned, <3 stacks, long TTD")
_G.EaxRotations.spell_exists = _prev_swipe_exists

-- ============================================================================
-- Maul: pure rage dump (TBC community consensus)
-- ============================================================================

local maul = find_strategy("Maul")

local maul_settings = { bear_maul_rage = 50 }

action_calls = {}
assert_false(maul.matches({ rage = 20, target = { _debuff_stacks = 5 }, settings = maul_settings }), "Maul should not match when rage < maul_rage")
assert_eq(#action_calls, 0, "action_matches should not be called when rage < maul_rage")

action_calls = {}
assert_true(maul.matches({ rage = 50, target = { _debuff_stacks = 5 }, settings = maul_settings }), "Maul should match when rage >= maul_rage and lacerate at 5")

action_calls = {}
assert_true(maul.matches({ rage = 50, target = { _debuff_stacks = 3 }, target_ttd = 12, settings = maul_settings }), "Maul should match as rage dump when rage >= maul_rage, even with low lacerate")

action_calls = {}
assert_false(maul.matches({ rage = 50, target = { _debuff_stacks = 3 }, target_ttd = 1, settings = maul_settings }), "Maul should not match when target_ttd < 3 (on-next-swing rage waste)")

assert_true(maul.matches({ rage = 50, settings = maul_settings }), "Maul without target falls through to action_matches (mock returns true)")

-- Boss bypass: Maul should match even at target_ttd=1 when target_is_boss=true
action_calls = {}
assert_true(maul.matches({ rage = 50, target = { _debuff_stacks = 3 }, target_ttd = 1, target_is_boss = true, settings = maul_settings }), "Maul should match on boss even with target_ttd < 3")

-- AoE suppression: 3+ enemies with rage < HIGH_RAGE (75) should NOT match
action_calls = {}
assert_false(maul.matches({ rage = 50, target = { _debuff_stacks = 5 }, enemy_count = 4, settings = maul_settings }), "Maul should not match in AoE (3+ enemies) with rage < 75")

-- Exact threshold: rage = maul_rage (50) should match; rage = 49 should not
action_calls = {}
assert_true(maul.matches({ rage = 50, target = { _debuff_stacks = 5 }, settings = maul_settings }), "Maul should match at exactly maul_rage threshold")
action_calls = {}
assert_false(maul.matches({ rage = 49, target = { _debuff_stacks = 5 }, settings = maul_settings }), "Maul should not match just below maul_rage threshold")

-- Pre-Mangle (not learned): Maul is primary spender — level-scaled threshold (~23 at L17)
-- so we do not bank to endgame 50 rage on leveling bears.
-- In test env define_action returns rank_ids[1] (MangleBear R1 = 33987).
local MANGLE_BEAR_R1 = 33987
local _prev_spell_exists = _G.EaxRotations.spell_exists
_G.EaxRotations.spell_exists = function(spell)
    if spell == MANGLE_BEAR_R1 then return false end
    return true
end
-- L17 scaled floor = max(15, min(40, 15+floor(17/2))) = 23
action_calls = {}
assert_true(maul.matches({ rage = 23, level = 17, target = { _debuff_stacks = 0 }, settings = maul_settings }),
    "Maul should match at level-scaled threshold when Mangle not learned (L17 ~23)")
action_calls = {}
assert_false(maul.matches({ rage = 22, level = 17, target = { _debuff_stacks = 0 }, settings = maul_settings }),
    "Maul should not match below level-scaled threshold when Mangle not learned")
-- User slider still caps: configured 30 with scaled 23 → 23; configured below scaled uses configured
action_calls = {}
assert_false(maul.matches({ rage = 20, level = 17, target = {}, settings = { bear_maul_rage = 30 } }),
    "Pre-Mangle Maul still respects a configured floor when above scaled")
action_calls = {}
assert_true(maul.matches({ rage = 20, level = 10, target = {}, settings = { bear_maul_rage = 20 } }),
    "Pre-Mangle Maul uses configured when lower than scaled")
_G.EaxRotations.spell_exists = _prev_spell_exists

local demo_idx, ff_idx
for i, s in ipairs(strategies) do
    if s.name == "DemoralizingRoar" then demo_idx = i end
    if s.name == "FaerieFireFeral" then ff_idx = i end
end
assert_true(demo_idx and ff_idx, "Both DemoRoar and FF Feral must be registered")
assert_true(demo_idx < ff_idx, "DemoralizingRoar must be registered BEFORE FaerieFireFeral (TBC tanking priority)")

local function strategy_exists(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return true end
    end
    return false
end
assert_false(strategy_exists("Healthstone"), "Healthstone strategy should be removed from bear spec")
assert_false(strategy_exists("HealingPotion"), "HealingPotion strategy should be removed from bear spec")

local bear_form = find_strategy("BearForm")
action_calls = {}
assert_true(bear_form.matches({ now = 10, in_combat = true, combat_time = 10, stance = 0, is_bear = false, settings = { auto_bear_form_ooc = true } }), "BearForm should match in combat when not in bear form")

action_calls = {}
assert_true(bear_form.matches({ now = 13, in_combat = true, combat_time = 10, stance = 0, is_bear = false, enrage_on_cd = true, settings = { auto_bear_form_ooc = true } }), "BearForm should re-shift in combat even while Enrage is on cooldown")

local faerie_fire_pull = find_strategy("FaerieFirePull")
action_calls = {}
assert_false(faerie_fire_pull.matches({ in_combat = true, is_bear = true, has_valid_enemy_target = true, target = { _debuff_remains = 0 }, target_armor = 5000, target_range = 20 }), "FaerieFirePull should not match while in combat")

local demo_roar = find_strategy("DemoralizingRoar")
action_calls = {}
assert_false(demo_roar.matches({ in_combat = true, is_bear = true, target_range = 15, enemy_count = 1, target = { _debuff_remains = 0 }, settings = { bear_demo_roar = true } }), "DemoralizingRoar should not match beyond 10 yards")
assert_eq(#action_calls, 0, "action_matches should not be called beyond 10 yards")

action_calls = {}
assert_true(demo_roar.matches({ now = 100, in_combat = true, is_bear = true, target_range = 8, enemy_count = 1, target = { _debuff_remains = 0 }, settings = { bear_demo_roar = true } }), "DemoralizingRoar should match within 10 yards")

-- Dying single-target trash: HP gate (TTD often unknown / defaults to 999)
action_calls = {}
assert_false(demo_roar.matches({
    now = 105, in_combat = true, is_bear = true, target_range = 8, enemy_count = 1,
    target_hp = 5, target = { _debuff_remains = 0 }, settings = { bear_demo_roar = true },
}), "DemoralizingRoar should not match on single-target trash at <=20% HP")
action_calls = {}
assert_false(demo_roar.matches({
    now = 106, in_combat = true, is_bear = true, target_range = 8, enemy_count = 1,
    target_ttd = 4, target_hp = 50, target = { _debuff_remains = 0 }, settings = { bear_demo_roar = true },
}), "DemoralizingRoar should not match on single-target with TTD < 10")
-- Multi-pack: still allow Demo even if current target is low (AoE mitigation)
action_calls = {}
assert_true(demo_roar.matches({
    now = 107, in_combat = true, is_bear = true, target_range = 8, enemy_count = 3,
    target_hp = 5, target = { _debuff_remains = 0 }, settings = { bear_demo_roar = true },
}), "DemoralizingRoar should still match multi-pack even if current target is low HP")

action_calls = {}
assert_false(faerie_fire.matches({ in_combat = true, is_bear = true, has_valid_enemy_target = true, in_melee_range = true, target_range = 35, target = { _debuff_remains = 0 }, target_armor = 5000, settings = { bear_demo_roar = true } }), "FaerieFireFeral should not match beyond 30 yards")
assert_eq(#action_calls, 0, "action_matches should not be called beyond 30 yards")

local immune_target = { _debuff_remains = 0, get_guid = function() return "immune-mob" end }
local normal_target = { _debuff_remains = 0, get_guid = function() return "normal-mob" end }

action_calls = {}
assert_true(demo_roar.matches({ now = 200, in_combat = true, is_bear = true, target_range = 8, enemy_count = 1, target = immune_target, settings = { bear_demo_roar = true } }), "DemoralizingRoar should match on fresh immune target")
demo_roar.execute({ now = 200, in_combat = true, is_bear = true, target_range = 8, enemy_count = 1, target = immune_target, settings = { bear_demo_roar = true } })

action_calls = {}
assert_false(demo_roar.matches({ now = 202, in_combat = true, is_bear = true, target_range = 8, enemy_count = 1, target = immune_target, settings = { bear_demo_roar = true } }), "DemoralizingRoar should be throttled on same immune target within 8s")

action_calls = {}
assert_true(demo_roar.matches({ now = 203, in_combat = true, is_bear = true, target_range = 8, enemy_count = 1, target = normal_target, settings = { bear_demo_roar = true } }), "DemoralizingRoar should still match on a different target")

action_calls = {}
assert_true(demo_roar.matches({ now = 210, in_combat = true, is_bear = true, target_range = 8, enemy_count = 1, target = immune_target, settings = { bear_demo_roar = true } }), "DemoralizingRoar should retry immune target after 8s cooldown")

print("PASS test_bear_custom_matches")
