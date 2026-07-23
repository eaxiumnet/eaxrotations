-- test_elemental_dsl_priority.lua â Shaman Elemental DSL priority + equivalence test.
-- WHAT:  verifies full strategy priority order, DSL position checks, and condition
--        equivalence for 7 DSL-converted strategies (WaterShield, GhostWolf,
--        EarthbindTotem, ManaTideTotem, FlameShock, ElementalMastery, ChainLightning).
-- WHEN:  runs as part of the rotation test suite.
-- WHY:   regression guard for the 16th DSL adopter (elemental shaman).
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
    Bloodlust = 2825, ChainHeal = 1064, ChainLightning = 421, EarthbindTotem = 2484,
    EarthShock = 8042, ElementalMastery = 16166, FireNovaTotem = 1535,
    FlametongueWeapon = 8024, FlameShock = 8050, FrostShock = 8056, GhostWolf = 2645,
    HealingWave = 331, LightningBolt = 403, LightningBoltLowerRank = 25448,
    LightningShield = 324, MagmaTotem = 8190, ManaSpringTotem = 5675, ManaTideTotem = 16190,
    NaturesSwiftness = 16188, RockbiterWeapon = 8017, TotemicCall = 36936,
    TotemOfWrath = 30706, TremorTotem = 8143, WaterShield = 23575, WindfuryWeapon = 8232,
    WrathOfAirTotem = 3738,
}
NS.PLAYER_UNIT = {
    get_health = function() return 100 end,
    get_health_percentage = function() return 100 end,
    is_valid = function() return true end,
    is_dead = function() return false end,
    is_casting = function() return false end,
    is_mounted = function() return false end,
    get_guid = function() return "player" end,
    get_target = function() return nil end,
}
NS.GetPlayer = function() return NS.PLAYER_UNIT end
NS.GetTarget = function() return nil end
NS.buff_up = function() return false end
NS.debuff_up = function() return false end
NS.debuff_remains = function() return 0 end
NS.get_debuff_stacks = function() return 0 end
NS.spell_ready = function(spell, target, opts) return true end
NS.try_cast = function() return true end
NS.unit_mana_pct = function() return 100 end
NS.unit_health_pct = function() return 100 end
NS.time_now = function() return 0 end
NS.game_time_ms = function() return 0 end
NS.broken_api_throttled = function() return false end
NS.cooldown_remains = function() return 0 end
NS.spell_exists = function() return true end
NS.is_item_ready = function() return false end
NS.use_item_by_id = function() return false end
NS.gate_cooldown_boss_only = function() return true end
NS.is_interruptible = function() return true end
NS.is_in_combat = function() return false end
NS.has_player_buff = function() return false end
NS.should_refresh_dot = function(flame_remains, _, ttd, _) return flame_remains <= 1.5 end
NS.aoe_target_meets = function(min_targets, radius, target, context, state) return true end
NS.AOE_RADIUS = { TARGET_10 = 10, SELF_10 = 10, SELF_8 = 8 }
NS.log = function() end
NS.log_warning = function() end
NS.rotation_registry = { register = function() end }

-- Mock spec_kit
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

-- Mock shared modules
package.loaded["shared/tbc_data_sylvanas"] = { SPELLS = { shaman = {} } }
package.loaded["shared/potion_helper_sylvanas"] = { try_use_potion = function() return false end }
package.loaded["common/utility/inventory_helper"] = { has_item = function() return false end }

-- Load the real DSL engine and cache it so the spec file's require() picks it up
package.loaded["shared/strategy_dsl_sylvanas"] = dofile("EaxRotations/shared/strategy_dsl_sylvanas.lua")

-- Load the elemental shaman spec
local elemental = dofile("EaxRotations/classes/shaman/elemental_sylvanas.lua")
local strategies = elemental.strategies

-- ============================================================================
-- Priority order verification
-- ============================================================================
local expected_order = {
    "ManaPotion", "Healthstone", "ManaEmergencyWand",
    "TotemOfWrath", "WrathOfAirTotem", "ManaSpringTotem",
    "LightningShield", "WaterShield", "GhostWolf", "TremorTotem", "EarthbindTotem",
    "ManaTideTotem", "ElementalMastery", "NaturesSwiftness", "Bloodlust",
    "ChainLightning", "FlameShock", "LightningBolt", "ChainHeal",
    "FlameShockMoving", "EarthShockMoving", "FrostShockMoving",
    "FireNovaTotem", "MagmaTotem",
    "FlametongueWeapon", "WindfuryWeapon", "RockbiterWeapon",
    "HealingWave", "TotemicCall",
}
assert_true(#strategies == #expected_order, "strategy count matches (" .. #strategies .. " vs " .. #expected_order .. ")")
for i = 1, math.min(#strategies, #expected_order) do
    assert_true(strategies[i].name == expected_order[i],
        string.format("priority[%d] = %s (expected %s)", i, strategies[i].name or "?", expected_order[i]))
end

-- DSL position checks
local dsl_indices = {}
for i = 1, #strategies do dsl_indices[strategies[i].name] = i end
assert_true(dsl_indices["WaterShield"] == 8, "WaterShield at index 8")
assert_true(dsl_indices["GhostWolf"] == 9, "GhostWolf at index 9")
assert_true(dsl_indices["EarthbindTotem"] == 11, "EarthbindTotem at index 11")
assert_true(dsl_indices["ManaTideTotem"] == 12, "ManaTideTotem at index 12")
assert_true(dsl_indices["ElementalMastery"] == 13, "ElementalMastery at index 13")
assert_true(dsl_indices["ChainLightning"] == 16, "ChainLightning at index 16")
assert_true(dsl_indices["FlameShock"] == 17, "FlameShock at index 17")

-- ============================================================================
-- Mock context + state helpers
-- ============================================================================
local function make_ctx(overrides)
    local ctx = {
        me = NS.PLAYER_UNIT,
        target = { is_valid = function() return true end, is_dead = function() return false end,
                   is_casting = function() return false end, get_health_percentage = function() return 100 end,
                   get_creature_type = function() return nil end, get_guid = function() return "target" end,
                   get_target = function() return NS.PLAYER_UNIT end },
        in_combat = true,
        is_pvp = false,
        is_moving = false,
        is_casting = false,
        is_channeling = false,
        ttd_known = false,
        ttd = 999,
        should_burst = true,
        cc_safe = true,
        threat_pct = 50,
        settings = { elemental_use_elemental_mastery = true, elemental_water_shield_mana = 50,
                     elemental_cl_min_targets = 3 },
    }
    for k, v in pairs(overrides or {}) do ctx[k] = v end
    return ctx
end

local function make_state(overrides)
    local s = {
        mana_pct = 80,
        mana_emergency = false,
        mana_conserve = false,
        flame_remains = 0,
        clearcast_active = false,
        target_count = 1,
    }
    for k, v in pairs(overrides or {}) do s[k] = v end
    return s
end

-- ============================================================================
-- WaterShield: not mana emergency, mana_pct <= threshold, spell_ready self
-- ============================================================================
local idx_ws = 8
assert_true(strategies[idx_ws].matches(make_ctx(), make_state({ mana_pct = 40 })),
    "WaterShield matches when low mana and not emergency")
assert_false(strategies[idx_ws].matches(make_ctx(), make_state({ mana_pct = 60 })),
    "WaterShield skips when mana above threshold")
assert_false(strategies[idx_ws].matches(make_ctx(), make_state({ mana_emergency = true })),
    "WaterShield skips during mana emergency")

-- ============================================================================
-- GhostWolf: not in_combat, spell_ready self
-- ============================================================================
local idx_gw = 9
assert_true(strategies[idx_gw].matches(make_ctx({ in_combat = false }), make_state()),
    "GhostWolf matches when out of combat")
assert_false(strategies[idx_gw].matches(make_ctx({ in_combat = true }), make_state()),
    "GhostWolf skips when in combat")

-- ============================================================================
-- EarthbindTotem: is_pvp, not mana emergency, spell_ready self
-- ============================================================================
local idx_et = 11
assert_true(strategies[idx_et].matches(make_ctx({ is_pvp = true }), make_state()),
    "EarthbindTotem matches in PvP and not emergency")
assert_false(strategies[idx_et].matches(make_ctx({ is_pvp = false }), make_state()),
    "EarthbindTotem skips when not PvP")
assert_false(strategies[idx_et].matches(make_ctx({ is_pvp = true }), make_state({ mana_emergency = true })),
    "EarthbindTotem skips during mana emergency")

-- ============================================================================
-- ManaTideTotem: mana_pct <= 30, not mana emergency, spell_ready self
-- ============================================================================
local idx_mtt = 12
assert_true(strategies[idx_mtt].matches(make_ctx(), make_state({ mana_pct = 20 })),
    "ManaTideTotem matches when very low mana and not emergency")
assert_false(strategies[idx_mtt].matches(make_ctx(), make_state({ mana_pct = 50 })),
    "ManaTideTotem skips when mana above threshold")
assert_false(strategies[idx_mtt].matches(make_ctx(), make_state({ mana_pct = 20, mana_emergency = true })),
    "ManaTideTotem skips during mana emergency")

-- ============================================================================
-- ElementalMastery: in_combat, should_burst, not mana_conserve, setting enabled, spell_ready self
-- ============================================================================
local idx_em = 13
assert_true(strategies[idx_em].matches(make_ctx(), make_state()),
    "ElementalMastery matches with burst enabled and not conserving mana")
assert_false(strategies[idx_em].matches(make_ctx({ in_combat = false }), make_state()),
    "ElementalMastery skips when not in combat")
assert_false(strategies[idx_em].matches(make_ctx({ should_burst = false }), make_state()),
    "ElementalMastery skips when not bursting")
assert_false(strategies[idx_em].matches(make_ctx(), make_state({ mana_conserve = true })),
    "ElementalMastery skips when mana conserving")
assert_false(strategies[idx_em].matches(make_ctx({ settings = { elemental_use_elemental_mastery = false } }), make_state()),
    "ElementalMastery skips when setting disabled")

-- ============================================================================
-- ChainLightning: not moving, not mana emergency/conserve, cc_safe, low threat,
--                 clearcast or AoE target meets, spell_ready target
-- ============================================================================
local idx_cl = 16
assert_true(strategies[idx_cl].matches(make_ctx(), make_state({ clearcast_active = true })),
    "ChainLightning matches when Clearcast is active")
assert_false(strategies[idx_cl].matches(make_ctx({ is_moving = true }), make_state()),
    "ChainLightning skips while moving")
assert_false(strategies[idx_cl].matches(make_ctx(), make_state({ mana_emergency = true })),
    "ChainLightning skips during mana emergency")
assert_false(strategies[idx_cl].matches(make_ctx(), make_state({ mana_conserve = true })),
    "ChainLightning skips during mana conserve")
assert_false(strategies[idx_cl].matches(make_ctx({ cc_safe = false }), make_state()),
    "ChainLightning skips when cc_safe is false")
assert_false(strategies[idx_cl].matches(make_ctx({ threat_pct = 90 }), make_state()),
    "ChainLightning skips when high threat")

-- ============================================================================
-- FlameShock: target exists, flame_remains <= 1, should_refresh_dot true, spell_ready target
-- ============================================================================
local idx_fs = 17
assert_true(strategies[idx_fs].matches(make_ctx(), make_state({ flame_remains = 0 })),
    "FlameShock matches when debuff absent and should_refresh_dot agrees")
assert_false(strategies[idx_fs].matches(make_ctx(), make_state({ flame_remains = 5 })),
    "FlameShock skips when debuff still has duration")
local no_target_ctx = make_ctx()
no_target_ctx.target = nil
assert_false(strategies[idx_fs].matches(no_target_ctx, make_state({ flame_remains = 0 })),
    "FlameShock skips when no target")

-- ============================================================================
-- Summary
-- ============================================================================
print(string.format("test_elemental_dsl_priority: %d passed, %d failed", _pass, _fail))
if _fail > 0 then
    os.exit(1)
end
print("PASS test_elemental_dsl_priority")
