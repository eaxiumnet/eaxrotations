-- test_arcane_dsl_priority.lua â Mage Arcane DSL priority + equivalence test.
-- WHAT:  verifies full strategy priority order, DSL position checks, and condition
--        equivalence for 6 DSL-converted strategies (IceBarrier, ManaShield,
--        PresenceOfMind, ArcanePower, Evocation, ManaGem).
-- WHEN:  runs as part of the rotation test suite.
-- WHY:   regression guard for the tenth DSL adopter (first arcane mage/mana-proc spec).
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

NS.MageSpells = {
    ArcaneBlast = 30451, ArcaneMissiles = 5143, ArcanePower = 12042,
    Blink = 1953, ColdSnap = 11958, Evocation = 12051, FireBlast = 2136,
    Fireball = 133, FrostNova = 122, Frostbolt = 116, IceBarrier = 11426,
    IceBlock = 45438, IcyVeins = 12472, ManaShield = 1463, Polymorph = 118,
    PresenceOfMind = 12043, Slow = 31589,
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
NS.use_item_by_id = function() return false end
NS.gate_cooldown_boss_only = function() return true end
NS.is_interruptible = function() return true end
NS.is_in_combat = function() return false end
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
package.loaded["shared/tbc_data_sylvanas"] = {
    SPELLS = { mage = { frost_nova = { 27088, 10230, 6131, 865, 122 } } },
}

-- Load the real DSL engine and cache it so the spec file's require() picks it up
package.loaded["shared/strategy_dsl_sylvanas"] = dofile("EaxRotations/shared/strategy_dsl_sylvanas.lua")

-- Load the arcane mage spec
local arcane = dofile("EaxRotations/classes/mage/arcane_sylvanas.lua")
local strategies = arcane.strategies

-- ============================================================================
-- Priority order verification (22 strategies)
-- ============================================================================
local expected_order = {
    "IceBarrier", "IceBlock", "ColdSnap", "Blink", "ManaShield", "Healthstone",
    "Polymorph", "FrostNova", "Slow", "PresenceOfMind", "ArcanePower", "IcyVeins",
    "ColdSnapIVReset", "Evocation", "ManaGem", "ArcaneBlast", "FireBlastExecute",
    "FireBlast", "FrostboltConserve", "ArcaneMissiles", "FireballLeveling",
    "FrostboltLeveling",
}
assert_true(#strategies == #expected_order, "strategy count matches (" .. #strategies .. " vs " .. #expected_order .. ")")
for i = 1, math.min(#strategies, #expected_order) do
    assert_true(strategies[i].name == expected_order[i],
        string.format("priority[%d] = %s (expected %s)", i, strategies[i].name or "?", expected_order[i]))
end

-- DSL position checks â verify the 6 DSL-converted strategies are at expected indices
local dsl_indices = {}
for i = 1, #strategies do dsl_indices[strategies[i].name] = i end
assert_true(dsl_indices["IceBarrier"] == 1, "IceBarrier at index 1")
assert_true(dsl_indices["ManaShield"] == 5, "ManaShield at index 5")
assert_true(dsl_indices["PresenceOfMind"] == 10, "PresenceOfMind at index 10")
assert_true(dsl_indices["ArcanePower"] == 11, "ArcanePower at index 11")
assert_true(dsl_indices["Evocation"] == 14, "Evocation at index 14")
assert_true(dsl_indices["ManaGem"] == 15, "ManaGem at index 15")

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
        settings = { use_defensives = true, use_ice_barrier = true, use_mana_shield = true,
                     use_cooldowns = true, arcane_use_burn = true, use_evocation = true, use_mana_gem = true },
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
        has_mana_shield = false,
        has_presence_of_mind = false,
        has_arcane_power = false,
        in_combat = true,
        is_moving = false,
        hp_pct = 50,
        mana_pct = 80,
        phase = "burn",
        ab_stacks = 0,
        ab_remains = 0,
        icy_veins_remains = 0,
        evocation_available = true,
        mana_gem_available = true,
        arcane_power_available = true,
        bloodlust_active = false,
        current_mana = 12000,
        max_mana = 15000,
        mana_regen = 0,
        has_serpent_coil = false,
    }
    for k, v in pairs(overrides or {}) do s[k] = v end
    return s
end

-- ============================================================================
-- IceBarrier: defensives/ice_barrier enabled, no buff, hp <= 60
-- ============================================================================
local idx_ib = 1
assert_true(strategies[idx_ib].matches(make_ctx(), make_state()),
    "IceBarrier matches when ready + no buff + settings enabled + low HP")
assert_false(strategies[idx_ib].matches(make_ctx(), make_state({ has_ice_barrier = true })),
    "IceBarrier skips when buff already up")
assert_false(strategies[idx_ib].matches(make_ctx(), make_state({ hp_pct = 70 })),
    "IceBarrier skips when HP above threshold")
assert_false(strategies[idx_ib].matches(make_ctx({ settings = { use_defensives = true, use_ice_barrier = false } }), make_state()),
    "IceBarrier skips when use_ice_barrier disabled")
assert_false(strategies[idx_ib].matches(make_ctx({ settings = { use_defensives = false, use_ice_barrier = true } }), make_state()),
    "IceBarrier skips when use_defensives disabled")

-- ============================================================================
-- ManaShield: defensives/mana_shield enabled, no buff, hp <= 40, mana >= 30
-- ============================================================================
local idx_ms = 5
assert_true(strategies[idx_ms].matches(make_ctx(), make_state({ hp_pct = 30 })),
    "ManaShield matches when ready + no buff + low HP + enough mana")
assert_false(strategies[idx_ms].matches(make_ctx(), make_state({ has_mana_shield = true })),
    "ManaShield skips when buff already up")
assert_false(strategies[idx_ms].matches(make_ctx(), make_state({ hp_pct = 50 })),
    "ManaShield skips when HP above threshold")
assert_false(strategies[idx_ms].matches(make_ctx(), make_state({ mana_pct = 20 })),
    "ManaShield skips when mana below threshold")
assert_false(strategies[idx_ms].matches(make_ctx({ settings = { use_defensives = true, use_mana_shield = false } }), make_state()),
    "ManaShield skips when use_mana_shield disabled")

-- ============================================================================
-- PresenceOfMind: in combat, no presence, cooldowns enabled, burn/bloodlust/AP window
-- ============================================================================
local idx_pom = 10
assert_true(strategies[idx_pom].matches(make_ctx(), make_state({ arcane_power_available = false })),
    "PresenceOfMind matches during burn phase when AP is on cooldown")
assert_false(strategies[idx_pom].matches(make_ctx(), make_state({ in_combat = false })),
    "PresenceOfMind skips when not in combat")
assert_false(strategies[idx_pom].matches(make_ctx(), make_state({ has_presence_of_mind = true })),
    "PresenceOfMind skips when Presence of Mind already active")
assert_false(strategies[idx_pom].matches(make_ctx({ settings = { use_cooldowns = false } }), make_state()),
    "PresenceOfMind skips when cooldowns disabled")
assert_false(strategies[idx_pom].matches(make_ctx(), make_state({ phase = "conserve", bloodlust_active = false, arcane_power_available = true })),
    "PresenceOfMind skips during conserve when AP is not active and not on cooldown")
assert_true(strategies[idx_pom].matches(make_ctx(), make_state({ phase = "conserve", bloodlust_active = true, arcane_power_available = false })),
    "PresenceOfMind matches during bloodlust even in conserve phase")

-- ============================================================================
-- ArcanePower: in combat, no AP, cooldowns/burn enabled, boss gate, burn/cd_window, mana >= 35
-- ============================================================================
local idx_ap = 11
assert_true(strategies[idx_ap].matches(make_ctx(), make_state({ ab_stacks = 2 })),
    "ArcanePower matches with 2+ AB stacks")
assert_true(strategies[idx_ap].matches(make_ctx(), make_state({ phase = "burn", mana_pct = 60 })),
    "ArcanePower matches during burn phase with sufficient mana")
assert_false(strategies[idx_ap].matches(make_ctx(), make_state({ has_arcane_power = true })),
    "ArcanePower skips when Arcane Power already active")
assert_false(strategies[idx_ap].matches(make_ctx(), make_state({ in_combat = false })),
    "ArcanePower skips when not in combat")
assert_false(strategies[idx_ap].matches(make_ctx({ settings = { use_cooldowns = false } }), make_state()),
    "ArcanePower skips when cooldowns disabled")
assert_false(strategies[idx_ap].matches(make_ctx({ settings = { arcane_use_burn = false } }), make_state()),
    "ArcanePower skips when burn disabled")
assert_false(strategies[idx_ap].matches(make_ctx(), make_state({ phase = "conserve", bloodlust_active = false, icy_veins_remains = 0 })),
    "ArcanePower skips during conserve without a cooldown window")
assert_false(strategies[idx_ap].matches(make_ctx(), make_state({ mana_pct = 30 })),
    "ArcanePower skips when mana below 35%")

-- ============================================================================
-- Evocation: in combat, evocation available, use_evocation enabled, low mana
-- ============================================================================
local idx_evo = 14
assert_true(strategies[idx_evo].matches(make_ctx(), make_state({ mana_pct = 15, has_arcane_power = false, icy_veins_remains = 0 })),
    "Evocation matches when mana below conserve start and AP/IV inactive")
assert_true(strategies[idx_evo].matches(make_ctx(), make_state({ phase = "conserve", mana_pct = 25 })),
    "Evocation matches during conserve phase with mana <= 30%")
assert_false(strategies[idx_evo].matches(make_ctx(), make_state({ in_combat = false })),
    "Evocation skips when not in combat")
assert_false(strategies[idx_evo].matches(make_ctx(), make_state({ evocation_available = false })),
    "Evocation skips when not available")
assert_false(strategies[idx_evo].matches(make_ctx({ settings = { use_evocation = false } }), make_state()),
    "Evocation skips when use_evocation disabled")
assert_false(strategies[idx_evo].matches(make_ctx(), make_state({ mana_pct = 80, has_arcane_power = false, icy_veins_remains = 0 })),
    "Evocation skips when mana is high")

-- ============================================================================
-- ManaGem: mana gem available, use_mana_gem enabled, mana gap justifies gem
-- ============================================================================
local idx_gem = 15
assert_true(strategies[idx_gem].matches(make_ctx(), make_state({ current_mana = 5000, max_mana = 15000 })),
    "ManaGem matches when max mana far exceeds current + gem restore")
assert_true(strategies[idx_gem].matches(make_ctx(), make_state({ mana_pct = 50 })),
    "ManaGem matches when mana percent below fallback threshold")
assert_false(strategies[idx_gem].matches(make_ctx(), make_state({ mana_gem_available = false })),
    "ManaGem skips when no gem available")
assert_false(strategies[idx_gem].matches(make_ctx({ settings = { use_mana_gem = false } }), make_state()),
    "ManaGem skips when use_mana_gem disabled")
assert_false(strategies[idx_gem].matches(make_ctx(), make_state({ current_mana = 14000, max_mana = 15000 })),
    "ManaGem skips when mana gap is small and percent fallback not met")

-- ============================================================================
-- Summary
-- ============================================================================
print(string.format("test_arcane_dsl_priority: %d passed, %d failed", _pass, _fail))
if _fail > 0 then
    os.exit(1)
end
print("PASS test_arcane_dsl_priority")
