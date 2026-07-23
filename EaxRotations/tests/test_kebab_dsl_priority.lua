-- test_kebab_dsl_priority.lua â Kebab Warrior DSL priority test.
-- WHAT:  Verifies the 16 DSL-converted strategies preserve priority order.
-- WHEN:  Run by the rotation test suite.
-- WHY:   Regression guard for the final DSL adopter (kebab warrior).
-- SAFETY: Pure unit tests with mocked API context.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local _pass, _fail = 0, 0
local function assert_true(cond, msg) if cond then _pass = _pass + 1 else _fail = _fail + 1 print("  FAIL: " .. msg) end end
local function assert_false(cond, msg) if not cond then _pass = _pass + 1 else _fail = _fail + 1 print("  FAIL: " .. msg) end end

local NS = {}
_G.EaxRotations = NS
NS.CLASS_ID = { WARRIOR = 1 }
NS.WarriorSpells = {}
NS.WarriorConstants = { STANCE = { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 }, SUNDER_DEBUFF = { 7386 }, SUNDER_MAX_STACKS = 5, SUNDER_REFRESH_WINDOW = 3, TC_REFRESH_WINDOW = 2, COMMANDING_SHOUT_BUFF = { 469 }, BUFF_ID = { SWEEPING_STRIKES = 12328 } }
NS.PLAYER_UNIT = { get_health = function() return 100 end, is_valid = function() return true end, get_class = function() return 1 end }
NS.GetPlayer = function() return NS.PLAYER_UNIT end
NS.buff_up = function() return false end; NS.buff_remains = function() return 0 end
NS.debuff_up = function() return false end; NS.debuff_remains = function() return 0 end; NS.debuff_stacks = function() return 0 end
NS.has_player_buff = function() return false end
NS.spell_ready = function() return true end; NS.spell_exists = function() return true end
NS.try_cast = function() return true end
NS.is_item_ready = function() return false end; NS.use_item_by_id = function() return true end
NS.unit_health_pct = function() return 100 end; NS.mana_pct = function() return 100 end
NS.time_now = function() return 0 end; NS.broken_api_throttled = function() return false end
NS.rotation_registry = { register = function() end }; NS.log = function() end
NS.is_execute_phase = function(hp, t) return (hp or 100) <= (t or 20) end
NS.is_current_spell = function() return false end
NS.cooldown_remains = function() return 99 end
NS.get_spell_id = function(spell) return 78 end
NS.aoe_self_meets = function() return false end
NS.aoe_target_meets = function() return false end
NS.try_interrupt = function() return false end
NS.get_time_until_swing = function() return nil end; NS.get_time_until_oh_swing = function() return nil end
NS.has_breakable_cc_nearby = function() return false end
NS.import_helpers = function(...)
    local t = {}; for _, key in ipairs({...}) do t[key] = function(...) return true end end
    return t.try_cast or function() return true end, t.spell_exists or function() return true end,
           t.spell_ready or function() return true end, t.debuff_remains or function() return 0 end,
           t.debuff_stacks or function() return 0 end, t.buff_remains or function() return 0 end,
           t.health_pct or function() return 100 end, t.player_control_locked or function() return false end,
           t.has_player_buff or function() return false end, t.has_breakable_cc_nearby or function() return false end,
           t.can_attack_target or function() return true end
end

package.loaded["common/utility/inventory_helper"] = { has_item = function() return false end }
package.loaded["common/enums"] = { class_id = { WARRIOR = 1 } }
local _setting = function(context, key, default)
    if context and context.settings and context.settings[key] ~= nil then return context.settings[key] end
    return default
end
local mock_spec_kit = {
    merge_state = dofile("EaxRotations/tests/spec_kit_merge_state.lua").merge_state,
    define_action_for_class = function() return function(field, ids, label) return ids and ids[1] or field end end,
    safe_state = function(raw, schema) return setmetatable({}, { __index = function(t, k) if raw[k] ~= nil then return raw[k] end if schema and schema[k] ~= nil then return schema[k] end return nil end }) end,
    setting = _setting, setting_bool = function(ctx, key, def) local v = _setting(ctx, key, nil); if v == nil then return def end return v ~= false end,
    setting_number = function(ctx, key, def) local v = _setting(ctx, key, nil); if type(v) == "number" then return v end return def end,
}
package.loaded["shared/spec_kit_sylvanas"] = mock_spec_kit
package.loaded["shared/strategy_dsl_sylvanas"] = dofile("EaxRotations/shared/strategy_dsl_sylvanas.lua")
package.loaded["shared/potion_helper_sylvanas"] = { HEALTH_POTION_IDS = {}, DAMAGE_POTION_IDS = {}, try_use_potion = function() return false end }

local kebab = dofile("EaxRotations/classes/warrior/kebab_sylvanas.lua")
local strategies = kebab.strategies
package.loaded["shared/spec_kit_sylvanas"] = nil

local function find_strategy(name)
    for i = 1, #strategies do if strategies[i].name == name then return strategies[i], i end end
    error("strategy not found: " .. name)
end
local function index_of(name) local _, idx = find_strategy(name); return idx end

local function make_ctx(overrides)
    local ctx = { me = NS.PLAYER_UNIT, in_combat = true, hp = 100, mana_pct = 100, settings = {}, stance = 3, rage = 50, enemy_count = 1, target_hp = 100, in_melee_range = true, has_offhand = true, target = { get_health = function() return 100 end, is_valid = function() return true end, is_casting = function() return false end, is_cast_interruptible = function() return true end } }
    for k, v in pairs(overrides or {}) do ctx[k] = v end
    return ctx
end
local function make_state(overrides)
    local s = { hp_pct = 100, mana_pct = 100, target_below_20 = false, sunder_stacks = 0, sunder_duration = 0, thunder_clap_duration = 0, demo_shout_duration = 0, ms_cd = 99, ww_cd = 99, pummel_ready = true, healthstone_ready = 0, is_group = false, general_use = false }
    for k, v in pairs(overrides or {}) do s[k] = v end
    return s
end

-- Priority order
assert_true(index_of("HealthPotion") < index_of("DamagePotion"), "HealthPotion before DamagePotion")
assert_true(index_of("DamagePotion") < index_of("Healthstone"), "DamagePotion before Healthstone")
assert_true(index_of("Healthstone") < index_of("Pummel"), "Healthstone before Pummel")
assert_true(index_of("Pummel") < index_of("Execute"), "Pummel before Execute")
assert_true(index_of("Execute") < index_of("SweepingStrikes"), "Execute before SweepingStrikes")
assert_true(index_of("SweepingStrikes") < index_of("MortalStrikeGeneralUse"), "SweepingStrikes before MortalStrikeGeneralUse")
assert_true(index_of("MortalStrikeGeneralUse") < index_of("Whirlwind"), "MortalStrikeGeneralUse before Whirlwind")
assert_true(index_of("Whirlwind") < index_of("MortalStrike"), "Whirlwind before MortalStrike")
assert_true(index_of("MortalStrike") < index_of("Overpower"), "MortalStrike before Overpower")
assert_true(index_of("Overpower") < index_of("BattleShout"), "Overpower before BattleShout")
assert_true(index_of("BattleShout") < index_of("CommandingShout"), "BattleShout before CommandingShout")
assert_true(index_of("CommandingShout") < index_of("SunderMaintain"), "CommandingShout before SunderMaintain")
assert_true(index_of("SunderMaintain") < index_of("ThunderClap"), "SunderMaintain before ThunderClap")
assert_true(index_of("ThunderClap") < index_of("DemoShout"), "ThunderClap before DemoShout")
assert_true(index_of("DemoShout") < index_of("HeroicStrike"), "DemoShout before HeroicStrike")

-- Verify extra fields preserved by substitution loop
local bs = find_strategy("BattleShout")
assert_true(bs.is_gcd_gated ~= nil and bs.is_gcd_gated == false, "BattleShout is_gcd_gated preserved")
local cs = find_strategy("CommandingShout")
assert_true(cs.is_gcd_gated ~= nil and cs.is_gcd_gated == false, "CommandingShout is_gcd_gated preserved")
local hss = find_strategy("HeroicStrike")
assert_true(hss.is_gcd_gated ~= nil and hss.is_gcd_gated == false, "HeroicStrike is_gcd_gated preserved")

-- Basic match checks
local hs = find_strategy("HeroicStrike")
assert_true(hs.matches(make_ctx(), make_state()), "HeroicStrike matches by default")

local execute = find_strategy("Execute")
assert_false(execute.matches(make_ctx({ target_hp = 80 }), make_state({ target_below_20 = false })), "Execute skips when target above 20%")
assert_true(execute.matches(make_ctx({ target_hp = 15, rage = 30 }), make_state({ target_below_20 = true })), "Execute matches when target below 20%")

local pummel = find_strategy("Pummel")
assert_false(pummel.matches(make_ctx(), make_state()), "Pummel skips when target not casting (mocked false)")
-- Override target to be casting
local ok_pummel, _ = pcall(function()
    return pummel.matches(make_ctx({ target = { is_casting = function() return true end, is_cast_interruptible = function() return true end } }), make_state())
end)

print(string.format("test_kebab_dsl_priority: %d passed, %d failed", _pass, _fail))
if _fail > 0 then os.exit(1) end
print("PASS test_kebab_dsl_priority")
