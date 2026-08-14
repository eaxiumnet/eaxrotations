-- test_hunter_vanilla_live_fixes.lua — Hunter vanilla live-fix regression coverage.
-- WHAT:  Pins the Wave 1.3 hunter vanilla gates: survival/MM LevelingArcaneShot
--        leveling-gate, MultiShot in_combat/enemy gates, FeignDeath threat gate,
--        ViperSting target/combat/mana gates, and leveling state.in_melee wiring.
-- WHEN:  Standalone (lua EaxRotations/tests/test_hunter_vanilla_live_fixes.lua);
--        registered in run_rotation_tests.lua (Wave 1.5 close-out).
-- WHY:   The audit wave flagged OOC/single-target/gated-lane defects that were
--        fixed in the 2026-08-13 wave; these asserts pin the fixed contract.
-- SAFETY: Pure unit tests with mocked NS + stubbed shared modules; no live game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

-- Faithful safe_state stub (spec_kit:217 semantics): schema-defaulted reads.
local function safe_state(raw_state, schema)
    raw_state = raw_state or {}
    return setmetatable({}, {
        __index = function(_, key)
            if raw_state[key] ~= nil then return raw_state[key] end
            local d = schema and schema[key]
            if d ~= nil then return d end
            return nil
        end,
        __newindex = function(_, key, value) raw_state[key] = value end,
        __pairs = function(_) return pairs(raw_state) end,
    })
end

package.loaded["shared/spec_kit_sylvanas"] = {
    safe_state = safe_state,
    setting = function(context, key, default)
        local s = context and context.settings
        if s and s[key] ~= nil then return s[key] end
        return default
    end,
    setting_bool = function(context, key, default) return (context and context.settings and context.settings[key]) or default end,
    setting_number = function(context, key, default)
        local v = context and context.settings and context.settings[key]
        return (type(v) == "number") and v or default
    end,
}
package.loaded["shared/potion_helper_sylvanas"] = {
    try_use_potion = function() return false end,
    HEALTH_POTION_IDS = {}, MANA_POTION_IDS = {},
}
package.loaded["shared/pet_manager_sylvanas"] = {
    set_defensive = function() return true end,
    set_passive = function() return true end,
    set_aggressive = function() return true end,
}
package.loaded["shared/hunter_core_sylvanas"] = {
    should_feign_death = function(threat_level, fd_mode)
        if fd_mode == "off" or not fd_mode then return false end
        if fd_mode == "high_threat" and threat_level >= 2 then return true end
        if fd_mode == "aggro_only" and threat_level >= 3 then return true end
        return false
    end,
}
package.loaded["shared/leveling_sylvanas"] = {
    create_context_guard = function() return function() return true end end,
    build_common_state = function(context, st)
        st.in_combat = context.in_combat or false
        st.mana_pct = context.mana_pct or 100
        st.hp = context.hp or 100
        st.enemies = context.enemies or context.enemies_count or 0
        st.target = context.target or nil
        st.is_moving = context.is_moving or false
        st.pet = context.pet or nil
    end,
}

local registrations = {}
_G.EaxRotations = {
    HunterSpells = {
        AimedShot = 19434, ArcaneShot = 3044, AspectOfTheHawk = 13165,
        AspectOfTheCheetah = 5118, CallPet = 883, ConcussiveShot = 5116,
        ExplosiveTrap = 8294, FeignDeath = 5384, FreezingTrap = 1499,
        HuntersMark = 1430, MendPet = 136, MongooseBite = 1495,
        MultiShot = 2643, RapidFire = 3045, RaptorStrike = 2973,
        RevivePet = 982, ScareBeast = 1513, ScorpidSting = 3043,
        SerpentSting = 1978, ViperSting = 3034, Volley = 1510, WingClip = 2974,
        PetAggressive = 1742, PetDefensive = 1742, PetPassive = 1742,
    },
    PLAYER_UNIT = {},
    GetPlayer = function() return {} end,
    GetPet = function() return nil end,
    spell_action = function(ids) return type(ids) == "table" and ids[1] or ids end,
    spell_ready = function() return true end,
    try_cast = function() return true end,
    buff_up = function() return false end,
    debuff_up = function() return false end,
    debuff_remains = function() return 0 end,
    unit_mana_pct = function() return 100 end,
    time_now = function() return 0 end,
    log = function() end,
    rotation_registry = {
        register = function(_, name, strategies, opts) registrations[name] = opts end,
    },
    should_use_long_cd = function() return true end,
    HunterClipTracker = {
        ms_until_auto = function() return 0 end,
        record_manual_shot = function() end,
    },
}

local function find(strategies, name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local function get_state(spec_key)
    local reg = registrations[spec_key]
    assert_true(reg and reg.get_state, "registered get_state for " .. spec_key)
    return reg.get_state
end

-- ============================================================================
-- survival_vanilla.lua
-- ============================================================================
local sv = dofile("EaxRotations/classes/hunter/survival_vanilla.lua")
if type(sv) == "table" and sv.strategies then sv = sv.strategies end
assert_true(type(sv) == "table" and #sv > 0, "survival strategies load")

-- LevelingArcaneShot: leveling gate + in_combat + mana floor.
local sv_las = find(sv, "LevelingArcaneShot")
assert_false(sv_las.matches({}, { pre_steady_leveling = false, in_combat = true, arcane_shot_ready = true, mana_pct = 80 }),
    "survival LevelingArcaneShot must not fire when Aimed lane is active")
assert_false(sv_las.matches({}, { pre_steady_leveling = true, in_combat = false, arcane_shot_ready = true, mana_pct = 80 }),
    "survival LevelingArcaneShot must not fire OOC")
assert_false(sv_las.matches({}, { pre_steady_leveling = true, in_combat = true, arcane_shot_ready = true, mana_pct = 5 }),
    "survival LevelingArcaneShot must respect the mana floor")
assert_true(sv_las.matches({}, { pre_steady_leveling = true, in_combat = true, arcane_shot_ready = true, mana_pct = 80 }),
    "survival LevelingArcaneShot matches only in the leveling lane")

-- LevelingSting: same leveling gate (never steals the shared Arcane/Aimed CD).
local sv_ls = find(sv, "LevelingSting")
assert_false(sv_ls.matches({}, { pre_steady_leveling = false, in_combat = true, has_serpent_sting = false, serpent_sting_ready = true, mana_pct = 80 }),
    "survival LevelingSting must not fire when Aimed lane is active")
assert_false(sv_ls.matches({}, { pre_steady_leveling = true, in_combat = false, has_serpent_sting = false, serpent_sting_ready = true, mana_pct = 80 }),
    "survival LevelingSting must not fire OOC")
assert_true(sv_ls.matches({}, { pre_steady_leveling = true, in_combat = true, has_serpent_sting = false, serpent_sting_ready = true, mana_pct = 80 }),
    "survival LevelingSting matches in the leveling lane")

-- ExplosiveTrap: combat + proximity gates (no OOC foot-cast self-pull).
local sv_et = find(sv, "ExplosiveTrap")
assert_false(sv_et.matches({ target = {} }, { in_combat = false, enemy_count = 4, explosive_trap_ready = true }),
    "survival ExplosiveTrap must not fire OOC")
assert_false(sv_et.matches({ target = {}, distance = 20 }, { in_combat = true, enemy_count = 4, explosive_trap_ready = true }),
    "survival ExplosiveTrap must not fire at range (detonation cannot connect)")
assert_false(sv_et.matches({ target = {}, distance = 5 }, { in_combat = true, enemy_count = 2, explosive_trap_ready = true }),
    "survival ExplosiveTrap must not fire below the AoE enemy floor")
assert_true(sv_et.matches({ target = {}, distance = 5 }, { in_combat = true, enemy_count = 4, explosive_trap_ready = true }),
    "survival ExplosiveTrap matches in melee AoE")

-- MultiShot: in_combat + enemy-count gates (BM parity).
local sv_ms = find(sv, "MultiShot")
assert_false(sv_ms.matches({}, { in_combat = false, enemy_count = 4, multi_shot_ready = true, mana_pct = 80 }),
    "survival MultiShot must not fire OOC")
assert_false(sv_ms.matches({}, { in_combat = true, enemy_count = 1, multi_shot_ready = true, mana_pct = 80 }),
    "survival MultiShot must not fire on a single enemy")
assert_true(sv_ms.matches({}, { in_combat = true, enemy_count = 2, multi_shot_ready = true, mana_pct = 80 }),
    "survival MultiShot matches in combat with 2+ enemies")

-- FeignDeath: threat gate (no 30s-timer threat dump).
local sv_fd = find(sv, "FeignDeath")
assert_false(sv_fd.matches({}, { in_combat = true, fd_mode = "off", threat_level = 2, feign_death_ready = true }),
    "survival FeignDeath must not fire with fd_mode off")
assert_false(sv_fd.matches({}, { in_combat = true, fd_mode = "high_threat", threat_level = 1, feign_death_ready = true }),
    "survival FeignDeath must not fire below the high-threat threshold")
assert_true(sv_fd.matches({}, { in_combat = true, fd_mode = "high_threat", threat_level = 2, feign_death_ready = true }),
    "survival FeignDeath matches at high threat")

-- ViperSting: combat + target + target-mana gates.
local sv_vs = find(sv, "ViperSting")
assert_false(sv_vs.matches({}, { in_combat = false, viper_sting_ready = true }),
    "survival ViperSting must not fire OOC")
assert_false(sv_vs.matches({}, { in_combat = true, viper_sting_ready = true }),
    "survival ViperSting must not fire without a target")
assert_false(sv_vs.matches({ target = { get_mana_percentage = function() return 10 end } }, { in_combat = true, viper_sting_ready = true }),
    "survival ViperSting must not fire on a drained target")
assert_true(sv_vs.matches({ target = { get_mana_percentage = function() return 50 end } }, { in_combat = true, viper_sting_ready = true }),
    "survival ViperSting matches on a mana-rich target")

-- build_state wiring: pre_steady_leveling mirrors the MM leveling gate.
local sv_build = get_state("survival")
assert_true(sv_build({ level = 10, target = {} }).pre_steady_leveling,
    "survival pre_steady_leveling true pre-20")
assert_false(sv_build({ level = 60, target = {} }).pre_steady_leveling,
    "survival pre_steady_leveling false at 60 with Aimed learned")
assert_true(sv_build({ level = 60, is_leveling = true, target = {} }).pre_steady_leveling,
    "survival pre_steady_leveling true while leveling")

-- ============================================================================
-- marksmanship_vanilla.lua
-- ============================================================================
local mm = dofile("EaxRotations/classes/hunter/marksmanship_vanilla.lua")
if type(mm) == "table" and mm.strategies then mm = mm.strategies end
assert_true(type(mm) == "table" and #mm > 0, "MM strategies load")

-- MultiShot: in_combat + enemy-count gates.
local mm_ms = find(mm, "MultiShot")
assert_false(mm_ms.matches({}, { in_combat = false, enemy_count = 4, multi_shot_ready = true, mana_pct = 80 }),
    "MM MultiShot must not fire OOC")
assert_false(mm_ms.matches({}, { in_combat = true, enemy_count = 1, multi_shot_ready = true, mana_pct = 80 }),
    "MM MultiShot must not fire on a single enemy")
assert_true(mm_ms.matches({}, { in_combat = true, enemy_count = 2, multi_shot_ready = true, mana_pct = 80 }),
    "MM MultiShot matches in combat with 2+ enemies")

-- FeignDeath: threat gate.
local mm_fd = find(mm, "FeignDeath")
assert_false(mm_fd.matches({}, { in_combat = true, fd_mode = "off", threat_level = 2, feign_death_ready = true }),
    "MM FeignDeath must not fire with fd_mode off")
assert_false(mm_fd.matches({}, { in_combat = true, fd_mode = "high_threat", threat_level = 1, feign_death_ready = true }),
    "MM FeignDeath must not fire below the high-threat threshold")
assert_true(mm_fd.matches({}, { in_combat = true, fd_mode = "high_threat", threat_level = 2, feign_death_ready = true }),
    "MM FeignDeath matches at high threat")

-- ViperSting: combat + target + target-mana gates.
local mm_vs = find(mm, "ViperSting")
assert_false(mm_vs.matches({}, { in_combat = false, viper_sting_ready = true }),
    "MM ViperSting must not fire OOC")
assert_false(mm_vs.matches({}, { in_combat = true, viper_sting_ready = true }),
    "MM ViperSting must not fire without a target")
assert_false(mm_vs.matches({ target = { get_mana_percentage = function() return 10 end } }, { in_combat = true, viper_sting_ready = true }),
    "MM ViperSting must not fire on a drained target")
assert_true(mm_vs.matches({ target = { get_mana_percentage = function() return 50 end } }, { in_combat = true, viper_sting_ready = true }),
    "MM ViperSting matches on a mana-rich target")

-- build_state wiring: pre_steady_leveling + fd_mode default.
local mm_build = get_state("marksmanship")
assert_true(mm_build({ level = 10, target = {} }).pre_steady_leveling,
    "MM pre_steady_leveling true pre-20")
assert_false(mm_build({ level = 60, target = {} }).pre_steady_leveling,
    "MM pre_steady_leveling false at 60 with Aimed learned")
assert_eq_fd = mm_build({}).fd_mode
assert_true(assert_eq_fd == "off", "MM fd_mode defaults off")

-- ============================================================================
-- leveling_vanilla.lua — state.in_melee wiring (WingClip/RaptorStrike/MongooseBite)
-- ============================================================================
local lv = dofile("EaxRotations/classes/hunter/leveling_vanilla.lua")
assert_true(type(lv) == "table" and type(lv.build_state) == "function", "leveling module shape")

local lv_strategies = lv.strategies
local wing = find(lv_strategies, "WingClip")
local raptor = find(lv_strategies, "RaptorStrike")
local mongoose = find(lv_strategies, "MongooseBite")

-- In melee: all three melee lanes fire.
local ctx_melee = { in_combat = true, mana_pct = 100, hp = 40, enemies_count = 1, target = {}, in_melee_range = true }
local st_melee = get_state("leveling")(ctx_melee)
assert_true(st_melee.in_melee, "leveling state.in_melee populated from context.in_melee_range")
st_melee.wing_clip_ready = true
st_melee.raptor_strike_ready = true
st_melee.mongoose_bite_ready = true
assert_true(wing.matches(ctx_melee, st_melee), "leveling WingClip matches in melee")
assert_true(raptor.matches(ctx_melee, st_melee), "leveling RaptorStrike matches in melee")
assert_true(mongoose.matches(ctx_melee, st_melee), "leveling MongooseBite matches in melee")

-- Out of melee: all three stay dead.
local ctx_ranged = { in_combat = true, mana_pct = 100, hp = 40, enemies_count = 1, target = {}, in_melee_range = false }
local st_ranged = get_state("leveling")(ctx_ranged)
assert_false(st_ranged.in_melee, "leveling state.in_melee false when out of melee range")
st_ranged.wing_clip_ready = true
st_ranged.raptor_strike_ready = true
st_ranged.mongoose_bite_ready = true
assert_false(wing.matches(ctx_ranged, st_ranged), "leveling WingClip must not match at range")
assert_false(raptor.matches(ctx_ranged, st_ranged), "leveling RaptorStrike must not match at range")
assert_false(mongoose.matches(ctx_ranged, st_ranged), "leveling MongooseBite must not match at range")

-- Missing context field defaults to false (nil-guard, Pattern 14).
local ctx_bare = { in_combat = true, mana_pct = 100, hp = 40, enemies_count = 1, target = {} }
local st_bare = get_state("leveling")(ctx_bare)
assert_false(st_bare.in_melee, "leveling state.in_melee defaults false without context field")

print("PASS test_hunter_vanilla_live_fixes")
