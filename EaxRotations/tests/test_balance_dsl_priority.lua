-- test_balance_dsl_priority.lua — Balance Druid DSL priority order + condition equivalence.
-- WHAT:  regression gate verifying the DSL in-place substitution preserves the exact
--        26-strategy priority order and that DSL-compiled match functions are behaviorally
--        equivalent to the original inline functions.
-- WHEN:  runs as part of run_rotation_tests.lua.
-- WHY:   fourth DSL adopter (first mana-based caster) — must prove generality across
--        mana thresholds, DoT windows, spell readiness, PvP gates, and AoE enemy count.
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
-- Mock NS for balance_sylvanas.lua
-- ============================================================================
local mock_mana_pct = 100
local mock_hp = 100
local mock_enemy_count = 1
local mock_in_combat = false
local mock_is_pvp = false
local mock_melee_on_you = false
local mock_healthstone_ready = 0
local mock_spell_ready_result = true
local mock_moonkin_auto = true

_G.EaxRotations = _G.EaxRotations or {}
local NS = _G.EaxRotations
NS.log = function() end
NS.log_warning = function() end
NS.GetPlayer = function() return { get_health = function() return 100 end } end
NS.PLAYER_UNIT = "player"
NS.time_now = function() return 0 end
NS.spell_ready = function() return mock_spell_ready_result end
NS.try_cast = function() return true end
NS.action_matches = function() return true end
NS.action_execute = function() return true end
NS.buff_up = function() return false end
NS.buff_remains = function() return 0 end
NS.debuff_remains = function() return 0 end
NS.debuff_up = function() return false end
NS.debuff_stacks = function() return 0 end
NS.buff_would_downgrade = function() return false end
NS.aoe_target_meets = function() return false end
NS.aoe_self_meets = function() return false end
NS.same_unit = function(a, b) return a == b end
NS.use_item_by_id = function() return true end
NS.broken_api_throttled = function() return false end
NS.pvp_trinket_used_recently = function() return false end
NS.find_dead_party_ally = function() return nil end
NS.unit_health_pct = function() return mock_hp end
NS.unit_energy_pct = function() return 100 end
NS.rotation_registry = { register = function() end }
NS.DruidSpells = {
    Barkskin = 22812,
    MoonkinForm = 24858,
    Hurricane = 16914,
    FaerieFire = 770,
    InsectSwarm = 5570,
    Moonfire = 8921,
    Starfire = 2912,
    Wrath = 5176,
    RemoveCurse = 2782,
    MarkOfTheWild = 26991,
    Thorns = 467,
}
NS.DruidConstants = {}

-- Mock ACTION table — balance uses ACTION for some spells
local ACTION = {
    Innervate = 29166,
    Rebirth = 20484,
    NaturesGrasp = 16689,
    EntanglingRoots = 339,
    Cyclone = 33786,
    WarStomp = 20549,
    MarkOfTheWild = 26991,
    Thorns = 467,
}
_G.EaxRotations._balance_ACTION = ACTION

-- Mock shared modules
package.loaded["shared/spec_kit_sylvanas"] = {
    safe_state = function(raw, schema)
        -- Return a simple proxy that falls back to schema defaults
        local proxy = {}
        setmetatable(proxy, {
            __index = function(t, k)
                if raw[k] ~= nil then return raw[k] end
                if schema and schema[k] ~= nil then return schema[k] end
                return nil
            end,
        })
        -- Copy raw fields
        for k, v in pairs(raw) do proxy[k] = v end
        return proxy
    end,
    define_action_for_class = function(SPELLS)
        return function(spell_field, rank_ids, label)
            if SPELLS and type(SPELLS) == "table" and SPELLS[spell_field] ~= nil then
                return SPELLS[spell_field]
            end
            -- Fallback: return a simple action object (first rank ID or name)
            return rank_ids and rank_ids[1] or spell_field
        end
    end,
    setting = function(ctx, key, default)
        if key == "balance_moonkin_auto" then return mock_moonkin_auto end
        if ctx and ctx.settings and ctx.settings[key] ~= nil then return ctx.settings[key] end
        return default
    end,
    setting_bool = function(ctx, key, default)
        if key == "balance_moonkin_auto" then return mock_moonkin_auto end
        if ctx and ctx.settings and ctx.settings[key] ~= nil then return ctx.settings[key] end
        return default
    end,
    setting_number = function(ctx, key, default)
        if ctx and ctx.settings and ctx.settings[key] ~= nil then return ctx.settings[key] end
        return default
    end,
}
package.loaded["shared/strategy_dsl_sylvanas"] = dofile("EaxRotations/shared/strategy_dsl_sylvanas.lua")
package.loaded["shared/potion_helper_sylvanas"] = {
    try_use_potion = function() return false end,
    MANA_POTION_IDS = { 28100, 28070, 28068 },
    HEALTH_POTION_IDS = { 22851, 13446 },
}
package.loaded["shared/tbc_data_sylvanas"] = { ITEMS = { potions = {} } }
package.loaded["shared/find_dead_party_ally_sylvanas"] = { find_dead_party_ally = function() return nil end }
package.loaded["shared/ts_helper_sylvanas"] = nil
package.loaded["shared/aoe_hit_volume_sylvanas"] = { install = function() end }

-- ============================================================================
-- Load the balance spec
-- ============================================================================
local balance = dofile("EaxRotations/classes/druid/balance_sylvanas.lua")
local strategies = balance.strategies

-- ============================================================================
-- Test 1: Strategy count
-- ============================================================================
assert_eq(#strategies, 26, "strategy count = 26")

-- ============================================================================
-- Test 2: Full priority order
-- ============================================================================
local expected_order = {
    "BarkskinDefense",         -- 1
    "ManaPotionEmergency",     -- 2 (DSL)
    "ForceOfNature",           -- 3
    "MoonkinForm",             -- 4 (DSL)
    "InnervateSelf",           -- 5
    "RebirthBattleRez",        -- 6
    "PreHurricaneBarkskin",    -- 7
    "HurricaneAoE",            -- 8
    "FaerieFireDebuff",        -- 9
    "InsectSwarmDoT",          -- 10
    "MoonfireDoT",             -- 11
    "MoonfireSpread",          -- 12
    "InsectSwarmSpread",       -- 13
    "MovingMoonfire",          -- 14
    "StarfirePrimary",         -- 15
    "WrathFiller",             -- 16
    "RemoveCurse",             -- 17
    "ManaGem",                 -- 18
    "ManaPotion",              -- 19 (DSL)
    "PvP_NaturesGrasp",        -- 20 (DSL)
    "PvP_EntanglingRoots",     -- 21
    "PvP_Cyclone",             -- 22
    "WarStomp",                -- 23 (DSL)
    "Healthstone",             -- 24 (DSL)
    "MarkOfTheWild",           -- 25
    "ThornsBuff",              -- 26
}

for i = 1, #expected_order do
    assert_eq(strategies[i].name, expected_order[i], "position " .. i .. " = " .. expected_order[i])
end

-- ============================================================================
-- Test 3: DSL strategy positions (verify they exist at the expected indices)
-- ============================================================================
local dsl_positions = {
    ManaPotionEmergency = 2,
    MoonkinForm = 4,
    ManaPotion = 19,
    PvP_NaturesGrasp = 20,
    WarStomp = 23,
    Healthstone = 24,
}

for name, pos in pairs(dsl_positions) do
    assert_eq(strategies[pos].name, name, "DSL position " .. pos .. " = " .. name)
    -- DSL-compiled strategies have a wrapped_matches function (not the original inline)
    assert_true(type(strategies[pos].matches) == "function", name .. " has matches function")
    assert_true(type(strategies[pos].execute) == "function", name .. " has execute function")
end

-- ============================================================================
-- Test 4: DSL condition equivalence — ManaPotionEmergency
-- Original: if (s.mana_pct or 100) > 15 then return false end; return true
-- DSL: { type = "state", field = "mana_pct", op = "<=", value = 15 }
-- ============================================================================
local function make_ctx(overrides)
    local ctx = {
        me = { get_health = function() return 100 end },
        target = nil,
        in_combat = mock_in_combat,
        is_pvp = mock_is_pvp,
        hp = mock_hp,
        settings = {},
        has_valid_enemy_target = false,
    }
    for k, v in pairs(overrides or {}) do ctx[k] = v end
    return ctx
end

local function make_state(overrides)
    local s = {
        mana_pct = mock_mana_pct,
        enemy_count = mock_enemy_count,
        healthstone_ready = mock_healthstone_ready,
        barkskin_active = false,
        innervate_target = nil,
    }
    for k, v in pairs(overrides or {}) do s[k] = v end
    return s
end

-- ManaPotionEmergency: mana <= 15 should match
local idx_mpe = 2
mock_mana_pct = 10
assert_true(strategies[idx_mpe].matches(make_ctx(), make_state({ mana_pct = 10 })), "ManaPotionEmergency matches at mana=10")
assert_false(strategies[idx_mpe].matches(make_ctx(), make_state({ mana_pct = 20 })), "ManaPotionEmergency skips at mana=20")
assert_false(strategies[idx_mpe].matches(make_ctx(), make_state({ mana_pct = 100 })), "ManaPotionEmergency skips at mana=100")

-- ManaPotion: mana <= 25 should match
local idx_mp = 19
assert_true(strategies[idx_mp].matches(make_ctx(), make_state({ mana_pct = 20 })), "ManaPotion matches at mana=20")
assert_false(strategies[idx_mp].matches(make_ctx(), make_state({ mana_pct = 30 })), "ManaPotion skips at mana=30")

-- MoonkinForm: requires balance_moonkin_auto=true, not in combat, spell ready
local idx_mf = 4
mock_moonkin_auto = true
mock_in_combat = false
mock_spell_ready_result = true
assert_true(strategies[idx_mf].matches(make_ctx({ settings = { balance_moonkin_auto = true } }), make_state()), "MoonkinForm matches when auto=true, OOC, ready")
mock_in_combat = true
assert_false(strategies[idx_mf].matches(make_ctx({ settings = { balance_moonkin_auto = true } }), make_state()), "MoonkinForm skips in combat")
mock_in_combat = false
assert_false(strategies[idx_mf].matches(make_ctx({ settings = { balance_moonkin_auto = false } }), make_state()), "MoonkinForm skips when auto=false")

-- WarStomp: requires in_combat, enemy_count >= 4, spell ready
local idx_ws = 23
mock_in_combat = true
mock_spell_ready_result = true
assert_true(strategies[idx_ws].matches(make_ctx(), make_state({ enemy_count = 5 })), "WarStomp matches at 5 enemies in combat")
assert_false(strategies[idx_ws].matches(make_ctx(), make_state({ enemy_count = 3 })), "WarStomp skips at 3 enemies")
mock_in_combat = false
assert_false(strategies[idx_ws].matches(make_ctx(), make_state({ enemy_count = 5 })), "WarStomp skips out of combat")

-- Healthstone: requires in_combat, hp <= 28, healthstone_ready > 0
local idx_hs = 24
mock_in_combat = true
assert_true(strategies[idx_hs].matches(make_ctx({ hp = 25 }), make_state({ healthstone_ready = 1 })), "Healthstone matches at hp=25, ready=1")
assert_false(strategies[idx_hs].matches(make_ctx({ hp = 30 }), make_state({ healthstone_ready = 1 })), "Healthstone skips at hp=30")
assert_false(strategies[idx_hs].matches(make_ctx({ hp = 25 }), make_state({ healthstone_ready = 0 })), "Healthstone skips when not ready")
mock_in_combat = false
assert_false(strategies[idx_hs].matches(make_ctx({ hp = 25 }), make_state({ healthstone_ready = 1 })), "Healthstone skips out of combat")

-- PvP_NaturesGrasp: requires is_pvp, melee_on_you, spell ready
local idx_ng = 20
mock_spell_ready_result = true
assert_true(strategies[idx_ng].matches(make_ctx({ is_pvp = true, melee_on_you = true }), make_state()), "NaturesGrasp matches in PvP with melee on you")
assert_false(strategies[idx_ng].matches(make_ctx({ is_pvp = true, melee_on_you = false }), make_state()), "NaturesGrasp skips without melee on you")
assert_false(strategies[idx_ng].matches(make_ctx({ is_pvp = false, melee_on_you = true }), make_state()), "NaturesGrasp skips outside PvP")

-- ============================================================================
-- Summary
-- ============================================================================
print(string.format("test_balance_dsl_priority: %d passed, %d failed", _pass, _fail))
if _fail > 0 then
    os.exit(1)
end
print("PASS test_balance_dsl_priority")
