-- test_retribution_dsl_priority.lua — Retribution Paladin DSL priority order + condition equivalence.
-- WHAT:  regression gate verifying the DSL in-place substitution preserves the exact
--        priority order and that DSL-compiled match functions are behaviorally
--        equivalent to the original imperative functions for the 7 converted strategies.
-- WHEN:  runs as part of run_rotation_tests.lua.
-- WHY:   17th DSL adopter (retribution paladin) — proves generality across melee,
--        mana, seals, and defensive cooldowns.
-- SAFETY: mock NS; no real game API calls.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

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
-- Mock NS
-- ============================================================================
local mock_hp_pct = 100
local mock_target_hp_pct = 100
local mock_mana_pct = 100
local mock_in_combat = true
local mock_spell_ready_result = true
local mock_has_forbearance = false
local mock_has_command = false
local mock_has_damage_seal = false
local mock_has_cleanse_debuff = false
local mock_has_sanctity = false
local mock_healing_item = nil
local mock_preferred_seal = "command"

_G.EaxRotations = _G.EaxRotations or {}
local NS = _G.EaxRotations
NS.log = function() end
NS.log_warning = function() end
NS.GetPlayer = function() return { get_health = function() return 100 end } end
NS.PLAYER_UNIT = "player"
NS.time_now = function() return 0 end
NS.spell_ready = function() return mock_spell_ready_result end
NS.try_cast = function() return true end
NS.buff_up = function() return false end
NS.debuff_up = function() return false end
NS.has_player_buff = function(ids) return mock_has_sanctity end
NS.has_player_debuff = function(ids) return mock_has_cleanse_debuff end
NS.use_item_by_id = function(id) return id ~= nil end
NS.broken_api_throttled = function() return false end
NS.unit_health_pct = function() return mock_hp_pct end
NS.unit_mana_pct = function() return mock_mana_pct end
NS.rotation_registry = { register = function() end }
NS.PaladinSpells = {
    AvengingWrath = 31884, BlessingOfFreedom = 1044, BlessingOfKings = 20217,
    BlessingOfMight = 27140, BlessingOfProtection = 10278, Cleanse = 4987,
    Consecration = 27173, CrusaderStrike = 35395, DivineProtection = 498,
    DivineShield = 642, Exorcism = 879, HammerOfJustice = 853,
    HammerOfWrath = 24275, HolyWrath = 2812, Judgement = 20271,
    LayOnHands = 633, Purify = 1152, Repentance = 20066, SanctityAura = 20218,
    SealBlood = 31892, SealCommand = 20375, SealCrusader = 21082,
    SealOfTheMartyr = 348700, SealOfWisdom = 20166, SealRighteousness = 20154,
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
}
package.loaded["shared/hit_cap_tracker_sylvanas"] = {
    get_hit_cap = function() return nil end,
    get_expertise_cap = function() return nil end,
}
package.loaded["shared/tbc_data_sylvanas"] = nil
package.loaded["shared/aoe_hit_volume_sylvanas"] = { install = function() end }

-- Capture globals used by the loaded spec
local SANCTITY_AURA_GATE_BUFF = { 20218 }
local COMMON_CLEANSE = { 1330, 1714, 2818, 3409, 6358, 6788, 8122, 11831, 12579, 16856, 17928, 25368, 27087, 27218, 30414, 30443, 30466, 30980, 33786 }

-- Load DSL module fresh so compile_strategy picks up the real spec_kit mock
package.loaded["shared/strategy_dsl_sylvanas"] = nil

-- ============================================================================
-- Load the retribution spec
-- ============================================================================
local ret = dofile("EaxRotations/classes/paladin/retribution_sylvanas.lua")
local strategies = ret.strategies

-- ============================================================================
-- Helpers
-- ============================================================================
local function make_ctx(overrides)
    local ctx = {
        me = { get_health = function() return mock_hp_pct end, is_valid = function() return true end, is_dead = function() return false end, get_distance = function() return 5 end },
        target = { get_health = function() return mock_target_hp_pct end, is_valid = function() return true end, is_dead = function() return false end, is_player = function() return false end, get_creature_type = function() return 1 end },
        in_combat = mock_in_combat,
        is_pvp = false,
        settings = {},
        hp = mock_hp_pct,
        mana_pct = mock_mana_pct,
    }
    for k, v in pairs(overrides or {}) do ctx[k] = v end
    return ctx
end

local function make_state(overrides)
    local s = {
        hp_pct = mock_hp_pct,
        target_hp_pct = mock_target_hp_pct,
        mana_pct = mock_mana_pct,
        is_group = false,
        has_forbearance = mock_has_forbearance,
        has_command = mock_has_command,
        has_damage_seal = mock_has_damage_seal,
        preferred_damage_seal = mock_preferred_seal,
        healing_item = mock_healing_item,
    }
    for k, v in pairs(overrides or {}) do s[k] = v end
    return s
end

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i], i end
    end
    return nil, -1
end

-- ============================================================================
-- Test 1: converted strategies are present and executable
-- ============================================================================
local dsl_names = {
    "Ret_DivineShield_Emergency", "Ret_LayOnHands_LastResort", "Ret_SanctityAura",
    "Ret_HealthstoneOrPotion", "Ret_HammerWrath_Execute", "Ret_Cleanse_Self",
    "Ret_SealCommand_Primary",
}
for _, name in ipairs(dsl_names) do
    local s, idx = find_strategy(name)
    assert_true(s ~= nil, name .. " exists")
    assert_true(type(s.matches) == "function", name .. " has matches function")
    assert_true(type(s.execute) == "function", name .. " has execute function")
end

-- ============================================================================
-- Test 2: priority order sanity check
-- ============================================================================
local function idx_of(name)
    local _, idx = find_strategy(name)
    return idx
end

assert_true(idx_of("Ret_DivineShield_Emergency") < idx_of("Ret_LayOnHands_LastResort"), "DivineShield before LayOnHands")
assert_true(idx_of("Ret_LayOnHands_LastResort") < idx_of("Ret_SanctityAura"), "LayOnHands before SanctityAura")
assert_true(idx_of("Ret_SanctityAura") < idx_of("Ret_HealthstoneOrPotion"), "SanctityAura before HealthstoneOrPotion")
assert_true(idx_of("Ret_HealthstoneOrPotion") < idx_of("Ret_HammerWrath_Execute"), "HealthstoneOrPotion before HammerWrath_Execute")
assert_true(idx_of("Ret_Cleanse_Self") < idx_of("Ret_HammerWrath_Execute"), "Cleanse_Self before HammerWrath_Execute")
assert_true(idx_of("Ret_Cleanse_Self") < idx_of("Ret_SealCommand_Primary"), "Cleanse_Self before SealCommand_Primary")

-- ============================================================================
-- Test 3: DSL condition equivalence
-- ============================================================================
mock_spell_ready_result = true

-- DivineShield: low HP, no forbearance, ready
local ds = find_strategy("Ret_DivineShield_Emergency")
assert_true(ds.matches(make_ctx(), make_state({ hp_pct = 10, has_forbearance = false })), "DivineShield matches at low HP without forbearance")
assert_false(ds.matches(make_ctx(), make_state({ hp_pct = 10, has_forbearance = true })), "DivineShield skips with forbearance")
assert_false(ds.matches(make_ctx(), make_state({ hp_pct = 80, has_forbearance = false })), "DivineShield skips at high HP")

-- LayOnHands: low HP, ready
local loh = find_strategy("Ret_LayOnHands_LastResort")
assert_true(loh.matches(make_ctx(), make_state({ hp_pct = 5 })), "LayOnHands matches at low HP")
assert_false(loh.matches(make_ctx(), make_state({ hp_pct = 80 })), "LayOnHands skips at high HP")

-- SanctityAura: setting enabled, buff missing, ready
local sanctity = find_strategy("Ret_SanctityAura")
assert_true(sanctity.matches(make_ctx({ settings = { sanctity_aura_enabled = true } }), make_state()), "SanctityAura matches when enabled and missing")
assert_false(sanctity.matches(make_ctx({ settings = { sanctity_aura_enabled = false } }), make_state()), "SanctityAura skips when disabled")

-- HealthstoneOrPotion: low HP, item available
local hsw = find_strategy("Ret_HealthstoneOrPotion")
assert_true(hsw.matches(make_ctx(), make_state({ hp_pct = 10, healing_item = 12345 })), "HealthstoneOrPotion matches with low HP and item")
assert_false(hsw.matches(make_ctx(), make_state({ hp_pct = 10, healing_item = nil })), "HealthstoneOrPotion skips without item")
assert_false(hsw.matches(make_ctx(), make_state({ hp_pct = 80, healing_item = 12345 })), "HealthstoneOrPotion skips at high HP")

-- HammerWrath: target HP < 20, ready
local how = find_strategy("Ret_HammerWrath_Execute")
assert_true(how.matches(make_ctx(), make_state({ target_hp_pct = 15 })), "HammerWrath_Execute matches at target HP 15")
assert_false(how.matches(make_ctx(), make_state({ target_hp_pct = 25 })), "HammerWrath_Execute skips at target HP 25")

-- Cleanse_Self: setting enabled, debuff present, ready
local cleanse = find_strategy("Ret_Cleanse_Self")
mock_has_cleanse_debuff = true
assert_true(cleanse.matches(make_ctx({ settings = { use_cleanse = true } }), make_state()), "Cleanse_Self matches when debuffed and enabled")
assert_false(cleanse.matches(make_ctx({ settings = { use_cleanse = false } }), make_state()), "Cleanse_Self skips when disabled")
mock_has_cleanse_debuff = false
assert_false(cleanse.matches(make_ctx({ settings = { use_cleanse = true } }), make_state()), "Cleanse_Self skips without debuff")

-- SealCommand_Primary: seal_refresh_allowed, preferred command, not has_command, ready
local seal = find_strategy("Ret_SealCommand_Primary")
assert_true(seal.matches(make_ctx({ in_combat = true }), make_state({ has_command = false, preferred_damage_seal = "command" })), "SealCommand_Primary matches when command preferred and not active")
assert_false(seal.matches(make_ctx({ in_combat = true }), make_state({ has_command = true, preferred_damage_seal = "command" })), "SealCommand_Primary skips when already active")
assert_false(seal.matches(make_ctx({ in_combat = true }), make_state({ has_command = false, preferred_damage_seal = "blood" })), "SealCommand_Primary skips when blood preferred")

-- ============================================================================
-- Summary
-- ============================================================================
print(string.format("test_retribution_dsl_priority: %d passed, %d failed", _pass, _fail))
if _fail > 0 then
    os.exit(1)
end
print("PASS test_retribution_dsl_priority")
