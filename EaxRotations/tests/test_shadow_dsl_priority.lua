-- test_shadow_dsl_priority.lua â Shadow Priest DSL priority + equivalence test.
-- WHAT:  verifies full strategy priority order, DSL position checks, and condition
--        equivalence for 6 DSL-converted strategies (Shadowform, VampiricTouch,
--        ShadowWordPain, MindBlast, ShadowWordDeath, InnerFire).
-- WHEN:  runs as part of the rotation test suite.
-- WHY:   regression guard for the eighth DSL adopter (first shadow priest/DoT-tracking spec).
-- SAFETY: standalone â mocks NS, spec_kit, and shared modules; no game API calls.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

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

NS.PriestSpells = {
    ArcaneTorrent = 25046, Berserking = 26297, BloodFury = 33697,
    DevouringPlague = 2944, DispelMagic = 527, Fade = 586,
    FlashHeal = 2061, HolyNova = 15237, InnerFire = 588,
    InnerFocus = 14751, MindBlast = 8092, MindFlay = 15407,
    PowerWordFortitude = 1243, PowerWordShield = 17,
    PsychicScream = 8122, ShackleUndead = 9484,
    ShadowWordDeath = 32379, ShadowWordPain = 589,
    Shadowfiend = 34433, Shadowform = 15473, Starshards = 10797,
    VampiricEmbrace = 15286, VampiricTouch = 34914,
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
NS.spell_ready = function() return true end
NS.try_cast = function() return true end
NS.unit_mana_pct = function() return 100 end
NS.unit_health_pct = function() return 100 end
NS.time_now = function() return 0 end
NS.game_time_ms = function() return 0 end
NS.broken_api_throttled = function() return false end
NS.cooldown_remains = function() return 0 end
NS.spell_exists = function() return true end
NS.get_spell_id = function(spell)
    return type(spell) == "number" and spell or 8092
end
NS.is_item_ready = function() return false end
NS.is_auto_attacking = function() return false end
NS.is_threat_safe = function() return true end
NS.is_spell_in_range = function() return true end
NS.same_unit = function() return true end
NS.unit_interruptible = function() return true end
NS.unit_creature_type = function() return nil end
NS.get_debuff_stacks = function() return 0 end
NS.GetEnemiesInRange = function() return {} end
NS.aoe_self_meets = function() return false end
NS.aoe_target_meets = function() return false end
NS.log = function() end
NS.log_warning = function() end
NS.rotation_registry = { register = function() end }
NS.OffensiveDispelDB = {
    is_breakable_cc_active = function() return false, nil end,
    is_casting_preemptive_cc = function() return false, nil end,
}

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

-- Mock shared modules
package.loaded["shared/mf_tick_compute_sylvanas"] = {
    compute_channel_state = function() return false, 0 end,
    should_clip_mf = function() return true end,
}
package.loaded["shared/offensive_dispel_sylvanas"] = NS.OffensiveDispelDB
package.loaded["shared/dot_ttd_gating_sylvanas"] = {
    should_skip_dot = function() return false end,
    DOT_DURATIONS = { vampiric_touch = 15, shadow_word_pain = 18, devouring_plague = 24 },
}
package.loaded["shared/buff_manager_helper_sylvanas"] = {
    get_all_debuffs = function() return {} end,
}
package.loaded["shared/cooldown_planner_sylvanas"] = {
    is_major_offensive_cd_active = function() return false end,
}
package.loaded["shared/snapshot_sylvanas"] = {
    should_upgrade = function() return true end,
}
package.loaded["shared/active_fight_tracker_sylvanas"] = {
    get_active_fights = function() return {} end,
    find_undotted_target = function() return nil end,
}
package.loaded["shared/ts_helper_sylvanas"] = nil
package.loaded["shared/aoe_hit_volume_sylvanas"] = { install = function() end }
-- Mock only the documented spell-helper surface needed by the optional
-- outgoing-damage estimate; the production module remains optional.
local mock_mind_blast_damage = 600
package.loaded["common/utility/spell_helper"] = {
    get_spell_damage = function(_, spell_id)
        if type(spell_id) == "number" then return mock_mind_blast_damage end
        return 0
    end,
}

-- Mock the platform's target-aware damage speculator. Production resolves it
-- through the engine facades the gate must use: NS.health_prediction (published
-- by main_sylvanas) and NS.GetAPIModule (published by core_sylvanas).
local mock_speculation_factor = 1    -- simulated "damage taken / tooltip" ratio
local mock_speculation_result = nil  -- when set, the speculator's literal answer
local mock_speculation_args = nil    -- last call arguments, for wiring assertions
local mock_health_prediction = {
    speculate_spell_damage = function(_, caster, target, damage, spell_id)
        mock_speculation_args = { caster = caster, target = target, damage = damage, spell_id = spell_id }
        if mock_speculation_result ~= nil then return mock_speculation_result end
        if type(damage) ~= "number" or damage <= 0 then return damage end
        return damage * mock_speculation_factor
    end,
}
NS.health_prediction = mock_health_prediction
NS.GetAPIModule = function(name)
    if name == "health_prediction" then return mock_health_prediction end
    return nil
end

-- Load the real DSL engine and cache it so the spec file's require() picks it up
package.loaded["shared/strategy_dsl_sylvanas"] = dofile("EaxRotations/shared/strategy_dsl_sylvanas.lua")

-- Load the shadow priest spec
local shadow = dofile("EaxRotations/classes/priest/shadow_sylvanas.lua")
local strategies = shadow.strategies

-- ============================================================================
-- Priority order verification (32 strategies)
-- ============================================================================
local expected_order = {
    "PowerWordFortitude", "PreCombatPull", "Shadowform", "SWDCCBreak",
    "Shadowfiend", "VampiricTouch", "ShadowWordPain", "MovingSWP",
    "VampiricEmbrace", "DevouringPlague", "InnerFocusMindBlast", "MindBlast",
    "Starshards", "ShadowWordDeath", "MindFlay", "PsychicScream",
    "Fade", "Healthstone", "DispelMagic", "ShackleUndead",
    "SWPSpread", "VTSpread", "MultiDotSWP", "MultiDotVT",
    "InnerFire", "PowerWordShield", "FlashHeal", "HolyNovaAoE",
    "ManaEmergencyWand", "RacialBerserking", "RacialBloodFury", "RacialArcaneTorrent",
}
assert_true(#strategies == #expected_order, "strategy count matches (" .. #strategies .. " vs " .. #expected_order .. ")")
for i = 1, math.min(#strategies, #expected_order) do
    assert_true(strategies[i].name == expected_order[i],
        string.format("priority[%d] = %s (expected %s)", i, strategies[i].name or "?", expected_order[i]))
end

-- DSL position checks â verify the 6 DSL-converted strategies are at expected indices
local dsl_indices = {}
for i = 1, #strategies do dsl_indices[strategies[i].name] = i end
assert_true(dsl_indices["Shadowform"] == 3, "Shadowform at index 3")
assert_true(dsl_indices["VampiricTouch"] == 6, "VampiricTouch at index 6")
assert_true(dsl_indices["ShadowWordPain"] == 7, "ShadowWordPain at index 7")
assert_true(dsl_indices["MindBlast"] == 12, "MindBlast at index 12")
assert_true(dsl_indices["ShadowWordDeath"] == 14, "ShadowWordDeath at index 14")
assert_true(dsl_indices["InnerFire"] == 25, "InnerFire at index 25")

-- ============================================================================
-- Mock context + state helpers
-- ============================================================================
local function make_ctx(overrides)
    local ctx = {
        me = NS.PLAYER_UNIT,
        target = { is_valid = function() return true end, is_dead = function() return false end,
                   is_casting = function() return false end, get_health = function() return 1000 end,
                   get_health_percentage = function() return 100 end,
                   get_creature_type = function() return nil end, get_guid = function() return "target" end,
                   get_target = function() return NS.PLAYER_UNIT end },
        in_combat = true,
        hp = 100,
        mana_pct = 80,
        settings = { use_cooldowns = true, shadow_use_inner_fire = true, shadow_swd_cc_break = true },
        has_valid_enemy_target = true,
        is_pvp = false,
        is_moving = false,
        is_casting = false,
        is_channeling = false,
        combat_time = 50,
        ttd = 999,
        ttd_known = false,
        target_hp_pct = 100,
        target_hp = 100,
    }
    for k, v in pairs(overrides or {}) do ctx[k] = v end
    return ctx
end

local function make_state(overrides)
    local s = {
        has_shadowform = true,
        shadowform_known = true,
        vampiric_touch_known = true,
        swp_known = true,
        vt_remaining = 0,
        swp_remaining = 0,
        dp_remaining = 0,
        ve_remaining = 0,
        mb_ready = true,
        mb_cd_remains = 0,
        swd_ready = true,
        mana_pct = 80,
        mana_low = false,
        mana_emergency = false,
        threat_safe = true,
        swd_safety_hp = 80,
        has_inner_fire = false,
        inner_fire_known = true,
        mf_channeling = false,
        should_clip_mf = true,
        weaving_stacks = 5,
        spell_damage = 1000,
        snapshot_vt_dmg = 0,
        snapshot_swp_dmg = 0,
        snapshot_dp_dmg = 0,
        has_bloodlust = false,
        in_combat = true,
        enemy_count = 1,
        combat_mode = "st",
        target_hp_pct = 100,
        target_health = 1000,
        mind_blast_damage = 600,
    }
    for k, v in pairs(overrides or {}) do s[k] = v end
    return s
end

-- ============================================================================
-- Shadowform: not broken_api, no shadowform buff, spell known
-- ============================================================================
local idx_sf = 3
-- Positive: no shadowform, spell known
assert_true(strategies[idx_sf].matches(make_ctx(), make_state({ has_shadowform = false })),
    "Shadowform matches when no buff + spell known")
-- Negative: already has shadowform
assert_false(strategies[idx_sf].matches(make_ctx(), make_state({ has_shadowform = true })),
    "Shadowform skips when already has buff")
-- Negative: spell not known
assert_false(strategies[idx_sf].matches(make_ctx(), make_state({ has_shadowform = false, shadowform_known = false })),
    "Shadowform skips when spell not known")

-- ============================================================================
-- VampiricTouch: not casting/channeling, can break MF, not moving, valid target,
--                VT remaining <= threshold, not mana emergency, engaged
-- ============================================================================
local idx_vt = 6
-- Positive: all conditions met (no VT active)
assert_true(strategies[idx_vt].matches(make_ctx(), make_state()),
    "VampiricTouch matches when no VT active + in combat + not moving")
-- Negative: currently casting
assert_false(strategies[idx_vt].matches(make_ctx({ is_casting = true }), make_state()),
    "VampiricTouch skips when casting")
-- Negative: channeling Mind Flay (can't break)
assert_false(strategies[idx_vt].matches(make_ctx({ is_channeling = true }), make_state({ mf_channeling = true, should_clip_mf = false })),
    "VampiricTouch skips when channeling MF and can't clip")
-- Negative: moving
assert_false(strategies[idx_vt].matches(make_ctx({ is_moving = true }), make_state()),
    "VampiricTouch skips when moving")
-- Negative: no valid target
assert_false(strategies[idx_vt].matches(make_ctx({ has_valid_enemy_target = false }), make_state()),
    "VampiricTouch skips without valid target")
-- Negative: VT still has plenty of time
assert_false(strategies[idx_vt].matches(make_ctx(), make_state({ vt_remaining = 10 })),
    "VampiricTouch skips when VT remaining > clip threshold")
-- Negative: mana emergency
assert_false(strategies[idx_vt].matches(make_ctx(), make_state({ mana_emergency = true })),
    "VampiricTouch skips during mana emergency")
-- Negative: spell not known (leveling gate)
assert_false(strategies[idx_vt].matches(make_ctx(), make_state({ vampiric_touch_known = false })),
    "VampiricTouch skips when spell not known")

-- ============================================================================
-- ShadowWordPain: not broken_api, can break MF, valid target, not mana emergency,
--                 weaving-aware refresh, snapshot upgrade, TTD gate
-- ============================================================================
local idx_swp = 7
-- Positive: no SW:P active
assert_true(strategies[idx_swp].matches(make_ctx(), make_state({ swp_remaining = 0 })),
    "ShadowWordPain matches when no SW:P active")
-- Positive: SW:P in refresh window
assert_true(strategies[idx_swp].matches(make_ctx(), make_state({ swp_remaining = 1 })),
    "ShadowWordPain matches when SW:P in refresh window")
-- Negative: SW:P has plenty of time
assert_false(strategies[idx_swp].matches(make_ctx(), make_state({ swp_remaining = 10 })),
    "ShadowWordPain skips when SW:P remaining > window")
-- Negative: no valid target
assert_false(strategies[idx_swp].matches(make_ctx({ has_valid_enemy_target = false }), make_state()),
    "ShadowWordPain skips without valid target")
-- Negative: mana emergency
assert_false(strategies[idx_swp].matches(make_ctx(), make_state({ mana_emergency = true })),
    "ShadowWordPain skips during mana emergency")
-- Negative: channeling MF and can't clip
assert_false(strategies[idx_swp].matches(make_ctx(), make_state({ mf_channeling = true, should_clip_mf = false })),
    "ShadowWordPain skips when channeling MF and can't clip")
-- Negative: spell not known (leveling gate)
assert_false(strategies[idx_swp].matches(make_ctx(), make_state({ swp_known = false })),
    "ShadowWordPain skips when spell not known")

-- ============================================================================
-- MindBlast: not casting/channeling, can break MF, not moving, valid target,
--            spell ready, not mana low, threat safe, engaged
-- ============================================================================
local idx_mb = 12
-- Positive: all conditions met. make_state's own defaults ARE the gate's pass
-- case (target_health 1000 vs mind_blast_damage 600), so this assertion also
-- pins "health above the predicted hit"; an explicit { target_health = 1000,
-- mind_blast_damage = 600 } override would re-run the identical predicate on
-- the identical state and prove nothing.
assert_true(strategies[idx_mb].matches(make_ctx(), make_state()),
    "MindBlast matches when ready + not casting + not moving + mana ok + threat safe")
assert_true(strategies[idx_mb].matches(make_ctx(), make_state({ target_health = 600, mind_blast_damage = 600 })),
    "MindBlast matches at the exact predicted-damage boundary")
-- Negative: the same 600-damage hit is clearly excessive at 100 HP
assert_false(strategies[idx_mb].matches(make_ctx(), make_state({ target_health = 100, mind_blast_damage = 600 })),
    "MindBlast skips predictable overkill (100 HP vs 600 damage)")
-- The real builder must also fail open when the optional estimate is absent.
assert_true(strategies[idx_mb].matches(make_ctx(), make_state({ target_health = 100, mind_blast_damage = 0 })),
    "MindBlast matches when damage prediction is unavailable")
assert_true(strategies[idx_mb].matches(make_ctx(), make_state({ target_health = 0 })),
    "MindBlast matches when target health is unavailable")
-- Exercise the production state builder's documented health/damage wiring.
local normal_built_state = shadow.build_state(make_ctx())
assert_true(normal_built_state.target_health == 1000 and normal_built_state.mind_blast_damage == 600,
    "Shadow state reads absolute target health and Mind Blast tooltip damage")
assert_true(strategies[idx_mb].matches(make_ctx(), normal_built_state),
    "MindBlast matches through the builder on a healthy target")
local empty_target_ctx = make_ctx()
empty_target_ctx.target = nil
local empty_target_state = shadow.build_state(empty_target_ctx)
assert_true(empty_target_state.target_health == 0 and empty_target_state.mind_blast_damage == 0,
    "builder handles an empty target without stale prediction data")
local overkill_ctx = make_ctx()
overkill_ctx.target.get_health = function() return 100 end
local overkill_built_state = shadow.build_state(overkill_ctx)
assert_false(strategies[idx_mb].matches(overkill_ctx, overkill_built_state),
    "MindBlast skips builder-derived predictable overkill")
assert_false(strategies[11].matches(overkill_ctx, overkill_built_state),
    "InnerFocusMindBlast does not burn Inner Focus for predictable overkill")

-- Exercise the optional adapter's real builder failure paths.
local missing_health_ctx = make_ctx()
missing_health_ctx.target.get_health = nil
local missing_health_state = shadow.build_state(missing_health_ctx)
assert_true(missing_health_state.target_health == 0 and missing_health_state.mind_blast_damage == 600,
    "builder fails open when target health is unavailable")
local invalid_damage = mock_mind_blast_damage
local previous_get_spell_id = NS.get_spell_id
mock_mind_blast_damage = math.huge
NS.get_spell_id = function() return 10947 end
local invalid_damage_state = shadow.build_state(make_ctx())
assert_true(invalid_damage_state.mind_blast_damage == 0,
    "builder rejects an invalid tooltip damage value after a rank change")
NS.get_spell_id = previous_get_spell_id
mock_mind_blast_damage = invalid_damage

-- A damage cache must not survive an Inner Focus transition. The next Mind
-- Blast can have a different tooltip value immediately after the buff changes.
local previous_buff_up = NS.buff_up
local previous_damage = mock_mind_blast_damage
mock_mind_blast_damage = 1200
NS.buff_up = function(_, ids)
    if ids and ids[1] == 14751 then return true end
    return previous_buff_up and previous_buff_up(_, ids) or false
end
local inner_focus_ctx = make_ctx()
local inner_focus_state = shadow.build_state(inner_focus_ctx)
assert_true(inner_focus_state.has_inner_focus, "state observes Inner Focus activation")
assert_true(inner_focus_state.mind_blast_damage == 1200,
    "damage cache refreshes when Inner Focus changes the tooltip estimate")
NS.buff_up = previous_buff_up
mock_mind_blast_damage = previous_damage

-- ============================================================================
-- Target-aware speculation (common/modules/health_prediction)
-- ============================================================================
-- The gate's estimate is a documented two-stage pipeline: the spell_helper
-- tooltip origin, then the platform's target-aware speculator. A tooltip
-- overestimate must not suppress a Mind Blast the target actually survives.
-- Each fresh context is a distinct unit (unique guid) unless a guid is supplied,
-- so cache behavior under test is explicit rather than incidental.
local low_hp_guid_counter = 0
local function low_hp_ctx(guid)
    low_hp_guid_counter = low_hp_guid_counter + 1
    local ctx = make_ctx()
    ctx.target.get_health = function() return 100 end
    local unit_guid = guid or ("low-hp-unit-" .. low_hp_guid_counter)
    ctx.target.get_guid = function() return unit_guid end
    return ctx
end

local previous_factor = mock_speculation_factor
local previous_result = mock_speculation_result

-- Ratio 1.0: the target takes the full estimate, so behavior is unchanged.
mock_speculation_factor = 1
local unmitigated_state = shadow.build_state(low_hp_ctx())
assert_true(unmitigated_state.target_health == 100 and unmitigated_state.mind_blast_damage == 600,
    "speculation passes an unmitigated estimate through unchanged")
assert_true(mock_speculation_args and mock_speculation_args.spell_id == 8092,
    "speculation receives the resolved Mind Blast spell id")
assert_true(mock_speculation_args and mock_speculation_args.damage == 600,
    "speculation receives the raw tooltip estimate as its damage input")
assert_true(mock_speculation_args and mock_speculation_args.caster == NS.PLAYER_UNIT,
    "speculation receives the local player as caster")
assert_false(strategies[idx_mb].matches(low_hp_ctx(), unmitigated_state),
    "MindBlast still skips overkill when the target takes the full estimate")

-- Ratio 0.1: 600 tooltip damage becomes 60 actually taken, which no longer
-- overkills 100 HP. This is the audit's "tooltip overestimates" regression.
mock_speculation_factor = 0.1
local mitigated_state = shadow.build_state(low_hp_ctx())
assert_true(mitigated_state.mind_blast_damage == 60,
    "speculated damage replaces the raw tooltip estimate")
assert_true(strategies[idx_mb].matches(low_hp_ctx(), mitigated_state),
    "MindBlast is allowed when the speculated hit no longer overkills")
assert_true(strategies[11].matches(low_hp_ctx(), mitigated_state),
    "InnerFocusMindBlast is allowed when the speculated hit no longer overkills")
assert_true(mitigated_state.target_health == 100,
    "speculation leaves the absolute target health untouched")

-- The speculator's own answer must be validated before it is trusted.
mock_speculation_factor = 1
mock_speculation_result = "not a number"
local garbage_state = shadow.build_state(low_hp_ctx())
assert_true(garbage_state.mind_blast_damage == 600,
    "builder falls back to the raw estimate on a non-numeric speculation")
mock_speculation_result = 0
local zero_state = shadow.build_state(low_hp_ctx())
assert_true(zero_state.mind_blast_damage == 600,
    "builder falls back to the raw estimate on a zero speculation")
mock_speculation_result = nil
mock_speculation_factor = 1

-- A missing speculator member must fail open.
local speculator = mock_health_prediction.speculate_spell_damage
mock_health_prediction.speculate_spell_damage = nil
local absent_state = shadow.build_state(low_hp_ctx())
assert_true(absent_state.mind_blast_damage == 600,
    "builder falls back to the raw estimate when the speculator is absent")
mock_health_prediction.speculate_spell_damage = speculator

-- Resolution goes through the engine's facades, with no private require path:
-- NS.health_prediction is preferred and NS.GetAPIModule is the fallback.
mock_speculation_factor = 0.1
local published_damage = shadow.build_state(low_hp_ctx()).mind_blast_damage
assert_true(published_damage == 60,
    "gate resolves the speculator from NS.health_prediction")
local published_module = NS.health_prediction
local api_module_lookup = NS.GetAPIModule
NS.health_prediction = nil
local module_map_damage = shadow.build_state(low_hp_ctx()).mind_blast_damage
assert_true(module_map_damage == 60,
    "gate falls back to the NS.GetAPIModule map for the speculator")
NS.GetAPIModule = nil
local unresolved_damage = shadow.build_state(low_hp_ctx()).mind_blast_damage
assert_true(unresolved_damage == 600,
    "gate fails open to the raw estimate when neither facade resolves the speculator")
-- A private package.loaded entry is not a resolution path any more.
package.loaded["common/modules/health_prediction"] = mock_health_prediction
local private_only_damage = shadow.build_state(low_hp_ctx()).mind_blast_damage
assert_true(private_only_damage == 600,
    "gate does not resolve the speculator through a private require path")
package.loaded["common/modules/health_prediction"] = nil
NS.health_prediction = published_module
NS.GetAPIModule = api_module_lookup

-- The estimate is keyed by the unit's stable identity, not by the wrapper table:
-- a fresh wrapper for the same unit guid reuses the cached estimate, while a
-- different unit recomputes. Capture each value before the next build; the
-- returned state is a live proxy over the shared raw state table.
mock_speculation_factor = 1
local recycled_first = shadow.build_state(low_hp_ctx("recycled-unit")).mind_blast_damage
mock_speculation_factor = 0.5
local recycled_second = shadow.build_state(low_hp_ctx("recycled-unit")).mind_blast_damage
-- Pinned on VALUES, not on a speculator call count: under the 0.5 factor a
-- cache miss would return 300, so 600 both times proves the same unit guid
-- reused the first estimate. That keeps the observable contract and lets the
-- cache's internal shape (or how many platform reads it costs) change without
-- a false red here.
assert_true(recycled_first == 600 and recycled_second == 600,
    "a fresh wrapper for the same unit guid reuses the cached estimate")
local other_unit_damage = shadow.build_state(low_hp_ctx()).mind_blast_damage
assert_true(other_unit_damage == 300,
    "a different unit guid does not reuse the cached estimate")

-- Direct helper checks: caster resolution has exactly one path and fails open.
local _gate_ok, MindBlastGate = pcall(require, "classes/priest/helpers/shadow_mind_blast_gate_sylvanas")
assert_true(_gate_ok and type(MindBlastGate.read_target_prediction) == "function",
    "the prediction gate helper is require-able")
mock_speculation_factor = 0.1
local no_caster_ns = setmetatable({ GetPlayer = function() return nil end }, { __index = NS })
local _, no_caster_damage = MindBlastGate.read_target_prediction(no_caster_ns, 8092, make_ctx().target, false)
assert_true(no_caster_damage == 600,
    "gate fails open to the raw estimate when no caster can be resolved")
-- NS.me is never assigned in production, so it must not be a fallback: the module
-- resolves here, only the caster does not.
local me_only_ns = { GetPlayer = false, me = function() return NS.PLAYER_UNIT end,
                     get_spell_id = function() return 8092 end,
                     health_prediction = mock_health_prediction }
local _, me_only_damage = MindBlastGate.read_target_prediction(me_only_ns, 8092, make_ctx().target, false)
assert_true(me_only_damage == 600,
    "gate does not fall back to NS.me for caster resolution")

mock_speculation_factor = previous_factor
mock_speculation_result = previous_result

-- ============================================================================
-- Inner Focus lane: the estimate stays non-crit (documented limitation)
-- ============================================================================
-- No documented API exposes a crit chance, a crit damage multiplier, or a
-- guaranteed-crit flag (grep of .api/ finds only spell_attributes.CANT_CRIT, the
-- CRITTER creature type, and crit *rating* inputs). health_prediction also takes
-- the damage to speculate on as an *input*, so applying our own crit multiplier
-- could double-count a factor the platform may already fold in. The gate therefore
-- compares the non-crit estimate on the Inner Focus lane too. These assertions pin
-- that behavior so a future change, or a new platform crit signal, cannot alter it
-- silently.
local restore_mind_blast_damage = mock_mind_blast_damage
local previous_inner_focus_buff_up = NS.buff_up
NS.buff_up = function(_, ids)
    if ids and ids[1] == 14751 then return true end
    return previous_inner_focus_buff_up and previous_inner_focus_buff_up(_, ids) or false
end

-- Inner Focus guarantees a crit but does not change the tooltip or the speculated
-- number: the buff's only effect on the gate is the cache-key refresh.
mock_speculation_factor = 1
mock_mind_blast_damage = 80
local inner_focus_small = shadow.build_state(low_hp_ctx())
assert_true(inner_focus_small.has_inner_focus == true, "Inner Focus is observed on the state")
assert_true(inner_focus_small.mind_blast_damage == 80,
    "Inner Focus does not scale the estimate (no documented crit multiplier)")

-- A genuinely small Inner Focus hit must still fire.
assert_true(strategies[idx_mb].matches(make_ctx(), inner_focus_small),
    "a small Inner Focus Mind Blast still fires")
assert_false(strategies[11].matches(make_ctx(), inner_focus_small),
    "InnerFocusMindBlast does not re-fire while Inner Focus is already active")

-- Known limitation, pinned: when only the crit would overkill, the non-crit
-- estimate still clears the target's health and the cast is allowed, because no
-- documented API supplies a crit multiplier to compare against.
local inner_focus_crit_ctx = low_hp_ctx()
local inner_focus_crit_state = shadow.build_state(inner_focus_crit_ctx)
assert_true(inner_focus_crit_state.target_health == 100 and inner_focus_crit_state.mind_blast_damage == 80,
    "Inner Focus crit case compares the non-crit estimate against target health")
assert_true(strategies[idx_mb].matches(inner_focus_crit_ctx, inner_focus_crit_state),
    "gate allows the cast when only the crit would overkill (documented limitation)")

-- The non-crit lane is unchanged.
NS.buff_up = previous_inner_focus_buff_up
mock_mind_blast_damage = 600
local non_crit_overkill_ctx = low_hp_ctx()
local non_crit_overkill_state = shadow.build_state(non_crit_overkill_ctx)
assert_false(strategies[idx_mb].matches(non_crit_overkill_ctx, non_crit_overkill_state),
    "non-crit lane still skips predictable overkill")
mock_mind_blast_damage = 80
local non_crit_small_ctx = low_hp_ctx()
local non_crit_small_state = shadow.build_state(non_crit_small_ctx)
assert_true(strategies[idx_mb].matches(non_crit_small_ctx, non_crit_small_state),
    "non-crit lane still fires a Mind Blast that does not overkill")
mock_mind_blast_damage = restore_mind_blast_damage

-- Negative: casting
assert_false(strategies[idx_mb].matches(make_ctx({ is_casting = true }), make_state()),
    "MindBlast skips when casting")
-- Negative: moving
assert_false(strategies[idx_mb].matches(make_ctx({ is_moving = true }), make_state()),
    "MindBlast skips when moving")
-- Negative: not ready
assert_false(strategies[idx_mb].matches(make_ctx(), make_state({ mb_ready = false })),
    "MindBlast skips when not ready")
-- Negative: mana low
assert_false(strategies[idx_mb].matches(make_ctx(), make_state({ mana_low = true })),
    "MindBlast skips when mana low")
-- Negative: threat unsafe
assert_false(strategies[idx_mb].matches(make_ctx(), make_state({ threat_safe = false })),
    "MindBlast skips when threat unsafe")
-- Negative: no valid target
assert_false(strategies[idx_mb].matches(make_ctx({ has_valid_enemy_target = false }), make_state()),
    "MindBlast skips without valid target")
-- Negative: channeling MF and can't clip
assert_false(strategies[idx_mb].matches(make_ctx(), make_state({ mf_channeling = true, should_clip_mf = false })),
    "MindBlast skips when channeling MF and can't clip")

-- ============================================================================
-- ShadowWordDeath: can break MF, valid target, spell ready, TTD gate,
--                  not mana emergency, threat safe, safety HP check, engaged
-- ============================================================================
local idx_swd = 14
-- Positive: all conditions met
assert_true(strategies[idx_swd].matches(make_ctx(), make_state()),
    "ShadowWordDeath matches when ready + threat safe + HP ok")
-- Positive: execute range (target HP <= 25%, safety floor lowered to 60)
assert_true(strategies[idx_swd].matches(make_ctx({ target_hp_pct = 20, hp = 65 }), make_state({ target_hp_pct = 20 })),
    "ShadowWordDeath matches in execute range with lowered safety floor")
-- Negative: not ready
assert_false(strategies[idx_swd].matches(make_ctx(), make_state({ swd_ready = false })),
    "ShadowWordDeath skips when not ready")
-- Negative: no valid target
assert_false(strategies[idx_swd].matches(make_ctx({ has_valid_enemy_target = false }), make_state()),
    "ShadowWordDeath skips without valid target")
-- Negative: mana emergency
assert_false(strategies[idx_swd].matches(make_ctx(), make_state({ mana_emergency = true })),
    "ShadowWordDeath skips during mana emergency")
-- Negative: threat unsafe
assert_false(strategies[idx_swd].matches(make_ctx(), make_state({ threat_safe = false })),
    "ShadowWordDeath skips when threat unsafe")
-- Negative: player HP below safety floor
assert_false(strategies[idx_swd].matches(make_ctx({ hp = 50 }), make_state()),
    "ShadowWordDeath skips when player HP below safety floor")
-- Negative: channeling MF and can't clip
assert_false(strategies[idx_swd].matches(make_ctx(), make_state({ mf_channeling = true, should_clip_mf = false })),
    "ShadowWordDeath skips when channeling MF and can't clip")

-- ============================================================================
-- InnerFire: spell known, not broken_api, no buff, setting enabled, not in combat
-- ============================================================================
local idx_if = 25
-- Positive: OOC, no inner fire, spell known, setting on
assert_true(strategies[idx_if].matches(make_ctx({ in_combat = false }), make_state()),
    "InnerFire matches when OOC + no buff + spell known + setting on")
-- Negative: already has inner fire
assert_false(strategies[idx_if].matches(make_ctx({ in_combat = false }), make_state({ has_inner_fire = true })),
    "InnerFire skips when already has buff")
-- Negative: in combat
assert_false(strategies[idx_if].matches(make_ctx({ in_combat = true }), make_state()),
    "InnerFire skips when in combat")
-- Negative: spell not known
assert_false(strategies[idx_if].matches(make_ctx({ in_combat = false }), make_state({ inner_fire_known = false })),
    "InnerFire skips when spell not known")
-- Negative: setting disabled
assert_false(strategies[idx_if].matches(make_ctx({ in_combat = false, settings = { shadow_use_inner_fire = false } }), make_state()),
    "InnerFire skips when setting disabled")

-- ============================================================================
-- Summary
-- ============================================================================
print(string.format("test_shadow_dsl_priority: %d passed, %d failed", _pass, _fail))
if _fail > 0 then
    os.exit(1)
end
print("PASS test_shadow_dsl_priority")
