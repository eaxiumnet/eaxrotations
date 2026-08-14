-- test_priest_dps_live_fixes.lua — regression tests for the 2026-08-12 live-correctness
-- audit fixes in priest shadow + smite (+ shared/mf_tick_compute_sylvanas).
-- WHAT:  pins (1) should_clip_mf's optional 8th swp_clip_threshold param and
--        shadow's wiring of the shadow_swp_refresh_window setting into the MF
--        clip gate, (2) the 1s-per-debuff-set throttle on _find_multidot_target,
--        (3) smite build_state nil-player guard, (4) smite threat gate passing
--        context into NS.is_threat_safe (MindBlast/SWD actually threat-gated),
--        (5) 2/2-talent Surge of Light proc aura (33154) in the SoL buff list,
--        (6) ShackleUndead restricted to Undead (creature type 6), (7) the
--        Healthstone action reporting executed=true when the item is used.
-- SAFETY: standalone — mocks _G.EaxRotations only; real shared/ modules used;
--         no game API calls. Not registered in any runner.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(got, want, label)
    if got ~= want then
        error((label or "assert_eq failed") .. ": got " .. tostring(got) .. ", want " .. tostring(want), 2)
    end
end

package.loaded["common/enums"] = { class_id = { PRIEST = 5 } }
-- Mock inventory helper so smite's first_ready_item() finds a healthstone.
package.loaded["common/utility/inventory_helper"] = { has_item = function() return true end }

-- ============================================================================
-- Part 1: should_clip_mf — optional 8th swp_clip_threshold param (real module)
-- ============================================================================
local mf_tick = dofile("EaxRotations/shared/mf_tick_compute_sylvanas.lua")

-- 7-arg backward compat: swp window defaults to 0.7
assert_true(mf_tick.should_clip_mf(true, 2, 1.5, false, false, 5, 0.5),
    "7-arg: swp_remaining 0.5 < default 0.7 → clip")
assert_false(mf_tick.should_clip_mf(true, 2, 1.5, false, false, 5, 0.8),
    "7-arg: swp_remaining 0.8 >= default 0.7 → no clip")
-- 8-arg: configured threshold overrides the default
assert_false(mf_tick.should_clip_mf(true, 2, 1.5, false, false, 5, 0.5, 0.3),
    "8-arg: configured 0.3, swp_remaining 0.5 → no clip")
assert_true(mf_tick.should_clip_mf(true, 2, 1.5, false, false, 5, 0.5, 0.9),
    "8-arg: configured 0.9, swp_remaining 0.5 → clip")
-- Other clip legs unchanged
assert_true(mf_tick.should_clip_mf(true, 2, 1.5, true, false, 5, 5, 0.1),
    "8-arg: mb_ready still clips regardless of swp threshold")
assert_true(mf_tick.should_clip_mf(true, 2, 1.5, false, true, 5, 5, 0.1),
    "8-arg: swd_ready still clips regardless of swp threshold")
assert_true(mf_tick.should_clip_mf(true, 2, 1.5, false, false, 1.0, 5, 0.1),
    "8-arg: vt_remaining < vt threshold still clips")
assert_false(mf_tick.should_clip_mf(false, 2, 1.5, false, false, 0.5, 0.5),
    "not channeling → no clip")
assert_false(mf_tick.should_clip_mf(true, 3, 1.5, false, false, 0.5, 0.5),
    "3 ticks → no clip")

-- ============================================================================
-- Shared mock NS for the spec loads
-- ============================================================================
local _mock_now = 100.0
local _surge_aura = nil            -- which SoL proc aura is currently active
local scan_count = 0               -- GetEnemiesInRange call counter (throttle probe)
local threat_arg = nil
local used_hs_id = nil
local mf_recorded8 = nil

local me_unit = {
    get_class = function() return 5 end,
    get_race_id = function() return 1 end,
    is_mounted = function() return false end,
    is_moving = function() return false end,
    mana_pct = function() return 100 end,
    is_valid = function() return true end,
    is_in_combat = function() return true end,
    get_guid = function() return "me" end,
    get_target = function() return me_unit end,
    is_casting = function() return false end,
    is_channeling = function() return false end,
}
local target_unit = {
    is_valid = function() return true end,
    is_in_combat = function() return true end,
    get_guid = function() return "t1" end,
    get_target = function() return me_unit end,
}
local function make_enemy(has_swp, has_vt)
    return {
        _has_swp = has_swp, _has_vt = has_vt,
        is_valid = function() return true end,
        is_in_combat = function() return true end,
    }
end
local enemies = { make_enemy(true, true), make_enemy(false, false) }

local SWP_FIRST_ID, VT_FIRST_ID = 25368, 34917

local NS = {}
_G.EaxRotations = NS

NS.CLASS_ID = { PRIEST = 5 }
NS.PLAYER_UNIT = me_unit
NS.PriestSpells = {
    ArcaneTorrent = 25046, Berserking = 26297, BloodFury = 33697,
    DevouringPlague = 2944, DispelMagic = 527, Fade = 586,
    FlashHeal = 2061, HolyFire = 14914, HolyNova = 15237, InnerFire = 588,
    InnerFocus = 14751, MindBlast = 8092, MindFlay = 15407,
    PowerInfusion = 10060, PowerWordFortitude = 1243, PowerWordShield = 17,
    PsychicScream = 8122, Renew = 139, ShackleUndead = 9484,
    ShadowWordDeath = 32379, ShadowWordPain = 589, Shadowfiend = 34433,
    Shadowform = 15473, Smite = 585, Starshards = 10797,
    VampiricEmbrace = 15286, VampiricTouch = 34914,
}
NS.OffensiveDispelDB = {
    is_breakable_cc_active = function() return false, nil end,
    is_casting_preemptive_cc = function() return false, nil end,
}
NS.GetPlayer = function() return me_unit end
NS.GetTarget = function() return nil end
NS.game_time_ms = function() return _mock_now * 1000 end
NS.time_now = function() return _mock_now end
NS.buff_up = function(unit, ids)
    if _surge_aura and type(ids) == "table" then
        for _, id in ipairs(ids) do
            if id == _surge_aura then return true end
        end
    end
    return false
end
NS.debuff_up = function(unit, ids)
    local key = (ids and ids[1] == SWP_FIRST_ID) and "_has_swp" or "_has_vt"
    return unit and unit[key] == true or false
end
NS.debuff_remains = function() return 0 end
NS.spell_ready = function() return true end
NS.spell_exists = function() return true end
NS.cooldown_remains = function() return 0 end
NS.unit_mana_pct = function() return 100 end
NS.unit_health_pct = function() return 100 end
NS.get_debuff_stacks = function() return 0 end
NS.is_item_ready = function() return false end
NS.is_threat_safe = function(context)
    threat_arg = context
    return not (context and context.has_aggro)
end
NS.is_spell_in_range = function() return true end
NS.same_unit = function(a, b) return a == b end
NS.unit_creature_type = function() return nil end
NS.GetEnemiesInRange = function()
    scan_count = scan_count + 1
    return enemies
end
NS.aoe_self_meets = function() return false end
NS.AOE_RADIUS = { SELF_10 = 10 }
NS.try_cast = function() return true end
NS.use_item_by_id = function(id, unit)
    used_hs_id = id
    return true
end
NS.is_auto_attacking = function() return false end
NS.start_auto_attack = function() return true end
NS.stop_casting = function() end
NS.cancel_current_cast = function() end
NS.rotation_registry = { register = function() end }
NS.log = function() end
NS.log_warning = function() end
NS.import_helpers = function()
    return function() return true end,   -- try_cast
           function() return true end,   -- spell_exists
           function() return true end,   -- spell_ready
           function() return 0 end,      -- debuff_remains
           function(unit, ids)           -- buff_up
               if _surge_aura and type(ids) == "table" then
                   for _, id in ipairs(ids) do
                       if id == _surge_aura then return true end
                   end
               end
               return false
           end,
           function() return 0 end,      -- buff_remains
           function() return 100 end,    -- health_pct
           function() return false end   -- player_control_locked
end

-- Recording mock for mf_tick_compute: verifies shadow passes the configured
-- swp clip threshold as the 8th argument of should_clip_mf.
package.loaded["shared/mf_tick_compute_sylvanas"] = {
    compute_channel_state = function() return true, 2 end,
    should_clip_mf = function(a, b, c, d, e, f, g, h)
        mf_recorded8 = h
        return true
    end,
}
-- Pin the optional/backup modules to inert stubs so the multidot picker and
-- state builder take the deterministic legacy path (the real modules would
-- enumerate via their own API paths and skew the throttle probe below).
-- NOTE: package.loaded[mod] = false does NOT prevent loading in Lua 5.1
-- (require treats falsy entries as "not loaded"); an empty table is required.
-- Modules whose members are called without an `and` guard get functional stubs.
package.loaded["shared/ts_helper_sylvanas"] = {}
package.loaded["shared/active_fight_tracker_sylvanas"] = {}
package.loaded["shared/cooldown_planner_sylvanas"] = {
    is_major_offensive_cd_active = function() return false end,
}
package.loaded["shared/snapshot_sylvanas"] = {
    should_upgrade = function() return false end,
}
package.loaded["shared/aoe_hit_volume_sylvanas"] = {}
package.loaded["common/izi_sdk"] = {}

-- ============================================================================
-- Part 2: shadow — build_state passes shadow_swp_refresh_window into the MF clip
-- ============================================================================
local shadow_mod = dofile("EaxRotations/classes/priest/shadow_sylvanas.lua")
assert_true(type(shadow_mod) == "table" and type(shadow_mod.build_state) == "function",
    "shadow module should load and expose build_state")

local shadow_ctx = {
    target = target_unit,
    me = me_unit,
    has_valid_enemy_target = true,
    in_combat = true,
    enemy_count = 3,
    mana_pct = 100,
    hp = 100,
    is_group = false,
    spell_damage = 0,
    settings = { shadow_swp_refresh_window = 0.4 },
}
local shadow_state = shadow_mod.build_state(shadow_ctx)
assert_eq(mf_recorded8, 0.4,
    "shadow build_state must pass swp_clip_threshold(context)=0.4 as should_clip_mf 8th arg")
assert_eq(mf_recorded8 ~= 0.7, true,
    "the 8th arg must carry the configured threshold, not the hardcoded 0.7 default")
assert_true(shadow_state.should_clip_mf == true, "shadow clip state should reflect the mock")

-- ============================================================================
-- Part 3: shadow — _find_multidot_target 1s-per-debuff-set throttle
-- ============================================================================
local function find_strategy(strategies, name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name, 2)
end

local spread_ctx = {
    target = target_unit,
    me = me_unit,
    in_combat = true,
    has_valid_enemy_target = true,
    target_hp = 100,
}
local spread_state = {
    swp_known = true,
    vampiric_touch_known = true,
    combat_mode = "cleave",
    enemy_count = 3,
    swp_refresh_window = 3,
    vt_refresh_window = 3,
    spell_damage = 0,
    snapshot_swp_dmg = 0,
    snapshot_vt_dmg = 0,
    swp_remaining = 0,
    vt_remaining = 0,
    mana_emergency = false,
}

local swp_spread = find_strategy(shadow_mod.strategies, "SWPSpread")
local vt_spread = find_strategy(shadow_mod.strategies, "VTSpread")

scan_count = 0
_mock_now = 200.0
assert_true(swp_spread.matches(spread_ctx, spread_state), "SWP spread should match on first pick")
assert_eq(scan_count, 1, "first pick must enumerate enemies once")
assert_true(swp_spread.matches(spread_ctx, spread_state), "SWP spread repeat within TTL still matches")
assert_eq(scan_count, 1, "repeat within the 1s TTL must NOT re-enumerate")
_mock_now = 201.5
assert_true(swp_spread.matches(spread_ctx, spread_state), "SWP spread should re-pick after TTL")
assert_eq(scan_count, 2, "after the 1s TTL the picker must re-enumerate")
-- VT uses a different debuff set: it must not be starved by a fresh SWP pick
assert_true(vt_spread.matches(spread_ctx, spread_state), "VT spread should match (per-set throttle)")
assert_eq(scan_count, 3, "VT pick enumerates independently of the SWP pick")
assert_true(vt_spread.matches(spread_ctx, spread_state), "VT spread repeat within TTL still matches")
assert_eq(scan_count, 3, "VT repeat within the 1s TTL must NOT re-enumerate")

-- ============================================================================
-- Part 4: smite — nil player guard, threat context, SoL 2/2, shackle, healthstone
-- ============================================================================
local smite_mod = dofile("EaxRotations/classes/priest/smite_sylvanas.lua")
assert_true(type(smite_mod) == "table" and type(smite_mod.build_state) == "function",
    "smite module should load and expose build_state")

-- 4a. nil player guard: build_state must not crash and must return schema defaults
local saved_get_player = NS.GetPlayer
NS.GetPlayer = function() return nil end
local nil_state = smite_mod.build_state({ settings = {} })
assert_true(type(nil_state) == "table", "smite build_state with nil player must return state, not crash")
assert_eq(nil_state.mana_pct, 100, "nil-player state must fall back to schema default mana_pct")
NS.GetPlayer = saved_get_player

-- 4b. threat gate: NS.is_threat_safe receives context, so MindBlast is gated on has_aggro
local smite_ctx = {
    target = target_unit,
    me = me_unit,
    in_combat = true,
    is_moving = false,
    has_valid_enemy_target = true,
    target_phys_immune = false,
    player_control_locked = false,
    mana_pct = 100,
    hp = 100,
    is_group = false,
    has_aggro = true,
    settings = {},
}
local threat_state = smite_mod.build_state(smite_ctx)
assert_eq(threat_arg, smite_ctx, "smite build_state must pass context into NS.is_threat_safe")
assert_false(threat_state.threat_safe, "has_aggro=true must make threat_safe=false (gate live)")
local mb = find_strategy(smite_mod.strategies, "MindBlast")
assert_false(mb.matches(smite_ctx, threat_state), "MindBlast must be threat-gated when holding aggro")

smite_ctx.has_aggro = false
local safe_state2 = smite_mod.build_state(smite_ctx)
assert_true(safe_state2.threat_safe, "no aggro → threat_safe=true")
assert_true(mb.matches(smite_ctx, safe_state2), "MindBlast must fire when threat-safe")

-- 4c. Surge of Light: both 1/2 (33151) and 2/2 (33154) proc auras must trigger
--     the instant-Smite lane (2/2 talent proc previously missed the single-ID list)
_surge_aura = 33154
local sol_state = smite_mod.build_state(smite_ctx)
assert_true(sol_state.surge_of_light, "2/2 Surge of Light proc (33154) must be detected")
local sol = find_strategy(smite_mod.strategies, "SurgeOfLightSmite")
assert_true(sol.matches(smite_ctx, sol_state), "SurgeOfLightSmite must match on the 2/2 proc")
_surge_aura = 33151
local sol_state1 = smite_mod.build_state(smite_ctx)
assert_true(sol_state1.surge_of_light, "1/2 Surge of Light proc (33151) must still be detected")
_surge_aura = nil
assert_false(smite_mod.build_state(smite_ctx).surge_of_light, "no SoL proc → surge off")

-- 4d. ShackleUndead: Undead (6) only — Demon (3) must not shackle
local shackle = find_strategy(smite_mod.strategies, "ShackleUndead")
assert_false(shackle.matches(smite_ctx, { target_creature_type = 3, shackle_undead_ready = true }),
    "ShackleUndead must NOT target Demons (creature type 3)")
assert_true(shackle.matches(smite_ctx, { target_creature_type = 6, shackle_undead_ready = true }),
    "ShackleUndead must target Undead (creature type 6)")

-- 4e. Healthstone action reports executed=true when the item is actually used
local hs = find_strategy(smite_mod.strategies, "Healthstone")
used_hs_id = nil
local hs_executed = hs.execute(smite_ctx, { healthstone_ready = 22105 })
assert_eq(used_hs_id, 22105, "Healthstone execute must call use_item_by_id with the found stone")
assert_true(hs_executed == true, "Healthstone execute must return true when the item is used")

print("PASS test_priest_dps_live_fixes")
