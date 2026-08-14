-- test_restoration_dsl_priority.lua â Restoration Shaman DSL priority + equivalence test.
-- WHAT:  verifies full strategy priority order, DSL position checks, and condition
--        equivalence for 6 DSL-converted strategies (ManaTideTotem, Purge, TremorTotem,
--        GroundingTotem, CurePoison, CureDisease).
-- WHEN:  runs as part of the rotation test suite.
-- WHY:   regression guard for the sixth DSL adopter (first healer spec).
-- SAFETY: standalone â mocks NS, spec_kit, and shared modules; no game API calls.

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

NS.ShamanSpells = {
    Bloodlust = 2825, ChainHeal = 25423, ChainLightning = 25442,
    CureDisease = 2870, CurePoison = 526, DiseaseCleansingTotem = 8170,
    EarthShield = 32594, EarthShock = 25454, FlameShock = 25457,
    GraceOfAirTotem = 25359, GroundingTotem = 8177, HealingWave = 25396,
    LesserHealingWave = 25420, LightningBolt = 25449, LightningShield = 25472,
    ManaSpringTotem = 25570, ManaTideTotem = 16190, NaturesSwiftness = 16188,
    PoisonCleansingTotem = 8166, Purge = 8012, StrengthOfEarthTotem = 25528,
    TremorTotem = 8143, WaterShield = 33736, WindfuryTotem = 25587,
}
NS.ShamanHealing = {
    scan_healing_targets = function() return {}, 0 end,
    select_heal = function() return nil end,
    group_mana_avg = function() return nil end,
    all_members_above_hp = function() return true end,
    count_below_hp = function() return 0 end,
    get_cleanse_target = function() return nil end,
}
NS.PLAYER_UNIT = { get_health = function() return 100 end, is_valid = function() return true end }
NS.GetPlayer = function() return NS.PLAYER_UNIT end
NS.buff_up = function() return false end
NS.debuff_up = function() return false end
NS.debuff_remains = function() return 0 end
NS.buff_stacks = function() return 0 end
NS.buff_remains = function() return 0 end
NS.spell_ready = function() return true end
NS.try_cast = function() return true end
local _healthstone_used = false
NS.use_item_by_id = function(id, target)
    _healthstone_used = id ~= nil and target == NS.PLAYER_UNIT
    return _healthstone_used
end
NS.unit_mana_pct = function() return 100 end
NS.unit_health_pct = function() return 100 end
NS.unit_distance = function() return 100 end
NS.time_now = function() return 0 end
NS.game_time_ms = function() return 0 end
NS.not_same_unit = function() return true end
NS.has_dispel_type_debuff = function() return false end
NS.broken_api_throttled = function() return false end
NS.log = function() end
NS.rotation_registry = { register = function() end }

-- Mock Healing (loaded via require)
package.loaded["classes/shaman/healing_sylvanas"] = NS.ShamanHealing

-- Mock spec_kit (uses _setting local to avoid self-reference issues)
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

-- Mock other shared modules
package.loaded["shared/potion_helper_sylvanas"] = {
    try_use_potion = function() return false end,
    MANA_POTION_IDS = {},
}
package.loaded["shared/fsr_manager_sylvanas"] = {
    is_inside_fsr = function() return false end,
    seconds_until_fsr = function() return 0 end,
    get_regen_delta = function() return 0 end,
    should_pause_for_fsr = function() return false end,
}
package.loaded["shared/preemptive_heal_sylvanas"] = {
    DEFAULT_THRESHOLD = 40,
    match = function() return false end,
    execute = function() return false end,
    get_penalty_adjusted_heal = function(id, ct) return id, 1 end,
}
package.loaded["shared/ts_helper_sylvanas"] = nil
package.loaded["shared/tbc_data_sylvanas"] = { SPELLS = { shaman = {} } }
package.loaded["shared/health_pred_helper_sylvanas"] = nil
package.loaded["shared/aoe_hit_volume_sylvanas"] = { install = function() end }
package.loaded["shared/find_dead_party_ally_sylvanas"] = nil
package.loaded["common/utility/inventory_helper"] = { has_item = function() return true end }

-- Load the real DSL engine and cache it so the spec file's require() picks it up
package.loaded["shared/strategy_dsl_sylvanas"] = dofile("EaxRotations/shared/strategy_dsl_sylvanas.lua")

-- Load the restoration spec
local resto = dofile("EaxRotations/classes/shaman/restoration_sylvanas.lua")
local strategies = resto.strategies

local healthstone
for i = 1, #strategies do
    if strategies[i].name == "Healthstone" then healthstone = strategies[i] break end
end
assert_true(healthstone ~= nil, "Healthstone strategy exists")
_healthstone_used = false
assert_true(healthstone.matches(make_ctx and make_ctx({}) or { in_combat = true }, { hp_pct = 20, healthstone_ready = 1 }), "Healthstone matches at low health")
assert_true(healthstone.execute({ me = NS.PLAYER_UNIT }) == true, "Healthstone executor reports successful item use")
assert_true(_healthstone_used, "Healthstone executor uses the selected item")
NS.use_item_by_id = function() return false end
assert_false(healthstone.execute({ me = NS.PLAYER_UNIT }), "Healthstone executor preserves failed item use")

local earth_shield
for i = 1, #strategies do
    if strategies[i].name == "EarthShieldTank" then earth_shield = strategies[i] break end
end
assert_true(earth_shield ~= nil, "EarthShieldTank strategy exists")
NS.buff_up = function() return true end
local earth_shield_ok, earth_shield_matches = pcall(earth_shield.matches, { settings = {} }, {
    mana_emergency = false,
    tank = { unit = {} },
    earth_shield_ready = true,
    earth_shield_charges = 1,
    earth_shield_remains = 4,
})
assert_true(earth_shield_ok, "Earth Shield low-charge refresh does not crash")
assert_true(earth_shield_matches, "Earth Shield refreshes at low charges near expiry")
NS.buff_up = function() return false end

-- ============================================================================
-- Priority order verification
-- ============================================================================
local expected_order = {
    "FriendlyTarget", "ManaPotion", "Healthstone", "ManaEmergencyWand",
    "WaterShield", "LightningShield", "EarthShieldTank", "NaturesSwiftness",
    "ManaTideTotem", "Bloodlust", "HealingWay", "PreemptiveChainHeal", "FSRPause",
    "LesserHealingWaveEmergency", "ChainHeal", "SmartHeal", "Purge", "TremorTotem",
    "GroundingTotem", "StrengthOfEarthTotem", "ManaSpringTotem", "GraceOfAirTotem",
    "WindfuryTotem", "CurePoison", "CureDisease", "PoisonCleansingTotem",
    "DiseaseCleansingTotem", "EarthShock", "FlameShock", "ChainLightning",
    "LightningBolt",
}
assert_true(#strategies == #expected_order, "strategy count matches (" .. #strategies .. " vs " .. #expected_order .. ")")
for i = 1, math.min(#strategies, #expected_order) do
    assert_true(strategies[i].name == expected_order[i],
        string.format("priority[%d] = %s (expected %s)", i, strategies[i].name or "?", expected_order[i]))
end

-- DSL position checks — verify the 6 DSL-converted strategies are at expected indices
local dsl_indices = {}
for i = 1, #strategies do dsl_indices[strategies[i].name] = i end
assert_true(dsl_indices["ManaTideTotem"] == 9, "ManaTideTotem at index 9")
assert_true(dsl_indices["Purge"] == 17, "Purge at index 17")
assert_true(dsl_indices["TremorTotem"] == 18, "TremorTotem at index 18")
assert_true(dsl_indices["GroundingTotem"] == 19, "GroundingTotem at index 19")
assert_true(dsl_indices["CurePoison"] == 24, "CurePoison at index 24")
assert_true(dsl_indices["CureDisease"] == 25, "CureDisease at index 25")

-- ============================================================================
-- Mock context + state helpers
-- ============================================================================
local function make_ctx(overrides)
    local ctx = {
        me = NS.PLAYER_UNIT,
        target = { is_valid = function() return true end, is_dead = function() return false end,
                   is_casting = function() return false end, get_creature_type = function() return nil end },
        in_combat = true,
        hp = 100,
        mana_pct = 80,
        settings = { use_cooldowns = true },
        has_valid_enemy_target = true,
        is_pvp = false,
        is_moving = false,
    }
    for k, v in pairs(overrides or {}) do ctx[k] = v end
    return ctx
end

local function make_state(overrides)
    local s = {
        mana_pct = 80, hp_pct = 100,
        mana_low = false, mana_conserve = false, mana_emergency = false,
        in_combat = true, is_group = false, enemy_count = 1,
        target_casting = false,
        cure_poison_ready = true, cure_disease_ready = true,
        tremor_totem_ready = true, grounding_totem_ready = true,
        purge_ready = true, mana_tide_ready = true,
        lowest = { unit = NS.PLAYER_UNIT, effective_hp = 80, hp = 80 },
        cleanse_target = nil,
    }
    for k, v in pairs(overrides or {}) do s[k] = v end
    return s
end

-- ============================================================================
-- LesserHealingWaveEmergency (Phase 2.2d): sits ABOVE ChainHeal; mirrors the
-- NaturesSwiftness gates (lowest < 30% HP + TTD < 3s) but casts LHW directly.
-- ============================================================================
local lhw_idx = dsl_indices["LesserHealingWaveEmergency"]
local ch_idx = dsl_indices["ChainHeal"]
assert_true(lhw_idx ~= nil and ch_idx ~= nil, "LesserHealingWaveEmergency + ChainHeal present")
assert_true(lhw_idx < ch_idx, "LesserHealingWaveEmergency above ChainHeal (" .. lhw_idx .. " < " .. ch_idx .. ")")
local lhw_emergency = strategies[lhw_idx]
local emergency_ctx = make_ctx({})
-- Positive: lowest 20% HP, TTD 2s, spell ready -> matches
assert_true(lhw_emergency.matches(emergency_ctx, {
    mana_emergency = false,
    lowest = { unit = NS.PLAYER_UNIT, effective_hp = 20 },
    lowest_time_to_die = 2,
    lesser_healing_wave_ready = true,
}), "LHW emergency matches at 20% HP + 2s TTD")
-- Negative: lowest above 30% HP
assert_false(lhw_emergency.matches(emergency_ctx, {
    mana_emergency = false,
    lowest = { unit = NS.PLAYER_UNIT, effective_hp = 40 },
    lowest_time_to_die = 2,
    lesser_healing_wave_ready = true,
}), "LHW emergency skips above 30% HP")
-- Negative: TTD not short
assert_false(lhw_emergency.matches(emergency_ctx, {
    mana_emergency = false,
    lowest = { unit = NS.PLAYER_UNIT, effective_hp = 20 },
    lowest_time_to_die = 10,
    lesser_healing_wave_ready = true,
}), "LHW emergency skips when TTD is not short")
-- Negative: spell not ready
assert_false(lhw_emergency.matches(emergency_ctx, {
    mana_emergency = false,
    lowest = { unit = NS.PLAYER_UNIT, effective_hp = 20 },
    lowest_time_to_die = 2,
    lesser_healing_wave_ready = false,
}), "LHW emergency skips when spell not ready")
-- Negative: mana emergency
assert_false(lhw_emergency.matches(emergency_ctx, {
    mana_emergency = true,
    lowest = { unit = NS.PLAYER_UNIT, effective_hp = 20 },
    lowest_time_to_die = 2,
    lesser_healing_wave_ready = true,
}), "LHW emergency skips during mana emergency")

-- ============================================================================
-- ManaTideTotem: requires cooldowns enabled, in combat, mana below threshold,
--                group mana below threshold, group healthy, spell ready
-- ============================================================================
local idx_mt = 9
-- Positive: all conditions met (mana=50, group healthy, in combat)
assert_true(strategies[idx_mt].matches(make_ctx({ mana_pct = 50 }), make_state({ mana_pct = 50 })),
    "ManaTideTotem matches when mana low + group healthy + in combat")
-- Negative: cooldowns disabled
assert_false(strategies[idx_mt].matches(make_ctx({ settings = { use_cooldowns = false } }), make_state()),
    "ManaTideTotem skips when cooldowns disabled")
-- Negative: not in combat
assert_false(strategies[idx_mt].matches(make_ctx({ in_combat = false }), make_state({ in_combat = false })),
    "ManaTideTotem skips when not in combat")
-- Negative: mana too high
assert_false(strategies[idx_mt].matches(make_ctx(), make_state({ mana_pct = 90 })),
    "ManaTideTotem skips when mana above threshold")

-- ============================================================================
-- Purge: requires spell ready, target exists, PvP or purge_target
-- ============================================================================
local idx_pg = 17
-- Positive: PvP mode
assert_true(strategies[idx_pg].matches(make_ctx({ is_pvp = true }), make_state()),
    "Purge matches in PvP with target")
-- Positive: purge_target flag
assert_true(strategies[idx_pg].matches(make_ctx({ purge_target = true }), make_state()),
    "Purge matches with purge_target flag")
-- Negative: not PvP, no purge_target
assert_false(strategies[idx_pg].matches(make_ctx(), make_state()),
    "Purge skips when not PvP and no purge_target")
-- Negative: no target
assert_false(strategies[idx_pg].matches(make_ctx({ target = nil }), make_state()),
    "Purge skips without target")
-- Negative: not ready
assert_false(strategies[idx_pg].matches(make_ctx({ is_pvp = true }), make_state({ purge_ready = false })),
    "Purge skips when not ready")

-- ============================================================================
-- TremorTotem: requires spell ready, in combat, fear/control nearby
-- ============================================================================
local idx_tr = 18
-- Positive: fear nearby
assert_true(strategies[idx_tr].matches(make_ctx({ fear_nearby = true }), make_state()),
    "TremorTotem matches when fear nearby + in combat")
-- Positive: control_risk
assert_true(strategies[idx_tr].matches(make_ctx({ control_risk = true }), make_state()),
    "TremorTotem matches when control_risk + in combat")
-- Negative: no fear/control flags
assert_false(strategies[idx_tr].matches(make_ctx(), make_state()),
    "TremorTotem skips without fear/control flags")
-- Negative: not in combat
assert_false(strategies[idx_tr].matches(make_ctx({ fear_nearby = true, in_combat = false }), make_state({ in_combat = false })),
    "TremorTotem skips when not in combat")
-- Negative: not ready
assert_false(strategies[idx_tr].matches(make_ctx({ fear_nearby = true }), make_state({ tremor_totem_ready = false })),
    "TremorTotem skips when not ready")

-- ============================================================================
-- GroundingTotem: requires spell ready, in combat, enemy_count >= 1,
--                 PvP or target casting
-- ============================================================================
local idx_gr = 19
-- Positive: PvP
assert_true(strategies[idx_gr].matches(make_ctx({ is_pvp = true }), make_state()),
    "GroundingTotem matches in PvP + in combat")
-- Positive: target casting
assert_true(strategies[idx_gr].matches(make_ctx({ target_casting = true }), make_state({ target_casting = true })),
    "GroundingTotem matches when target casting")
-- Negative: not PvP, not casting
assert_false(strategies[idx_gr].matches(make_ctx(), make_state()),
    "GroundingTotem skips when not PvP and not casting")
-- Negative: not in combat
assert_false(strategies[idx_gr].matches(make_ctx({ is_pvp = true, in_combat = false }), make_state({ in_combat = false })),
    "GroundingTotem skips when not in combat")
-- Negative: not ready
assert_false(strategies[idx_gr].matches(make_ctx({ is_pvp = true }), make_state({ grounding_totem_ready = false })),
    "GroundingTotem skips when not ready")

-- ============================================================================
-- CurePoison: requires spell ready, not broken_api, not mana_emergency,
--             cleanse target with poison, lowest HP not critical
-- ============================================================================
local idx_cp = 24
local mock_cleanse_poison = { unit = NS.PLAYER_UNIT, has_poison = true, has_disease = false }
-- Positive: has poison target
assert_true(strategies[idx_cp].matches(make_ctx(), make_state({ cleanse_target = mock_cleanse_poison })),
    "CurePoison matches with poison target")
-- Negative: no cleanse target
assert_false(strategies[idx_cp].matches(make_ctx(), make_state({ cleanse_target = nil })),
    "CurePoison skips without cleanse target")
-- Negative: target has no poison
assert_false(strategies[idx_cp].matches(make_ctx(), make_state({ cleanse_target = { has_poison = false } })),
    "CurePoison skips when target has no poison")
-- Negative: mana emergency
assert_false(strategies[idx_cp].matches(make_ctx(), make_state({ cleanse_target = mock_cleanse_poison, mana_emergency = true })),
    "CurePoison skips during mana emergency")
-- Negative: not ready
assert_false(strategies[idx_cp].matches(make_ctx(), make_state({ cleanse_target = mock_cleanse_poison, cure_poison_ready = false })),
    "CurePoison skips when not ready")
-- Negative: lowest HP critical
assert_false(strategies[idx_cp].matches(make_ctx(), make_state({ cleanse_target = mock_cleanse_poison, lowest = { effective_hp = 20 } })),
    "CurePoison skips when lowest ally HP critical")

-- ============================================================================
-- CureDisease: requires spell ready, not broken_api, not mana_emergency,
--              cleanse target with disease, lowest HP not critical
-- ============================================================================
local idx_cd = 25
local mock_cleanse_disease = { unit = NS.PLAYER_UNIT, has_poison = false, has_disease = true }
-- Positive: has disease target
assert_true(strategies[idx_cd].matches(make_ctx(), make_state({ cleanse_target = mock_cleanse_disease })),
    "CureDisease matches with disease target")
-- Negative: no cleanse target
assert_false(strategies[idx_cd].matches(make_ctx(), make_state({ cleanse_target = nil })),
    "CureDisease skips without cleanse target")
-- Negative: target has no disease
assert_false(strategies[idx_cd].matches(make_ctx(), make_state({ cleanse_target = { has_disease = false } })),
    "CureDisease skips when target has no disease")
-- Negative: mana emergency
assert_false(strategies[idx_cd].matches(make_ctx(), make_state({ cleanse_target = mock_cleanse_disease, mana_emergency = true })),
    "CureDisease skips during mana emergency")
-- Negative: not ready
assert_false(strategies[idx_cd].matches(make_ctx(), make_state({ cleanse_target = mock_cleanse_disease, cure_disease_ready = false })),
    "CureDisease skips when not ready")
-- Negative: lowest HP critical
assert_false(strategies[idx_cd].matches(make_ctx(), make_state({ cleanse_target = mock_cleanse_disease, lowest = { effective_hp = 20 } })),
    "CureDisease skips when lowest ally HP critical")

-- ============================================================================
-- Summary
-- ============================================================================
print(string.format("test_restoration_dsl_priority: %d passed, %d failed", _pass, _fail))
if _fail > 0 then
    os.exit(1)
end
print("PASS test_restoration_dsl_priority")
