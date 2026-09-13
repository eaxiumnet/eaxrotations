-- test_destruction_dsl_priority.lua â Warlock Destruction DSL priority + equivalence test.
-- WHAT:  verifies full strategy priority order, DSL position checks, and condition
--        equivalence for 6 DSL-converted strategies (Immolate, Conflagrate,
--        Shadowburn, Incinerate, CurseOfDoom, LifeTap).
-- WHEN:  runs as part of the rotation test suite.
-- WHY:   regression guard for the thirteenth DSL adopter (first warlock spec).
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

NS.WarlockSpells = {
    Conflagrate = 30912, Corruption = 27216, CurseOfAgony = 27218, CurseOfDoom = 30910,
    CurseElements = 27228, CurseOfRecklessness = 27226, CurseOfWeakness = 30909,
    DeathCoil = 27223, FelArmor = 28189, Immolate = 27215, Incinerate = 32231,
    LifeTap = 27222, ShadowBolt = 27209, Shadowburn = 30546, Shadowfury = 30414,
    ShadowWard = 28610, Soulshatter = 29858,
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
local immo_remains = 0
NS.debuff_remains = function() return immo_remains end
NS.get_debuff_stacks = function() return 0 end
NS.spell_ready = function() return true end
NS.try_cast = function() return true end
NS.unit_mana_pct = function() return 100 end
NS.unit_health_pct = function() return 100 end
NS.time_now = function() return 0 end
NS.game_time_ms = function() return 0 end
NS.broken_api_throttled = function() return false end
-- Cooldown reads for the two DSL lanes whose ACTIONS entry used to carry a
-- `cooldown` field that the DSL substitution drops (TBC Conflagrate 30912 10s,
-- Shadowburn 30546 15s). Variable-driven so the pins can prove both sides.
local conf_cd, sb_cd = 0, 0
NS.cooldown_remains = function(spell)
    local id = (NS.get_spell_id and NS.get_spell_id(spell)) or spell
    if id == 30912 then return conf_cd end
    if id == 30546 then return sb_cd end
    return 0
end
NS.spell_exists = function() return true end
NS.is_item_ready = function() return false end
NS.has_item = function(id) return true end
NS.is_auto_attacking = function() return false end
NS.gate_cooldown_boss_only = function() return true end
NS.is_spell_learned = function() return true end
NS.is_interruptible = function() return true end
NS.is_in_combat = function() return false end
NS.should_use_long_cd = function() return true end
NS.is_execute_phase = function(target_hp, threshold) return (target_hp or 100) <= (threshold or 20) end
NS.should_refresh_dot = function(remains, pandemic, ttd, duration) return (remains or 0) <= (pandemic or 3) end
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
NS.spell_action = function(arg, label)
    if type(arg) == "table" then
        if arg.ids then return arg end
        return arg[1] or 0
    end
    return arg or 0
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
package.loaded["shared/warlock_curse_helper_sylvanas"] = {
    CURSE_REFRESH_WINDOW = 3,
    CURSE_OF_RECKLESSNESS_DEBUFF = { 27226 },
    CURSE_OF_WEAKNESS_DEBUFF = { 30909 },
    other_curse_active = function() return false end,
}
package.loaded["shared/aoe_hit_volume_sylvanas"] = { install = function() end }
package.loaded["shared/potion_helper_sylvanas"] = {
    try_use_potion = function() return false end,
    MANA_POTION_IDS = {},
}

-- Soulshatter helper is required by destruction_sylvanas.lua; preload the real helper
-- so the spec file loads without hitting disk in the mocked environment.
package.loaded["shared/warlock_soulshatter_sylvanas"] = dofile("EaxRotations/shared/warlock_soulshatter_sylvanas.lua")
package.loaded["shared/warlock_healthstone_sylvanas"] = dofile("EaxRotations/shared/warlock_healthstone_sylvanas.lua")
package.loaded["shared/warlock_mana_gem_sylvanas"] = dofile("EaxRotations/shared/warlock_mana_gem_sylvanas.lua")
package.loaded["shared/life_tap_batch_sylvanas"] = dofile("EaxRotations/shared/life_tap_batch_sylvanas.lua")

-- Load the real DSL engine and cache it so the spec file's require() picks it up
package.loaded["shared/strategy_dsl_sylvanas"] = dofile("EaxRotations/shared/strategy_dsl_sylvanas.lua")

-- Load the destruction warlock spec
local destruction = dofile("EaxRotations/classes/warlock/destruction_sylvanas.lua")
local strategies = destruction.strategies

-- ============================================================================
-- Priority order verification (partial; dynamic build, just verify DSL indices)
-- ============================================================================
local dsl_names = { Immolate = true, Conflagrate = true, Shadowburn = true,
                    Incinerate = true, CurseOfDoom = true, LifeTap = true, LifeTapMoving = true }
local dsl_indices = {}
for i = 1, #strategies do
    if dsl_names[strategies[i].name] then
        dsl_indices[strategies[i].name] = i
    end
end

for name, _ in pairs(dsl_names) do
    assert_true(dsl_indices[name] ~= nil, name .. " found in strategies table")
end

-- Expected relative order (from original ACTIONS order):
-- CurseOfDoom > Corruption > Immolate > Conflagrate > Shadowburn > Incinerate > ... > LifeTap
assert_true(dsl_indices["CurseOfDoom"] < dsl_indices["Immolate"], "CurseOfDoom before Immolate")
assert_true(dsl_indices["Immolate"] < dsl_indices["Conflagrate"], "Immolate before Conflagrate")
assert_true(dsl_indices["Conflagrate"] < dsl_indices["Shadowburn"], "Conflagrate before Shadowburn")
assert_true(dsl_indices["Shadowburn"] < dsl_indices["Incinerate"], "Shadowburn before Incinerate")

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
        target_hp = 100,
        settings = { warlock_assigned_curse = "none", warlock_curse_mode = "auto" },
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
        immolate_remains = 0,
        corruption_remains = 0,
        cod_remains = 0,
        coa_remains = 0,
        coe_remains = 0,
        recklessness_remains = 0,
        weakness_remains = 0,
        has_backlash = false,
        has_backdraft = false,
        has_fel_armor = false,
        has_demon_armor = false,
        has_shadow_ward = false,
        has_demonic_sacrifice = false,
        hp = 100,
        mana_pct = 100,
        spell_damage = 500,
        level = 70,
    }
    for k, v in pairs(overrides or {}) do s[k] = v end
    return s
end

-- ============================================================================
-- Immolate: not moving, target exists, immolate_remains <= pandemic window, SP threshold met
-- ============================================================================
local idx_imm = dsl_indices["Immolate"]
assert_true(strategies[idx_imm].matches(make_ctx(), make_state()),
    "Immolate matches with no debuff, high SP, stationary")
-- Immolate DSL preserves the ACTIONS `not_moving` gate: the DSL substitution
-- drops the ACTIONS metadata, so the DSL definition carries its own is_moving
-- check (2026-08 live audit: without it Immolate fired while moving).
assert_false(strategies[idx_imm].matches(make_ctx({ is_moving = true }), make_state()),
    "Immolate skips while moving (not_moving restored)")
assert_false(strategies[idx_imm].matches(make_ctx(), make_state({ immolate_remains = 10 })),
    "Immolate skips when debuff has plenty of time")
-- 2026-08 read-side audit: the spell-damage min-SP gate was REMOVED (the
-- engine never writes context.spell_damage, so state.spell_damage was always
-- 0 and the old gate blocked Immolate + Conflagrate at level 40+ live).
-- Immolate now matches regardless of the always-zero spell damage — this
-- assertion is the non-vacuity proof (it failed before the gate removal).
assert_true(strategies[idx_imm].matches(make_ctx(), make_state({ spell_damage = 200, level = 70 })),
    "Immolate matches with low spell damage at high level (SP gate removed)")
-- New: Immolate toggle — disable destro_use_immolate to skip entirely (speed kills)
assert_false(strategies[idx_imm].matches(make_ctx({ settings = { destro_use_immolate = false } }), make_state()),
    "Immolate skips when destro_use_immolate is false (speed kill mode)")
-- Configurable refresh window (destro_immolate_refresh slider). The mock
-- should_refresh_dot returns `remains <= window`, so this pins the setting is
-- actually read and that the default keeps the historical 1.5s behaviour.
assert_true(strategies[idx_imm].matches(make_ctx(), make_state({ immolate_remains = 1.0 })),
    "Immolate refresh fires at 1.0s remaining with the default 1.5s window")
assert_false(strategies[idx_imm].matches(make_ctx(), make_state({ immolate_remains = 2.0 })),
    "Immolate refresh holds at 2.0s remaining with the default 1.5s window")
assert_true(strategies[idx_imm].matches(make_ctx({ settings = { destro_immolate_refresh = 3.0 } }), make_state({ immolate_remains = 2.0 })),
    "Immolate refresh slider fires at 2.0s remaining with a 3.0s window")
assert_false(strategies[idx_imm].matches(make_ctx({ settings = { destro_immolate_refresh = 3.0 } }), make_state({ immolate_remains = 3.5 })),
    "Immolate refresh slider holds at 3.5s remaining with a 3.0s window")
-- Original match function does not gate on target presence, so DSL equivalence
-- preserves that behavior (target check is left to the framework/execute path).

-- ============================================================================
-- Conflagrate: immolate active, target not dying
-- ============================================================================
local idx_conf = dsl_indices["Conflagrate"]
assert_true(strategies[idx_conf].matches(make_ctx(), make_state({ immolate_remains = 8 })),
    "Conflagrate matches when Immolate active and target not dying")
assert_false(strategies[idx_conf].matches(make_ctx(), make_state({ immolate_remains = 0 })),
    "Conflagrate skips when Immolate absent")
assert_false(strategies[idx_conf].matches(make_ctx({ ttd_known = true, ttd = 2 }), make_state({ immolate_remains = 8 })),
    "Conflagrate skips when target dying soon")

-- Real 10s cooldown (Wowhead TBC 2.5.5: 17962, "Cooldown 10 seconds"): the
-- ACTIONS entry this DSL lane replaced carried cooldown = 10 and the DSL
-- substitution dropped it, so the lane claimed the race while cooling.
assert_true(strategies[idx_conf].matches(make_ctx(), make_state({ immolate_remains = 8, conflagrate_cd = 0 })),
    "Conflagrate matches at the cooldown-ready boundary")
assert_false(strategies[idx_conf].matches(make_ctx(), make_state({ immolate_remains = 8, conflagrate_cd = 4 })),
    "Conflagrate holds while its 10s cooldown is running")
-- End-to-end through the real read path: NS.cooldown_remains -> build_state ->
-- state.conflagrate_cd -> the gate.
immo_remains = 8; conf_cd = 0
assert_true(strategies[idx_conf].matches(make_ctx(), destruction.build_state(make_ctx())),
    "Conflagrate matches when NS.cooldown_remains reports ready")
immo_remains = 8; conf_cd = 9.9
assert_false(strategies[idx_conf].matches(make_ctx(), destruction.build_state(make_ctx())),
    "Conflagrate holds through the real cooldown read (NS.cooldown_remains)")
immo_remains = 0; conf_cd = 0

-- ============================================================================
-- Shadowburn: target exists, has soul shard, target in execute range, spell ready
-- ============================================================================
local idx_sb = dsl_indices["Shadowburn"]
assert_true(strategies[idx_sb].matches(make_ctx({ target_hp = 15 }), make_state()),
    "Shadowburn matches in execute range with soul shard")
assert_false(strategies[idx_sb].matches(make_ctx({ target_hp = 50 }), make_state()),
    "Shadowburn skips when target HP above execute threshold")
-- Real 15s cooldown (Wowhead TBC 2.5.5: 30546, "Cooldown 15 seconds").
assert_true(strategies[idx_sb].matches(make_ctx({ target_hp = 15 }), make_state({ shadowburn_cd = 0 })),
    "Shadowburn matches at the cooldown-ready boundary")
assert_false(strategies[idx_sb].matches(make_ctx({ target_hp = 15 }), make_state({ shadowburn_cd = 14.9 })),
    "Shadowburn holds while its 15s cooldown is running")
-- End-to-end through the real read path (NS.cooldown_remains -> build_state).
sb_cd = 10
assert_false(strategies[idx_sb].matches(make_ctx({ target_hp = 15 }), destruction.build_state(make_ctx({ target_hp = 15 }))),
    "Shadowburn holds through the real cooldown read (NS.cooldown_remains)")
sb_cd = 0

-- ============================================================================
-- Incinerate: not moving, immolate active, target not dying
-- ============================================================================
local idx_inc = dsl_indices["Incinerate"]
assert_true(strategies[idx_inc].matches(make_ctx(), make_state({ immolate_remains = 8 })),
    "Incinerate matches when Immolate active and target not dying")
assert_false(strategies[idx_inc].matches(make_ctx(), make_state({ immolate_remains = 0 })),
    "Incinerate skips when Immolate absent")
assert_false(strategies[idx_inc].matches(make_ctx({ is_moving = true }), make_state({ immolate_remains = 8 })),
    "Incinerate skips while moving")

-- ============================================================================
-- CurseOfDoom: auto/assigned curse == doom, long CD gate passes, debuff absent/refreshable
-- ============================================================================
local idx_cod = dsl_indices["CurseOfDoom"]
assert_true(strategies[idx_cod].matches(make_ctx(), make_state({ cod_remains = 0 })),
    "CurseOfDoom matches when CoD debuff absent and curse assignment is doom")
assert_false(strategies[idx_cod].matches(make_ctx({ settings = { warlock_curse_mode = "agony" } }), make_state({ cod_remains = 0 })),
    "CurseOfDoom skips when curse mode is not doom")
-- New: auto mode switches to Agony when TTD < 60s (short fight = Doom is a DPS loss)
assert_false(strategies[idx_cod].matches(make_ctx({ ttd_known = true, ttd = 30 }), make_state({ cod_remains = 0 })),
    "CurseOfDoom skips in auto mode when TTD < 60s (switches to Agony)")

-- ============================================================================
-- CurseOfAgony: complement to CoD test — verify Agony MATCHES when TTD < 60s in auto mode
-- CurseOfAgony uses the imperative match function (not DSL-compiled), so find by name.
-- ============================================================================
local idx_coa = nil
for i = 1, #strategies do
    if strategies[i].name == "CurseOfAgony" then idx_coa = i break end
end
assert_true(idx_coa ~= nil, "CurseOfAgony found in strategies table")

-- Core TTD switch: Agony matches for short fights, skips for long fights (auto mode)
assert_true(strategies[idx_coa].matches(make_ctx({ ttd_known = true, ttd = 30 }), make_state({ coa_remains = 0 })),
    "CurseOfAgony matches in auto mode when TTD < 60s (short fight → Agony)")
assert_false(strategies[idx_coa].matches(make_ctx({ ttd_known = true, ttd = 90 }), make_state({ coa_remains = 0 })),
    "CurseOfAgony skips in auto mode when TTD >= 60s (long fight → Doom)")
-- TTD boundary: exactly 60s → Doom (>= 60), 59s → Agony (< 60)
assert_false(strategies[idx_coa].matches(make_ctx({ ttd_known = true, ttd = 60 }), make_state({ coa_remains = 0 })),
    "CurseOfAgony skips at TTD = 60s (boundary: >= 60 selects Doom)")
assert_true(strategies[idx_coa].matches(make_ctx({ ttd_known = true, ttd = 59 }), make_state({ coa_remains = 0 })),
    "CurseOfAgony matches at TTD = 59s (boundary: < 60 selects Agony)")
-- Explicit curse_mode overrides TTD-based auto selection
assert_true(strategies[idx_coa].matches(make_ctx({ settings = { warlock_curse_mode = "agony" }, ttd_known = true, ttd = 90 }), make_state({ coa_remains = 0 })),
    "CurseOfAgony matches when curse_mode=agony even with long TTD")
assert_false(strategies[idx_coa].matches(make_ctx({ settings = { warlock_curse_mode = "doom" }, ttd_known = true, ttd = 10 }), make_state({ coa_remains = 0 })),
    "CurseOfAgony skips when curse_mode=doom even with short TTD")
-- Assigned curse overrides everything
assert_true(strategies[idx_coa].matches(make_ctx({ settings = { warlock_assigned_curse = "agony" }, ttd_known = true, ttd = 90 }), make_state({ coa_remains = 0 })),
    "CurseOfAgony matches when assigned_curse=agony even with long TTD")
assert_false(strategies[idx_coa].matches(make_ctx({ settings = { warlock_assigned_curse = "doom" }, ttd_known = true, ttd = 10 }), make_state({ coa_remains = 0 })),
    "CurseOfAgony skips when assigned_curse=doom even with short TTD")
-- Existing debuff blocks refresh (CURSE_REFRESH_WINDOW = 3 in mock)
assert_false(strategies[idx_coa].matches(make_ctx({ ttd_known = true, ttd = 30 }), make_state({ coa_remains = 10 })),
    "CurseOfAgony skips when CoA debuff still has time remaining")
-- Unknown TTD defaults to 999 (long fight) → Doom selected, Agony skips
assert_false(strategies[idx_coa].matches(make_ctx({ ttd_known = false }), make_state({ coa_remains = 0 })),
    "CurseOfAgony skips when TTD unknown (defaults to long fight → Doom)")

-- ============================================================================
-- LifeTap: not casting/channeling, mana low (default 20%), hp safe (default 50%)
-- ============================================================================
local idx_lt = dsl_indices["LifeTap"]
local _orig_time_now = NS.time_now
-- Keep time_now at 2 for all LifeTap/LifeTapMoving tests so the throttle doesn't block
NS.time_now = function() return 2 end
assert_true(strategies[idx_lt].matches(make_ctx(), make_state({ mana_pct = 15, hp = 100 })),
    "LifeTap matches when mana <= 20% and HP >= 50%")
assert_false(strategies[idx_lt].matches(make_ctx(), make_state({ mana_pct = 80, hp = 100 })),
    "LifeTap skips when mana above threshold")
assert_false(strategies[idx_lt].matches(make_ctx(), make_state({ mana_pct = 15, hp = 30 })),
    "LifeTap skips when HP below 50% threshold")
assert_false(strategies[idx_lt].matches(make_ctx({ is_casting = true }), make_state({ mana_pct = 15, hp = 100 })),
    "LifeTap skips while casting")
-- Configurable threshold: override destro_life_tap_mana to 35%
assert_true(strategies[idx_lt].matches(make_ctx({ settings = { destro_life_tap_mana = 35 } }), make_state({ mana_pct = 30, hp = 100 })),
    "LifeTap matches when mana 30% with destro_life_tap_mana=35")
assert_false(strategies[idx_lt].matches(make_ctx({ settings = { destro_life_tap_mana = 35 } }), make_state({ mana_pct = 40, hp = 100 })),
    "LifeTap skips when mana 40% with destro_life_tap_mana=35")

-- ============================================================================
-- LifeTapMoving: fires when moving, mana not full, HP safe (replaces Searing Pain)
-- ============================================================================
local idx_ltm = dsl_indices["LifeTapMoving"]
assert_true(dsl_indices["LifeTapMoving"] ~= nil, "LifeTapMoving found in strategies table")
assert_true(strategies[idx_ltm].matches(make_ctx({ is_moving = true }), make_state({ mana_pct = 50, hp = 100 })),
    "LifeTapMoving matches when moving, mana not full, HP safe")
assert_false(strategies[idx_ltm].matches(make_ctx({ is_moving = false }), make_state({ mana_pct = 50, hp = 100 })),
    "LifeTapMoving skips when not moving")
assert_false(strategies[idx_ltm].matches(make_ctx({ is_moving = true }), make_state({ mana_pct = 100, hp = 100 })),
    "LifeTapMoving skips when mana is full")
assert_false(strategies[idx_ltm].matches(make_ctx({ is_moving = true }), make_state({ mana_pct = 50, hp = 30 })),
    "LifeTapMoving skips when HP below safety gate")
assert_false(strategies[idx_ltm].matches(make_ctx({ is_moving = true, is_casting = true }), make_state({ mana_pct = 50, hp = 100 })),
    "LifeTapMoving skips while casting")
NS.time_now = _orig_time_now

-- ============================================================================
-- LifeTap batching engine: fire / hold / consecutive / exit pins
-- ============================================================================
local lt_batch = require("shared/life_tap_batch_sylvanas")
lt_batch.reset()
local _bt = 100
local _casts = 0
local _orig_try_cast = NS.try_cast
NS.try_cast = function(...) _casts = _casts + 1 return true end
NS.time_now = function() return _bt end

-- FIRE from idle: mana under the entry threshold taps and opens a batch.
local lt_ctx = make_ctx()
local lt_low = make_state({ mana_pct = 15, hp = 100 })
assert_true(strategies[idx_lt].matches(lt_ctx, lt_low), "LifeTap batch: fire from idle at 15% mana")
_casts = 0
assert_true(strategies[idx_lt].execute(lt_ctx, lt_low) == true, "LifeTap batch: first tap returns true")
assert_true(_casts == 1, "LifeTap batch: first tap casts once")
assert_true(lt_batch.is_active(), "LifeTap batch: first tap opens the batch")
assert_true(lt_batch.target() >= 20, "LifeTap batch: recover target is at/above the entry threshold")

-- HOLD: same GCD, mana still under the recover target -> the lane still claims
-- the tick but must not cast, so no filler slots in between the taps.
local lt_mid = make_state({ mana_pct = 25, hp = 100 })
assert_true(strategies[idx_lt].matches(lt_ctx, lt_mid), "LifeTap batch: claim the tick inside the batch")
_casts = 0
assert_true(strategies[idx_lt].execute(lt_ctx, lt_mid) == true, "LifeTap batch: hold returns true")
assert_true(_casts == 0, "LifeTap batch: hold does NOT cast (no tap/cast ping-pong)")

-- CONSECUTIVE: next GCD, still under the recover target -> taps again.
_bt = _bt + 2
_casts = 0
assert_true(strategies[idx_lt].matches(lt_ctx, lt_mid), "LifeTap batch: matched at the next GCD")
assert_true(strategies[idx_lt].execute(lt_ctx, lt_mid) == true, "LifeTap batch: consecutive tap returns true")
assert_true(_casts == 1, "LifeTap batch: taps again on the next GCD")
assert_true(lt_batch.taps() >= 2, "LifeTap batch: two consecutive taps recorded")

-- EXIT + hysteresis re-arm.
local _recover = lt_batch.target()
local lt_full = make_state({ mana_pct = _recover + 1, hp = 100 })
assert_false(strategies[idx_lt].matches(lt_ctx, lt_full), "LifeTap batch: exits at the recover target")
lt_batch.observe(_bt, _recover + 1, 100, 20, _recover, 50)
assert_false(lt_batch.is_active(), "LifeTap batch: cleared at the recover target")
assert_false(strategies[idx_lt].matches(lt_ctx, lt_mid),
    "LifeTap batch: above the entry threshold a new batch does not re-enter")

-- ABORT on unsafe HP.
lt_batch.start(_bt, _recover)
assert_false(strategies[idx_lt].matches(lt_ctx, make_state({ mana_pct = 25, hp = 30 })),
    "LifeTap batch: holds off when HP is unsafe mid-batch")
lt_batch.observe(_bt, 25, 30, 20, _recover, 50)
assert_false(lt_batch.is_active(), "LifeTap batch: aborts when HP drops below the safety gate")

-- A zero buffer disables batching: the recover target collapses onto entry.
lt_batch.reset()
local lt_nobatch = make_ctx({ settings = { destro_life_tap_batch = 0 } })
_bt = _bt + 2  -- step past the tap GCD left by the abort pin above
_casts = 0
assert_true(strategies[idx_lt].matches(lt_nobatch, lt_low), "LifeTap no-batch: still taps from idle")
_casts = 0
assert_true(strategies[idx_lt].execute(lt_nobatch, lt_low) == true, "LifeTap no-batch: first tap returns true")
_bt = _bt + 2
lt_batch.observe(_bt, 25, 100, 20, 20, 50)
assert_false(lt_batch.is_active(), "LifeTap no-batch: buffer 0 ends the batch once mana leaves entry")

lt_batch.reset()
NS.try_cast = _orig_try_cast
NS.time_now = _orig_time_now

-- ============================================================================
-- Summary
-- ============================================================================
print(string.format("test_destruction_dsl_priority: %d passed, %d failed", _pass, _fail))
if _fail > 0 then
    os.exit(1)
end
print("PASS test_destruction_dsl_priority")
