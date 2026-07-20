-- test_frost_dsl_priority.lua — Mage Frost DSL priority + equivalence test.
-- WHAT:  verifies full strategy priority order, DSL position checks, and condition
--        equivalence for 6 DSL-converted strategies (IceBarrier, IcyVeins,
--        WaterElemental, FrozenIceLance, FrostbiteFrostbolt, WintersChill).
-- WHEN:  runs as part of the rotation test suite.
-- WHY:   regression guard for the ninth DSL adopter (first frost mage/proc-tracking spec).
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

NS.MageSpells = {
    ArcaneExplosion = 1449, ArcaneIntellect = 1459, ArcaneMissiles = 5143,
    Blink = 1953, Blizzard = 10, ColdSnap = 11958, ConeOfCold = 120,
    ConjureManaEmerald = 759, Counterspell = 2139, Evocation = 12051,
    FireBlast = 2136, FrostArmor = 168, FrostNova = 122, FrostWard = 6143,
    Frostbolt = 116, IceBarrier = 11426, IceBlock = 45438, IceLance = 30455,
    IcyVeins = 12472, MageArmor = 6117, ManaShield = 1463, Polymorph = 118,
    PresenceOfMind = 12043, RemoveCurse = 475, Scorch = 2948, WaterElemental = 31687,
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
NS.debuff_stacks = function() return 0 end
NS.spell_ready = function() return true end
NS.try_cast = function() return true end
NS.unit_mana_pct = function() return 100 end
NS.unit_health_pct = function() return 100 end
NS.time_now = function() return 0 end
NS.game_time_ms = function() return 0 end
NS.broken_api_throttled = function() return false end
NS.cooldown_remains = function() return 0 end
NS.spell_exists = function() return true end
NS.is_item_ready = function() return false end
NS.is_auto_attacking = function() return false end
NS.gate_cooldown_boss_only = function() return true end
NS.is_spell_learned = function() return true end
NS.is_interruptible = function() return true end
NS.is_in_combat = function() return false end
NS.log = function() end
NS.log_warning = function() end
NS.rotation_registry = { register = function() end }
NS.AOE_RADIUS = { GROUND_8 = 8, SELF_10 = 10 }
NS.aoe_self_meets = function() return false end
NS.aoe_target_meets = function() return false end
NS.cast_ground_aoe = function() return false end
NS.get_aoe_cast_position = function() return nil end
NS.get_spell_id = function(spell) return spell end
NS.try_cast_position = function() return false end
NS.use_item_by_id = function() return false end

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
package.loaded["shared/potion_helper_sylvanas"] = {
    try_use_potion = function() return false end,
    MANA_POTION_IDS = {},
}
package.loaded["shared/tbc_data_sylvanas"] = {
    SPELLS = { mage = { frost_nova = { 27088, 10230, 6131, 865, 122 } } },
}
package.loaded["shared/aoe_hit_volume_sylvanas"] = { install = function() end }

-- Load the real DSL engine and cache it so the spec file's require() picks it up
package.loaded["shared/strategy_dsl_sylvanas"] = dofile("EaxRotations/shared/strategy_dsl_sylvanas.lua")

-- Load the frost mage spec
local frost = dofile("EaxRotations/classes/mage/frost_sylvanas.lua")
local strategies = frost.strategies

-- ============================================================================
-- Priority order verification (30 strategies)
-- ============================================================================
local expected_order = {
    "ManaPotion", "FrostArmor", "MageArmor", "ArcaneIntellect", "IceBarrier",
    "IceBlock", "Healthstone", "Blink", "ColdSnap", "IcyVeins", "WaterElemental",
    "FrostbiteFrostbolt", "FrozenIceLance", "PresenceOfMind", "Evocation",
    "ManaGemConjure", "ManaGem", "ManaShield", "FrostWard", "RemoveCurse",
    "WintersChill", "FrostNova", "ConeOfCold", "Polymorph", "ArcaneExplosion",
    "Blizzard", "FireBlast", "Scorch", "ArcaneMissiles", "Frostbolt",
}
assert_true(#strategies == #expected_order, "strategy count matches (" .. #strategies .. " vs " .. #expected_order .. ")")
for i = 1, math.min(#strategies, #expected_order) do
    assert_true(strategies[i].name == expected_order[i],
        string.format("priority[%d] = %s (expected %s)", i, strategies[i].name or "?", expected_order[i]))
end

-- DSL position checks — verify the 6 DSL-converted strategies are at expected indices
local dsl_indices = {}
for i = 1, #strategies do dsl_indices[strategies[i].name] = i end
assert_true(dsl_indices["IceBarrier"] == 5, "IceBarrier at index 5")
assert_true(dsl_indices["IcyVeins"] == 10, "IcyVeins at index 10")
assert_true(dsl_indices["WaterElemental"] == 11, "WaterElemental at index 11")
assert_true(dsl_indices["FrostbiteFrostbolt"] == 12, "FrostbiteFrostbolt at index 12")
assert_true(dsl_indices["FrozenIceLance"] == 13, "FrozenIceLance at index 13")
assert_true(dsl_indices["WintersChill"] == 21, "WintersChill at index 21")

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
        hp = 100,
        mana_pct = 80,
        settings = { use_cooldowns = true, use_defensives = true, use_ice_barrier = true },
        is_pvp = false,
        is_moving = false,
        is_casting = false,
        is_channeling = false,
        ttd_known = false,
        ttd = 999,
    }
    for k, v in pairs(overrides or {}) do ctx[k] = v end
    return ctx
end

local function make_state(overrides)
    local s = {
        has_ice_barrier = false,
        ice_barrier_remains = 999,
        ice_barrier_ready = true,
        in_combat = true,
        icy_veins_ready = true,
        has_water_elemental = false,
        water_elemental_ready = true,
        ice_lance_ready = true,
        target_frozen = false,
        frostbite_active = false,
        frostbolt_ready = true,
        winter_chill_stacks = 0,
        mana_pct = 80,
        hp_pct = 100,
    }
    for k, v in pairs(overrides or {}) do s[k] = v end
    return s
end

-- ============================================================================
-- IceBarrier: not broken_api, defensives/ice_barrier enabled, no buff or short remaining, ready
-- ============================================================================
local idx_ib = 5
assert_true(strategies[idx_ib].matches(make_ctx(), make_state()),
    "IceBarrier matches when ready + no buff + settings enabled")
assert_false(strategies[idx_ib].matches(make_ctx(), make_state({ has_ice_barrier = true, ice_barrier_remains = 10 })),
    "IceBarrier skips when buff has plenty of time remaining")
assert_false(strategies[idx_ib].matches(make_ctx(), make_state({ ice_barrier_ready = false })),
    "IceBarrier skips when not ready")
assert_false(strategies[idx_ib].matches(make_ctx({ settings = { use_defensives = true, use_ice_barrier = false } }), make_state()),
    "IceBarrier skips when use_ice_barrier disabled")
assert_false(strategies[idx_ib].matches(make_ctx({ settings = { use_defensives = false, use_ice_barrier = true } }), make_state()),
    "IceBarrier skips when use_defensives disabled")

-- ============================================================================
-- IcyVeins: cooldowns enabled, boss gate, in combat, ready, not dying target
-- ============================================================================
local idx_iv = 10
assert_true(strategies[idx_iv].matches(make_ctx(), make_state()),
    "IcyVeins matches when ready + in combat + boss gate + long TTD")
assert_false(strategies[idx_iv].matches(make_ctx(), make_state({ in_combat = false })),
    "IcyVeins skips when not in combat")
assert_false(strategies[idx_iv].matches(make_ctx(), make_state({ icy_veins_ready = false })),
    "IcyVeins skips when not ready")
assert_false(strategies[idx_iv].matches(make_ctx({ ttd_known = true, ttd = 10 }), make_state()),
    "IcyVeins skips when target dying soon")
assert_false(strategies[idx_iv].matches(make_ctx({ settings = { use_cooldowns = false } }), make_state()),
    "IcyVeins skips when cooldowns disabled")

-- ============================================================================
-- WaterElemental: cooldowns enabled, in combat, no pet, ready, not dying target
-- ============================================================================
local idx_we = 11
assert_true(strategies[idx_we].matches(make_ctx(), make_state()),
    "WaterElemental matches when ready + in combat + no pet + long TTD")
assert_false(strategies[idx_we].matches(make_ctx(), make_state({ in_combat = false })),
    "WaterElemental skips when not in combat")
assert_false(strategies[idx_we].matches(make_ctx(), make_state({ has_water_elemental = true })),
    "WaterElemental skips when pet already active")
assert_false(strategies[idx_we].matches(make_ctx(), make_state({ water_elemental_ready = false })),
    "WaterElemental skips when not ready")
assert_false(strategies[idx_we].matches(make_ctx({ ttd_known = true, ttd = 10 }), make_state()),
    "WaterElemental skips when target dying soon")

-- ============================================================================
-- FrozenIceLance: valid target, ready, target frozen OR moving
-- ============================================================================
local idx_il = 13
assert_true(strategies[idx_il].matches(make_ctx(), make_state({ target_frozen = true })),
    "FrozenIceLance matches when target frozen")
assert_true(strategies[idx_il].matches(make_ctx({ is_moving = true }), make_state({ target_frozen = false })),
    "FrozenIceLance matches when moving")
assert_false(strategies[idx_il].matches(make_ctx(), make_state({ target_frozen = false })),
    "FrozenIceLance skips when target not frozen and not moving")
assert_false(strategies[idx_il].matches(make_ctx(), make_state({ ice_lance_ready = false, target_frozen = true })),
    "FrozenIceLance skips when not ready")

-- ============================================================================
-- FrostbiteFrostbolt: valid target, not moving, frostbite active, frostbolt ready
-- ============================================================================
local idx_ffb = 12
assert_true(strategies[idx_ffb].matches(make_ctx(), make_state({ frostbite_active = true })),
    "FrostbiteFrostbolt matches when frostbite active + frostbolt ready")
assert_false(strategies[idx_ffb].matches(make_ctx(), make_state({ frostbite_active = false })),
    "FrostbiteFrostbolt skips when no frostbite")
assert_false(strategies[idx_ffb].matches(make_ctx({ is_moving = true }), make_state({ frostbite_active = true })),
    "FrostbiteFrostbolt skips when moving")
assert_false(strategies[idx_ffb].matches(make_ctx(), make_state({ frostbite_active = true, frostbolt_ready = false })),
    "FrostbiteFrostbolt skips when frostbolt not ready")

-- ============================================================================
-- WintersChill: valid target, not moving, frostbolt ready, stacks < 5 or debuff expiring
-- ============================================================================
local idx_wc = 21
assert_true(strategies[idx_wc].matches(make_ctx(), make_state({ winter_chill_stacks = 3 })),
    "WintersChill matches when stacks < 5")
assert_true(strategies[idx_wc].matches(make_ctx(), make_state({ winter_chill_stacks = 5 })),
    "WintersChill matches when stacks = 5 and debuff expiring soon (mock returns 0)")
assert_false(strategies[idx_wc].matches(make_ctx({ is_moving = true }), make_state({ winter_chill_stacks = 3 })),
    "WintersChill skips when moving")
assert_false(strategies[idx_wc].matches(make_ctx(), make_state({ winter_chill_stacks = 3, frostbolt_ready = false })),
    "WintersChill skips when frostbolt not ready")

-- ============================================================================
-- Summary
-- ============================================================================
print(string.format("test_frost_dsl_priority: %d passed, %d failed", _pass, _fail))
if _fail > 0 then
    os.exit(1)
end
print("PASS test_frost_dsl_priority")
