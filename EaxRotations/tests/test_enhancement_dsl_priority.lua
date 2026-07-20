-- test_enhancement_dsl_priority.lua — Enhancement Shaman DSL priority + equivalence test.
-- WHAT:  verifies full strategy priority order, DSL position checks, and condition
--        equivalence for 6 DSL-converted strategies (ShamanisticRage, Bloodlust,
--        ManaTideTotem, Stormstrike, FlameShock, FrostShock).
-- WHEN:  runs as part of the rotation test suite.
-- WHY:   regression guard for the twelfth DSL adopter (first enhancement shaman/melee+totem spec).
-- SAFETY: standalone — mocks NS, spec_kit, and shared modules; no game API calls.

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
    EarthShock = 25454, FireNovaTotem = 25547, FlametongueWeapon = 25489,
    FlameShock = 25457, FrostShock = 25464, FrostbrandWeapon = 25500,
    GiftOfTheNaaru = 28880, GraceOfAirTotem = 25359, GroundingTotem = 8177,
    HealingStreamTotem = 25567, LesserHealingWave = 25420, LightningBolt = 25449,
    LightningShield = 25472, MagmaTotem = 25552, ManaSpringTotem = 25570,
    ManaTideTotem = 16190, NaturesSwiftness = 16188, Purge = 8012,
    RockbiterWeapon = 25485, SearingTotem = 25533, ShamanisticRage = 30823,
    Stormstrike = 17364, StrengthOfEarthTotem = 25528, StoneskinTotem = 25509,
    TotemicCall = 36936, WaterShield = 33736, WindfuryTotem = 25587,
    WindfuryWeapon = 25505,
}
NS.PLAYER_UNIT = {
    get_health = function() return 100 end,
    get_health_percentage = function() return 100 end,
    is_valid = function() return true end,
    is_dead = function() return false end,
    is_casting = function() return false end,
    is_mounted = function() return false end,
    is_moving = function() return false end,
    get_guid = function() return "player" end,
    get_level = function() return 70 end,
}
NS.GetPlayer = function() return NS.PLAYER_UNIT end
NS.buff_up = function() return false end
NS.debuff_up = function() return false end
NS.debuff_remains = function() return 0 end
NS.get_debuff_stacks = function() return 0 end
NS.buff_stacks = function() return 0 end
NS.buff_remains = function() return 0 end
NS.spell_ready = function() return true end
NS.try_cast = function() return true end
NS.unit_mana_pct = function() return 100 end
NS.unit_health_pct = function() return 100 end
NS.unit_distance = function() return 5 end
NS.time_now = function() return 0 end
NS.game_time_ms = function() return 0 end
NS.broken_api_throttled = function() return false end
NS.gate_cooldown_boss_only = function() return true end
NS.should_use_long_cd = function() return true end
NS.is_interruptible = function() return true end
NS.is_in_combat = function() return false end
NS.is_auto_attacking = function() return false end
NS.start_auto_attack = function() return true end
NS.log = function() end
NS.log_warning = function() end
NS.rotation_registry = { register = function() end }
NS.purge_should_cast = function() return false end
NS.get_totem_info = function() return nil end
NS.WeaponImbueManager = {
    mainhand_has_imbue = function() return false end,
    offhand_has_imbue = function() return false end,
    get_mainhand_enchant_info = function() return nil end,
    get_offhand_enchant_info = function() return nil end,
}
NS.SwingDiagnostics = nil

-- Mock spec_kit
local _setting = function(context, key, default)
    if context and context.settings and context.settings[key] ~= nil then
        return context.settings[key]
    end
    return default
end
local mock_spec_kit = {
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

-- Mock shared modules
package.loaded["shared/tbc_data_sylvanas"] = { SPELLS = { shaman = {} } }
package.loaded["shared/potion_helper_sylvanas"] = {
    try_use_potion = function() return false end,
    MANA_POTION_IDS = {},
}
package.loaded["shared/cooldown_planner_sylvanas"] = {
    is_major_offensive_cd_active = function() return false end,
}
package.loaded["common/utility/inventory_helper"] = { has_item = function() return nil end }

-- Load the real DSL engine and cache it so the spec file's require() picks it up
package.loaded["shared/strategy_dsl_sylvanas"] = dofile("EaxRotations/shared/strategy_dsl_sylvanas.lua")

-- Load the enhancement spec
local enh = dofile("EaxRotations/classes/shaman/enhancement_sylvanas.lua")
local strategies = enh.strategies

-- ============================================================================
-- Priority order verification
-- ============================================================================
local expected_order = {
    "ManaPotion", "Healthstone", "ManaEmergencyWand", "AutoAttack", "GhostWolf",
    "TotemicCall", "FireNovaReplacement", "EarthTotem", "WaterTotem", "FireTotem",
    "WindfuryTotemTwist", "GraceOfAirTotemTwist", "WindfuryTotemMaintain",
    "MHWeaponBuff", "OHWeaponBuff", "WaterShield", "LightningShield",
    "ShamanisticRage", "Bloodlust", "ManaTideTotem", "NaturesSwiftness",
    "TremorTotem", "GroundingTotem", "Purge", "BloodFury", "Berserking",
    "GiftOfTheNaaru", "LesserHealingWave", "ChainHeal", "Stormstrike",
    "FlameShock", "EarthShock", "FrostShock", "ChainLightning", "LightningBolt",
}
assert_true(#strategies == #expected_order, "strategy count matches (" .. #strategies .. " vs " .. #expected_order .. ")")
for i = 1, math.min(#strategies, #expected_order) do
    assert_true(strategies[i].name == expected_order[i],
        string.format("priority[%d] = %s (expected %s)", i, strategies[i].name or "?", expected_order[i]))
end

-- DSL position checks — verify the 6 DSL-converted strategies are at expected indices
local dsl_indices = {}
for i = 1, #strategies do dsl_indices[strategies[i].name] = i end
assert_true(dsl_indices["ShamanisticRage"] == 18, "ShamanisticRage at index 18")
assert_true(dsl_indices["Bloodlust"] == 19, "Bloodlust at index 19")
assert_true(dsl_indices["ManaTideTotem"] == 20, "ManaTideTotem at index 20")
assert_true(dsl_indices["Stormstrike"] == 30, "Stormstrike at index 30")
assert_true(dsl_indices["FlameShock"] == 31, "FlameShock at index 31")
assert_true(dsl_indices["FrostShock"] == 33, "FrostShock at index 33")

-- ============================================================================
-- Mock context + state helpers
-- ============================================================================
local function make_target()
    return {
        is_valid = function() return true end,
        is_dead = function() return false end,
        is_casting = function() return false end,
        get_cast_pct = function() return 0 end,
        get_health_percentage = function() return 100 end,
        get_creature_type = function() return nil end,
        get_guid = function() return "target" end,
        get_distance = function() return 5 end,
    }
end

local function make_ctx(overrides)
    local ctx = {
        me = NS.PLAYER_UNIT,
        target = make_target(),
        in_combat = true,
        hp = 100,
        hp_pct = 100,
        mana_pct = 80,
        settings = {
            use_cooldowns = true,
            enhancement_cd_shamanistic_rage = true,
            enhancement_cd_bloodlust = true,
            enhancement_cd_mana_tide = true,
        },
        is_pvp = false,
        is_moving = false,
        ttd_known = false,
        ttd = 999,
    }
    for k, v in pairs(overrides or {}) do ctx[k] = v end
    return ctx
end

local function make_state(overrides)
    local s = {
        in_combat = true,
        is_moving = false,
        hp_pct = 100,
        mana_pct = 80,
        mana_low = false,
        mana_emergency = false,
        enemy_count = 1,
        effective_mode = "single",
        hold_shocks_focus = false,
        fs_multi_target = false,
        sr_melee_only = false,
        shamanistic_rage_ready = true,
        bloodlust_ready = true,
        mana_tide_totem_ready = true,
        stormstrike_ready = true,
        flame_shock_ready = true,
        frost_shock_ready = true,
        major_cd_window = true,
        target_has_flame_shock = false,
        flame_shock_remains = 0,
    }
    for k, v in pairs(overrides or {}) do s[k] = v end
    return s
end

-- ============================================================================
-- ShamanisticRage: in combat, no buff, ready, setting enabled, boss gate,
--                  major_cd_window or low mana/hp, melee range if sr_melee_only
-- ============================================================================
local idx_sr = dsl_indices["ShamanisticRage"]
assert_true(strategies[idx_sr].matches(make_ctx(), make_state()),
    "ShamanisticRage matches with all defaults + major_cd_window")
assert_false(strategies[idx_sr].matches(make_ctx({ in_combat = false }), make_state({ in_combat = false })),
    "ShamanisticRage skips when not in combat")
assert_false(strategies[idx_sr].matches(make_ctx({ settings = { enhancement_cd_shamanistic_rage = false } }), make_state()),
    "ShamanisticRage skips when CD toggle disabled")
assert_false(strategies[idx_sr].matches(make_ctx(), make_state({ shamanistic_rage_ready = false })),
    "ShamanisticRage skips when not ready")
assert_false(strategies[idx_sr].matches(make_ctx(), make_state({ major_cd_window = false, mana_pct = 80, hp_pct = 100 })),
    "ShamanisticRage skips when neither offensive nor defensive use")

-- ============================================================================
-- Bloodlust: cooldowns enabled, setting enabled, in combat, no buff, ready
-- ============================================================================
local idx_bl = dsl_indices["Bloodlust"]
assert_true(strategies[idx_bl].matches(make_ctx(), make_state()),
    "Bloodlust matches with all defaults")
assert_false(strategies[idx_bl].matches(make_ctx({ in_combat = false }), make_state({ in_combat = false })),
    "Bloodlust skips when not in combat")
assert_false(strategies[idx_bl].matches(make_ctx({ settings = { use_cooldowns = false } }), make_state()),
    "Bloodlust skips when cooldowns disabled")
assert_false(strategies[idx_bl].matches(make_ctx(), make_state({ bloodlust_ready = false })),
    "Bloodlust skips when not ready")

-- ============================================================================
-- ManaTideTotem: cooldowns enabled, setting enabled, ready, mana <= 60
-- ============================================================================
local idx_mtt = dsl_indices["ManaTideTotem"]
assert_true(strategies[idx_mtt].matches(make_ctx({ mana_pct = 50 }), make_state({ mana_pct = 50 })),
    "ManaTideTotem matches when mana low + ready")
assert_false(strategies[idx_mtt].matches(make_ctx({ mana_pct = 80 }), make_state({ mana_pct = 80 })),
    "ManaTideTotem skips when mana above threshold")
assert_false(strategies[idx_mtt].matches(make_ctx({ settings = { use_cooldowns = false } }), make_state({ mana_pct = 50 })),
    "ManaTideTotem skips when cooldowns disabled")
assert_false(strategies[idx_mtt].matches(make_ctx(), make_state({ mana_tide_totem_ready = false })),
    "ManaTideTotem skips when not ready")

-- ============================================================================
-- Stormstrike: ready, not mana emergency
-- ============================================================================
local idx_ss = dsl_indices["Stormstrike"]
assert_true(strategies[idx_ss].matches(make_ctx(), make_state()),
    "Stormstrike matches when ready + no mana emergency")
assert_false(strategies[idx_ss].matches(make_ctx(), make_state({ stormstrike_ready = false })),
    "Stormstrike skips when not ready")
assert_false(strategies[idx_ss].matches(make_ctx(), make_state({ mana_emergency = true })),
    "Stormstrike skips during mana emergency")

-- ============================================================================
-- FlameShock: ready, not mana_low, not hold_shocks_focus OOC, ttd >= 6,
--             refresh when debuff missing or < 3s
-- ============================================================================
local idx_fs = dsl_indices["FlameShock"]
assert_true(strategies[idx_fs].matches(make_ctx(), make_state()),
    "FlameShock matches when ready + no debuff + enough mana")
assert_false(strategies[idx_fs].matches(make_ctx(), make_state({ flame_shock_ready = false })),
    "FlameShock skips when not ready")
assert_false(strategies[idx_fs].matches(make_ctx(), make_state({ mana_low = true })),
    "FlameShock skips when mana_low")
assert_false(strategies[idx_fs].matches(make_ctx(), make_state({ target_has_flame_shock = true, flame_shock_remains = 10 })),
    "FlameShock skips when debuff safe")
assert_true(strategies[idx_fs].matches(make_ctx(), make_state({ target_has_flame_shock = true, flame_shock_remains = 2 })),
    "FlameShock matches when debuff about to drop")

-- ============================================================================
-- FrostShock: ready, not mana_low, not hold_shocks_focus OOC
-- ============================================================================
local idx_frs = dsl_indices["FrostShock"]
assert_true(strategies[idx_frs].matches(make_ctx(), make_state()),
    "FrostShock matches when ready + enough mana")
assert_false(strategies[idx_frs].matches(make_ctx(), make_state({ frost_shock_ready = false })),
    "FrostShock skips when not ready")
assert_false(strategies[idx_frs].matches(make_ctx(), make_state({ mana_low = true })),
    "FrostShock skips when mana_low")

-- ============================================================================
-- Summary
-- ============================================================================
print(string.format("test_enhancement_dsl_priority: %d passed, %d failed", _pass, _fail))
if _fail > 0 then
    os.exit(1)
end
print("PASS test_enhancement_dsl_priority")
