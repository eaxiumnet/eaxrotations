-- test_holy_dsl_priority.lua â Holy Paladin DSL priority + equivalence test.
-- WHAT:  Verifies that the 6 DSL-converted strategies preserve priority order
--        and behave equivalently to the original imperative match functions.
-- WHEN:  Run by the rotation test suite.
-- WHY:   Regression guard for the 26th strategy DSL adopter (holy paladin healer).
-- SAFETY: Pure unit tests with mocked API context; mocks are restored after loading.

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

NS.PaladinSpells = {}
NS.PaladinHealing = {
    scan_healing_targets = function() return {}, 0 end,
    get_tank = function() return nil end,
    get_lowest_hp = function() return nil end,
}
NS.PLAYER_UNIT = { get_health = function() return 100 end, is_valid = function() return true end }
NS.GetPlayer = function() return NS.PLAYER_UNIT end
NS.buff_up = function() return false end
NS.debuff_up = function() return false end
NS.debuff_remains = function() return 0 end
NS.has_player_buff = function() return false end
NS.has_player_debuff = function() return false end
NS.buff_remains = function() return 0 end
NS.spell_ready = function() return true end
NS.try_cast = function() return true end
NS.is_item_ready = function() return false end
NS.use_item_by_id = function() return true end
NS.unit_health_pct = function() return 100 end
NS.mana_pct = function() return 100 end
NS.power_pct = function() return 100 end
NS.time_now = function() return 0 end
NS.broken_api_throttled = function() return false end
NS.gate_overheal = function() return false end
NS.healing_get_lowest_hp = function() return nil end
NS.healing_get_tank = function() return nil end
NS.get_friendly_target_entry = function() return nil end
NS.is_pvp_zone = function() return false end
NS.log = function() end
NS.rotation_registry = { register = function() end }

-- Mock shared modules
local _setting = function(context, key, default)
    if context and context.settings and context.settings[key] ~= nil then
        return context.settings[key]
    end
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
        return setmetatable({}, {
            __index = function(t, k)
                if raw[k] ~= nil then return raw[k] end
                if schema and schema[k] ~= nil then return schema[k] end
                return nil
            end,
        })
    end,
    setting = _setting,
    setting_bool = function(context, key, default)
        local v = _setting(context, key, nil)
        if v == nil then return default end
        return v ~= false
    end,
    setting_number = function(context, key, default)
        local v = _setting(context, key, nil)
        if type(v) == "number" then return v end
        return default
    end,
}
package.loaded["shared/spec_kit_sylvanas"] = mock_spec_kit
package.loaded["classes/paladin/healing_sylvanas"] = NS.PaladinHealing
package.loaded["shared/fsr_manager_sylvanas"] = {
    is_inside_fsr = function() return false end,
    seconds_until_fsr = function() return 0 end,
    get_regen_delta = function() return 0 end,
    should_pause_for_fsr = function() return false end,
}
package.loaded["shared/tbc_data_sylvanas"] = { ITEMS = { potions = {} } }
package.loaded["shared/health_pred_helper_sylvanas"] = nil
package.loaded["shared/potion_helper_sylvanas"] = {
    MANA_POTION_IDS = { 28100 },
    try_use_potion = function(ctx, ids) return true end,
}

-- Load the real DSL engine so the spec file's require() picks it up
package.loaded["shared/strategy_dsl_sylvanas"] = dofile("EaxRotations/shared/strategy_dsl_sylvanas.lua")

-- Load the holy paladin spec
local holy = dofile("EaxRotations/classes/paladin/holy_sylvanas.lua")
local strategies = holy.strategies

-- Restore package.loaded for spec_kit so later tests load real module
package.loaded["shared/spec_kit_sylvanas"] = nil

-- ============================================================================
-- Helpers
-- ============================================================================
local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i], i end
    end
    error("strategy not found: " .. name)
end

local function index_of(name)
    local _, idx = find_strategy(name)
    return idx
end

local function make_ctx(overrides)
    local ctx = {
        me = NS.PLAYER_UNIT,
        in_combat = true,
        hp = 100,
        mana_pct = 100,
        settings = {},
    }
    for k, v in pairs(overrides or {}) do ctx[k] = v end
    return ctx
end

local function make_state(overrides)
    local s = {
        hp_pct = 100,
        mana_pct = 100,
        has_forbearance = false,
        has_divine_illumination = false,
        heavy_healing = false,
        has_seal_wisdom = false,
        healthstone_ready = 0,
    }
    for k, v in pairs(overrides or {}) do s[k] = v end
    return s
end

-- ============================================================================
-- Priority order sanity check
-- ============================================================================
local ds = index_of("DivineShieldSelfPreservation")
local di = index_of("DivineIlluminationHeavyHealing")
local mp = index_of("ManaPotion")
local dr = index_of("DarkRune")
local sw = index_of("SealOfWisdomLowMana")
local hs = index_of("Healthstone")

assert_true(ds < di, "DivineShieldSelfPreservation before DivineIlluminationHeavyHealing")
assert_true(di < mp, "DivineIlluminationHeavyHealing before ManaPotion")
assert_true(mp < dr, "ManaPotion before DarkRune")
assert_true(dr < sw, "DarkRune before SealOfWisdomLowMana")
assert_true(sw < hs, "SealOfWisdomLowMana before Healthstone")

-- ============================================================================
-- DivineShieldSelfPreservation equivalence
-- ============================================================================
local divine_shield = find_strategy("DivineShieldSelfPreservation")
assert_true(divine_shield.matches(make_ctx({ hp = 15 }), make_state({ hp_pct = 15 })),
    "DivineShield matches at low HP without forbearance")
assert_false(divine_shield.matches(make_ctx({ hp = 80 }), make_state({ hp_pct = 80 })),
    "DivineShield skips at high HP")
assert_false(divine_shield.matches(make_ctx({ hp = 15 }), make_state({ hp_pct = 15, has_forbearance = true })),
    "DivineShield skips with forbearance")

-- ============================================================================
-- DivineIlluminationHeavyHealing equivalence
-- ============================================================================
local div_illum = find_strategy("DivineIlluminationHeavyHealing")
assert_true(div_illum.matches(make_ctx(), make_state({ has_divine_illumination = false, heavy_healing = true })),
    "DivineIllumination matches during heavy healing")
assert_true(div_illum.matches(make_ctx(), make_state({ has_divine_illumination = false, heavy_healing = false, mana_pct = 30 })),
    "DivineIllumination matches at low mana")
assert_false(div_illum.matches(make_ctx(), make_state({ has_divine_illumination = false, heavy_healing = false, mana_pct = 80 })),
    "DivineIllumination skips when not heavy and mana ok")
assert_false(div_illum.matches(make_ctx(), make_state({ has_divine_illumination = true, heavy_healing = true })),
    "DivineIllumination skips when already active")

-- ============================================================================
-- ManaPotion equivalence
-- ============================================================================
local mana_pot = find_strategy("ManaPotion")
assert_true(mana_pot.matches(make_ctx(), make_state({ mana_pct = 20 })),
    "ManaPotion matches at low mana")
assert_false(mana_pot.matches(make_ctx(), make_state({ mana_pct = 80 })),
    "ManaPotion skips at high mana")

-- ============================================================================
-- DarkRune equivalence
-- ============================================================================
local dark_rune = find_strategy("DarkRune")
assert_true(dark_rune.matches(make_ctx(), make_state({ mana_pct = 15, hp_pct = 80 })),
    "DarkRune matches at low mana and safe HP")
assert_false(dark_rune.matches(make_ctx(), make_state({ mana_pct = 15, hp_pct = 30 })),
    "DarkRune skips when HP too low")
assert_false(dark_rune.matches(make_ctx(), make_state({ mana_pct = 80, hp_pct = 80 })),
    "DarkRune skips when mana ok")

-- ============================================================================
-- SealOfWisdomLowMana equivalence
-- ============================================================================
local seal_wisdom = find_strategy("SealOfWisdomLowMana")
assert_true(seal_wisdom.matches(make_ctx(), make_state({ mana_pct = 30, has_seal_wisdom = false })),
    "SealOfWisdom matches at low mana without buff")
assert_false(seal_wisdom.matches(make_ctx(), make_state({ mana_pct = 30, has_seal_wisdom = true })),
    "SealOfWisdom skips when buff already active")
assert_false(seal_wisdom.matches(make_ctx(), make_state({ mana_pct = 80, has_seal_wisdom = false })),
    "SealOfWisdom skips when mana ok")

-- ============================================================================
-- Healthstone equivalence
-- ============================================================================
local healthstone = find_strategy("Healthstone")
assert_true(healthstone.matches(make_ctx({ in_combat = true, hp = 20 }), make_state({ healthstone_ready = 12345 })),
    "Healthstone matches in combat with low HP and item ready")
assert_false(healthstone.matches(make_ctx({ in_combat = false, hp = 20 }), make_state({ healthstone_ready = 12345 })),
    "Healthstone skips out of combat")
assert_false(healthstone.matches(make_ctx({ in_combat = true, hp = 80 }), make_state({ healthstone_ready = 12345 })),
    "Healthstone skips at high HP")
assert_false(healthstone.matches(make_ctx({ in_combat = true, hp = 20 }), make_state({ healthstone_ready = 0 })),
    "Healthstone skips when no item ready")

-- ============================================================================
-- Priority order sanity check for expanded strategies
-- ============================================================================
local loh = index_of("LayOnHandsLastResort")
local aw = index_of("AvengingWrathHeavyHealing")
local lgc = index_of("LightGraceChain")

assert_true(loh > index_of("FriendlyTarget"), "LayOnHandsLastResort after FriendlyTarget")
assert_true(loh < ds, "LayOnHandsLastResort before DivineShieldSelfPreservation")
assert_true(aw > di, "AvengingWrathHeavyHealing after DivineIlluminationHeavyHealing")
assert_true(aw < index_of("HolyShock"), "AvengingWrathHeavyHealing before HolyShock")
assert_true(lgc > index_of("DivineFavorHolyLightFollowup"), "LightGraceChain after DivineFavorHolyLightFollowup")
assert_true(lgc < index_of("LightGraceBuild"), "LightGraceChain before LightGraceBuild")

-- ============================================================================
-- LayOnHandsLastResort equivalence
-- ============================================================================
local lay_on_hands = find_strategy("LayOnHandsLastResort")
assert_true(lay_on_hands.matches(make_ctx(), make_state({ lowest = { unit = "party1", effective_hp = 10 } })),
    "LayOnHands matches on lowest with <=12% HP and spell ready")
assert_false(lay_on_hands.matches(make_ctx(), make_state({ lowest = { unit = "party1", effective_hp = 50 } })),
    "LayOnHands skips when lowest HP is above threshold")
assert_false(lay_on_hands.matches(make_ctx(), make_state({ lowest = nil })),
    "LayOnHands skips when lowest is nil")
local original_spell_ready = NS.spell_ready
NS.spell_ready = function() return false end
local ok, err = pcall(function()
    assert_false(lay_on_hands.matches(make_ctx(), make_state({ lowest = { unit = "party1", effective_hp = 10 } })),
        "LayOnHands skips when spell is not ready")
end)
NS.spell_ready = original_spell_ready
if not ok then error(err) end

-- ============================================================================
-- AvengingWrathHeavyHealing equivalence
-- ============================================================================
local avenging_wrath = find_strategy("AvengingWrathHeavyHealing")
assert_true(avenging_wrath.matches(make_ctx({ in_combat = true }), make_state({ heavy_healing = true })),
    "AvengingWrath matches in combat during heavy healing")
assert_false(avenging_wrath.matches(make_ctx({ in_combat = false }), make_state({ heavy_healing = true })),
    "AvengingWrath skips out of combat")
assert_false(avenging_wrath.matches(make_ctx({ in_combat = true, settings = { holy_avenging_wrath = false } }), make_state({ heavy_healing = true })),
    "AvengingWrath skips when setting disabled")
assert_false(avenging_wrath.matches(make_ctx({ in_combat = true, ttd_known = true, ttd = 10 }), make_state({ heavy_healing = true })),
    "AvengingWrath skips when target time-to-die is too short")

-- ============================================================================
-- LightGraceChain equivalence
-- ============================================================================
local light_grace_chain = find_strategy("LightGraceChain")
assert_true(light_grace_chain.matches(make_ctx({ in_combat = true }), make_state({ lights_grace_remains = 1.8, tank = { unit = "tank1", deficit = 500, effective_hp = 50 } })),
    "LightGraceChain matches when LG expiring, tank has deficit and spell ready")
assert_false(light_grace_chain.matches(make_ctx({ in_combat = true }), make_state({ lights_grace_remains = 0, tank = { unit = "tank1", deficit = 500, effective_hp = 50 } })),
    "LightGraceChain skips when Light's Grace has expired")
assert_false(light_grace_chain.matches(make_ctx({ in_combat = true }), make_state({ lights_grace_remains = 3.0, tank = { unit = "tank1", deficit = 500, effective_hp = 50 } })),
    "LightGraceChain skips when Light's Grace buffer is still safe")
assert_false(light_grace_chain.matches(make_ctx({ in_combat = true }), make_state({ lights_grace_remains = 1.8, tank = nil })),
    "LightGraceChain skips when no tank is available")
assert_false(light_grace_chain.matches(make_ctx({ in_combat = true, settings = { holy_lg_chain_enabled = false } }), make_state({ lights_grace_remains = 1.8, tank = { unit = "tank1", deficit = 500, effective_hp = 50 } })),
    "LightGraceChain skips when setting disabled")

-- ============================================================================
-- DivineFavor equivalence
-- ============================================================================
local divine_favor = find_strategy("DivineFavor")
assert_true(divine_favor.matches(make_ctx(), make_state({ lowest = { unit = "party1", effective_hp = 30 } })),
    "DivineFavor matches when lowest is low HP and buff not active")
assert_false(divine_favor.matches(make_ctx(), make_state({ lowest = { unit = "party1", effective_hp = 30 }, has_divine_favor = true })),
    "DivineFavor skips when Divine Favor already active")
assert_false(divine_favor.matches(make_ctx(), make_state({ lowest = { unit = "party1", effective_hp = 80 } })),
    "DivineFavor skips when lowest HP is above threshold")
assert_false(divine_favor.matches(make_ctx(), make_state({ lowest = nil })),
    "DivineFavor skips when no lowest/tank target")

-- ============================================================================
-- DivineFavorHolyShockCombo equivalence
-- ============================================================================
local df_holy_shock = find_strategy("DivineFavorHolyShockCombo")
assert_true(df_holy_shock.matches(make_ctx(), make_state({ lowest = { unit = "party1", effective_hp = 30 }, has_divine_favor = true })),
    "DivineFavorHolyShockCombo matches with Divine Favor active and low target")
assert_false(df_holy_shock.matches(make_ctx(), make_state({ lowest = { unit = "party1", effective_hp = 30 }, has_divine_favor = false })),
    "DivineFavorHolyShockCombo skips without Divine Favor")
assert_false(df_holy_shock.matches(make_ctx(), make_state({ lowest = { unit = "party1", effective_hp = 80 }, has_divine_favor = true })),
    "DivineFavorHolyShockCombo skips when target HP is above threshold")

-- ============================================================================
-- HolyShock equivalence
-- ============================================================================
local holy_shock = find_strategy("HolyShock")
assert_true(holy_shock.matches(make_ctx(), make_state({ lowest = { unit = "party1", effective_hp = 30 } })),
    "HolyShock matches at low HP")
assert_false(holy_shock.matches(make_ctx({ is_moving = false }), make_state({ lowest = { unit = "party1", effective_hp = 80 } })),
    "HolyShock skips at high HP when not moving")
assert_true(holy_shock.matches(make_ctx({ is_moving = true }), make_state({ lowest = { unit = "party1", effective_hp = 80 } })),
    "HolyShock matches as an instant fallback when moving")
assert_false(holy_shock.matches(make_ctx(), make_state({ lowest = nil })),
    "HolyShock skips when no lowest target")

-- ============================================================================
-- HolyLightEmergency equivalence
-- ============================================================================
local holy_light_emergency = find_strategy("HolyLightEmergency")
assert_true(holy_light_emergency.matches(make_ctx(), make_state({ lowest = { unit = "party1", effective_hp = 40 } })),
    "HolyLightEmergency matches at low HP")
assert_false(holy_light_emergency.matches(make_ctx(), make_state({ lowest = { unit = "party1", effective_hp = 80 } })),
    "HolyLightEmergency skips at high HP")
assert_false(holy_light_emergency.matches(make_ctx(), make_state({ lowest = nil })),
    "HolyLightEmergency skips when no lowest target")

-- ============================================================================
-- DivineFavorHolyLightFollowup equivalence
-- ============================================================================
local df_holy_light = find_strategy("DivineFavorHolyLightFollowup")
assert_true(df_holy_light.matches(make_ctx(), make_state({ lowest = { unit = "party1", effective_hp = 40 }, has_divine_favor = true })),
    "DivineFavorHolyLightFollowup matches with Divine Favor and low target")
assert_false(df_holy_light.matches(make_ctx(), make_state({ lowest = { unit = "party1", effective_hp = 40 }, has_divine_favor = false })),
    "DivineFavorHolyLightFollowup skips without Divine Favor")
assert_false(df_holy_light.matches(make_ctx(), make_state({ lowest = nil, has_divine_favor = true })),
    "DivineFavorHolyLightFollowup skips when no lowest target")

-- ============================================================================
-- LightGraceBuild equivalence
-- ============================================================================
local light_grace_build = find_strategy("LightGraceBuild")
assert_true(light_grace_build.matches(make_ctx({ in_combat = true }), make_state({ tank = { unit = "tank1", deficit = 500, effective_hp = 50 }, lights_grace_remains = 1.0 })),
    "LightGraceBuild matches in combat with expiring LG and tank deficit")
assert_false(light_grace_build.matches(make_ctx({ in_combat = true }), make_state({ tank = { unit = "tank1", deficit = 0, effective_hp = 50 }, lights_grace_remains = 1.0 })),
    "LightGraceBuild skips when tank has no deficit")
assert_false(light_grace_build.matches(make_ctx({ in_combat = true }), make_state({ tank = { unit = "tank1", deficit = 500, effective_hp = 50 }, lights_grace_remains = 10.0 })),
    "LightGraceBuild skips when Light's Grace buffer is safe")
assert_false(light_grace_build.matches(make_ctx({ in_combat = false }), make_state({ tank = { unit = "tank1", deficit = 500, effective_hp = 50 }, lights_grace_remains = 1.0 })),
    "LightGraceBuild skips out of combat")
assert_false(light_grace_build.matches(make_ctx({ in_combat = true, settings = { holy_lg_build_enabled = false } }), make_state({ tank = { unit = "tank1", deficit = 500, effective_hp = 50 }, lights_grace_remains = 1.0 })),
    "LightGraceBuild skips when setting disabled")

-- ============================================================================
-- Summary
-- ============================================================================
print(string.format("test_holy_dsl_priority: %d passed, %d failed", _pass, _fail))
if _fail > 0 then
    os.exit(1)
end
print("PASS test_holy_dsl_priority")
