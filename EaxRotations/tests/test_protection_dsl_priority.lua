-- test_protection_dsl_priority.lua — Protection Paladin DSL priority order + condition equivalence.
-- WHAT:  regression gate verifying the DSL in-place substitution preserves the exact
--        26-strategy priority order and that DSL-compiled match functions are behaviorally
--        equivalent to the original imperative functions.
-- WHEN:  runs as part of run_rotation_tests.lua.
-- WHY:   fifth DSL adopter (first tank) — must prove generality across defensive cooldown
--        throttles, creature-type gating, settings-driven HP thresholds, and mana resources.
-- SAFETY: mock NS; no real game API calls.

local _pass, _fail = 0, 0
local function assert_true(v, label)
    if v then _pass = _pass + 1 else _fail = _fail + 1; print("  FAIL: " .. label) end
end
local function assert_false(v, label)
    if not v then _pass = _pass + 1 else _fail = _fail + 1; print("  FAIL: " .. label .. " (expected false)") end
end
local function assert_eq(a, b, label)
    if a == b then _pass = _pass + 1 else _fail = _fail + 1; print("  FAIL: " .. label .. " (got " .. tostring(a) .. " expected " .. tostring(b) .. ")") end
end

-- ============================================================================
-- Mock NS for protection_sylvanas.lua
-- ============================================================================
local mock_hp_pct = 100
local mock_target_hp_pct = 100
local mock_in_combat = false
local mock_enemy_count = 1
local mock_spell_ready_result = true
local mock_has_forbearance = false
local mock_has_divine_shield = false
local mock_needs_cleanse = false
local mock_target_creature_type = nil
local mock_time = 0

_G.EaxRotations = _G.EaxRotations or {}
local NS = _G.EaxRotations
NS.log = function() end
NS.log_warning = function() end
NS.GetPlayer = function() return { get_health = function() return 100 end } end
NS.PLAYER_UNIT = "player"
NS.time_now = function() return mock_time end
NS.spell_ready = function() return mock_spell_ready_result end
NS.try_cast = function() return true end
NS.action_matches = function() return true end
NS.action_execute = function() return true end
NS.buff_up = function() return false end
NS.buff_remains = function() return 0 end
NS.buff_points = function() return nil end
NS.debuff_remains = function() return 0 end
NS.debuff_up = function() return false end
NS.debuff_stacks = function() return 0 end
NS.aoe_target_meets = function() return false end
NS.aoe_self_meets = function() return false end
NS.use_item_by_id = function() return true end
NS.broken_api_throttled = function() return false end
NS.unit_health_pct = function() return mock_hp_pct end
NS.unit_energy_pct = function() return 100 end
NS.rotation_registry = { register = function() end }
NS.PaladinSpells = {
    AvengerShield = 31935,
    AvengingWrath = 31884,
    BlessingOfKings = 20217,
    BlessingOfProtection = 10278,
    BlessingOfSanctuary = 20911,
    Cleanse = 4987,
    Consecration = 26573,
    DevotionAura = 27149,
    DivineProtection = 498,
    DivineShield = 642,
    Exorcism = 879,
    FlashOfLight = 19939,
    HammerOfJustice = 853,
    HammerOfWrath = 24275,
    HolyLight = 25292,
    HolyShock = 25912,
    HolyShield = 20925,
    HolyWrath = 2812,
    Judgement = 20271,
    LayOnHands = 47750,
    RighteousDefense = 31789,
    RighteousFury = 25780,
    SealOfCommand = 20375,
    SealRighteousness = 21084,
    SealOfWisdom = 20166,
    TurnEvil = 10326,
}
NS.PaladinConstants = {}

-- Mock shared modules
package.loaded["shared/spec_kit_sylvanas"] = {
    safe_state = function(raw, schema)
        local proxy = {}
        setmetatable(proxy, {
            __index = function(t, k)
                if raw[k] ~= nil then return raw[k] end
                if schema and schema[k] ~= nil then return schema[k] end
                return nil
            end,
        })
        for k, v in pairs(raw) do proxy[k] = v end
        return proxy
    end,
    define_action_for_class = function(SPELLS)
        return function(spell_field, rank_ids, label)
            if SPELLS and type(SPELLS) == "table" and SPELLS[spell_field] ~= nil then
                return SPELLS[spell_field]
            end
            return rank_ids and rank_ids[1] or spell_field
        end
    end,
    setting = function(ctx, key, default)
        if ctx and ctx.settings and ctx.settings[key] ~= nil then return ctx.settings[key] end
        return default
    end,
    setting_bool = function(ctx, key, default)
        if ctx and ctx.settings and ctx.settings[key] ~= nil then return ctx.settings[key] end
        return default
    end,
    setting_number = function(ctx, key, default)
        if ctx and ctx.settings and ctx.settings[key] ~= nil then return ctx.settings[key] end
        return default
    end,
    merge_state = function(build_state, context, state_override)
        local s = build_state(context)
        if not state_override or next(state_override) == nil then return s end
        local merged = {}
        for k, v in pairs(s) do merged[k] = v end
        for k, v in pairs(state_override) do merged[k] = v end
        local mt = getmetatable(s)
        if mt then
            local mt_copy = {}
            for k, v in pairs(mt) do mt_copy[k] = v end
            mt_copy.__newindex = nil
            setmetatable(merged, mt_copy)
        end
        return merged
    end,
}
package.loaded["shared/strategy_dsl_sylvanas"] = dofile("EaxRotations/shared/strategy_dsl_sylvanas.lua")
package.loaded["shared/potion_helper_sylvanas"] = {
    try_use_potion = function() return false end,
    MANA_POTION_IDS = { 28100, 28070, 28068 },
    HEALTH_POTION_IDS = { 22851, 13446 },
}
package.loaded["shared/health_pred_helper_sylvanas"] = nil
package.loaded["shared/aoe_hit_volume_sylvanas"] = { install = function() end }

-- ============================================================================
-- Load the protection spec
-- ============================================================================
local prot = dofile("EaxRotations/classes/paladin/protection_sylvanas.lua")
local strategies = prot.strategies

-- ============================================================================
-- Test 1: Strategy count
-- ============================================================================
assert_eq(#strategies, 27, "strategy count = 27")

-- ============================================================================
-- Test 2: Full priority order
-- ============================================================================
local expected_order = {
    "Healthstone",              -- 1
    "ManaPotion",               -- 2
    "RighteousFury",            -- 3
    "HolyShield",               -- 4
    "Consecration",             -- 5 (wowsims: Consecration above Judgement)
    "Judgement",                -- 6
    "SealOfCommandAoE",         -- 7
    "SealRighteousness",        -- 8
    "SealOfWisdom",             -- 9
    "TurnEvil",                 -- 10
    "Exorcism",                 -- 11
    "HolyWrath",                -- 12 (DSL)
    "HammerOfWrath",            -- 13 (DSL)
    "AvengingWrath",            -- 14 (DSL)
    "AvengerShield",            -- 15
    "DevotionAura",             -- 16
    "BlessingOfSanctuary",      -- 17
    "HolyShock",                -- 18 (DSL)
    "FlashOfLight",             -- 19
    "HolyLight",                -- 20
    "Cleanse",                  -- 21 (DSL)
    "DivineProtection",         -- 22 (DSL)
    "DivineShield",             -- 23
    "LayOnHands",               -- 24
    "RighteousDefense",         -- 25
    "BlessingOfProtectionAlly", -- 26
    "BlessingOfKingsParty",     -- 27
}

for i = 1, #expected_order do
    assert_eq(strategies[i].name, expected_order[i], "position " .. i .. " = " .. expected_order[i])
end

-- ============================================================================
-- Test 3: DSL strategy positions
-- ============================================================================
local dsl_positions = {
    HolyWrath = 12,
    HammerOfWrath = 13,
    AvengingWrath = 14,
    HolyShock = 18,
    Cleanse = 21,
    DivineProtection = 22,
}

for name, pos in pairs(dsl_positions) do
    assert_eq(strategies[pos].name, name, "DSL position " .. pos .. " = " .. name)
    assert_true(type(strategies[pos].matches) == "function", name .. " has matches function")
    assert_true(type(strategies[pos].execute) == "function", name .. " has execute function")
end

-- ============================================================================
-- Test 4: DSL condition equivalence
-- ============================================================================
local function make_ctx(overrides)
    local ctx = {
        me = { get_health = function() return 100 end, is_valid = function() return true end, is_dead = function() return false end },
        target = { get_health = function() return 50 end, is_valid = function() return true end, is_dead = function() return false end, get_creature_type = function() return mock_target_creature_type end },
        in_combat = mock_in_combat,
        hp = mock_hp_pct,
        settings = {},
        has_valid_enemy_target = true,
        target_hp_pct = mock_target_hp_pct,
        enemy_count = mock_enemy_count,
    }
    for k, v in pairs(overrides or {}) do ctx[k] = v end
    return ctx
end

local function make_state(overrides)
    local s = {
        hp_pct = mock_hp_pct,
        target_hp_pct = mock_target_hp_pct,
        enemy_count = mock_enemy_count,
        has_forbearance = mock_has_forbearance,
        has_divine_shield = mock_has_divine_shield,
        needs_cleanse = mock_needs_cleanse,
        target_creature_type = mock_target_creature_type,
        hammer_of_wrath_ready = true,
        avenging_wrath_ready = true,
        holy_shock_ready = true,
        cleanse_ready = true,
        holy_wrath_ready = true,
        divine_protection_ready = true,
    }
    for k, v in pairs(overrides or {}) do s[k] = v end
    return s
end

-- HammerOfWrath: requires setting enabled, combat target, spell ready, target HP <= threshold
local idx_how = 13
mock_spell_ready_result = true
mock_in_combat = true
mock_target_hp_pct = 15
assert_true(strategies[idx_how].matches(make_ctx({ settings = { prot_hammer_of_wrath = true } }), make_state({ target_hp_pct = 15 })), "HammerOfWrath matches at target_hp=15")
assert_false(strategies[idx_how].matches(make_ctx(), make_state({ target_hp_pct = 25 })), "HammerOfWrath skips at target_hp=25")
assert_false(strategies[idx_how].matches(make_ctx({ settings = { prot_hammer_of_wrath = false } }), make_state({ target_hp_pct = 15 })), "HammerOfWrath skips when disabled")
assert_false(strategies[idx_how].matches(make_ctx(), make_state({ hammer_of_wrath_ready = false, target_hp_pct = 15 })), "HammerOfWrath skips when not ready")

-- AvengingWrath: requires setting enabled, cooldowns, no forbearance, spell ready, TTD gate
local idx_aw = 14
assert_true(strategies[idx_aw].matches(make_ctx({ settings = { use_cooldowns = true } }), make_state({ has_forbearance = false, avenging_wrath_ready = true })), "AvengingWrath matches when ready, no forbearance")
assert_false(strategies[idx_aw].matches(make_ctx({ settings = { use_cooldowns = true } }), make_state({ has_forbearance = true })), "AvengingWrath skips with forbearance")
assert_false(strategies[idx_aw].matches(make_ctx({ settings = { use_cooldowns = true } }), make_state({ avenging_wrath_ready = false })), "AvengingWrath skips when not ready")
assert_false(strategies[idx_aw].matches(make_ctx({ settings = { use_cooldowns = true, prot_avenging_wrath = false } }), make_state()), "AvengingWrath skips when disabled")
assert_false(strategies[idx_aw].matches(make_ctx({ settings = { use_cooldowns = true }, ttd_known = true, ttd = 10 }), make_state()), "AvengingWrath skips when TTD < 15")

-- HolyShock: requires combat target, spell ready, hp above FoL threshold
local idx_hs = 18
assert_true(strategies[idx_hs].matches(make_ctx(), make_state({ hp_pct = 80, holy_shock_ready = true })), "HolyShock matches at hp=80 (above FoL threshold)")
assert_false(strategies[idx_hs].matches(make_ctx(), make_state({ hp_pct = 35 })), "HolyShock skips at hp=35 (below FoL threshold)")
assert_false(strategies[idx_hs].matches(make_ctx(), make_state({ holy_shock_ready = false })), "HolyShock skips when not ready")

-- Cleanse: requires setting enabled, needs_cleanse, cleanse_ready
local idx_cl = 21
assert_true(strategies[idx_cl].matches(make_ctx(), make_state({ needs_cleanse = true, cleanse_ready = true })), "Cleanse matches when needs_cleanse + ready")
assert_false(strategies[idx_cl].matches(make_ctx(), make_state({ needs_cleanse = false })), "Cleanse skips when no cleanse needed")
assert_false(strategies[idx_cl].matches(make_ctx(), make_state({ needs_cleanse = true, cleanse_ready = false })), "Cleanse skips when not ready")
assert_false(strategies[idx_cl].matches(make_ctx({ settings = { prot_cleanse = false } }), make_state({ needs_cleanse = true })), "Cleanse skips when disabled")

-- HolyWrath: requires setting, combat target, enemy_count >= 2, spell ready, demon/undead
local idx_hw = 12
mock_target_creature_type = 3  -- Demon
assert_true(strategies[idx_hw].matches(make_ctx(), make_state({ enemy_count = 3, holy_wrath_ready = true, target_creature_type = 3 })), "HolyWrath matches 3 demon enemies")
assert_false(strategies[idx_hw].matches(make_ctx(), make_state({ enemy_count = 1, target_creature_type = 3 })), "HolyWrath skips at 1 enemy")
assert_false(strategies[idx_hw].matches(make_ctx(), make_state({ enemy_count = 3, target_creature_type = 1 })), "HolyWrath skips non-demon/undead")
assert_false(strategies[idx_hw].matches(make_ctx(), make_state({ enemy_count = 3, target_creature_type = 3, holy_wrath_ready = false })), "HolyWrath skips when not ready")

-- DivineProtection: requires hp <= threshold, no forbearance, no divine shield, ready, 3s throttle
local idx_dp = 22
mock_time = 5  -- >3s so the anti-loop throttle passes on first call
assert_true(strategies[idx_dp].matches(make_ctx(), make_state({ hp_pct = 20, has_forbearance = false, has_divine_shield = false, divine_protection_ready = true })), "DivineProtection matches at hp=20")
assert_false(strategies[idx_dp].matches(make_ctx(), make_state({ hp_pct = 30 })), "DivineProtection skips at hp=30 (above threshold)")
assert_false(strategies[idx_dp].matches(make_ctx(), make_state({ hp_pct = 20, has_forbearance = true })), "DivineProtection skips with forbearance")
assert_false(strategies[idx_dp].matches(make_ctx(), make_state({ hp_pct = 20, has_divine_shield = true })), "DivineProtection skips with divine shield active")
mock_time = 0  -- reset for hygiene (no subsequent tests use it, but keep it clean)

-- ============================================================================
-- Summary
-- ============================================================================
print(string.format("test_protection_dsl_priority: %d passed, %d failed", _pass, _fail))
if _fail > 0 then
    os.exit(1)
end
print("PASS test_protection_dsl_priority")
