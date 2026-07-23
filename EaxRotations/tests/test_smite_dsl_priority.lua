-- test_smite_dsl_priority.lua â Smite Priest DSL priority + equivalence test.
-- WHAT:  Verifies the 17 DSL-converted strategies preserve priority order.
-- WHEN:  Run by the rotation test suite.
-- WHY:   Regression guard for the second-to-last DSL adopter (smite priest).
-- SAFETY: Pure unit tests with mocked API context.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local _pass, _fail = 0, 0
local function assert_true(cond, msg)
    if cond then _pass = _pass + 1 else _fail = _fail + 1 print("  FAIL: " .. msg) end
end
local function assert_false(cond, msg)
    if not cond then _pass = _pass + 1 else _fail = _fail + 1 print("  FAIL: " .. msg) end
end

-- ============================================================================
-- Mock NS
-- ============================================================================
local NS = {}
_G.EaxRotations = NS

NS.CLASS_ID = { PRIEST = 5 }
NS.PriestSpells = {}
NS.PLAYER_UNIT = { get_health = function() return 100 end, is_valid = function() return true end, get_class = function() return 5 end, get_race_id = function() return 1 end }
NS.GetPlayer = function() return NS.PLAYER_UNIT end
NS.buff_up = function() return false end
NS.debuff_up = function() return false end
NS.debuff_remains = function() return 0 end
NS.has_player_buff = function() return false end
NS.buff_remains = function() return 0 end
NS.spell_ready = function() return true end
NS.try_cast = function() return true end
NS.is_item_ready = function() return false end
NS.use_item_by_id = function() return true end
NS.unit_health_pct = function() return 100 end
NS.mana_pct = function() return 100 end
NS.time_now = function() return 0 end
NS.broken_api_throttled = function() return false end
NS.rotation_registry = { register = function() end }
NS.log = function() end
NS.import_helpers = function(...)
    local t = {}
    for _, key in ipairs({...}) do t[key] = function() return true end end
    return t.try_cast or function() return true end, t.spell_exists or function() return true end,
           t.spell_ready or function() return true end, t.debuff_remains or function() return 0 end,
           t.buff_up or function() return false end, t.buff_remains or function() return 0 end,
           t.health_pct or function() return 100 end, t.player_control_locked or function() return false end
end

package.loaded["common/utility/inventory_helper"] = { has_item = function() return false end }
package.loaded["common/enums"] = { class_id = { PRIEST = 5 } }

local _setting = function(context, key, default)
    if context and context.settings and context.settings[key] ~= nil then return context.settings[key] end
    return default
end
local mock_spec_kit = {
    merge_state = dofile("EaxRotations/tests/spec_kit_merge_state.lua").merge_state,
    define_action_for_class = function(SPELLS)
        return function(field, rank_ids, label)
            if SPELLS and SPELLS[field] then return SPELLS[field] end
            return rank_ids and rank_ids[1] or field
        end
    end,
    safe_state = function(raw, schema)
        return setmetatable({}, { __index = function(t, k) if raw[k] ~= nil then return raw[k] end if schema and schema[k] ~= nil then return schema[k] end return nil end })
    end,
    setting = _setting,
    setting_bool = function(context, key, default) local v = _setting(context, key, nil); if v == nil then return default end return v ~= false end,
    setting_number = function(context, key, default) local v = _setting(context, key, nil); if type(v) == "number" then return v end return default end,
}
package.loaded["shared/spec_kit_sylvanas"] = mock_spec_kit
package.loaded["shared/strategy_dsl_sylvanas"] = dofile("EaxRotations/shared/strategy_dsl_sylvanas.lua")

local smite = dofile("EaxRotations/classes/priest/smite_sylvanas.lua")
local strategies = smite.strategies
package.loaded["shared/spec_kit_sylvanas"] = nil

local function find_strategy(name)
    for i = 1, #strategies do if strategies[i].name == name then return strategies[i], i end end
    error("strategy not found: " .. name)
end
local function index_of(name) local _, idx = find_strategy(name); return idx end

local function make_ctx(overrides)
    local ctx = { me = NS.PLAYER_UNIT, in_combat = true, hp = 100, mana_pct = 100, settings = {}, has_valid_enemy_target = true, target = { is_valid = function() return true end }, target_phys_immune = false }
    for k, v in pairs(overrides or {}) do ctx[k] = v end
    return ctx
end
local function make_state(overrides)
    local s = { hp_pct = 100, mana_pct = 100, mana_emergency = false, mana_low = false, hf_ready = true, mb_ready = true, swd_ready = true, swd_safe = true, surge_of_light = false, swp_active = false, has_inner_focus = false, has_inner_fire = false, inner_fire_remains = 0, inner_focus_ready = true, inner_fire_ready = true, power_word_shield_ready = true, renew_ready = true, psychic_scream_ready = true, shadowfiend_ready = true, threat_safe = true, enemy_count = 1, has_renew = false, has_weakened_soul = false, healthstone_ready = 0, dp_remaining = 0, in_weave_window = false }
    for k, v in pairs(overrides or {}) do s[k] = v end
    return s
end

-- ============================================================================
-- Priority order sanity check
-- ============================================================================
assert_true(index_of("InnerFire") < index_of("SoloPowerWordShield"), "InnerFire before SoloPowerWordShield")
assert_true(index_of("SoloPowerWordShield") < index_of("SoloRenew"), "SoloPowerWordShield before SoloRenew")
assert_true(index_of("SoloRenew") < index_of("SoloPsychicScream"), "SoloRenew before SoloPsychicScream")
assert_true(index_of("SoloPsychicScream") < index_of("Healthstone"), "SoloPsychicScream before Healthstone")
assert_true(index_of("Healthstone") < index_of("ShadowfiendMana"), "Healthstone before ShadowfiendMana")
assert_true(index_of("ShadowfiendMana") < index_of("HolyFire"), "ShadowfiendMana before HolyFire")
assert_true(index_of("HolyFire") < index_of("SurgeOfLightSmite"), "HolyFire before SurgeOfLightSmite")
assert_true(index_of("SurgeOfLightSmite") < index_of("ShadowWordPain"), "SurgeOfLightSmite before ShadowWordPain")
assert_true(index_of("ShadowWordPain") < index_of("PowerInfusion"), "ShadowWordPain before PowerInfusion")
assert_true(index_of("PowerInfusion") < index_of("InnerFocus"), "PowerInfusion before InnerFocus")
assert_true(index_of("InnerFocus") < index_of("Starshards"), "InnerFocus before Starshards")
assert_true(index_of("Starshards") < index_of("DevouringPlague"), "Starshards before DevouringPlague")
assert_true(index_of("DevouringPlague") < index_of("MindBlast"), "DevouringPlague before MindBlast")
assert_true(index_of("MindBlast") < index_of("ShadowWordDeath"), "MindBlast before ShadowWordDeath")
assert_true(index_of("ShadowWordDeath") < index_of("HolyNova"), "ShadowWordDeath before HolyNova")
assert_true(index_of("HolyNova") < index_of("SmiteFiller"), "HolyNova before SmiteFiller")

-- ============================================================================
-- Basic match tests
-- ============================================================================
local inner_fire = find_strategy("InnerFire")
assert_true(inner_fire.matches(make_ctx(), make_state()), "InnerFire matches by default")
assert_false(inner_fire.matches(make_ctx(), make_state({ inner_fire_ready = false })), "InnerFire skips when not ready")
assert_false(inner_fire.matches(make_ctx(), make_state({ has_inner_fire = true, inner_fire_remains = 999 })), "InnerFire skips when buff is fresh")

local holy_fire = find_strategy("HolyFire")
assert_true(holy_fire.matches(make_ctx(), make_state({ hf_ready = true })), "HolyFire matches with HF ready")
assert_false(holy_fire.matches(make_ctx(), make_state({ hf_ready = false })), "HolyFire skips when HF not ready")
assert_false(holy_fire.matches(make_ctx({ is_moving = true }), make_state({ hf_ready = true })), "HolyFire skips when moving")

local smash_filler = find_strategy("SmiteFiller")
assert_true(smash_filler.matches(make_ctx(), make_state()), "SmiteFiller matches by default")
assert_false(smash_filler.matches(make_ctx({ is_moving = true }), make_state()), "SmiteFiller skips when moving")

print(string.format("test_smite_dsl_priority: %d passed, %d failed", _pass, _fail))
if _fail > 0 then os.exit(1) end
print("PASS test_smite_dsl_priority")
