-- test_fire_dsl_priority.lua â Mage Fire DSL priority + equivalence test.
-- WHAT:  verifies full strategy priority order, DSL position checks, and condition
--        equivalence for 6 DSL-converted strategies (IceBarrier, ManaShield,
--        PresenceOfMind, Combustion, Scorch, Evocation).
-- WHEN:  runs as part of the rotation test suite.
-- WHY:   regression guard for the eleventh DSL adopter (first fire mage/debuff-stack spec).
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
    ArcaneExplosion = 1449, BlastWave = 11113, Blizzard = 10, Combustion = 11129,
    ConjureManaEmerald = 759, DragonsBreath = 31661, Evocation = 12051,
    FireBlast = 2136, Fireball = 133, Flamestrike = 2120, FlamestrikeRank6 = 10216,
    IceBarrier = 11426, ManaShield = 1463, Polymorph = 118, PresenceOfMind = 12043,
    Pyroblast = 11366, RemoveCurse = 475, Scorch = 2948,
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
NS.has_player_buff = function(id)
    -- called with numeric id by original match functions; DSL uses NS.buff_up
    return false
end

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
package.loaded["shared/tbc_data_sylvanas"] = { SPELLS = { mage = {} } }
package.loaded["shared/hit_cap_tracker_sylvanas"] = { get_hit_cap = function() return nil end }
package.loaded["shared/potion_helper_sylvanas"] = { try_use_potion = function() return false end }

-- Load the real DSL engine and cache it so the spec file's require() picks it up
package.loaded["shared/strategy_dsl_sylvanas"] = dofile("EaxRotations/shared/strategy_dsl_sylvanas.lua")

-- Load the fire mage spec
local fire = dofile("EaxRotations/classes/mage/fire_sylvanas.lua")
local strategies = fire.strategies

-- ============================================================================
-- Priority order verification
-- ============================================================================
local expected_order = {
    "ManaPotion", "IceBarrier", "ManaShield", "Healthstone", "PresenceOfMind",
    "Combustion", "Pyroblast", "Scorch", "Evocation", "ManaGem", "Fireball",
    "FireBlast", "Flamestrike", "FlamestrikeRank6", "ArcaneExplosion", "Blizzard",
    "BlastWave", "DragonsBreath", "Polymorph", "RemoveCurse", "ManaGemConjure",
    "HitCapPriority",
}
assert_true(#strategies == #expected_order, "strategy count matches (" .. #strategies .. " vs " .. #expected_order .. ")")
for i = 1, math.min(#strategies, #expected_order) do
    assert_true(strategies[i].name == expected_order[i],
        string.format("priority[%d] = %s (expected %s)", i, strategies[i].name or "?", expected_order[i]))
end

-- DSL position checks â verify the 6 DSL-converted strategies are at expected indices
local dsl_indices = {}
for i = 1, #strategies do dsl_indices[strategies[i].name] = i end
assert_true(dsl_indices["IceBarrier"] == 2, "IceBarrier at index 2")
assert_true(dsl_indices["ManaShield"] == 3, "ManaShield at index 3")
assert_true(dsl_indices["PresenceOfMind"] == 5, "PresenceOfMind at index 5")
assert_true(dsl_indices["Combustion"] == 6, "Combustion at index 6")
assert_true(dsl_indices["Scorch"] == 8, "Scorch at index 8")
-- 2026-08-13 guide-divergence resolution (Phase 2.2h): Evocation/ManaGem moved
-- ABOVE the damage fillers (Fireball/FireBlast) per the wowsims TBC mage guide
-- (Evocation is a combat mana CD at mana <= 20% max). Pin the new positions.
assert_true(dsl_indices["Evocation"] == 9, "Evocation at index 9")
assert_true(dsl_indices["ManaGem"] == 10, "ManaGem at index 10")

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
        hp_pct = 100,
        mana_pct = 80,
        settings = { use_defensives = true, use_ice_barrier = true, use_mana_shield = true,
                     use_cooldowns = true, use_scorch_debuff = true, use_evocation = true },
        is_pvp = false,
        is_moving = false,
        is_casting = false,
        is_channeling = false,
        ttd_known = false,
        ttd = 999,
        should_burst = true,
        combat_time = 60,
    }
    for k, v in pairs(overrides or {}) do ctx[k] = v end
    return ctx
end

local function make_state(overrides)
    local s = {
        in_combat = true,
        is_moving = false,
        hp_pct = 50,
        mana_pct = 80,
        combustion_ready = true,
        scorch_stacks = 0,
        scorch_remains = 0,
        major_cd_window = false,
        has_presence_of_mind = false,
    }
    for k, v in pairs(overrides or {}) do s[k] = v end
    return s
end

-- ============================================================================
-- IceBarrier: defensives/ice_barrier enabled, no buff, hp <= 60
-- ============================================================================
local idx_ib = 2
assert_true(strategies[idx_ib].matches(make_ctx(), make_state({ hp_pct = 50 })),
    "IceBarrier matches when ready + no buff + settings enabled + low HP")
assert_false(strategies[idx_ib].matches(make_ctx(), make_state({ hp_pct = 70 })),
    "IceBarrier skips when HP above threshold")
assert_false(strategies[idx_ib].matches(make_ctx({ settings = { use_defensives = true, use_ice_barrier = false } }), make_state({ hp_pct = 50 })),
    "IceBarrier skips when use_ice_barrier disabled")
assert_false(strategies[idx_ib].matches(make_ctx({ settings = { use_defensives = false, use_ice_barrier = true } }), make_state({ hp_pct = 50 })),
    "IceBarrier skips when use_defensives disabled")

-- ============================================================================
-- ManaShield: defensives/mana_shield enabled, no buff, hp <= 40, mana >= 30
-- ============================================================================
local idx_ms = 3
assert_true(strategies[idx_ms].matches(make_ctx(), make_state({ hp_pct = 30, mana_pct = 50 })),
    "ManaShield matches when ready + no buff + low HP + enough mana")
assert_false(strategies[idx_ms].matches(make_ctx(), make_state({ hp_pct = 50, mana_pct = 50 })),
    "ManaShield skips when HP above threshold")
assert_false(strategies[idx_ms].matches(make_ctx(), make_state({ hp_pct = 30, mana_pct = 20 })),
    "ManaShield skips when mana below threshold")
assert_false(strategies[idx_ms].matches(make_ctx({ settings = { use_defensives = true, use_mana_shield = false } }), make_state({ hp_pct = 30, mana_pct = 50 })),
    "ManaShield skips when use_mana_shield disabled")

-- ============================================================================
-- PresenceOfMind: in combat, cooldowns enabled, should_burst, no PoM buff
-- ============================================================================
local idx_pom = 5
assert_true(strategies[idx_pom].matches(make_ctx(), make_state()),
    "PresenceOfMind matches with cooldowns/burst enabled and no PoM buff")
assert_false(strategies[idx_pom].matches(make_ctx(), make_state({ in_combat = false })),
    "PresenceOfMind skips when not in combat")
assert_false(strategies[idx_pom].matches(make_ctx({ should_burst = false }), make_state()),
    "PresenceOfMind skips when not bursting")
assert_false(strategies[idx_pom].matches(make_ctx({ settings = { use_cooldowns = false } }), make_state()),
    "PresenceOfMind skips when cooldowns disabled")

-- ============================================================================
-- Combustion: in combat, cooldowns enabled, boss gate, TTD > 15 or burst,
--             scorch stacks >= 5 or burst, major cd window or combat_time >= 45
-- ============================================================================
local idx_comb = 6
assert_true(strategies[idx_comb].matches(make_ctx(), make_state({ scorch_stacks = 5 })),
    "Combustion matches with 5 Scorch stacks")
assert_true(strategies[idx_comb].matches(make_ctx({ should_burst = true }), make_state({ scorch_stacks = 0 })),
    "Combustion matches during burst regardless of Scorch stacks")
assert_false(strategies[idx_comb].matches(make_ctx(), make_state({ combustion_ready = false })),
    "Combustion skips when not ready")
assert_false(strategies[idx_comb].matches(make_ctx(), make_state({ in_combat = false, scorch_stacks = 5 })),
    "Combustion skips when not in combat")
assert_false(strategies[idx_comb].matches(make_ctx({ ttd = 10, should_burst = false }), make_state({ scorch_stacks = 5 })),
    "Combustion skips on short TTD when not bursting")
assert_false(strategies[idx_comb].matches(make_ctx({ settings = { use_cooldowns = false } }), make_state({ scorch_stacks = 5 })),
    "Combustion skips when cooldowns disabled")

-- ============================================================================
-- Scorch: not moving, target exists, use_scorch_debuff enabled,
--         scorch_stacks < 5 or scorch_remains <= 4
-- ============================================================================
local idx_scorch = 8
assert_true(strategies[idx_scorch].matches(make_ctx(), make_state({ scorch_stacks = 3 })),
    "Scorch matches when Scorch stacks below 5")
assert_true(strategies[idx_scorch].matches(make_ctx(), make_state({ scorch_stacks = 5, scorch_remains = 3 })),
    "Scorch matches when Scorch about to drop")
assert_false(strategies[idx_scorch].matches(make_ctx({ is_moving = true }), make_state({ scorch_stacks = 3 })),
    "Scorch skips while moving")
assert_false(strategies[idx_scorch].matches(make_ctx({ settings = { use_scorch_debuff = false } }), make_state({ scorch_stacks = 3 })),
    "Scorch skips when use_scorch_debuff disabled")
assert_false(strategies[idx_scorch].matches(make_ctx(), make_state({ scorch_stacks = 5, scorch_remains = 10 })),
    "Scorch skips when 5-stack is safe")
local no_target_ctx = make_ctx()
no_target_ctx.target = nil
assert_false(strategies[idx_scorch].matches(no_target_ctx, make_state({ scorch_stacks = 3 })),
    "Scorch skips when no target")

-- ============================================================================
-- Evocation: in combat, use_evocation enabled, mana <= 20
-- ============================================================================
local idx_evo = 9
assert_true(strategies[idx_evo].matches(make_ctx(), make_state({ mana_pct = 15 })),
    "Evocation matches when mana is low and in combat")
assert_false(strategies[idx_evo].matches(make_ctx(), make_state({ in_combat = false, mana_pct = 15 })),
    "Evocation skips when not in combat")
assert_false(strategies[idx_evo].matches(make_ctx(), make_state({ mana_pct = 80 })),
    "Evocation skips when mana above threshold")
assert_false(strategies[idx_evo].matches(make_ctx({ settings = { use_evocation = false } }), make_state({ mana_pct = 15 })),
    "Evocation skips when use_evocation disabled")

-- ============================================================================
-- Summary
-- ============================================================================
print(string.format("test_fire_dsl_priority: %d passed, %d failed", _pass, _fail))
if _fail > 0 then
    os.exit(1)
end
print("PASS test_fire_dsl_priority")
